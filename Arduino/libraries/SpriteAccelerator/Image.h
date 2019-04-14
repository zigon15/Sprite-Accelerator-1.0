#ifndef Image_h
#define Image_h

#include <SD.h>
#include <Arduino.h>
#include <SpriteAccelerator.h>

class Image{
  public:
    Image();
    Image(SpriteAccelerator *TempSpriteRenderer,uint16_t TempColour, uint16_t TempImageNum);
    Image(SpriteAccelerator *TempSpriteRenderer,char* Tfile, uint16_t TempImageNum);
    void SetUp(SpriteAccelerator *TempSpriteRenderer,char* Tfile, uint16_t TempImageNum);
    bool GetColourData(uint16_t ColourBuffer[][32]);
    bool UpLoadColourData();
    int32_t readNbytesInt(File *p_file, int position, byte nBytes);
  private:
    bool SolidColour;
    char* file;
    uint16_t Colour;
    uint16_t ImageNum;
    SpriteAccelerator* SpriteRenderer;
};

#endif
