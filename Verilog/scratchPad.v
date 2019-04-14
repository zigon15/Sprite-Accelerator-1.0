`timescale 1ns / 1ps

module SpriteCommands #(
  parameter SpritePixelDataStartAddress = 1228801,
  parameter SpriteWidth = 32,
  parameter SpriteHeight = 32,
  parameter SpriteSize = 2048
  )(
  input Clk,
  input Rst,
  //--------------SPI Interface-----------------//
  input SCLK,
	input MOSI,
	output MISO,
	input SS,
  output ReadyForCommand,
  //-----------Sprite Accelerator---------------//
  input FinishedRendering,
  output RenderNextFrame,
  output [11:0]NumSprites,
  //-----------Sprite Info BRAM---------------//
  output [11:0]SpriteInfoAddress,
  output [29:0]SpriteInfoData,
  output WriteEnable,
  //---------------Frame Buffer-----------------//
  output FrameBuffer,
  input FrameBufferActive,
  //--------------RAM Command Path--------------//
  input calib_done,

  //WRITE Port
  output write_cmd_clk,
  output write_cmd_en,
  output [2:0]write_cmd_instr,
  output [5:0]write_cmd_bl,
  output [29:0]write_cmd_byte_addr,
  input write_cmd_empty,
  input write_cmd_full,

  output wr_clk,
  output wr_en,
  output [3:0] wr_mask,
  output [31:0] wr_data,
  input wr_full,
  input wr_empty,
  input [6:0] wr_count,
  input wr_underrun,
  input wr_error
  );
  //--------------SPI Interface-----------------//
  assign ReadyForCommand = ReadyForCommand_q;

  wire FinishedTransmission;
  wire [7:0] SpiData;
  reg ReadyForCommand_q, ReadyForCommand_d;
  //-----------Sprite Accelerator---------------//
  assign RenderNextFrame = RenderNextFrame_q;
  assign NumSprites = NumSprites_q;

  reg RenderNextFrame_q, RenderNextFrame_d = 1'b0;
  reg [11:0] NumSprites_q, NumSprites_d = 12'b0;

  reg [9:0] XPos_q, XPos_d = 10'b0;
  reg [8:0] YPos_q, YPos_d = 9'b0;
  reg [9:0] ImageNum_q, ImageNum_d = 10'b0;
  //-----------Sprite Info BRAM---------------//
  assign SpriteInfoAddress = SpriteInfoAddress_q;
  assign SpriteInfoData = SpriteInfoData_q;
  assign WriteEnable = WriteEnable_q;

  reg [11:0]SpriteInfoAddress_q, SpriteInfoAddress_d = 12'b0;
  reg [29:0]SpriteInfoData_q, SpriteInfoData_d = 30'b0;
  reg WriteEnable_q, WriteEnable_d = 1'b0;
  //---------------Frame Buffer-----------------//
  assign FrameBuffer = FrameBuffer_q;

  reg FrameBuffer_q, FrameBuffer_d = 1'b0;
  //--------------RAM Command Path--------------//
  //Write Command/Fifo
  assign write_cmd_clk = Clk;
  assign write_cmd_en = write_cmd_en_q;
  assign write_cmd_instr = 3'b000; //permanetly set to write
  assign write_cmd_bl = write_cmd_bl_q;
  assign write_cmd_byte_addr = write_cmd_byte_addr_q;
  assign wr_clk = Clk;
  assign wr_en = wr_en_q;
  assign wr_mask = wr_mask_q;
  assign wr_data = wr_data_q;

  reg write_cmd_en_q, write_cmd_en_d = 1'b0;
  reg [5:0] write_cmd_bl_q, write_cmd_bl_d = 6'b0;
  reg [29:0]write_cmd_byte_addr_q, write_cmd_byte_addr_d;
  reg wr_en_q, wr_en_d = 1'b0;
  reg [3:0]wr_mask_q, wr_mask_d = 4'b0;
  reg [31:0]wr_data_q, wr_data_d = 32'b0;

  //--------------------State Machines-------------------//
  localparam STATE_SIZE = 4;
  localparam Wait = 0,
             NewSprite = 1,
             NewImage = 2,
             StartRender = 3,
             ToggleFrameBuffer = 4,
             UpdateSpriteAttributes = 5;
  reg [STATE_SIZE-1:0] state_q, state_d = Wait;

  localparam NewSprite_STATE_SIZE = 3;
  localparam NewSprite_GetXPosLSB = 0,
             NewSprite_GetXPosMSB = 1,
             NewSprite_GetYPosLSB = 2,
             NewSprite_GetYPosMSB = 3,
             NewSprite_GetImageNumLSB = 4,
             NewSprite_GetImageNumMSB = 5,
             NewSprite_Write = 6;
  reg [NewSprite_STATE_SIZE-1:0] NewSprite_state_q, NewSprite_state_d = NewSprite_GetXPosLSB;

  localparam NewImage_STATE_SIZE = 2;
  localparam NewImage_GetImageNumLSB = 0,
             NewImage_GetImageNumMSB = 1,
             NewImage_LoadFifo = 2,
             NewImage_CmdEnable = 3;
  reg [NewImage_STATE_SIZE-1:0] NewImage_state_q, NewImage_state_d = NewImage_GetImageNumLSB;

  localparam NewImage_WriteCMD_STATE_SIZE = 1;
  localparam NewImage_WriteCMD_Check = 0,
             NewImage_WriteCMD_Wait = 1;
  reg [NewImage_WriteCMD_STATE_SIZE-1:0] NewImage_WriteCMD_state_q,
                                         NewImage_WriteCMD_state_d = NewImage_WriteCMD_Check;

  localparam UpdateSpriteAttributes_STATE_SIZE = 4;
  localparam UpdateSpriteAttributes_GetSpriteNumLSB = 0,
             UpdateSpriteAttributes_GetSpriteNumMSB = 1,
             UpdateSpriteAttributes_GetXPosLSB = 2,
             UpdateSpriteAttributes_GetXPosMSB = 3,
             UpdateSpriteAttributes_GetYPosLSB = 4,
             UpdateSpriteAttributes_GetYPosMSB = 5,
             UpdateSpriteAttributes_GetImageNumLSB = 6,
             UpdateSpriteAttributes_GetImageNumMSB = 7,
             UpdateSpriteAttributes_Write = 8;
  reg [UpdateSpriteAttributes_STATE_SIZE-1:0] UpdateSpriteAttributes_state_q,
                                              UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_GetSpriteNumLSB;

  //--------------Sprite Accelerator Commands-----------//
  parameter CMDNewSprite = 5'd0;
  parameter CMDNewImage = 5'd1;
  parameter CMDStartRender = 5'd2;
  parameter CMDToggleFrameBuffer = 5'd3;
  parameter CMDUpdateSpriteAttributes = 5'd4;

  always @ ( * ) begin
    ReadyForCommand_d = ReadyForCommand_q;

    RenderNextFrame_d = RenderNextFrame_q;
    NumSprites_d = NumSprites_q;
    XPos_d = XPos_q;
    YPos_d = YPos_q;
    ImageNum_d = ImageNum_q;

    SpriteInfoAddress_d = SpriteInfoAddress_q;
    SpriteInfoData_d = SpriteInfoData_q;
    WriteEnable_d = WriteEnable_q;
    FrameBuffer_d = FrameBuffer_q;

    //Write
    write_cmd_en_d = write_cmd_en_q;
    write_cmd_bl_d = write_cmd_bl_q;
    write_cmd_byte_addr_d = write_cmd_byte_addr_q;
    wr_en_d = wr_en_q;
    wr_mask_d = wr_mask_q;
    wr_data_d = wr_data_q;

    //State Machines
    state_d = state_q;
    NewSprite_state_d = NewSprite_state_q;
    NewImage_state_d = NewImage_state_q;
    NewImage_WriteCMD_state_d = NewImage_WriteCMD_state_q;
    UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_state_q;

    case (state_q)
      Wait:begin
        ReadyForCommand_d = 1'b1;
        if (FinishedTransmission) begin
          ReadyForCommand_d = 1'b0;
          case (SpiData[4:0])
            CMDNewSprite:begin
              SpriteInfoData_d[29] = SpiData[7];
              SpriteInfoAddress_d = NumSprites;
              state_d = NewSprite;
            end
            CMDNewImage:begin
              state_d = NewImage;
            end
            CMDStartRender:begin
              RenderNextFrame_d = 1'b1;
              state_d = StartRender;
            end
            CMDToggleFrameBuffer:begin
              state_d = ToggleFrameBuffer;
            end
            CMDUpdateSpriteAttributes:begin
              SpriteInfoData_d[29] = SpiData[7];
              state_d = UpdateSpriteAttributes;
            end
          endcase
        end
      end
      NewSprite:begin
        case (NewSprite_state_q)
          NewSprite_GetXPosLSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[7:0] = SpiData;
              NewSprite_state_d = NewSprite_GetXPosMSB;
            end
          end
          NewSprite_GetXPosMSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[9:8] = SpiData[1:0];
              NewSprite_state_d = NewSprite_GetYPosLSB;
            end
          end
          NewSprite_GetYPosLSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[17:10] = SpiData;
              NewSprite_state_d = NewSprite_GetYPosMSB;
            end
          end
          NewSprite_GetYPosMSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[18] = SpiData[0];
              NewSprite_state_d = NewSprite_GetImageNumLSB;
            end
          end
          NewSprite_GetImageNumLSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[26:19] = SpiData;
              NewSprite_state_d = NewSprite_GetImageNumMSB;
            end
          end
          NewSprite_GetImageNumMSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[28:27] = SpiData[1:0];
              WriteEnable_d = 1'b1;
              NewSprite_state_d = NewSprite_Write;
            end
          end
          NewSprite_Write:begin
            WriteEnable_d = 1'b0;
            NewSprite_state_d = NewSprite_GetXPosLSB;
            NumSprites_d = NumSprites_q + 1'b1;
            state_d = Wait;
          end
        endcase
      end
      NewImage:begin
        case (NewImage_state_q)
          NewImage_GetImageNumLSB:begin
            if (FinishedTransmission) begin
              ImageNum_d[7:0] = SpiData;
              NewImage_state_d = NewImage_GetImageNumMSB;
            end
          end
          NewImage_GetImageNumMSB:begin
            if (FinishedTransmission) begin
              ImageNum_d[9:8] = SpiData[1:0];
              write_cmd_bl_d = 6'd15; //load 16 32 bit words at once, 32 pixels
              //calculate the starting address
              write_cmd_byte_addr_d = SpritePixelDataStartAddress + (ImageNum_q * SpriteSize);
              NewImage_state_d = NewImage_LoadFifo;
            end
          end
          NewImage_LoadFifo:begin
            wr_en_d = 1'b0;
            if(FinishedTransmission)begin
              XPos_d = XPos_q + 1'b1;
              case (XPos_q)
                10'd0:wr_data_d[7:0] = SpiData;
                10'd1:wr_data_d[15:8] = SpiData;
                10'd2:wr_data_d[23:16] = SpiData;
                10'd3:begin
                  wr_data_d[31:24] = SpiData;
                  wr_en_d = 1'b1;
                  XPos_d = 10'd0;
                end
              endcase
            end
            case (NewImage_WriteCMD_state_q)
              NewImage_WriteCMD_Check:begin
                if (wr_count >= 7'd16) begin  //if there are 16 words in the fifo
                  write_cmd_en_d = 1'b1;
                  YPos_d = YPos_q + 1'b1;
                  NewImage_WriteCMD_state_d = NewImage_WriteCMD_Wait;
                end
              end
              NewImage_WriteCMD_Wait:begin
                write_cmd_en_d = 1'b0;
                if(YPos_q <= 5'd31)begin //see if the whole image has been loaded into ram yet
                  if(wr_count <= 7'd8)begin
                    write_cmd_byte_addr_d = write_cmd_byte_addr_q + 7'd64;
                    NewImage_WriteCMD_state_d = NewImage_WriteCMD_Check;
                  end
                end else begin
                  YPos_d = 9'b0;
                  XPos_d = 10'b0;
                  ImageNum_d = 10'b0;
                  NewImage_state_d = NewImage_GetImageNumLSB;
                  NewImage_WriteCMD_state_d = NewImage_WriteCMD_Check;
                  state_d = Wait;
                end
              end
            endcase
          end
        endcase
      end
      UpdateSpriteAttributes:begin
        case (UpdateSpriteAttributes_state_q)
          UpdateSpriteAttributes_GetSpriteNumLSB:begin
            if (FinishedTransmission) begin
              SpriteInfoAddress_d[7:0] = SpiData;
              UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_GetSpriteNumMSB;
            end
          end
          UpdateSpriteAttributes_GetSpriteNumMSB:begin
            if (FinishedTransmission) begin
              SpriteInfoAddress_d[11:8] = SpiData[3:0];
              UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_GetXPosLSB;
            end
          end
          UpdateSpriteAttributes_GetXPosLSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[7:0] = SpiData;
              UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_GetXPosMSB;
            end
          end
          UpdateSpriteAttributes_GetXPosMSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[9:8] = SpiData[1:0];
              UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_GetYPosLSB;
            end
          end
          UpdateSpriteAttributes_GetYPosLSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[17:10] = SpiData;
              UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_GetYPosMSB;
            end
          end
          UpdateSpriteAttributes_GetYPosMSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[18] = SpiData[0];
              UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_GetImageNumLSB;
            end
          end
          UpdateSpriteAttributes_GetImageNumLSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[26:19] = SpiData;
              UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_GetImageNumMSB;
            end
          end
          UpdateSpriteAttributes_GetImageNumMSB:begin
            if (FinishedTransmission) begin
              SpriteInfoData_d[28:27] = SpiData[1:0];
              WriteEnable_d = 1'b1;
              UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_Write;
            end
          end
          UpdateSpriteAttributes_Write:begin
            WriteEnable_d = 1'b0;
            UpdateSpriteAttributes_state_d = UpdateSpriteAttributes_GetSpriteNumLSB;
            state_d = Wait;
          end
        endcase
      end
      StartRender:begin
        //make sure that the previous render has been shown
        if(FrameBufferActive == FrameBuffer_q)begin
          RenderNextFrame_d = 1'b0;
          if(FinishedRendering)begin
            FrameBuffer_d = ~FrameBufferActive; //toggle the frame buffer to show the latest rendered frame
            state_d = Wait;
          end
        end
      end
      ToggleFrameBuffer:begin
        FrameBuffer_d = ~FrameBufferActive;
        state_d = Wait;
      end
    endcase
  end

  always @ (posedge Clk) begin
    if (Rst || ~calib_done) begin
      ReadyForCommand_q <= 1'b0;

      RenderNextFrame_q <= 1'b0;
      NumSprites_q <= 12'b0;
      XPos_q <= 10'b0;
      YPos_q <= 9'b0;
      ImageNum_q <= 10'b0;

      SpriteInfoAddress_q <= 12'b0;
      SpriteInfoData_q <= 30'b0;
      WriteEnable_q <= 1'b0;
      FrameBuffer_q <= 1'b0;

      //Write
      write_cmd_en_q <= 1'b0;
      write_cmd_bl_q <= 6'b0;
      write_cmd_byte_addr_q <= 30'b0;
      wr_en_q <= 1'b0;
      wr_mask_q <= 4'b0;
      wr_data_q <= 32'b0;

      //State Machines
      state_q <= Wait;
      NewSprite_state_q <= NewSprite_GetXPosLSB;
      NewImage_state_q <= NewImage_GetImageNumLSB;
      NewImage_WriteCMD_state_q <= NewImage_WriteCMD_state_d;
      UpdateSpriteAttributes_state_q <= UpdateSpriteAttributes_GetSpriteNumLSB;
    end else begin
      ReadyForCommand_q <= ReadyForCommand_d;

      RenderNextFrame_q <= RenderNextFrame_d;
      NumSprites_q <= NumSprites_d;
      XPos_q <= XPos_d;
      YPos_q <= YPos_d;
      ImageNum_q <= ImageNum_d;

      SpriteInfoAddress_q <= SpriteInfoAddress_d;
      SpriteInfoData_q <= SpriteInfoData_d;
      WriteEnable_q <= WriteEnable_d;

      FrameBuffer_q <= FrameBuffer_d;
      //Write
      write_cmd_en_q <= write_cmd_en_d;
      write_cmd_bl_q <= write_cmd_bl_d;
      write_cmd_byte_addr_q <= write_cmd_byte_addr_d;
      wr_en_q <= wr_en_d;
      wr_mask_q <= wr_mask_d;
      wr_data_q <= wr_data_d;

      //State Machines
      state_q <= state_d;
      NewSprite_state_q <= NewSprite_state_d;
      NewImage_state_q <= NewImage_state_d;
      NewImage_WriteCMD_state_q <= NewImage_WriteCMD_state_d;
      UpdateSpriteAttributes_state_q <= UpdateSpriteAttributes_state_d;
    end
  end

  SPISlaveBase SPIReceiver(
	    .clk(Clk),
	    .rst(Rst),	//Active High
	    .ss(SS),
	    .mosi(MOSI),
	    .miso(MISO),
	    .sck(SCLK),
			.done(FinishedTransmission),
	    .din(8'b11100111),
	    .dout(SpiData)
	  );

endmodule
