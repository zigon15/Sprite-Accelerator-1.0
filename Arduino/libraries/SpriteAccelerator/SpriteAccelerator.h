#ifndef SpriteAccelerator_h
#define SpriteAccelerator_h

#include <SPI.h>
#include <Arduino.h>

class SpriteAccelerator{
  public:
    SpriteAccelerator(uint8_t TempCommandReadyPin, uint8_t TempChipSelectPin);
    uint16_t NewSprite(uint16_t XPos, uint16_t YPos, uint16_t ImageNum, uint8_t Visible);
    void UpdateSpriteAttributes(uint16_t SpriteNum, uint16_t XPos, uint16_t YPos, uint16_t ImageNum, uint8_t Visible);
    void NewImage(uint16_t Colour[32][32], uint16_t ImageNum);
    void StartRender();
    void ToggleFrameBuffer();
    void BeginTransfer();
    void EndTransfer();
    bool CommandFinished();
  private:
    uint8_t CommandReadyPin;
    uint8_t ChipSelectPin;
    uint16_t NumSprites;
};

#endif
