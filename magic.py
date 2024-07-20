import asyncio
import ctypes
import time
import random
from bleak import BleakClient, discover
import glob
import os
import struct
import subprocess

class IPC:
    def __init__(self):
        try:
            with open("hwnd.tmp", "rb") as f:
                self.hwnd = struct.unpack("L", f.read())[0]
        except BaseException as e:
            raise RuntimeError("hwnd.tmp を読めません、 Magical Base を起動してますか？ %s" % e)

    def send(self, command):
        command = command.encode("UTF-8")
        commandPointer = ctypes.cast(ctypes.create_string_buffer(command), ctypes.c_void_p)
        copydatastruct = struct.pack("LLP", 0, len(command), commandPointer.value)
        ctypes.windll.user32.SendMessageW(self.hwnd, 0x004A, 0, copydatastruct)

class GlobalState:
    def __init__(self):
        self.timer = time.time()
        self.step = "not_costumed"
        self.attacking = False
        self.totalCharges = 0
        self.lives = 3

    def timerRestart(self):
        self.timer = time.time()

    def timerElapsed(self):
        return time.time() - self.timer

def lucky():
    return random.randint(1, 20) == 1


globalState = GlobalState()
ipc = IPC()

# UUID
CORE_INDICATE_UUID = ('72c90005-57a9-4d40-b746-534e22ec9f9e')
CORE_NOTIFY_UUID = ('72c90003-57a9-4d40-b746-534e22ec9f9e')
CORE_WRITE_UUID = ('72c90004-57a9-4d40-b746-534e22ec9f9e')

# Constant values
MESSAGE_TYPE_INDEX = 0
EVENT_TYPE_INDEX = 1
STATE_INDEX = 2
MESSAGE_TYPE_ID = 1
EVENT_TYPE_ID = 0

# Callback
def on_receive_notify(sender, data: bytearray):
    message_type = data[MESSAGE_TYPE_INDEX]
    event_type = data[EVENT_TYPE_INDEX]
    if event_type == 3:
        if data[2] == 3:
            cast()
        else:
            charge()

def cast():
    if globalState.step == "ready":
        globalState.attacking = False
        loop = asyncio.get_event_loop()
        loop.create_task(cast1hit())
    if globalState.step == "ready2":
        loop = asyncio.get_event_loop()
        loop.create_task(cast2hit())

async def cast1hit():
    globalState.step = "wait"
    playSound("cast_hit1.wav")
    await asyncio.sleep(7)
    globalState.step = "ready2"
    globalState.totalCharges = 0
    globalState.timerRestart()

async def cast2hit():
    globalState.step = "wait"
    playSound("cast_hit2.wav")
    await asyncio.sleep(6)
    if lucky():
        playSound("monster_defeat_blooper.wav")
    else:
        playSound("monster_defeat1.wav")
    await asyncio.sleep(7)
    if lucky():
        playSound("girl_win1_blooper.wav")
        await asyncio.sleep(15)
        playSound("outro.wav")
        await asyncio.sleep(21)
    else:
        playSound("girl_win2.wav")
        await asyncio.sleep(7)
        playSound("outro.wav")
        await asyncio.sleep(21)
    globalState.step = "end"

def charge():
    if globalState.step == "costumed" or globalState.step == "wait":
        return
    globalState.totalCharges += 1
    if globalState.step == "ready" and globalState.totalCharges == 1:
        playSound("ready.wav")
    if globalState.step == "ready2" and globalState.totalCharges == 1:
        playSound("ready.wav")
    print("Charge %d!" % globalState.totalCharges)
    if globalState.step == "not_costumed" and globalState.totalCharges >= 5:
        globalState.step = "costumed"
        globalState.totalCharges = 0
        loop = asyncio.get_event_loop()
        loop.create_task(costumedSound())

async def costumedSound():
    globalState.step = "wait"
    playSound("costumed.wav")
    await asyncio.sleep(15)
    globalState.step = "ready"


def on_receive_indicate(sender, data: bytearray):
    print("on_receive_indicate")

async def introSound():
    playSound("monster_intro1.wav")
    await asyncio.sleep(10)
    playSound("girl_intro1.wav")

async def scan(prefix='MESH-100'):
    while True:
        print('scan...')
        try:
            return next(d for d in await discover() if d.name and d.name.startswith(prefix))
        except StopIteration:
            continue

async def main():
    # intro sound
    loop = asyncio.get_event_loop()
    loop.create_task(introSound())
    # Scan device
    device = await scan('MESH-100AC')
    print('found', device.name, device.address)

    # Connect device
    async with BleakClient(device, timeout=None) as client:
        # Initialize
        await client.start_notify(CORE_NOTIFY_UUID, on_receive_notify)
        await client.start_notify(CORE_INDICATE_UUID, on_receive_indicate)
        await client.write_gatt_char(CORE_WRITE_UUID, struct.pack('<BBBB', 0, 2, 1, 3), response=True)
        print('connected')

        while(True):
            await asyncio.sleep(1)
            if globalState.step == "ready" or globalState.step == "ready2":
                attackCheck()
            if globalState.attacking and globalState.timerElapsed() >= 1:
                loop.create_task(attackHit())
            if globalState.step == "end":
                break

        # Finish

def attackCheck():
    if globalState.timerElapsed() > 10:
        loop = asyncio.get_event_loop()
        loop.create_task(attack())

async def attack():
    playSound("sleep_shoot.wav")
    globalState.timerRestart()
    globalState.attacking = True

async def attackHit():
    prevStep = globalState.step
    globalState.totalCharges = 0
    globalState.step = "wait"
    globalState.attacking = False
    playSound("sleep_hit.wav")
    await asyncio.sleep(3)
    globalState.lives -= 1
    if globalState.lives == 0:
        playSound("girl_defeat1.wav")
        await asyncio.sleep(5)
        globalState.step = "end"
    elif globalState.lives == 1:
        playSound("girl_hit2.wav")
        await asyncio.sleep(3)
        globalState.step = prevStep
    elif globalState.lives == 2:
        playSound("girl_hit1.wav")
        await asyncio.sleep(4)
        globalState.step = prevStep
    globalState.timerRestart()


def playSound(name):
    name = os.path.join(os.getcwd(), "fx", name)
    ipc.send("playoneshot %s" % name)

def onConnected():
    pass

# Initialize event loop
if __name__ == '__main__':
    totalCharges = 0
    casted = False
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())
