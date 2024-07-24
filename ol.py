import asyncio
import ctypes
import os
import random
import struct
import time
from bleak import BleakClient, BleakScanner

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
        self.reset()

    def reset(self):
        self.timer = time.time()
        self.step = "welcome"
        self.attacking = False
        self.totalCharges = 0
        self.maxCharges = 0
        self.lives = 3
        self.cleared = False

    def timerRestart(self):
        self.timer = time.time()

    def timerElapsed(self):
        return time.time() - self.timer

def lucky():
    return random.randint(1, 20) == 1


class DeviceScanner:
    def __init__(self):
        self.motionDevice = None
        self.buttonDevice = None

    async def scanDevices(self):
        async with BleakScanner(detection_callback=self.onDeviceDetected) as scanner:
            for i in range(30):
                await asyncio.sleep(1)
                if self.motionDevice is not None and self.buttonDevice is not None:
                    break
                # end if
            # end for
        # end with scan
        if self.motionDevice is None or self.buttonDevice is None:
            raise RuntimeError("デバイスが見つかりませんでした。電源が入っているか確認してください。 モーション = %s, ボタン = %s" % (self.motionDevice, self.buttonDevice))

    def onDeviceDetected(self, device, advertising_data):
        if device.name is None:
            return
        # end unnamed device
        if self.motionDevice is None and device.name.startswith("MESH-100AC"): # motion
            self.motionDevice = device
            print("motion device found")
        if self.buttonDevice is None and device.name.startswith("MESH-100BU"): # button
            self.buttonDevice = device
            print("button device found")


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
def on_motion_receive_notify(sender, data: bytearray):
    message_type = data[MESSAGE_TYPE_INDEX]
    event_type = data[EVENT_TYPE_INDEX]
    if event_type == 1:
        charge()
    if event_type == 3:
        if data[2] == 3:
            cast()
        else:
            charge()

def cast():
    if globalState.totalCharges < globalState.maxCharges:
        return
    if globalState.step == "ready":
        globalState.attacking = False
        loop = asyncio.get_event_loop()
        loop.create_task(cast1hit())
    if globalState.step == "ready2":
        loop = asyncio.get_event_loop()
        loop.create_task(cast2hit())

async def cast1hit():
    globalState.step = "wait"
    ipc.send("chargestopwith fx\\cast_hit1.wav")
    await asyncio.sleep(5.5)
    globalState.step = "ready2"
    globalState.totalCharges = 0
    globalState.maxCharges = 13
    globalState.timerRestart()
    playSound("action.ogg")

async def cast2hit():
    globalState.cleared  = True
    globalState.step = "wait"
    ipc.send("chargestopwith fx\\cast_hit2.wav")
    await asyncio.sleep(3)
    ipc.send("fadeouttheme")
    await asyncio.sleep(3)
    if lucky():
        playSound("monster_defeat_blooper.wav")
    else:
        playSound("monster_defeat1.wav")
    await asyncio.sleep(7)
    # 相打ちになっているときは寝ている
    if globalState.lives == 0:
        playSound("girl_end_asleep.wav")
        await asyncio.sleep(3)
    else:
        if lucky():
            playSound("girl_win1_blooper.wav")
            await asyncio.sleep(15)
        else:
            playSound("girl_win2.wav")
            await asyncio.sleep(7)
    playSound("outro.wav")
    await asyncio.sleep(21)
    globalState.step = "end"

def charge():
    if globalState.totalCharges >= globalState.maxCharges:
        return
    if globalState.step == "costumed" or globalState.step == "wait":
        return
    globalState.totalCharges += 1
    ipc.send("charge %d" % globalState.totalCharges)
    if globalState.step == "ready" and globalState.totalCharges == globalState.maxCharges:
        ipc.send("charged")
    if globalState.step == "ready2" and globalState.totalCharges == globalState.maxCharges:
        ipc.send("charged")
    if globalState.step == "not_costumed" and globalState.totalCharges == globalState.maxCharges:
        globalState.step = "costumed"
        globalState.totalCharges = 0
        loop = asyncio.get_event_loop()
        loop.create_task(costumedSound())

