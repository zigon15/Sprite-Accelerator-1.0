#include<Engine.h>

Engine::Engine (uint8_t TempChipSelectPin, uint8_t TempCommandReadyPin)
           :SpriteRenderer(TempChipSelectPin,TempCommandReadyPin){
}

void Engine::Render(){
  SpriteRenderer.StartRender();
}

//Loads map data from a Tiled json map file
bool Engine::LoadMap(char* file){
  Serial.print("Loading Map Data from File ");Serial.println(file);

  if(!SD.exists(file)){
    Serial.print("Failed to Find Map File: ");Serial.println(file);
    return false;
  }
  File Map;
  Map = SD.open(file);

  DynamicJsonBuffer jb;
  JsonObject& JsonMap = jb.parseObject(Map);
  if(!JsonMap.success()){
    Serial.println("parseObject Failed");
    return false;
  }

  Serial.print("Map height: ");Serial.println((int)JsonMap["height"]);
  Serial.print("Map width: ");Serial.println((int)JsonMap["width"]);
  uint8_t NumLayers = JsonMap["layers"].size();
  Serial.print("Number of Layers: ");Serial.println(NumLayers);

  if(NumLayers <= 10){
    for(uint8_t t = 0; t < NumLayers; t++){
      Layers[t].SetUp(&SpriteRenderer);
      Serial.print("Layer: ");Serial.println(t);
      Layers[t].LoadLayer(JsonMap["layers"][t]["data"],t);
    }
  }else{
    Serial.println("Too many Layers in Map File");
    return false;
  }
  return true;
}

//Loads images based on a Tiled map tile set
bool Engine::LoadTileSet(char* file){
  Serial.print("Loading Tileset from File ");Serial.println(file);

  if(!SD.exists(file)){
    Serial.print("Failed to Find Tileset File: ");Serial.println(file);
    return false;
  }
  File TileSet;
  TileSet = SD.open(file);

  DynamicJsonBuffer jb;
  JsonObject& JsonTileSet = jb.parseObject(TileSet);

  if(!JsonTileSet.success()){
    Serial.println("parseObject Failed");
    return false;
  }
  uint16_t NumImages = (uint16_t)JsonTileSet["tilecount"];
  Serial.print("Number of Tiles: ");Serial.println(NumImages);

  JsonArray& TileImages = JsonTileSet["tiles"];

  for(uint16_t t = 0; t < NumImages; t++){
    JsonObject& Tile = TileImages[t];
    const char* ImageFile = Tile["image"];
    uint16_t ImageNum = Tile["id"];

    Images[t].SetUp(&SpriteRenderer,(char*)ImageFile,ImageNum);
    Images[t].UpLoadColourData();
  }
}
