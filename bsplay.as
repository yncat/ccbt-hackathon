/***************************************
BASS を、 ovplay 風に使うライブラリ
***************************************/
#module bsplay
	#uselib "bass.dll"
	#cfunc bass_errorGetCode "BASS_ErrorGetCode"
	#func bass_init "BASS_Init" int, int, int, int, int
	#func bass_free "BASS_Free"

	#cfunc bass_streamCreateFile "BASS_StreamCreateFile" int, sptr, double, int, int, int
	#func BASS_StreamFree "BASS_StreamFree" int

	#cfunc BASS_SampleLoad "BASS_SampleLoad" int, sptr, int, int, int, int, int
	#cfunc BASS_sampleGetChannel "BASS_SampleGetChannel" int, int
	#func BASS_SampleFree "BASS_SampleFree" int

	#func bass_channelPlay "BASS_ChannelPlay" int, int
	#func bass_channelPause "BASS_ChannelPause" int
	#func bass_channelStop "BASS_ChannelStop" int
	#func bass_ChannelGetAttribute "BASS_ChannelGetAttribute" int, int, var
	#func bass_ChannelSetAttribute "BASS_ChannelSetAttribute" int, int, float
	#func bass_ChannelSlideAttribute "BASS_ChannelSlideAttribute" int, int, float, int

	#func bass_channelFlags "BASS_ChannelFlags" int, int, int
	#cfunc BASS_ChannelIsActive "BASS_ChannelIsActive" int

	#cfunc BASS_GetConfig "BASS_GetConfig" int
	#func BASS_SetConfig "BASS_SetConfig" int, int
	#const BASS_CONFIG_GVOL_SAMPLE 4
	#const BASS_CONFIG_GVOL_STREAM 5

	#const BASS_ATTRIB_FREQ 1
	#const BASS_ATTRIB_VOLUME 2
	#const BASS_ATTRIB_PAN 3
	#const BASS_SAMPLE_LOOP 4

	; bs_loadで使用するフラグ
	#enum global BS_SAMPLE = 0
	#enum global BS_STREAM1
	#enum global BS_STREAM2
	#enum global BS_STREAM3
	#enum global BS_STREAM4
	#enum global BS_STREAM5

	; bs_setpan の値の範囲
	#const global BS_PAN_LEFT   -10000; 左
	#const global BS_PAN_CENTER      0; 中央
	#const global BS_PAN_RIGHT   10000; 右

	; bs_setvolume の値の範囲
	#const global BS_VOLUME_MIN -10000; 最低値
	#const global BS_VOLUME_MAX      0; 最大値

	; bs_setpitch の初期値
	#const global double BS_PITCH_DEFAULT 100.0

	; 拡張子
	#define	EXTNAME	".ogg"


	; BASSの初期化
	#deffunc bs_init int freq, int bits, int stereo, int ss
		bass_init -1, freq, 0, hwnd, 0
		if stat == 0 : dialog "Fatal error: Can not initialize BASS." : end
		sample_size = ss

		; サンプルプール
		; 実際にロードした音声のファイル名
		sdim loaded_filenames, 32, sample_size
		; 実際にロードした音声(ハンドル)
		dim loaded_handles, sample_size
		; ロードした音声の参照カウント (ロードで1増え、解放で1減る。0になるとサウンドプールから消える)
		dim loaded_sample_shared_count, sample_size

		; バッファ毎に持つ情報
		; ファイル名
		sdim filenames, 32, sample_size
		; ハンドルの種類
		dim handle_type, sample_size
		; ハンドルそのもの
		dim handles, sample_size
		; 再生チャンネル
		dim channels, sample_size
		; サンプルサイズ(ピッチ設定に必要)
		ddim freqs, sample_size
		; パン
		ddim pans, sample_size
		; 音量
		ddim volumes, sample_size
		; ピッチ
		dDim pitches, sample_size
		; ループ再生してるなら1
		dim is_loop, sample_size
		; ポーズ中なら1
		dim is_pause, sample_size

		; BGM再生用のハンドル (BGMは処理方法が異なるので別管理)
		dim original_stream_handles, 10
		; BGM用のメモリーバッファ1
		sdim memory_stream1
		; BGM用のメモリーバッファ2
		sdim memory_stream2
		; BGM用のメモリーバッファ3
		sdim memory_stream3
		; BGM用のメモリーバッファ4
		sdim memory_stream4
		; BGM用のメモリーバッファ5
		sdim memory_stream5

		return 1
	/*endfunc*/


	; BASSの解放 (終了時に自動で呼ぶ)
	#deffunc bs_finalize onexit
		bass_free
		return stat
	/*endfunc*/


	; ミキサーレベルでの効果音音量取得
	#define global bs_getSampleVolume BASS_GetConfig(BASS_CONFIG_GVOL_SAMPLE)


	; ミキサーレベルでのBGM音量取得
	#define global bs_getStreamVolume BASS_GetConfig(BASS_CONFIG_GVOL_STREAM)


	; ミキサーレベルでの効果音音量調整
	#deffunc bs_setSampleVolume int ivol
		BASS_SetConfig BASS_CONFIG_GVOL_SAMPLE, ivol
		return stat
	/*endfunc*/


	; ミキサーレベルでのBGM音量調整
	#deffunc bs_setStreamVolume int ivol
		BASS_SetConfig BASS_CONFIG_GVOL_STREAM, ivol
		return stat
	/*endfunc*/


	; ファイルのロード
	#deffunc bs_load str sFileName, int iChannel, int iType
		; フラグに応じてサンプル用、BGM用の関数を呼ぶ
		if iType { ; BGM系
			bs_streamLoad sFileName, iChannel, iType

		} else { ; 効果音系
			bs_sampleLoad sFileName, iChannel

		}
		return
	/*endfunc*/


	; 効果音のロード
	#deffunc local bs_sampleLoad str sFileName, int iChannel, local found
		; ロード済の音声があれば先に解放
		if handles.iChannel : bs_sampleRelease iChannel

		; サンプルプールに音声がロード済か調べる
		found = 1
		repeat sample_size
			; ロード済のサンプルがあれば、同じハンドルを指す
			if sFileName == loaded_filenames.cnt {
				bs_sampleLoad_from_samplePool sFileName, cnt, iChannel
				found = 0
				break
			}
		loop
		; サンプルプールから見つからなかった時は、新サンプルとして追加
		if found : bs_addSamplePool iChannel, sFileName
		return
	/*endfunc*/


	; サンプルプールへファイルを追加し、そのハンドルを返す
	#deffunc local bs_addSamplePool int iChannel, str sFileName, local snd_hwnd, local buf, local hed
		; ファイルを探す
		hed = ""
		exist sFileName + EXTNAME
		if strsize < 44 {
			exist "sound/" + sFileName + EXTNAME
			if strsize < 44 {
#ifdef _debug
				dialog sFileName + "がありません！"
#endif
				return
			} else : hed = "sound/"
		}

		; ロード
		sdim buf, strsize
		bload hed + sFileName + EXTNAME, buf, -1, 0
		snd_hwnd = BASS_SampleLoad(1, varptr(buf), 0, 0, strSize, 10000, 0)

		if SND_HWND {
			handles.iChannel = SND_HWND
			filenames.iChannel = sFileName
			handle_type.iChannel = 0
			bs_channelInit iChannel

			; サンプルプールに結果を格納
			repeat sample_size
				if loaded_handles.cnt : continue
				loaded_handles.cnt = snd_hwnd
				loaded_filenames.cnt = sFileName
				loaded_sample_shared_count.cnt = 1
				break; 終わったので抜ける
			loop
		}
		return
	/*endfunc*/


	; 既存のサンプルプールからファイルをロード
	#deffunc local bs_sampleLoad_from_samplePool str sFileName, int pool_cnt, int iChannel
		handles.iChannel = loaded_handles.pool_cnt
		filenames.iChannel = sFileName
		handle_type.iChannel = 0
		loaded_sample_shared_count.pool_cnt ++
		bs_channelInit iChannel
		return
	/*endfunc*/


	; BGMのロード
	#deffunc local bs_streamLoad str sFileName, int iChannel, int iType, local handle, local hed
		hed = ""
		exist sFileName + EXTNAME
		if strsize < 44 {
			exist "sound/" + sFileName + EXTNAME
			if strsize < 44 {
				#ifdef _debug
				dialog sFileName + "がありません！"
				#endif
				return 0
			} else : hed = "sound/"
		}

		switch iType
		case BS_stream1
			handle = private_bs_stream1_load(hed + sFileName + EXTNAME, strsize)
			swbreak

		case BS_stream2
			handle = private_bs_stream2_load(hed + sFileName + EXTNAME, strsize)
			swbreak

		case BS_stream3
			handle = private_bs_stream3_load(hed + sFileName + EXTNAME, strsize)
			swbreak

		case BS_stream4
			handle = private_bs_stream4_load(hed + sFileName + EXTNAME, strsize)
			swbreak

		case BS_stream5
			handle = private_bs_stream5_load(hed + sFileName + EXTNAME, strsize)
			swbreak

		swend

		handles.iChannel = handle
		filenames.iChannel = sFileName
		handle_type.iChannel = iType
		bs_channelInit iChannel
		return
	/*endfunc*/


	; バッファの解放
	#deffunc bs_releasebuf int iChannel
		if handles.iChannel {
			if handle_type.iChannel {
				bs_streamRelease iChannel

			} else {
				bs_sampleRelease iChannel

			}

			filenames.iChannel = ""
			handles.iChannel = 0
			bs_channelInit iChannel
		}
		return
	/*endfunc*/


	; 効果音の解放
	#deffunc local bs_sampleRelease int iChannel, local handle_in_ichannel
		; 対応するサンプルプールの参照カウントを減らす
		dup handle_in_iChannel, handles.iChannel

		repeat sample_size
			if handle_in_iChannel != loaded_handles.cnt : continue
			; 参照カウントを減らす
			loaded_sample_shared_count.cnt --
			if loaded_sample_shared_count.cnt > 0 : break
			BASS_sampleFree loaded_handles.cnt
			loaded_filenames.cnt = ""
			loaded_handles.cnt = 0
			break; ここで抜ける
		loop
		return
	/*endfunc*/


	; BGMの解放
	#deffunc local bs_streamRelease int iChannel
		BASS_StreamFree handles.iChannel
		original_stream_handles(handle_type.iChannel) = 0
		return 1
	/*endfunc*/


	; 再生
	#deffunc bs_play int iChannel
		if handles.iChannel == 0 : return

		is_pause.iChannel = 0
		is_loop.iChannel = 0
		private_bs_getChannelAttribute iChannel
		bass_channelPlay channels.iChannel, 1
		if stat == 0 : channels.iChannel = 0
		return
	/*endfunc*/


	; ポーズした位置から再生
	#deffunc bs_resume int iChannel
		if handles.iChannel == 0 : return

		if is_pause.iChannel == 0 : return
		private_bs_getChannelAttribute iChannel
		bass_channelPlay channels.iChannel
		if stat == 0 : channels.iChannel = 0
		return
	/*endfunc*/


	; ループ再生
	#deffunc bs_loop int iChannel
		if handles.iChannel == 0 : return

		is_pause.iChannel = 0
		is_loop.iChannel = 1
		private_bs_getChannelAttribute iChannel
		bass_channelFlags channels.iChannel, BASS_SAMPLE_LOOP, BASS_SAMPLE_LOOP
		bass_channelPlay channels.iChannel, 1
		if stat == 0 : channels.iChannel = 0
		return
	/*endfunc*/


	; 一時停止
	#deffunc bs_pause int iChannel
		if handles.iChannel == 0 : return

		is_pause.iChannel = 1
		bass_channelPause channels.iChannel
		return stat
	/*endfunc*/


	; 再生停止
	#deffunc bs_stop int iChannel
		if handles.iChannel == 0 : return

		bass_channelStop channels.iChannel
		bs_channelInit iChannel
		return
	/*endfunc*/


	; 再生中ならtrue
	#defcfunc _bs_getstatus int iChannel
		if channels.iChannel {
			if bass_channelIsActive(channels.iChannel) : return 1 + is_loop.iChannel
		}
		return 0
	/*endfunc*/


	; _bs_getstatus の命令版
	#deffunc bs_getstatus int iChannel
		return _bs_getStatus(iChannel)
	/*endfunc*/


	; パン設定
	#deffunc bs_setpan int iChannel, int iPan, int iSlide
		pans.iChannel = 0.0001 * iPan
		if channels.iChannel {
			if _bs_getStatus(iChannel) {
				if iSlide {
					BASS_channelSlideAttribute channels.iChannel, BASS_ATTRIB_PAN, pans.iChannel, iSlide
				} else {
					BASS_channelSetAttribute channels.iChannel, BASS_ATTRIB_PAN, pans.iChannel
				}
			}
		}
		return
	/*endfunc*/


	; 音量を設定
	#deffunc bs_setvolume int iChannel, int iVolume, int iSlide
		volumes.iChannel = 0.0001 * (10000 + iVolume)
		if channels.iChannel {
			if _bs_getStatus(iChannel) {
				if iSlide {
					BASS_channelSlideAttribute channels.iChannel, BASS_ATTRIB_VOLUME, volumes.iChannel, iSlide
				} else {
					BASS_channelSetAttribute channels.iChannel, BASS_ATTRIB_VOLUME, volumes.iChannel
				}
			}
		}
		return
	/*endfunc*/


	; ピッチを設定
	#deffunc bs_setPitch int iChannel, double dPitch
		pitches.iChannel = dPitch
		if channels.iChannel {
			if _bs_getstatus(iChannel) : BASS_channelSetAttribute channels.iChannel, BASS_ATTRIB_FREQ, 441 * pitches.iChannel
		}
		return
	/*endfunc*/


	; 指定IDにロードしたファイル名を得る
	#defcfunc bs_getfilename int iChannel
		return filenames.iChannel
	/*endfunc*/


	; 指定チャネルをフェイドアウト
	#deffunc bs_fadeout int iChannel
		while volumes.iChannel > 0.0
			volumes.iChannel -= 0.015
			if _bs_getStatus(iChannel) : BASS_channelSetAttribute channels.iChannel, BASS_ATTRIB_VOLUME, volumes.iChannel : await 20
		wend
		bs_stop iChannel
		return
	/*endfunc*/


	; ループ再生のフラグを設定する
	#deffunc bs_setloop int iChannel, int lp
		if lp {
			bass_channelFlags channels.iChannel, BASS_SAMPLE_LOOP, BASS_SAMPLE_LOOP
		} else {
			bass_channelFlags channels.iChannel
		}
		return
	/*endfunc*/


	; ループ再生してたか否かを返す
	#defcfunc bs_getloop int iChannel
		return is_loop.iChannel
	/*endfunc*/


	; エラーコード取得
	#defcfunc bs_getError
	switch(bass_errorGetCode())
		case 0 : return "BASS OK"
		case 1 : return "BASS ERROR MEM"
		case 2 : return "BASS ERROR FILEOPEN"
		case 3 : return "BASS ERROR DRIVER"
		case 4 : return "BASS ERROR BUFLOST"
		case 5 : return "BASS ERROR HANDLE"
		case 6 : return "BASS ERROR FORMAT"
		case 7 : return "BASS ERROR POSITION"
		case 8 : return "BASS ERROR INIT"
		case 9 : return "BASS ERROR START"
		case 10 : return "BASS ERROR SSL"
		case 14 : return "BASS ERROR ALREADY"
		case 18 : return "BASS ERROR NOCHAN"
		case 19 : return "BASS ERROR ILLTYPE"
		case 20 : return "BASS ERROR ILLPARAM"
		case 21 : return "BASS ERROR NO3D"
		case 22 : return "BASS ERROR NOEAX"
		case 23 : return "BASS ERROR DEVICE"
		case 24 : return "BASS ERROR NOPLAY"
		case 25 : return "BASS ERROR FREQ"
		case 27 : return "BASS ERROR NOTFILE"
		case 29 : return "BASS ERROR NOHW"
		case 31 : return "BASS ERROR EMPTY"
		case 32 : return "BASS ERROR NONET"
		case 33 : return "BASS ERROR CREATE"
		case 34 : return "BASS ERROR NOFX"
		case 37 : return "BASS ERROR NOTAVAIL"
		case 38 : return "BASS ERROR DECODE"
		case 39 : return "BASS ERROR DX"
		case 40 : return "BASS ERROR TIMEOUT"
		case 41 : return "BASS ERROR FILEFORM"
		case 42 : return "BASS ERROR SPEAKER"
		case 43 : return "BASS ERROR VERSION"
		case 44 : return "BASS ERROR CODEC"
		case 45 : return "BASS ERROR ENDED"
		case 46 : return "BASS ERROR BUSY"
		default : return "BASS ERROR UNKNOWN"
	swend
	/*endfunc*/


	; 有効なチャンネルを取得
	#deffunc local private_bs_getChannel int iChannel, local fFreq
		switch handle_type.iChannel
		case BS_SAMPLE
			channels.iChannel = BASS_SampleGetChannel(handles.iChannel, 0)
				if channels.iChannel {
				BASS_ChannelGetAttribute channels.iChannel, BASS_ATTRIB_FREQ, fFreq
				freqs.iChannel = private_float_to_double(fFreq)
			}
			swbreak

		default
			channels.iChannel = handles.iChannel

		swend
		return
	/*endfunc*/


	; チャネルの状態を取得
	#deffunc local private_bs_getChannelAttribute int iChannel
		if channels.iChannel == 0 : private_bs_getChannel iChannel

		bass_ChannelSetAttribute channels.iChannel, BASS_ATTRIB_PAN, pans.iChannel
		bass_ChannelSetAttribute channels.iChannel, BASS_ATTRIB_VOLUME, volumes.iChannel
		bass_channelSetAttribute channels.iChannel, BASS_ATTRIB_FREQ, freqs.iChannel * 0.01 * pitches.iChannel
		return
	/*endfunc*/


	#defcfunc local private_bs_stream1_load str sFileName, int bufSize
		if original_stream_handles.0 : BASS_StreamFree original_stream_handles.0
		sdim memory_stream1, bufSize
		bload sFileName, memory_stream1, -1, 0
		original_stream_handles.0 = bass_streamCreateFile(1, varptr(memory_stream1), 0.0, strsize, 0, 0)
		return original_stream_handles.0
	/*endfunc*/


	#defcfunc local private_bs_stream2_load str sFileName, int bufSize
		if original_stream_handles.1 : BASS_StreamFree original_stream_handles.1
		sdim memory_stream2, bufSize
		bload sFileName, memory_stream2, -1, 0
		original_stream_handles.1 = bass_streamCreateFile(1, varptr(memory_stream2), 0.0, strSize, 0, 0)
		return original_stream_handles.1
	/*endfunc*/


	#defcfunc local private_bs_stream3_load str sFileName, int bufSize
		if original_stream_handles.2 : BASS_StreamFree original_stream_handles.2
		sdim memory_stream3, bufSize
		bload sFileName, memory_stream3, -1, 0
		original_stream_handles.2 = bass_streamCreateFile(1, varptr(memory_stream3), 0.0, strSize, 0, 0)
		return original_stream_handles.2
	/*endfunc*/


	#defcfunc local private_bs_stream4_load str sFileName, int bufSize
		if original_stream_handles.3 : BASS_StreamFree original_stream_handles.3
		sdim memory_stream4, bufSize
		bload sFileName, memory_stream4, -1, 0
		original_stream_handles.3 = bass_streamCreateFile(1, varptr(memory_stream4), 0.0, strSize, 0, 0)
		return original_stream_handles.3
	/*endfunc*/


	#defcfunc local private_bs_stream5_load str sFileName, int bufSize
		if original_stream_handles.4 : BASS_StreamFree original_stream_handles.4
		sdim memory_stream5, bufSize
		bload sFileName, memory_stream5, -1, 0
		original_stream_handles.4 = bass_streamCreateFile(1, varptr(memory_stream5), 0.0, strSize, 0, 0)
		return original_stream_handles.4
	/*endfunc*/


	#deffunc local bs_channelInit int iChannel
		channels.iChannel = 0
		pans.iChannel = 0.0
		volumes.iChannel = 1.0
		pitches.iChannel = 0.0
		is_loop.iChannel = 0
		is_pause.iChannel = 0
		return
	/*endfunc*/


	#defcfunc local private_float_to_double int p1, local ret_
		ret_ = 0.0

		if ((p1 and 0x7F800000) == 0x7F800000) {
			lpoke ret_, 4, (p1 and 0x80000000) or (0x7FF00000) or ((p1 >> 3) and 0x000FFFFF)
			lpoke ret_, 0, (p1 << 29) and 0xE0000000

		} else : if ((p1 and 0x7F800000) == 0x00000000) {
			if ((p1 and 0x007FFFFF) == 0x00000000) {
				lpoke ret_, 4, p1 and 0x80000000

			} else {
				repeat 23
					if (((p1 << 9 << cnt) and 0x80000000) != 0) {
						lpoke ret_, 4, (p1 and 0x80000000) or (((((p1 >> 23) and 0xFF) - 127 + 1023 - cnt) << 20) and 0x7FF00000) or ((p1 << cnt >> 2) and 0x000FFFFF)
						lpoke ret_, 0, (p1 << cnt << 30) and 0xE0000000
						break
					}
				loop
			}

		} else {
			lpoke ret_, 4, (p1 and 0x80000000) or (((((p1 >> 23) and 0xFF) - 127 + 1023) << 20) and 0x7FF00000) or ((p1 >> 3) and 0x000FFFFF)
			lpoke ret_, 0, (p1 << 29) and 0xE0000000
		}

		return ret_
	/*endfunc*/

#global
