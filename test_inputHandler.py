import time
import inputHandler

def onCharge():
    print("charge!!!")


h = inputHandler.InputHandler(onCharge)
inputHandler.inputHandlerInstance = h
h.run()

