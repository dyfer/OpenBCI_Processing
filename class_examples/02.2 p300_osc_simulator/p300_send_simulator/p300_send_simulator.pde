import oscP5.*;
import netP5.*;

int oscSendToPort = 8100;
String oscSendToHost = "127.0.0.1"; //use "127.0.0.1" for sending to another app on the same computer

OscP5 oscP5;
NetAddress myRemoteLocation;

int backgroundVal = 0;

void setup() {
  size(400, 200);
  oscP5 = new OscP5(this, oscSendToPort + 1000); //offset receiving port (which we're not using anyway....) to not block other apps from reading from it
  myRemoteLocation = new NetAddress(oscSendToHost, oscSendToPort);
  //display some text
}

void draw() {
  background(backgroundVal);
  if(backgroundVal != 0) {
    backgroundVal = 0; //revert to black on next frame
  }
  textSize(20);
  text("Press 'p' to send a simulated\np300 message through OSC", 10, 30);
}

void keyPressed() {
  if (key == 'p' || key == 'P') {
    OscMessage myMessage = new OscMessage("/p300");
    oscP5.send(myMessage, myRemoteLocation);
    println("p300 sent through OSC");
    backgroundVal = 255; //quick blink
  }
}