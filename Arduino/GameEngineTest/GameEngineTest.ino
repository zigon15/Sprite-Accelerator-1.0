#include <SPI.h>
#include <SD.h>
#include <Engine.h>

#define ChipSelectPin 14
#define CommandReadyPin 15

#define XJoyStick A8
#define YJoyStick A9

#define SteveTop 29
#define SteveBottom 28

Engine GameEngine(CommandReadyPin, ChipSelectPin);
Entity Steve;

unsigned long Timer;
float DeltaX = 0;
float DeltaY = 0;
float Speed = 1.0;

void setup() {
  //start up serial
  Serial.begin(250000);
  SD.begin(BUILTIN_SDCARD);

  unsigned long TimerStartA = millis();
  GameEngine.LoadTileSet("tileset1.map");
  unsigned long TimerStartB = millis();
  GameEngine.LoadMap("map1.map");
  unsigned long TimerStartC = millis();
  Serial.print("Time Taken to Load Images: "); Serial.print(TimerStartB - TimerStartA); Serial.println(" ms");
  Serial.print("Time Taken to Load Sprites: "); Serial.print(TimerStartC - TimerStartB); Serial.println(" ms");
  Serial.print("Total Time: "); Serial.print(TimerStartC - TimerStartA); Serial.println(" ms");
  Steve.SetUp(&GameEngine.SpriteRenderer, &GameEngine.Layers[1], 0, 0, 1, SteveTop, SteveBottom);

}

void loop() {
  float DeltaT = (float)(millis() - Timer)/1000;
  Timer = millis();
  
  int16_t JoyStickX = map(analogRead(XJoyStick), 0, 1023, -255, 255);
  int16_t JoyStickY = map(analogRead(YJoyStick), 0, 1023, 255, -255);
  
  if (((JoyStickY < -50) || (JoyStickY > 50)) || (((JoyStickX < -50) || (JoyStickX > 50)))){
    DeltaX = JoyStickX * DeltaT * Speed;
    DeltaY = JoyStickY * DeltaT * Speed;
  }else{
    DeltaX = 0;
    DeltaY = DeltaT * Speed * 300.0;
  }
  Steve.DeltaMove(DeltaX, DeltaY);
  GameEngine.Render();
}


