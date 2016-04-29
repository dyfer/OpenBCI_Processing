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

int startingTime;

int index = 0;

int backgroundVal = 0;

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
  background(backgroundVal);
  if(backgroundVal != 0) {
    backgroundVal = 0; //revert to black on next frame
  }
}

/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage theOscMessage) {
  //println("message received"); //for debugging
  if (theOscMessage.checkAddrPattern("/raw")==true) {
    //process raw data
    //float channel = theOscMessage.get(7).floatValue(); //channel 8 (7 0-based)
    //println("channel 8: "+channel);
    //also, we'll start playing on once we receive first raw value
    //and let's start counting time
    if (!isPlaying) {
      println("Received first EEG data, starting playback");
      player.play();
      startingTime = millis();    
      isPlaying = true;
    }
    return;
  }

    //receiving filtered data (updated less frequently)
    if (theOscMessage.checkAddrPattern("/avgFilt")==true) {
      //process raw data
      //float channel = theOscMessage.get(7).floatValue(); //channel 8 (7 0-based)
      //println("channel 8 average: "+channel);
      return;
    }

    if (theOscMessage.checkAddrPattern("/p300")==true) {
      //we don't process any data, just report how much time passed since the beginning
      int milliseconds = millis() % 1000;// report milliseconds for the current second
      int seconds = (millis() - startingTime) / 1000;
      int minutes = seconds / 60;
      int hours = minutes / 60;

      println("Received p300 at " + hours + ":" + minutes + ":" + seconds + "." + milliseconds);

      // ----------------------------------------------------------------------
      // ------ your code to process data after receiving p300 goes here -----
      backgroundVal = 255; //quick blink
      // ----------------------------------------------------------------------
      return;
    }
  }