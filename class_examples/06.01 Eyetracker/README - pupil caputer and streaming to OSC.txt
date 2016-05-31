- Download Pupil Capture (and optionally Pupil Player) from
https://github.com/pupil-labs/pupil/releases/tag/v0.7.6#downloads

- attach webcam on your head; connect it to the computer

- open Pupil Captire; you should see webcam view in the main window and optionally eye view in a smaller window

- run calibration (press c)

- in the General section, select Open plugin -> pupil server

- scroll all the way down, take note of the Pupil Broadcast Server address and port (the default is tcp://127.0.0.1:5000)

- get ready for OSC: makes sure we have necessary python library (we need to do this only once). In terminal run: 
sudo pip install pyzmq
(and type in password + enter when prompted)

- go to python osc bridge

- run zmq_osc_bridge.py in python
in terminal:
cd <drop the python osc bridge folder here>
python zmq_osc_bridge.py 

- receive OSC in Processing 
see plan