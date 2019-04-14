#include <SpriteAccelerator.h>

#define CMDNewSprite 0
#define CMDNewImage 1
#define CMDStartRender 2
#define CMDToggleFrameBuffer 3
#define CMDUpdateSpriteAttributes 4

SpriteAccelerator::SpriteAccelerator(uint8_t TempCommandReadyPin, uint8_t TempChipSelectPin)
                  :CommandReadyPin(TempCommandReadyPin),ChipSelectPin(TempChipSelectPin){
  SPI.begin();
  pinMode(ChipSelectPin, OUTPUT);
  pinMode(CommandReadyPin,INPUT);
}

uint16_t SpriteAccelerator::NewSprite(uint16_t XPos, uint16_t YPos, uint16_t ImageNum, uint8_t Visible){
  while(!CommandFinished());
  BeginTransfer();
  SPI.transfer(CMDNewSprite | (Visible << 7));

  SPI.transfer(XPos & 0xFF);
  SPI.transfer(XPos >> 8);

  SPI.transfer(YPos & 0xFF);
  SPI.transfer(YPos >> 8);

  SPI.transfer(ImageNum & 0xFF);
  SPI.transfer(ImageNum >> 8);
  EndTransfer();
  NumSprites = NumSprites + 1;
  return NumSprites - 1;
}

void SpriteAccelerator::UpdateSpriteAttributes(uint16_t SpriteNum, uint16_t XPos, uint16_t YPos, uint16_t ImageNum, uint8_t Visible){
  while(!CommandFinished());
  BeginTransfer();

  SPI.transfer(CMDUpdateSpriteAttributes | (Visible << 7));

  SPI.transfer(SpriteNum & 0xFF);
  SPI.transfer(SpriteNum >> 8);

  SPI.transfer(XPos & 0xFF);
  SPI.transfer(XPos >> 8);

  SPI.transfer(YPos & 0xFF);
  SPI.transfer(YPos >> 8);

  SPI.transfer(ImageNum & 0xFF);
  SPI.transfer(ImageNum >> 8);

  EndTransfer();
}

void SpriteAccelerator::NewImage(uint16_t Colour[32][32], uint16_t ImageNum){
  while(!CommandFinished());
  BeginTransfer();

  SPI.transfer(CMDNewImage);

  SPI.transfer(ImageNum & 0xFF);
  SPI.transfer(ImageNum >> 8);

  for(int y = 31; y >= 0; y--){
    for(int x = 0; x < 32; x++){
      SPI.transfer(Colour[y][x] & 0xFF);
      SPI.transfer(Colour[y][x] >> 8);
    }
  }
  EndTransfer();
}

void SpriteAccelerator::StartRender(){
  while(!CommandFinished());
  BeginTransfer();
  SPI.transfer(CMDStartRender);
  EndTransfer();
}

void SpriteAccelerator::ToggleFrameBuffer(){
  while(!CommandFinished());
  BeginTransfer();
  SPI.transfer(CMDToggleFrameBuffer);
  EndTransfer();
}

void SpriteAccelerator::BeginTransfer(){
  SPI.beginTransaction(SPISettings(50000000, MSBFIRST, SPI_MODE0));
  digitalWrite(ChipSelectPin, LOW);
}

void SpriteAccelerator::EndTransfer(){
  digitalWrite(ChipSelectPin, HIGH);
  SPI.endTransaction();
}

bool SpriteAccelerator::CommandFinished(){
  return digitalRead(CommandReadyPin);
}
