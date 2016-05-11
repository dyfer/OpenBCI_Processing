/**
 * This sketch demonstrates how to an <code>AudioRecorder</code> to record audio to disk. 
 * To use this sketch you need to have something plugged into the line-in on your computer, 
 * or else be working on a laptop with an active built-in microphone. 
 * <p>
 * Press 'r' to toggle recording on and off and the press 's' to save to disk. 
 * The recorded file will be placed in the sketch folder of the sketch.
 * <p>
 * For more information about Minim and additional features, 
 * visit http://code.compartmental.net/minim/
 */

/*
 replace amp follower?
 add value readout
 add load/play/stop/rec controls
 add time for rec/play
 draw where the trigger is
 */


import ddf.minim.*;
import ddf.minim.ugens.*;
import ddf.minim.spi.*; // for AudioStream

import oscP5.*;
import netP5.*;

import java.util.Date;
import java.text.SimpleDateFormat;

//import processing.sound.*;

Minim minim;
AudioInput in;
AudioOutput out;  
AudioRecorder recorder;
EnvelopeFollower[] envFollow = new EnvelopeFollower[2]; 
LiveInput inStream;
FilePlayer filePlayer;


String message;

int oscSendToPort = 8100;
String oscSendToHost = "127.0.0.1"; //use "127.0.0.1" for sending to another app on the same computer
int bufferSize = 256;
int bitDepth = 16;
int vScale = 150;
float envFollowAtt = 0;
float envFollowRel = 0.5; //these don't seem to work
int envFollowBufferSize = 512; //this will rougly relate to the smoothing
int meterWidth = 80;

float[] lastAmp = new float[2];
boolean isMonitoring = false;
//float ampL;
//float ampR;

OscP5 oscP5;
NetAddress myRemoteLocation;

Gain ampFollowIn;

boolean isRecording = false;
boolean isPlaying = false;
boolean isPaused = false;

//Amplitude amp;
//AudioIn in;

void setup()
{
  size(640, 400, P3D);

  colorMode(HSB, 1.0);

  minim = new Minim(this);
  Balance balanceL = new Balance(1.0);
  Balance balanceR = new Balance(-1.0);

  in = minim.getLineIn(Minim.STEREO, bufferSize);
  out = minim.getLineOut();

  AudioStream inputStream = minim.getInputStream( out.getFormat().getChannels(), bufferSize, out.sampleRate(), bitDepth);


  // construct a LiveInput by giving it an InputStream from minim.         
  delay(100);
  inStream = new LiveInput( inputStream );
  println(Minim.STEREO);
  println(inStream.channelCount());  
  // create a recorder that will record from the input to the filename specified
  // the file will be located in the sketch's root folder.
  //recorder = minim.createRecorder(in, "myrecording.wav");

  textFont(createFont("Arial", 12));

  envFollow[0] = new EnvelopeFollower(envFollowAtt, envFollowRel, envFollowBufferSize); //BECAUSE ENV FOLLOWER SUMS BOTH INPUT CHANNELS!!!
  envFollow[1] = new EnvelopeFollower(envFollowAtt, envFollowRel, envFollowBufferSize); 
  //envFollow.setChannelCount(2);

  // a sink to tick the envelope follower because 
  // we won't use the output of it in the signal chain
  Sink sink = new Sink();
  ampFollowIn = new Gain();
  //monitor
  inStream.patch(ampFollowIn);
  ampFollowIn.patch(balanceL).patch(envFollow[0]).patch( sink ).patch( out );
  ampFollowIn.patch(balanceR).patch(envFollow[1]).patch( sink ).patch( out );
  //println(sink.channelCount());

  //println(envFollow.channelCount());

  //OSC
  oscP5 = new OscP5(this, oscSendToPort + 1000); //offset receiving port (which we're not using anyway....) to not block other apps from reading from it
  myRemoteLocation = new NetAddress(oscSendToHost, oscSendToPort);
  //println(new SimpleDateFormat("yyyyddMM_HHmmss").format(new Date()));
}

