#ifndef Layer_h
#define Layer_h

#include <SD.h>
#include <Arduino.h>
#include <SpriteAccelerator.h>
#include <Block.h>
#include <ArduinoJson.h>

class Layer{
  public:
    Layer();
    Layer(SpriteAccelerator *SpriteRenderer);
    void SetUp(SpriteAccelerator *SpriteRenderer);
    bool LoadLayer(JsonArray& LayerData, uint8_t LayerNum);
    bool LoadLayer(uint16_t ImageNum);
    Block Blocks[15][20];
  private:
    SpriteAccelerator *SpriteRenderer;
};

#endif
