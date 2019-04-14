#ifndef Block_h
#define Block_h

#include <Arduino.h>
#include <SpriteAccelerator.h>
#include <Sprite.h>

class Block{
  public:
    Block ();
    void SetUp(SpriteAccelerator *TempSpriteRenderer, bool TempSolid, uint16_t TempXPos, uint16_t TempYPos, bool TempVisible, uint16_t TempImageNum);
    Sprite BlockSprite;
    bool Solid;
  private:
};

#endif
