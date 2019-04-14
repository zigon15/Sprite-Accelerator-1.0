#include <Sprite.h>
Sprite::Sprite(){

}

void Sprite::SetUp(SpriteAccelerator *TempSpriteRenderer, uint16_t TempXPos, uint16_t TempYPos, bool TempVisible, uint16_t TempImageNum){
  SpriteRenderer = TempSpriteRenderer;
  XPos = TempXPos;
  YPos = TempYPos;
  Visible = TempVisible;
  ImageNum = TempImageNum;
  SpriteNum = SpriteRenderer->NewSprite(XPos,YPos,TempImageNum,Visible);
}

void Sprite::Move(uint16_t TempXPos, uint16_t TempYPos){
  XPos = TempXPos;
  YPos = TempYPos;
  SpriteRenderer->UpdateSpriteAttributes(SpriteNum,XPos,YPos,ImageNum,(uint8_t)Visible);
}

void Sprite::Update(){
  SpriteRenderer->UpdateSpriteAttributes(SpriteNum,XPos,YPos,ImageNum,(uint8_t)Visible);
}
