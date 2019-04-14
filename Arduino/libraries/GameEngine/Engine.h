#ifndef Engine_h
#define Engine_h

#include <SD.h>
#include <Arduino.h>
#include <SpriteAccelerator.h>
#include <Layer.h>
#include <Image.h>

class Engine{
  public:
    Engine (uint8_t TempChipSelectPin, uint8_t TempCommandReadyPin);
    SpriteAccelerator SpriteRenderer;
    void Render();
    bool LoadTileSet(char* file);
    bool LoadMap(char* file);
    Layer Layers[5];
    Image Images[40];
  private:
    uint8_t SdCardPin;
};
#endif
