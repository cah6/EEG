/* Reading Multiple Channels of EEG Data
 * by Christian Henry
 *
 * Used to read more than 2 channels of EEG data, with associated
 * Arduino code. 
 *
 * Also uses autoregressive frequency analysis in place of FFT in analyzing
 * the data, which gives a better estimate of the data's frequency composition
 * when it is varying rapidly.
 */
 
import processing.serial.*;
import ddf.minim.*;
import ddf.minim.signals.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;

int NUM_CHANNELS = 2; 
int timeHeight = 100; //how many vertical pixels time data occupies
int freqRange = 30;
float freqRes = 0.1f; //resolution of the frequency, choose such that 1/freqRes is a whole number
int L = 20;

Serial myPort;  // The serial port
int seconds = 2; //how many seconds of data to display / analyze at once
int fRate = 60;
int inBuffer = 4; //how many data points to take in at once, this*60 = sampling rate
float displayBuffer[][] = new float[NUM_CHANNELS][fRate*inBuffer*seconds];
float timeLength = displayBuffer[0].length; //number of samples/sec in time 
int N = (int)timeLength;

SquareWave squareWave;
Minim minim = new Minim(this);
AudioOutput out;

void setup(){
  frameRate(60);
  size(840, NUM_CHANNELS*timeHeight*2);
  myPort = new Serial(this, Serial.list()[0], 9600);
  rectMode(CORNER);
}

void draw(){
  println(frameRate);
  background(0);
  //grab the data
  //while (myPort.available() > 0) {
    shiftNtimes(displayBuffer, inBuffer);
    updateData(displayBuffer);
  //}
  stroke(255);
  displayData(displayBuffer);
  for (int i = 0; i < NUM_CHANNELS; i++){
    float temp[] = runAutoregression(i); //temp is array of "a" coefficients for this channel
    float magnitude[] = evaluateTransfer(temp);
    displayFreqData(magnitude,i);
  }
  
}

//Shifts all elements in myArray numShifts times left, resulting in the 
//[0-numShift] elements being pushed off, and the last numShift elements
//becoming zero. Does this for all data channels.
public void shiftNtimes(float[][] myArray, int numShifts){
  int timesShifted = 0;
  while (timesShifted < numShifts){
    for (int i = 0; i < NUM_CHANNELS; i++){
      for (int j = 0; j < timeLength - 1; j++){
        myArray[i][j] = myArray[i][j + 1];
      }
      myArray[i][(int)timeLength - 1] = 0;
      timesShifted++;
    }
  }
}

//Grabs data from a source and uses it to fill up the last inBuffer
//spots of the data stream, displayBuffer (usually spots that have
//just been cleared from shiftNtimes). Does this for all data channels.
int counter = 0;
public void updateData(float[][] displayBuffer){
  for (int i = 0; i < NUM_CHANNELS; i++){
      for (int j = 0; j < inBuffer; j++){
        float sinFrequency = 1;
        float inByte = 20*sin(2*PI*((inBuffer*counter+j)%(inBuffer*60/sinFrequency))/(inBuffer*60/sinFrequency));
        //float inByte = out.mix.get(j);
        //float inByte = random(0,1023);
        //inByte -= 512;
        //inByte = inByte * (timeHeight/2)/512;
        //float inByte = myPort.read();
        displayBuffer[i][displayBuffer[i].length - (inBuffer - j)] = inByte;
      }
  }
  counter++;
}

//Displays the signal in time domain. Gives a line to each data channel, and plots the
//current values stored in the data stream, displayBuffer.
public void displayData(float[][] displayBuffer){
  for (int i = 0; i < NUM_CHANNELS; i++){
    for (int j = 0; j < width-1; j++){
      line(j, timeHeight/2+timeHeight*i*2 + displayBuffer[i][floor(timeLength/width*j)],
      j+1, timeHeight/2+timeHeight*i*2 + displayBuffer[i][floor(timeLength/width*(j+1))]);
    }
  }
}

//Runs autoregressive frequency analysis (alternative to FFT)
//on the time domain signal. Outputs coefficients for the transfer
//function of the autocorrelated signal in frequency. Works on the
//time domain signals in displayBuffer, on specified channel. Tries fitting
//the data to all M values up L, the maximum M, (M is how far back in the data stream to
//go to interpolate further data), and chooses an 'a' with bestM length.
//Along the way, it computes Cxx, the autocovariances of the data, which will be
//used in future functions.
//Calculations follow directly from:
//http://www.csee.wvu.edu/~xinl/library/papers/math/statistics/Akaike1969.pdf
float Cxx[] = new float[L+1]; //declare Cxx as global
float xTilde[] = new float[N];

