#include <Image.h>
Image::Image(){}

Image::Image(SpriteAccelerator *TempSpriteRenderer,uint16_t TempColour, uint16_t TempImageNum)
      :SpriteRenderer(TempSpriteRenderer),Colour(TempColour),ImageNum(TempImageNum){
  SolidColour = true;
};

Image::Image(SpriteAccelerator *TempSpriteRenderer,char* Tfile, uint16_t TempImageNum)
      :SpriteRenderer(TempSpriteRenderer),file(Tfile),ImageNum(TempImageNum){
  SolidColour = false;
};

void Image::SetUp(SpriteAccelerator *TempSpriteRenderer,char* Tfile, uint16_t TempImageNum){
  SpriteRenderer = TempSpriteRenderer;
  file = Tfile;
  ImageNum = TempImageNum;
  SolidColour = false;
}

bool Image::GetColourData(uint16_t ColourBuffer[][32]){
  if(SolidColour){
    Serial.print("Uploading new solid colour image, color: ");Serial.println(Colour);
    for(int y = 0; y < 32; y++){
      for(int x = 0; x < 32; x++){
        ColourBuffer[y][x] = Colour;
      }
    }
  }else{
    byte R, G, B;
    //tempary buffer for colour calcualtions
    uint16_t color;
    //read sd buffer
    byte sdBuf[32 * 3];

    Serial.print("Uploading image from file: ");Serial.println(file);

    File bmpImage;
    if(SD.exists(file)){
      bmpImage = SD.open(file, FILE_READ);
    }else{
      Serial.print("Failed to find image: ");
      Serial.println(file);
      return false;
    }
    int32_t dataStartingOffset = readNbytesInt(&bmpImage, 0x0A, 4);
    int32_t width = readNbytesInt(&bmpImage, 0x12, 4);
    int32_t height = readNbytesInt(&bmpImage, 0x16, 4);

    if((width != 32) || (height != 32)){
      Serial.println(F("Image isn't 32 x 32 pixels!!"));
      return false;
    }

    int16_t pixelsize = readNbytesInt(&bmpImage, 0x1C, 2);
    if (pixelsize != 24){
      Serial.println(F("Image is not 24 bpp!!"));
      return false;
    }

    //skip bitmap header
    bmpImage.seek(dataStartingOffset);

    for (uint8_t y = 0; y < 32; y++) {
      bmpImage.read(sdBuf, sizeof(sdBuf));
      int index = 0;
      for (uint8_t x = 0; x < 32; x++) {
        B = sdBuf[index];
        G = sdBuf[index + 1];
        R = sdBuf[index + 2];
        index += 3;
        color = R >> 3;
        color = color << 6 | (G >> 2);
        color = color << 5 | (B >> 3);
        ColourBuffer[y][x] = color;
      }
    }
    //Close the bmpImage file
    bmpImage.close();
  }
  return true;
};

bool Image::UpLoadColourData(){
  uint16_t pixelBuff[32][32];
  if(GetColourData(pixelBuff)){
    SpriteRenderer->NewImage(pixelBuff,ImageNum);
    return true;
  }else{
    return false;
  }
}

int32_t Image::readNbytesInt(File *p_file, int position, byte nBytes){
  if (nBytes > 4)
    return 0;

  p_file->seek(position);

  int32_t weight = 1;
  int32_t result = 0;
  for (; nBytes; nBytes--){
    result += weight * p_file->read();
    weight <<= 8;
  }
  return result;
};