async def costumedSound():
    globalState.step = "wait"
    ipc.send("playtheme")
    await asyncio.sleep(3)
    ipc.send("costumed")
    await asyncio.sleep(4)
    playSound("girl_intro2.wav")
    await asyncio.sleep(5)
    globalState.timerRestart()
    globalState.step = "ready"
    globalState.maxCharges = 8
    playSound("action.ogg")

def on_motion_receive_indicate(sender, data: bytearray):
    pass

def on_button_receive_notify(sender, data: bytearray):
    if globalState.step != "welcome":
        return
    # end if
    if data[2] == 1:
        globalState.step = "start"

def on_button_receive_indicate(sender, data: bytearray):
    pass

async def introSound():
    playSound("monster_intro1.wav")
    await asyncio.sleep(10)
    playSound("girl_intro1.wav")
    await asyncio.sleep(10)
    playSound("action.ogg")
    globalState.step = "not_costumed"
    globalState.maxCharges = 5

async def main():
    print("Scanning devices...")
    scanner = DeviceScanner()
    await scanner.scanDevices()
    async with BleakClient(scanner.motionDevice, timeout=None) as client:
        print("connecting to motion device...")
        # Initialize
        await client.start_notify(CORE_NOTIFY_UUID, on_motion_receive_notify)
        await client.start_notify(CORE_INDICATE_UUID, on_motion_receive_indicate)
        await client.write_gatt_char(CORE_WRITE_UUID, struct.pack('<BBBB', 0, 2, 1, 3), response=True)
        print('connected to motion device')
        async with BleakClient(scanner.buttonDevice, timeout=None) as client:
            print("connecting to button device...")
            # Initialize
            await client.start_notify(CORE_NOTIFY_UUID, on_button_receive_notify)
            await client.start_notify(CORE_INDICATE_UUID, on_button_receive_indicate)
            await client.write_gatt_char(CORE_WRITE_UUID, struct.pack('<BBBB', 0, 2, 1, 3), response=True)
            print('connected to button device')
            print("Mahou Shoujo, Ready!")
            await game()


async def game():
    while(True):
        globalState.reset()
        while(globalState.step == "welcome"):
            await asyncio.sleep(0.1)
        # end wait until button is pressed and state changes
        await play()

async def play():
    # intro sound
    loop = asyncio.get_event_loop()
    loop.create_task(introSound())
    while(True):
        await asyncio.sleep(1)
        if globalState.step == "ready" or globalState.step == "ready2":
            attackCheck()
        if globalState.attacking and globalState.timerElapsed() >= 1:
            loop.create_task(attackHit())
        if globalState.step == "end":
            break


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
    globalState.lives -= 1
    ipc.send("chargestopwith fx\\sleep_hit.wav")
    if globalState.lives == 0:
        ipc.send("fadeouttheme")
    await asyncio.sleep(3)
    if globalState.lives == 0:
        playSound("girl_defeat1.wav")
        await asyncio.sleep(5)
        if not globalState.cleared: # 相打ちになっているときはネタを発動させるので例外的にフラグを立てない。撃破したほうのイベントでフラグが立つように。
            globalState.step = "end"
    elif globalState.lives == 1:
        playSound("girl_hit2.wav")
        await asyncio.sleep(2)
        globalState.step = prevStep
        if not globalState.cleared:
            playSound("action.ogg")
    elif globalState.lives == 2:
        playSound("girl_hit1.wav")
        await asyncio.sleep(4)
        globalState.step = prevStep
        if not globalState.cleared:
            playSound("action.ogg")
    globalState.timerRestart()


def playSound(name):
    name = os.path.join(os.getcwd(), "fx", name)
    ipc.send("playoneshot %s" % name)

# Initialize event loop
if __name__ == '__main__':
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())
