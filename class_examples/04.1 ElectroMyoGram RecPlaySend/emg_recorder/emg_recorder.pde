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
  
//import processing.sound.*;

Minim minim;
AudioInput in;
AudioOutput out;  
AudioRecorder recorder;
EnvelopeFollower envFollow;
LiveInput inStream;




int oscSendToPort = 8100;
String oscSendToHost = "127.0.0.1"; //use "127.0.0.1" for sending to another app on the same computer
int bufferSize = 256;
int bitDepth = 16;
int vScale = 150;
float envFollowAtt = 0;
float envFollowRel = 0.5;
int envFollowBufferSize = 256;
int meterWidth = 80;

float[] lastAmp;
boolean isMonitoring = false;

OscP5 oscP5;
NetAddress myRemoteLocation;

//Amplitude amp;
//AudioIn in;

void setup()
{
  size(640, 400, P3D);
  
  colorMode(HSB, 1.0);

  minim = new Minim(this);

  in = minim.getLineIn(Minim.STEREO, bufferSize);
  out = minim.getLineOut();

  AudioStream inputStream = minim.getInputStream( Minim.STEREO, bufferSize, out.sampleRate(), bitDepth);

  // construct a LiveInput by giving it an InputStream from minim.                                                  
  inStream = new LiveInput( inputStream );  
  // create a recorder that will record from the input to the filename specified
  // the file will be located in the sketch's root folder.
  recorder = minim.createRecorder(in, "myrecording.wav");

  textFont(createFont("Arial", 12));
  
  
  //amp = new Amplitude(this);
  //in = new AudioIn(this, 0);
  //in.start();
  //amp.input(in);

  envFollow = new EnvelopeFollower(envFollowAtt, envFollowRel, envFollowBufferSize);
  
  

  // a sink to tick the envelope follower because 
  // we won't use the output of it in the signal chain
  Sink sink = new Sink();
  inStream.patch(envFollow).patch( sink ).patch( out );
  
  println(envFollow.channelCount());

  //OSC
  oscP5 = new OscP5(this, oscSendToPort + 1000); //offset receiving port (which we're not using anyway....) to not block other apps from reading from it
  myRemoteLocation = new NetAddress(oscSendToHost, oscSendToPort);
}

void draw()
{
  background(0); 
  stroke(1);
  fill(1);
  // draw the waveforms
  // the values returned by left.get() and right.get() will be between -1 and 1,
  // so we need to scale them up to see the waveform
  for (int i = 0; i < width - meterWidth; i++)
  {
    line(i, height/4 + in.left.get(constrain(int(float(i) * (float(in.bufferSize())/float(width))), 0, in.bufferSize() - 1)) * vScale, i+1, height/4 + in.left.get(constrain(int(float(i + 1) * (float(in.bufferSize())/float(width))), 0, in.bufferSize() - 1))*vScale);
    line(i, height/4*3 + in.right.get(constrain(int(float(i) * (float(in.bufferSize())/float(width))), 0, in.bufferSize() - 1)) * vScale, i+1, height/4*3 + in.right.get(constrain(int(float(i + 1) * (float(in.bufferSize())/float(width))), 0, in.bufferSize() - 1))*vScale);
  }

  if ( recorder.isRecording() )
  {
    text("Currently recording...", 5, 15);
  } else
  {
    text("Not recording.", 5, 15);
  }

  lastAmp = envFollow.getLastValues();
  //draw amp
  //println(lastAmp);
   for (int i = 0; i < lastAmp.length; i++) {
     //println(lastAmp[i]);
     float thisAmpVal = amp2db(lastAmp[i]);
     fill(map(thisAmpVal, -100, 0, 0.33, 0), 0.5, 1);
    rect(width - meterWidth, height/2 + (height/2 * i), meterWidth, map(thisAmpVal, -100, 0, 0, height/-2), 5);
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
    // to indicate that you want to start or stop capturing audio data, you must call
    // beginRecord() and endRecord() on the AudioRecorder object. You can start and stop
    // as many times as you like, the audio data will be appended to the end of the buffer 
    // (in the case of buffered recording) or to the end of the file (in the case of streamed recording). 
    if ( recorder.isRecording() ) 
    {
      recorder.endRecord();
    } else 
    {
      recorder.beginRecord();
    }
  }
  if ( key == 's' )
  {
    // we've filled the file out buffer, 
    // now write it to the file we specified in createRecorder
    // in the case of buffered recording, if the buffer is large, 
    // this will appear to freeze the sketch for sometime
    // in the case of streamed recording, 
    // it will not freeze as the data is already in the file and all that is being done
    // is closing the file.
    // the method returns the recorded audio as an AudioRecording, 
    // see the example  AudioRecorder >> RecordAndPlayback for more about that
    recorder.save(); 
    println("Done saving.");
  }
}