void draw()
{
  background(0); 
  stroke(1);
  fill(1);
  // draw the waveforms
  // the values returned by left.get() and right.get() will be between -1 and 1,
  // so we need to scale them up to see the waveform
  if (isPlaying) {
    for (int i = 0; i < width - meterWidth; i++)
    {
      line(i, height/4 + out.left.get(constrain(int(float(i) * (float(out.bufferSize())/float(width))), 0, out.bufferSize() - 1)) * vScale, i+1, height/4 + out.left.get(constrain(int(float(i + 1) * (float(out.bufferSize())/float(width))), 0, out.bufferSize() - 1))*vScale);
      line(i, height/4*3 + out.right.get(constrain(int(float(i) * (float(out.bufferSize())/float(width))), 0, out.bufferSize() - 1)) * vScale, i+1, height/4*3 + out.right.get(constrain(int(float(i + 1) * (float(out.bufferSize())/float(width))), 0, out.bufferSize() - 1))*vScale);
    }
  } else {
    for (int i = 0; i < width - meterWidth; i++)
    {
      line(i, height/4 + in.left.get(constrain(int(float(i) * (float(in.bufferSize())/float(width))), 0, in.bufferSize() - 1)) * vScale, i+1, height/4 + in.left.get(constrain(int(float(i + 1) * (float(in.bufferSize())/float(width))), 0, in.bufferSize() - 1))*vScale);
      line(i, height/4*3 + in.right.get(constrain(int(float(i) * (float(in.bufferSize())/float(width))), 0, in.bufferSize() - 1)) * vScale, i+1, height/4*3 + in.right.get(constrain(int(float(i + 1) * (float(in.bufferSize())/float(width))), 0, in.bufferSize() - 1))*vScale);
    }
  }
  if(isPlaying || isPaused) {
    //draw progress line
    float songPos = map( filePlayer.position(), 0, filePlayer.length(), 0, width - meterWidth );
    stroke( 0.5, 1, 1 );
    line( songPos, 0, songPos, height );
  }

stroke(1);

  text("r: start recording, s: stop, o: open file, p: play/pause", 5, 15);
  if (message != null) {
    text(message, 5, 30);
  }
  //if ( recorder.isRecording() )
  //{
  //  text("Currently recording...", 5, 15);
  //} else
  //{
  //  text("Not recording.", 5, 15);
  //}
  //envFollow.printInputs();
  //println(envFollow.channelCount());
  //lastAmp[0] = envFollow.getLastValues()[0];
  //lastAmp[1] = envFollow.getLastValues()[1];
  //lastAmp = envFollow.getLastValues();
  //lastAmp = inStream.getLastValues();
  //ampL = envFollow.getLastValues()[0];
  //ampR = envFollow.getLastValues()[1];  
  //draw amp
  //println(lastAmp);
  for (int i = 0; i < lastAmp.length; i++) {
    lastAmp[i] = envFollow[i].getLastValues()[0];
    //println(lastAmp[i]);
    //float thisAmpVal;
    float thisAmpVal = amp2db(lastAmp[i]);
    //if(i==0) {
    //  thisAmpVal = ampL;
    //} else {
    //  thisAmpVal = ampR;  
    //};
    //thisAmpVal = amp2db(thisAmpVal);
    //if(i == 0 ) {
    //println(thisAmpVal);
    //}
    thisAmpVal = constrain(thisAmpVal, -90, 0);
    fill(map(thisAmpVal, -100, 0, 0.33, 0), 0.5, 1);
    rect(width - meterWidth, height/2 + (height/2 * i), meterWidth, map(thisAmpVal, -90, 0, 0, height/-2), 5);
  };
  //send amp values
  OscMessage myMessage = new OscMessage("/amp");
  for (int i = 0; i < lastAmp.length; i++) {
    myMessage.add(lastAmp[i]);
  }
  oscP5.send(myMessage, myRemoteLocation);

  //again for values in decibel (-infinity to 0)

  OscMessage myMessageDB = new OscMessage("/db");
  for (int i = 0; i < lastAmp.length; i++) {
    myMessageDB.add(amp2db(lastAmp[i]));
  }
  oscP5.send(myMessageDB, myRemoteLocation);


  //println(envFollow.getLastValues());
}

float amp2db (float amp) {
  float db = 20 * ((float)Math.log10(amp)); 
  return db;
}

void keyReleased()
{
  if ( key == 'r' ) 
  {
    startRec();
  }
  if ( key == 's' )
  {
    stop();
  }
  if (key == 'o')
  {
    stop();
    selectInput("Select a file to play:", "openFile");
  }
  if (key == 'p')
  {
    startPlay();
  }
}

void startRec() {
  String stamp = new SimpleDateFormat("yyyyddMM_HHmmss").format(new Date());
  String msg = "starting recording to " + stamp;
  recorder = minim.createRecorder(in, "data/"+ stamp +".wav");
  recorder.beginRecord();
  isRecording = true;
  message = msg;
  println(msg);
}
void stopRec() {
  recorder.endRecord();
  recorder.save();
  message = "recording saved";
  println("recording saved");
  isRecording = false;
}
void openFile(File selection) {
  String msg;
  String path;
  if (selection == null) {
    msg = "no file was selected";
  } else {
    path = selection.getAbsolutePath();
    msg = "opening " + path;
    filePlayer = new FilePlayer( minim.loadFileStream(path) );
  }
  message = msg;
  println(msg);
}
void startPlay() {
  String msg;
  if (filePlayer != null) {
    if (isPlaying) {
      filePlayer.pause();
      isPlaying = false;
      isPaused = true;
      msg = "pause";
    } else {
      inStream.unpatch(ampFollowIn);
      filePlayer.patch(out);
      filePlayer.play();
      isPlaying = true;
      isPaused = false;
      filePlayer.patch(ampFollowIn);
      msg = "playing";
    }
    message = msg;
    println(msg);
  }
}
void stopPlay() {
  String msg;
  if (filePlayer != null) {
    filePlayer.pause();
    filePlayer.rewind();
    filePlayer.unpatch(ampFollowIn);
    inStream.patch(ampFollowIn);
    isPlaying = false;
    msg = "stopped";
    message = msg;
    println(msg);
  }
}
void rewind() {
  String msg;
  if (filePlayer != null) {
    filePlayer.rewind();
    isPlaying = false;
    msg = "stopped";
    message = msg;
    println(msg);
  }
}
void stop() { //rec or play
  if (isRecording) {
    stopRec();
  }
  if (isPlaying || isPaused) {
    stopPlay();
  }
}