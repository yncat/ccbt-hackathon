import glob
import os
import socket
import bgtsound

def loadSoundFolder(self, path):
    files = glob.glob("fx/" + path + "/*.ogg")
    for elem in files:
        self.sounds[path + "/" +
                        os.path.basename(elem)] = sound_lib.sample.Sample(elem)
    # end loadSounds

server_ip = "127.0.0.1"
server_port = 8000
listen_num = 5
buffer_size = 1024


tcp_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
tcp_server.bind((server_ip, server_port))
tcp_server.listen(listen_num)
while True:
    client,address = tcp_server.accept()
    print("[*] Connected!! [ Source : {}]".format(address))

    # 6.データを受信する
    while(True):
        data = client.recv(buffer_size).decode("UTF-8")
        print("[*] Received Data : {}".format(data))