float[] runAutoregression(int channel){
  float maxFPE = 0;
  int bestM = 0;
  //construct our modified time domain signal, xTilde
  float xBar = 0;
  for (int i = 0; i < N; i++){
    xBar += displayBuffer[channel][i];
  }
  xBar /= N;
  for (int i = 0; i < N; i++){
    xTilde[i] = displayBuffer[channel][i] - xBar;
  }
  //Construct the sample autocovariances, Cxx(l)
  //Cxx declared at beginning so subfunctions can use it
  for (int i = 0; i < Cxx.length; i++){
    float Csum = 0;     
    for (int n = 0; n < N - i; n++){
      Csum += xTilde[n+i]*xTilde[n];
    }
    Csum /= N;
    Cxx[i] = Csum;
  }
  //construct square matrix to find a-hat coefficients
  for (int M = L; M > 0; M--){
    float a[] = new float[M];
    a = getCoefficients(M);
    float Rm = calculateR(a,M);
    float FPE = calculateFPE(Rm,M);
    if (FPE > maxFPE){
      maxFPE = FPE;
      bestM = M;
    }
  }
  float a[] = new float[bestM];
  a = getCoefficients(bestM);
  println(a);
  return a;
}

//Calculates the autoregressive coefficients 'a' for a given
//M, which is the number of previous samples to use in your 
//frequency analysis. Uses the sample autocovariances, Cxx,
//to calculate these coefficients.
float[] getCoefficients(int M){
  float CxxSquare[][] = new float[M][M];
  float a[] = new float[M];
  for (int i = 0; i < M; i++){
    for (int j = 0; j < M; j++){
      CxxSquare[i][j] = Cxx[abs(j-i)];
    }
  }
  float shiftedCxx[] = new float[M];
  for (int i = 0; i < M; i++){
    shiftedCxx[i] = Cxx[i+1];
  }
  a = solveLevinson(CxxSquare[0],shiftedCxx);
  return a;
}

//Evaluates a transfer function of the form 
//H = 1/(1+a1*e^(-j2pif)+a2e^(2*-j2pif) ...)
//for all f between 0 and .5, with resolution defines by
//the pre-set freqRange and freqRes.
float[] realtemp, imagtemp, magnitude;
float[] evaluateTransfer(float[] a){
  realtemp = new float[(int)(freqRange/freqRes)];
  imagtemp = new float[(int)(freqRange/freqRes)];
  magnitude = new float[(int)(freqRange/freqRes)];
  for (float f = 0; f < .5; f += freqRes/freqRange){
    int index = (int)(f*freqRange/freqRes);
    //break exp(i*2*pi*n*f) into its real and imaginary parts
    for (int i = 0; i < a.length; i++){
      realtemp[index] += a[i]*cos(-2*PI*(i+1)*f);
      imagtemp[index] += a[i]*sin(-2*PI*(i+1)*f);
    }
    realtemp[index] = pow(realtemp[index],2);
    imagtemp[index] = pow(imagtemp[index],2);
    magnitude[index] = 1/(realtemp[index]+imagtemp[index]);
  }
  return magnitude;
}

//Graphs the frequency data obtained in evaluateTransfer. The scaleFreq
//parameter directly before it controls the overall height of the data displayed.
float scaleFreq = 20; //controls total height of frequency bars
void displayFreqData(float[] magnitude, int channelNum){
  for (int i = 0; i < magnitude.length; i++){
    rect(i*(width/magnitude.length), timeHeight*2*(channelNum+1),
      (width/magnitude.length), -magnitude[i]*scaleFreq);
  }
}

//Solves the system R*hinv = q for hinv, via Levinson
//recursion. The first column of R is r. Method itself 
//was taken from the matlab version at this link:
//http://www.musicdsp.org/showone.php?id=188
float[] solveLevinson(float[] r,float[] q){
  int n = q.length;
  float a[][] = new float[n+1][2];
  a[0][0] = 1;
  float hinv[] = new float[n];
  hinv[0] = q[0]/r[0];
  float alph = r[0];
  int c = 1;
  int d = 2;
  for (int k = 0; k < n-1; k++){
    a[k+1][c-1] = 0;
    a[0][d-1] = 1;
    float beta = 0;
    for (int i = 1; i <= k+1; i++){
      beta += r[k+2-i]*a[i-1][c-1];
    }
    beta /= alph;
    for (int i = 1; i <= k+1; i++){
      a[i+1-1][d-1] = a[i+1-1][c-1] - beta*a[k+1-i][c-1];
    }
    alph *= 1-pow(beta,2);
    float hinvsum = 0;
    for (int i = 1; i <= k+1; i++){
      hinvsum += r[k+2-i]*hinv[i-1];
    }
    hinv[k+1] = q[k+1] - hinvsum;
    hinv[k+1] /= alph;
    for (int i = 1; i <= k+1; i++){
      hinv[i-1] = hinv[i-1] + a[k+2-i][d-1]*hinv[k+1];
    }
    int temp = c;
    c = d;
    d = temp;
  }
  return hinv;
}

float calculateR(float[] a, int M){
  float Rsum = 0;
  for (int n = 0; n < N; n++){
    float msum = 0;
    for (int m = 0; m < M; m++){
      if (n-m >= 0){
        msum += a[m]*xTilde[n-m];
      }
    }
    Rsum += pow(xTilde[n] - msum,2);
  }
  return Rsum / N;
}

float calculateFPE(float Rm, int M){
  float Sm = N/(N-1-M) * Rm;
  float FPE = (1 + (1 + M)/N) * Sm;
  return FPE;
}

void keyPressed(){
  if (key == 'p'){
    noLoop();
  }
  if (key == 'c'){
    loop();
  }
}

