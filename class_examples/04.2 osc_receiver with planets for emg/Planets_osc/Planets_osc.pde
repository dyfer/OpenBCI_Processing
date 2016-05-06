// Planets, by Andres Colubri
//
// Sun and mercury textures from http://planetpixelemporium.com
// Star field picture from http://www.galacticimages.com/

//art&brain experiment by Marcin

import oscP5.*;
import netP5.*;

int oscReceivePort = 8100; //this should match the sending port in EMG app
int channelToRead = 0;//0-based; define which channel we use
float threshold = -24; //for decibel values 

//incoming signal, when goes above/below threshold, make the scaler (used to change displacement of planets) to alternate between lo and hi value
int scaler = 1;
int scalerLo = 1;
int scalerHi = 20;

OscP5 oscP5;

PImage starfield;

PShape sun;
PImage suntex;

PShape planet1;
PImage surftex1;
PImage cloudtex;

PShape planet2;
PImage surftex2;

void setup() {
  size(1024, 768, P3D);

  starfield = loadImage("starfield.jpg");
  suntex = loadImage("sun.jpg");  
  surftex1 = loadImage("planet.jpg");  

  // We need trilinear sampling for this texture so it looks good
  // even when rendered very small.
  //PTexture.Parameters params1 = PTexture.newParameters(ARGB, TRILINEAR);  
  surftex2 = loadImage("mercury.jpg");  

  /*
  // The clouds texture will "move" having the values of its u
   // texture coordinates displaced by adding a constant increment
   // in each frame. This requires REPEAT wrapping mode so texture 
   // coordinates can be larger than 1.
   //PTexture.Parameters params2 = PTexture.newParameters();
   //params2.wrapU = REPEAT;
   cloudtex = createImage(512, 256);
   
   // Using 3D Perlin noise to generate a clouds texture that is seamless on
   // its edges so it can be applied on a sphere.
   cloudtex.loadPixels();
   Perlin perlin = new Perlin();
   for (int j = 0; j < cloudtex.height; j++) {
   for (int i = 0; i < cloudtex.width; i++) {
   // The angle values corresponding to each u,v pair:
   float u = float(i) / cloudtex.width;
   float v = float(j) / cloudtex.height;
   float phi = map(u, 0, 1, TWO_PI, 0); 
   float theta = map(v, 0, 1, -HALF_PI, HALF_PI);
   // The x, y, z point corresponding to these angles:
   float x = cos(phi) * cos(theta);
   float y = sin(theta);            
   float z = sin(phi) * cos(theta);      
   float n = perlin.noise3D(x, y, z, 1.2, 2, 8);
   cloudtex.pixels[j * cloudtex.width + i] = color(255, 255,  255, 255 * n * n);
   }
   }  
   cloudtex.updatePixels();
   */

  noStroke();
  fill(255);
  sphereDetail(40);

  sun = createShape(SPHERE, 150);
  sun.setTexture(suntex);  

  planet1 = createShape(SPHERE, 150);
  planet1.setTexture(surftex1);

  planet2 = createShape(SPHERE, 50);
  planet2.setTexture(surftex2);

  //osc
  oscP5 = new OscP5(this, 8100);
}

void draw() {
  // Even we draw a full screen image after this, it is recommended to use
  // background to clear the screen anyways, otherwise A3D will think
  // you want to keep each drawn frame in the framebuffer, which results in 
  // slower rendering.
  background(0);

  // Disabling writing to the depth mask so the 
  // background image doesn't occludes any 3D object.
  hint(DISABLE_DEPTH_MASK);
  image(starfield, 0, 0, width, height);
  hint(ENABLE_DEPTH_MASK);

  pushMatrix();
  translate(width/2, height/2, -300);  

  pushMatrix();
  rotateY(PI * frameCount * scaler / 500);
  shape(sun);
  popMatrix();

  pointLight(255, 255, 255, 0, 0, 0);  
  rotateY(PI * frameCount * scaler / 300);
  translate(0, 0, 300);

  shape(planet2);  

  popMatrix();

  noLights();
  pointLight(255, 255, 255, 0, 0, -150); 

  translate(0.75 * width, 0.6 * height, 50);
  shape(planet1);
}

void oscEvent(OscMessage theOscMessage) {
  /* print the address pattern and the typetag of the received OscMessage */
  //print("### received an osc message.");
  //print(" addrpattern: "+theOscMessage.addrPattern());
  //println(" typetag: "+theOscMessage.typetag());
  //println(" typetag: "+theOscMessage.typetag());
  //if (theOscMessage.checkAddrPattern("/raw")==true) {
  //  //process raw data
  //  float channel = theOscMessage.get(7).floatValue(); //channel 8 (7 0-based)
  //  println("channel 8: "+channel);
  //  return;
  //}
  
  if (theOscMessage.checkAddrPattern("/amp")==true) {
    //process amp data
    float amp = theOscMessage.get(channelToRead).floatValue(); //0-based
    println("amp of channel "+channelToRead+" is: "+amp);
    return;
  }
  if (theOscMessage.checkAddrPattern("/db")==true) {
    //process raw data
    float db = theOscMessage.get(channelToRead).floatValue(); //0-based
    println("amp (db) of channel "+channelToRead+" is: "+db);
    if(db>threshold) {
      scaler = scalerHi;
    } else {
      scaler = scalerLo;
    }
    return;
  }
}