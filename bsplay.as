/***************************************
BASS ���A ovplay ���Ɏg�����C�u����
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

	; bs_load�Ŏg�p����t���O
	#enum global BS_SAMPLE = 0
	#enum global BS_STREAM1
	#enum global BS_STREAM2
	#enum global BS_STREAM3
	#enum global BS_STREAM4
	#enum global BS_STREAM5

	; bs_setpan �̒l�͈̔�
	#const global BS_PAN_LEFT   -10000; ��
	#const global BS_PAN_CENTER      0; ����
	#const global BS_PAN_RIGHT   10000; �E

	; bs_setvolume �̒l�͈̔�
	#const global BS_VOLUME_MIN -10000; �Œ�l
	#const global BS_VOLUME_MAX      0; �ő�l

	; bs_setpitch �̏����l
	#const global double BS_PITCH_DEFAULT 100.0

	; �g���q
	#define	EXTNAME	".ogg"


	; BASS�̏�����
	#deffunc bs_init int freq, int bits, int stereo, int ss
		bass_init -1, freq, 0, hwnd, 0
		if stat == 0 : dialog "Fatal error: Can not initialize BASS." : end
		sample_size = ss

		; �T���v���v�[��
		; ���ۂɃ��[�h���������̃t�@�C����
		sdim loaded_filenames, 32, sample_size
		; ���ۂɃ��[�h��������(�n���h��)
		dim loaded_handles, sample_size
		; ���[�h���������̎Q�ƃJ�E���g (���[�h��1�����A�����1����B0�ɂȂ�ƃT�E���h�v�[�����������)
		dim loaded_sample_shared_count, sample_size

		; �o�b�t�@���Ɏ����
		; �t�@�C����
		sdim filenames, 32, sample_size
		; �n���h���̎��
		dim handle_type, sample_size
		; �n���h�����̂���
		dim handles, sample_size
		; �Đ��`�����l��
		dim channels, sample_size
		; �T���v���T�C�Y(�s�b�`�ݒ�ɕK�v)
		ddim freqs, sample_size
		; �p��
		ddim pans, sample_size
		; ����
		ddim volumes, sample_size
		; �s�b�`
		dDim pitches, sample_size
		; ���[�v�Đ����Ă�Ȃ�1
		dim is_loop, sample_size
		; �|�[�Y���Ȃ�1
		dim is_pause, sample_size

		; BGM�Đ��p�̃n���h�� (BGM�͏������@���قȂ�̂ŕʊǗ�)
		dim original_stream_handles, 10
		; BGM�p�̃������[�o�b�t�@1
		sdim memory_stream1
		; BGM�p�̃������[�o�b�t�@2
		sdim memory_stream2
		; BGM�p�̃������[�o�b�t�@3
		sdim memory_stream3
		; BGM�p�̃������[�o�b�t�@4
		sdim memory_stream4
		; BGM�p�̃������[�o�b�t�@5
		sdim memory_stream5

		return 1
	/*endfunc*/


	; BASS�̉�� (�I�����Ɏ����ŌĂ�)
	#deffunc bs_finalize onexit
		bass_free
		return stat
	/*endfunc*/


	; �~�L�T�[���x���ł̌��ʉ����ʎ擾
	#define global bs_getSampleVolume BASS_GetConfig(BASS_CONFIG_GVOL_SAMPLE)


	; �~�L�T�[���x���ł�BGM���ʎ擾
	#define global bs_getStreamVolume BASS_GetConfig(BASS_CONFIG_GVOL_STREAM)


	; �~�L�T�[���x���ł̌��ʉ����ʒ���
	#deffunc bs_setSampleVolume int ivol
		BASS_SetConfig BASS_CONFIG_GVOL_SAMPLE, ivol
		return stat
	/*endfunc*/


	; �~�L�T�[���x���ł�BGM���ʒ���
	#deffunc bs_setStreamVolume int ivol
		BASS_SetConfig BASS_CONFIG_GVOL_STREAM, ivol
		return stat
	/*endfunc*/


	; �t�@�C���̃��[�h
	#deffunc bs_load str sFileName, int iChannel, int iType
		; �t���O�ɉ����ăT���v���p�ABGM�p�̊֐����Ă�
		if iType { ; BGM�n
			bs_streamLoad sFileName, iChannel, iType

		} else { ; ���ʉ��n
			bs_sampleLoad sFileName, iChannel

		}
		return
	/*endfunc*/


	; ���ʉ��̃��[�h
	#deffunc local bs_sampleLoad str sFileName, int iChannel, local found
		; ���[�h�ς̉���������ΐ�ɉ��
		if handles.iChannel : bs_sampleRelease iChannel

		; �T���v���v�[���ɉ��������[�h�ς����ׂ�
		found = 1
		repeat sample_size
			; ���[�h�ς̃T���v��������΁A�����n���h�����w��
			if sFileName == loaded_filenames.cnt {
				bs_sampleLoad_from_samplePool sFileName, cnt, iChannel
				found = 0
				break
			}
		loop
		; �T���v���v�[�����猩����Ȃ��������́A�V�T���v���Ƃ��Ēǉ�
		if found : bs_addSamplePool iChannel, sFileName
		return
	/*endfunc*/


	; �T���v���v�[���փt�@�C����ǉ����A���̃n���h����Ԃ�
	#deffunc local bs_addSamplePool int iChannel, str sFileName, local snd_hwnd, local buf, local hed
		; �t�@�C����T��
		hed = ""
		exist sFileName + EXTNAME
		if strsize < 44 {
			exist "sound/" + sFileName + EXTNAME
			if strsize < 44 {
#ifdef _debug
				dialog sFileName + "������܂���I"
#endif
				return
			} else : hed = "sound/"
		}

		; ���[�h
		sdim buf, strsize
		bload hed + sFileName + EXTNAME, buf, -1, 0
		snd_hwnd = BASS_SampleLoad(1, varptr(buf), 0, 0, strSize, 10000, 0)

		if SND_HWND {
			handles.iChannel = SND_HWND
			filenames.iChannel = sFileName
			handle_type.iChannel = 0
			bs_channelInit iChannel

			; �T���v���v�[���Ɍ��ʂ��i�[
			repeat sample_size
				if loaded_handles.cnt : continue
				loaded_handles.cnt = snd_hwnd
				loaded_filenames.cnt = sFileName
				loaded_sample_shared_count.cnt = 1
				break; �I������̂Ŕ�����
			loop
		}
		return
	/*endfunc*/


	; �����̃T���v���v�[������t�@�C�������[�h
	#deffunc local bs_sampleLoad_from_samplePool str sFileName, int pool_cnt, int iChannel
		handles.iChannel = loaded_handles.pool_cnt
		filenames.iChannel = sFileName
		handle_type.iChannel = 0
		loaded_sample_shared_count.pool_cnt ++
		bs_channelInit iChannel
		return
	/*endfunc*/


	; BGM�̃��[�h
	#deffunc local bs_streamLoad str sFileName, int iChannel, int iType, local handle, local hed
		hed = ""
		exist sFileName + EXTNAME
		if strsize < 44 {
			exist "sound/" + sFileName + EXTNAME
			if strsize < 44 {
				#ifdef _debug
				dialog sFileName + "������܂���I"
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


	; �o�b�t�@�̉��
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


	; ���ʉ��̉��
	#deffunc local bs_sampleRelease int iChannel, local handle_in_ichannel
		; �Ή�����T���v���v�[���̎Q�ƃJ�E���g�����炷
		dup handle_in_iChannel, handles.iChannel

		repeat sample_size
			if handle_in_iChannel != loaded_handles.cnt : continue
			; �Q�ƃJ�E���g�����炷
			loaded_sample_shared_count.cnt --
			if loaded_sample_shared_count.cnt > 0 : break
			BASS_sampleFree loaded_handles.cnt
			loaded_filenames.cnt = ""
			loaded_handles.cnt = 0
			break; �����Ŕ�����
		loop
		return
	/*endfunc*/


	; BGM�̉��
	#deffunc local bs_streamRelease int iChannel
		BASS_StreamFree handles.iChannel
		original_stream_handles(handle_type.iChannel) = 0
		return 1
	/*endfunc*/


	; �Đ�
	#deffunc bs_play int iChannel
		if handles.iChannel == 0 : return

		is_pause.iChannel = 0
		is_loop.iChannel = 0
		private_bs_getChannelAttribute iChannel
		bass_channelPlay channels.iChannel, 1
		if stat == 0 : channels.iChannel = 0
		return
	/*endfunc*/


	; �|�[�Y�����ʒu����Đ�
	#deffunc bs_resume int iChannel
		if handles.iChannel == 0 : return

		if is_pause.iChannel == 0 : return
		private_bs_getChannelAttribute iChannel
		bass_channelPlay channels.iChannel
		if stat == 0 : channels.iChannel = 0
		return
	/*endfunc*/


	; ���[�v�Đ�
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


	; �ꎞ��~
	#deffunc bs_pause int iChannel
		if handles.iChannel == 0 : return

		is_pause.iChannel = 1
		bass_channelPause channels.iChannel
		return stat
	/*endfunc*/


	; �Đ���~
	#deffunc bs_stop int iChannel
		if handles.iChannel == 0 : return

		bass_channelStop channels.iChannel
		bs_channelInit iChannel
		return
	/*endfunc*/


	; �Đ����Ȃ�true
	#defcfunc _bs_getstatus int iChannel
		if channels.iChannel {
			if bass_channelIsActive(channels.iChannel) : return 1 + is_loop.iChannel
		}
		return 0
	/*endfunc*/


	; _bs_getstatus �̖��ߔ�
	#deffunc bs_getstatus int iChannel
		return _bs_getStatus(iChannel)
	/*endfunc*/


	; �p���ݒ�
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


	; ���ʂ�ݒ�
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


	; �s�b�`��ݒ�
	#deffunc bs_setPitch int iChannel, double dPitch
		pitches.iChannel = dPitch
		if channels.iChannel {
			if _bs_getstatus(iChannel) : BASS_channelSetAttribute channels.iChannel, BASS_ATTRIB_FREQ, 441 * pitches.iChannel
		}
		return
	/*endfunc*/


	; �w��ID�Ƀ��[�h�����t�@�C�����𓾂�
	#defcfunc bs_getfilename int iChannel
		return filenames.iChannel
	/*endfunc*/


	; �w��`���l�����t�F�C�h�A�E�g
	#deffunc bs_fadeout int iChannel
		while volumes.iChannel > 0.0
			volumes.iChannel -= 0.015
			if _bs_getStatus(iChannel) : BASS_channelSetAttribute channels.iChannel, BASS_ATTRIB_VOLUME, volumes.iChannel : await 20
		wend
		bs_stop iChannel
		return
	/*endfunc*/


	; ���[�v�Đ��̃t���O��ݒ肷��
	#deffunc bs_setloop int iChannel, int lp
		if lp {
			bass_channelFlags channels.iChannel, BASS_SAMPLE_LOOP, BASS_SAMPLE_LOOP
		} else {
			bass_channelFlags channels.iChannel
		}
		return
	/*endfunc*/


	; ���[�v�Đ����Ă����ۂ���Ԃ�
	#defcfunc bs_getloop int iChannel
		return is_loop.iChannel
	/*endfunc*/


	; �G���[�R�[�h�擾
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


	; �L���ȃ`�����l�����擾
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


	; �`���l���̏�Ԃ��擾
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
