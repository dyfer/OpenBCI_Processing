/**
 * -- modified for Art&Brain 2016 by Marcin Pączkowski --
 * oscP5sendreceive by andreas schlegel
 * example shows how to send and receive osc messages.
 * oscP5 website at http://www.sojamo.de/oscP5
 */

import oscP5.*;
import netP5.*;
import ddf.minim.*;

OscP5 oscP5;
NetAddress myRemoteLocation;

Minim minim;
AudioPlayer player;

int oscReceivePort = 8100; //this should match the sending port in OpenBCI app
//String filePath = "samples/Auditory.Oddball.Meter.wav"; //can be relative to current sketch directory
String filePath = "samples/reich.wav"; //can be relative to current sketch directory

boolean isPlaying = false;

int index = 0;

void setup() {
  size(400, 400);
  frameRate(25);
  /* start oscP5, listening for incoming messages at port 12000 */
  oscP5 = new OscP5(this, oscReceivePort);
    
  // we pass this to Minim so that it can load files from the data directory
  minim = new Minim(this);
  
  // loadFile will look in all the same places as loadImage does.
  // this means you can find files that are in the data folder and the 
  // sketch folder. you can also pass an absolute path, or a URL.
  player = minim.loadFile(filePath);
}


void draw() { 
  background(0);
}

/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage theOscMessage) {
  /* print the address pattern and the typetag of the received OscMessage */
  //print("### received an osc message.");
  //print(" addrpattern: "+theOscMessage.addrPattern());
  //println(" typetag: "+theOscMessage.typetag());
  //println(" typetag: "+theOscMessage.typetag());
  if (theOscMessage.checkAddrPattern("/raw")==true) {
    //process raw data
    float channel = theOscMessage.get(7).floatValue(); //channel 8 (7 0-based)
    println("channel 8: "+channel);
    //index++;
    //if(index >=250) {
    //index = 0;
    //println("reached 250 messagages");
    //} //with these few lines you can check how often you get messages
    
    //also, we'll start playing on once we receive first raw value
    if(!isPlaying) {
      player.play();
      isPlaying = true;
    }
    return;
  }
  
  //receiving filtered data (updated less frequently)
  if (theOscMessage.checkAddrPattern("/avgFilt")==true) {
   //process raw data
   float channel = theOscMessage.get(3).floatValue(); //channel 8 (7 0-based)
   println("channel 4 average: "+channel);
  return;
  }
}