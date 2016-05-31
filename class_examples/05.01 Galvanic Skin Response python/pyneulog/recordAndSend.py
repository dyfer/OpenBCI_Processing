from neulog import gsr
from gzp import save
import time
import datetime
import OSC

"""
Based on https://github.com/thearn/pyneulog
Record and stream 

Gathers data over two phases. Use a keyboard interrupt (control-c) to end a phase.

Saves data to disk afterwards.
"""

OSC_SEND = 8100;
OSC_ADDR = '/microSiemens';
OSC_IP = 'localhost';

sensor = gsr()

data = []
times = []
t0 = time.time()

print "Starting..."

print "preparing OSC client (sending)"
oscClient = OSC.OSCClient()
oscClient.connect( (OSC_IP, OSC_SEND) )

while True: #first phase (eg. 'resting')
    try:
        x = sensor.get_data()
        t = time.time() - t0
        print t, x
        data.append(x)
        times.append(t)

        #osc
        oscMsg = OSC.OSCMessage()
        oscMsg.setAddress(OSC_ADDR)
        oscMsg.append(x)        
        oscMsg.append(t);
        oscClient.send(oscMsg)
    
    except KeyboardInterrupt:
        break

# breaktime = time.time() - t0

# print "Second phase..."
# while True: #second phase (eg. 'attentive')
    
    # try:
    #     x = sensor.get_data()
    #     t = time.time() - t0
    #     print t, x
    #     data.append(x)
    #     times.append(t)
    
    # except KeyboardInterrupt:
    #     break

ts = time.time()
timeStamp = datetime.datetime.fromtimestamp(ts).strftime('%Y%m%d_%H%M%S')

print ("Done - saving to disk (data/" + timeStamp + ".dat)")
save([data, times], "data/" + timeStamp + ".dat")
