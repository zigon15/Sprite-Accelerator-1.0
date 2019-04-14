#ifndef Entity_h
#define Entity_h

#include <Arduino.h>
#include <SpriteAccelerator.h>
#include <Sprite.h>
#include <Layer.h>

class Entity{
  public:
    Entity();
    Sprite SpriteTop;
    Sprite SpriteBottom;
    void SetUp(SpriteAccelerator *TempSpriteRenderer, Layer *TempCollisionLayer, uint16_t TempXPos, uint16_t TempYPos, bool TempVisible, uint16_t TempImageNumTop, uint16_t TempImageNumBottom);
    void Move(uint16_t TempXPos, uint16_t TempYPos);
    void DeltaMove(int16_t TempDeltaXPos, int16_t TempDeltaYPos);
    bool TestCollision(uint16_t XPos, uint16_t YPos);
  private:
    int16_t XPos;
    int16_t YPos;
    Layer *CollisionLayer;
    //Layer TestLayer;
};
#endif
