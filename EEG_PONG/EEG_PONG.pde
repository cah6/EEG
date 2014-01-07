/* Mind Pong
 * by Christian Henry
 *
 * Simple single player "pong" game. Measuring off the occipital lobe,
 * close your eyes and relax to increase alpha wave concentration and 
 * move the paddle up, open your eyes and focus to move the paddle down.
 *
 * This sketch has sparse documentation, as most of the code is taken
 * directly from the READ_EEG sketch. To make it easier to start off with,
 * this one is not object oriented. The two player version is.
 */
 
 //grab the libraries we need
 import ddf.minim.*;
 import ddf.minim.signals.*;
 import ddf.minim.analysis.*;
 import ddf.minim.effects.*;
 
 int windowLength = 500;
 int windowHeight = 400;
 int paddleWidth;
 int paddleLength;
 float[] alphaAverages;
 int averageLength = 50; //averages about the last 5 seconds worth of data
 int counter = 0;
 
 static int alphaCenter = 9;
 static int alphaBandwidth = 2; //really bandwidth divided by 2
 
 //mostly audio functions to grab/process the data
 Minim minim;
 AudioInput in;
 FFT fft;
 BandPass alphaFilter;
 float scaleFreq = 1.33f;
 
 boolean absoluteBadDataFlag;
 boolean averageBadDataFlag;
 
 //Parameters for the ball. For both pos and vel, 0 index is x and 1 index is y.
 float[] ballpos = {250,250};
 float ballspeed = 1;
 float[] ballvel = {0,0}; //velocity
 float ballrad = 10;      //radius
 
void setup(){
  alphaAverages = new float[averageLength];
  for (int i = 0; i < averageLength; i++){
    alphaAverages[i] = 0;
  }
  
  size(windowLength,windowHeight,P2D);
  background(0); //make background black
  stroke(255);   //and everything we draw white
  
  paddleWidth = 5;
  paddleLength = (height-100) / 5;
  
  //initialize minim, as well as our alpha filter
  minim = new Minim(this);
  minim.debugOn();
  alphaFilter = new BandPass(alphaCenter/scaleFreq,alphaBandwidth/scaleFreq,32768);
  
  in = minim.getLineIn(Minim.MONO, 8192*4);
  in.addEffect(alphaFilter);
  fft = new FFT(in.bufferSize(), in.bufferSize());
  fft.window(FFT.HAMMING);
}

void draw(){
  background(0); //clear previous drawings
  
  absoluteBadDataFlag = false;
  averageBadDataFlag = false;
  float timeDomainAverage = 0;
  
  fft.forward(in.mix); //compute FFT
  line(0,100,windowLength,100); //line separating time and frequency data
  
  //get a good amount of time data
  for(int i = 0; i < windowLength; i++){
    if (abs(in.left.get(i*round(in.bufferSize()/windowLength)))*2 > .95){
      absoluteBadDataFlag = true;
    }
    
    line(i, 50 + in.left.get(i*round(in.bufferSize()/windowLength))*100, 
         i+1, 50 + in.left.get((i+1)*round(in.bufferSize()/windowLength))*100);
   
    timeDomainAverage += abs(in.left.get(i*round(in.bufferSize()/windowLength)));
  }
  
  timeDomainAverage = timeDomainAverage / (windowLength);
  
  for (int i = 0; i < windowLength - 1; i++){
    if (abs(in.left.get((i+1)*round(in.bufferSize()/windowLength))) > timeDomainAverage*4)
      averageBadDataFlag = true;
  }
  
  text("absoluteBadDataFlag = " + absoluteBadDataFlag, windowLength - 170, 20);
  text("averageBadDataFlag = " + averageBadDataFlag, windowLength - 170, 40);
  
  int lowBound = fft.freqToIndex(alphaCenter - alphaBandwidth);
  int hiBound = fft.freqToIndex(alphaCenter + alphaBandwidth);
  
  lowBound = round(lowBound/scaleFreq);
  hiBound = round(hiBound/scaleFreq);
  
  float avg = 0;
  for (int j = lowBound; j <= hiBound; j++){
    avg += fft.getBand(j);
  }
  avg /= (hiBound - lowBound + 1);
  //scale averages a bit
  avg *= .3775;
  
  if (absoluteBadDataFlag == false && averageBadDataFlag == false){
    alphaAverages[counter%averageLength] = avg;
  }
  
  float finalAlphaAverage = 0;
  for (int k = 0; k < averageLength; k++){
    finalAlphaAverage += alphaAverages[k];
  }
  finalAlphaAverage = finalAlphaAverage / averageLength;
  finalAlphaAverage = finalAlphaAverage - 200; //base average is around 100, normalize it
                                               //and make the lower half negative
  
  float paddleHeight = height-paddleLength;
  
  paddleHeight += finalAlphaAverage /5; //finalAlphaAverage ranges from about 0 to 200 now,
                                           //we want that to cover window of 0 to 300
  //make sure the paddle doesn't go off-screen
  if (paddleHeight > height - paddleLength)
    paddleHeight = height - paddleLength;
  if (paddleHeight < 100)
    paddleHeight = 100;

  rect(5,paddleHeight,paddleWidth,paddleLength);
  
  ballpos[0] += ballvel[0];
  ballpos[1] += ballvel[1];
  
  ellipse(ballpos[0],ballpos[1],ballrad,ballrad);
  
  //collision detection with paddle
  if ((ballpos[0] - ballrad > 5) && (ballpos[0] - ballrad < 5 + paddleWidth) && 
  (ballpos[1] < paddleHeight + paddleLength) && (ballpos[1] > paddleHeight)){
    ballvel[0] *= -1;
    float paddleCenter = (paddleHeight + (paddleHeight + paddleLength)) / 2;
    ballvel[1] = -(paddleCenter - ballpos[1])/15;
  }
  //collision detection with opposite wall
  if (ballpos[0] + ballrad > width){
    ballvel[0] *= -1;
  }
  //collision with top wall
  if (ballpos[1] < 100 + ballrad || ballpos[1] > height - ballrad){
    ballvel[1] *= -1;
  }
  
  counter++;
}

void keyPressed(){
  if (key == ' '){
    ballpos[0] = 250;
    ballpos[1] = 250;
    ballvel[0] = -ballspeed;
    ballvel[1] = 0;
  }
}














