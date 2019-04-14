#include <Block.h>

Block::Block(){
}

void Block::SetUp(SpriteAccelerator *TempSpriteRenderer, bool TempSolid, uint16_t TempXPos, uint16_t TempYPos, bool TempVisible, uint16_t TempImageNum){
  Solid = TempSolid;
  BlockSprite.SetUp(TempSpriteRenderer,TempXPos, TempYPos,TempVisible, TempImageNum);
}
