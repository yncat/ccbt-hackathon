# 必要なファイルを dist ディレクトリにコピーして圧縮する
# バージョンは version.txt から取得する
import shutil
import os
import zipfile

# バージョンを取得
with open('version.txt', 'r') as f:
    version = f.read().strip()

dir = f'dist/ol_{version}'

# すでに同じバージョンのビルドがあれば削除
if os.path.exists(f'{dir}.zip'):
    os.remove(f'{dir}.zip')
if os.path.isdir(dir):
    shutil.rmtree(dir)

# ディレクトリを作成
os.makedirs(dir, exist_ok=True)

# 必要なファイルをコピー
files = [
    "ol.py",
    "ol.bat",
    "ol_heart.exe",
    "ovplay.dll",
    "bass.dll",
    "requirements.txt",
    "readme.md",
    "version.txt"
]

for file in files:
    shutil.copy(file, dir)

# fx ディレクトリをコピー
shutil.copytree('fx', f'{dir}/fx')

# 圧縮
with zipfile.ZipFile(f'dist/ol_{version}.zip', 'w', zipfile.ZIP_DEFLATED) as new_zip:
    for root, dirs, files in os.walk(dir):
        for file in files:
            new_zip.write(os.path.join(root, file), os.path.relpath(os.path.join(root, file), "dist"))

print("Built ol_" + version + ".zip")
