#include <Layer.h>
Layer::Layer(){
}

Layer::Layer(SpriteAccelerator *TempSpriteRenderer)
      :SpriteRenderer(TempSpriteRenderer){
}

void Layer::SetUp(SpriteAccelerator *TempSpriteRenderer){
  SpriteRenderer = TempSpriteRenderer;
}

bool Layer::LoadLayer(JsonArray& LayerData, uint8_t LayerNum){
  for(uint8_t y = 0; y < 15; y++){
    for(uint8_t x = 0; x < 20; x++){
      uint16_t ImageNum = LayerData[(y*20) + x];
      if(ImageNum == 0){
        Blocks[y][x].SetUp(SpriteRenderer, false, x * 32, y * 32, false, 0);
      }else{
        Blocks[y][x].SetUp(SpriteRenderer, true, x * 32, y * 32, true, ImageNum - 1);
      }
    }
  }
  return true;
}

bool Layer::LoadLayer(uint16_t ImageNum){
  for(uint8_t y = 0; y < 15; y++){
    for(uint8_t x = 0; x < 20; x++){
      if(ImageNum == 0){
        Blocks[y][x].SetUp(SpriteRenderer, false, x * 32, y * 32, false, 0);
      }else{
        Blocks[y][x].SetUp(SpriteRenderer, true, x * 32, y * 32, true, ImageNum);
      }
    }
  }
  return true;
}
