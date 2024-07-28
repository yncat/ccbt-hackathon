import ctypes
import struct

with open("hwnd.tmp", "rb") as f:
    hwnd = struct.unpack("L", f.read())[0]


command = "stoptheme".encode("UTF-8")
commandPointer = ctypes.cast(ctypes.create_string_buffer(command), ctypes.c_void_p)
copydatastruct = struct.pack("LLP", 0, len(command), commandPointer.value)
ctypes.windll.user32.SendMessageW(hwnd, 0x004A, 0, copydatastruct)