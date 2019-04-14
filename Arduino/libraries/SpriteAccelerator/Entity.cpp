#include <Entity.h>

Entity::Entity (){
}

void Entity::SetUp(SpriteAccelerator *TempSpriteRenderer, Layer *TempCollisionLayer, uint16_t TempXPos, uint16_t TempYPos, bool TempVisible, uint16_t TempImageNumTop, uint16_t TempImageNumBottom){
  //TestLayer.SetUp(TempSpriteRenderer);
  //TestLayer.LoadLayer(0);
  SpriteTop.SetUp(TempSpriteRenderer,TempXPos,TempYPos,TempVisible,TempImageNumTop);
  SpriteBottom.SetUp(TempSpriteRenderer,TempXPos,TempYPos+32,TempVisible,TempImageNumBottom);
  CollisionLayer = TempCollisionLayer;
}

void Entity::Move(uint16_t TempXPos, uint16_t TempYPos){
  XPos = TempXPos;
  YPos = TempYPos;
  SpriteTop.Move(XPos,YPos);
  SpriteBottom.Move(XPos,YPos+32);
}

void Entity::DeltaMove(int16_t TempDeltaXPos, int16_t TempDeltaYPos){

  if(!TestCollision(XPos + TempDeltaXPos, YPos + TempDeltaYPos)){
    XPos += TempDeltaXPos;
    YPos += TempDeltaYPos;
    SpriteTop.Move(XPos,YPos);
    SpriteBottom.Move(XPos,YPos+32);
  }
  Serial.print("XPos = ");Serial.print(XPos);
  Serial.print(" YPos = ");Serial.println(YPos);
}

bool Entity::TestCollision(uint16_t XPos, uint16_t YPos){
  uint8_t XTilePos = XPos / 32;
  uint8_t YTilePos = YPos / 32;

  if(XPos < 0){
    return true;
  }else if(XPos > 608){
    return true;
  }

  if(YPos < 0){
    return true;
  }else if(YPos > 416){
    return true;
  }
  /*for(int8_t y = 0; y < 15; y++){
    for(int8_t x = 0; x < 20; x++){
      TestLayer.Blocks[y][x].BlockSprite.ImageNum = 0;
      TestLayer.Blocks[y][x].BlockSprite.Visible = false;
      TestLayer.Blocks[y][x].BlockSprite.Update();
    }
  }*/

  bool Test = false;
  uint8_t XWidth, YWidth;
  if(YPos%32 == 0){
    YWidth = 1;
  }else{
    YWidth = 2;
  }

  if(XPos%32 == 0){
    XWidth = 0;
  }else{
    XWidth = 1;
  }

  for(int8_t y = 0; y <= YWidth; y++){
    for(int8_t x = 0; x <= XWidth; x++){
      /*TestLayer.Blocks[YTilePos+y][XTilePos+x].BlockSprite.ImageNum = 1;
      TestLayer.Blocks[YTilePos+y][XTilePos+x].BlockSprite.Visible = true;
      TestLayer.Blocks[YTilePos+y][XTilePos+x].BlockSprite.Update();*/
      if(CollisionLayer->Blocks[YTilePos+y][XTilePos+x].Solid){
        Test = true;
      }
    }
  }
  return Test;
}
