import asyncio
from bleak import BleakClient, discover
from struct import pack

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
    print("rcv")
    message_type = data[MESSAGE_TYPE_INDEX]
    event_type = data[EVENT_TYPE_INDEX]
    if event_type == 2:
        inputHandlerInstance.onCharge()

def on_receive_indicate(sender, data: bytearray):
    pass



class InputHandler:
    def __init__(self, onCharge):
        super(InputHandler, self).__init__()
        self.onCharge = onCharge
        self.ready = False
        self.stopped = False

    def run(self):
        asyncio.run(self.main())

    def stop(self):
        self.stopped = True

    def isReady(self):
        return self.ready

    async def scan(self, prefix='MESH-100'):
        while True:
            print('scan...')
            try:
                return next(d for d in await discover() if d.name and d.name.startswith(prefix))
            except StopIteration:
                continue

    async def main(self):
        # Scan device
        device = await self.scan('MESH-100AC')
        print('found', device.name, device.address)
        # Connect device
        async with BleakClient(device, timeout=None) as client:
            # Initialize
            await client.start_notify(CORE_NOTIFY_UUID, on_receive_notify)
            await client.start_notify(CORE_INDICATE_UUID, on_receive_indicate)
            await client.write_gatt_char(CORE_WRITE_UUID, pack('<BBBB', 0, 2, 1, 3), response=True)
        print('connected')
        self.ready = True
        while(True):
            await asyncio.sleep(1)
            if self.stopped:
                break


class ChargeEvent:
    def __init__(self):
        self.type = "charge"


class FireEvent:
    def __init__(self):
        self.type = "fire"
