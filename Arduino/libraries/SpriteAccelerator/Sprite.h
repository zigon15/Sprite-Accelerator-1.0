#ifndef Sprite_h
#define Sprite_h

#include <Arduino.h>
#include <SpriteAccelerator.h>

class Sprite{
  public:
    Sprite();
    void SetUp(SpriteAccelerator *TempSpriteRenderer, uint16_t TempXPos, uint16_t TempYPos, bool TempVisible, uint16_t TempImageNum);
    void Move(uint16_t TempXPos, uint16_t TempYPos);
    void Update();
    bool Visible;
    uint16_t XPos;
    uint16_t YPos;
    uint16_t ImageNum;
  private:
    uint16_t SpriteNum;
    SpriteAccelerator* SpriteRenderer;
};

#endif
