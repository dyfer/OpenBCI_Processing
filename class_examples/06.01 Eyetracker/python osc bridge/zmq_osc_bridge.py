'''
a script that will replay pupil server messages to a osc server.

as implemented here only the pupil_norm_pos is relayed.
implementeing other messages to be send as well is a matter of renaming the vaiables.

installing pyOSC:

git clone git://gitorious.org/pyosc/devel.git pyosc
cd pyosc
python setup.py install (may need sudo)
'''
oscSendPort = 8100;
pupilRecorderAddress = "tcp://127.0.0.1:5000"

#zmq setup
import zmq
import json

context = zmq.Context()
socket = context.socket(zmq.SUB)
print "Connecting to Pupil Broadcast Server at ", pupilRecorderAddress
socket.connect(pupilRecorderAddress)
#print "Connected!" #this is not accurate, socket doesn't seem to throw an error even when pupil server is not running
#filter by messages by stating string 'STRING'. '' receives all messages
socket.setsockopt(zmq.SUBSCRIBE, 'pupil_positions')

# #osc setup
from OSC import OSCClient, OSCMessage
client = OSCClient()
client.connect( ("localhost", oscSendPort) )

print "Starting OSC streaming" #regardless if we have something to stream or not
while True:
    topic,msg =  socket.recv_multipart()
    pupil_positions = json.loads(msg)
#    print pupil_positions #check/debug:

#    [{u'diameter': 152.002685546875, u'confidence': 1.0, u'ellipse': {u'axes': [82.03343963623047, 152.002685546875], u'angle': 154.11952209472656, u'center': [163.97737884521484, 258.87591552734375]}, u'index': 382, u'norm_pos': [0.25621465444564817, 0.46067517598470054], u'id': 0, u'timestamp': 28811.866421915, u'method': u'2d c++'}]

    for pupil_position in pupil_positions:
        pupil_x,pupil_y = pupil_position['norm_pos']
        msg = OSCMessage("/pupil/norm_pos")
        msg.append((pupil_x,pupil_y))
        try:
            client.send(msg)
        except:
            pass

    for diameter in pupil_positions:
        thisDiameter = pupil_position['diameter']
        msg = OSCMessage("/pupil/diameter")
        msg.append((thisDiameter))
        try:
            client.send(msg)
        except:
            pass

    for confidence in pupil_positions:
        thisConf = pupil_position['confidence']
        msg = OSCMessage("/pupil/confidence")
        msg.append((thisConf))
        try:
            client.send(msg)
        except:
            pass

    for axes in pupil_positions:
        axis_x,axis_y = pupil_position['ellipse']['axes']
#        print axis_x
        msg = OSCMessage("/pupil//ellipse/axes")
        msg.append((axis_x,axis_y))
        try:
            client.send(msg)
        except:
            pass

    for angle in pupil_positions:
        thisAngle = pupil_position['ellipse']['angle']
        msg = OSCMessage("/pupil/ellipse/angle")
        msg.append((thisAngle))
        try:
            client.send(msg)
        except:
            pass

    for center in pupil_positions:
        center_x,center_y = pupil_position['ellipse']['center']
        msg = OSCMessage("/pupil/ellipse/center")
        msg.append((center_x,center_y))
        print center_x, center_y
        try:
            client.send(msg)
        except:
            pass

