`timescale 1ns / 1ps

module SpriteAccelerator #(
    parameter Width = 640,
    parameter Height = 480,
    parameter FrameBufferZeroStartAddress = 0,
    parameter FrameBufferOneStartAddress = 614400,
    parameter SpritePixelDataStartAddress = 1228801,
    parameter SpriteWidth = 32,
    parameter SpriteHeight = 32,
    parameter SpriteSize = 2048
    )(
    input Clk,
    input Rst,
    output [7:0] LED,
    //--------------SPI Interface-----------------//
    input SCLK,
	  input MOSI,
	  output MISO,
	  input SS,
    output ReadyForCommand,
    //---------------Frame Buffer-----------------//
    output FrameBuffer,
    input FrameBufferActive,
    //--------------RAM Command Path--------------//
    input calib_done,

    //WRITE Render Port
    output WriteRender_cmd_clk,
    output WriteRender_cmd_en,
    output [2:0]WriteRender_cmd_instr,
    output [5:0]WriteRender_cmd_bl,
    output [29:0]WriteRender_cmd_byte_addr,
    input WriteRender_cmd_empty,
    input WriteRender_cmd_full,

    output WrRender_clk,
    output WrRender_en,
    output [3:0] WrRender_mask,
    output [31:0] WrRender_data,
    input WrRender_full,
    input WrRender_empty,
    input [6:0] WrRender_count,
    input WrRender_underrun,
    input WrRender_error,

    //READ Render Port
    output ReadRender_cmd_clk,
    output ReadRender_cmd_en,
    output [2:0]ReadRender_cmd_instr,
    output [5:0]ReadRender_cmd_bl,
    output [29:0]ReadRender_cmd_byte_addr,
    input ReadRender_cmd_empty,
    input ReadRender_cmd_full,

    output RdRender_clk,
    output RdRender_en,
    input [31:0] RdRender_data,
    input RdRender_full,
    input RdRender_empty,
    input [6:0] RdRender_count,
    input RdRender_overflow,
    input RdRender_error,

    //WRITE Command Port
    output WriteCommand_cmd_clk,
    output WriteCommand_cmd_en,
    output [2:0]WriteCommand_cmd_instr,
    output [5:0]WriteCommand_cmd_bl,
    output [29:0]WriteCommand_cmd_byte_addr,
    input WriteCommand_cmd_empty,
    input WriteCommand_cmd_full,

    output WrCommand_clk,
    output WrCommand_en,
    output [3:0] WrCommand_mask,
    output [31:0] WrCommand_data,
    input WrCommand_full,
    input WrCommand_empty,
    input [6:0] WrCommand_count,
    input WrCommand_underrun,
    input WrCommand_error
    );

    wire [11:0] ReadAddress;
    wire [29:0] ReadData;

    wire [11:0] WriteAddress;
    wire [29:0] WriteData;
    wire WriteEnable;

    wire FinishedRendering;
    wire RenderNextFrame;
    wire [11:0] NumSprites;

    SpriteInfo SpriteInfo1 (
      .clka(Clk), // input clka
      .wea(WriteEnable), // input [0 : 0] wea
      .addra(WriteAddress), // input [11 : 0] addra
      .dina(WriteData), // input [29 : 0] dina
      .clkb(Clk), // input clkb
      .rstb(Rst), // input rstb
      .addrb(ReadAddress), // input [11 : 0] addrb
      .doutb(ReadData) // output [29 : 0] doutb
    );

    SpriteCommands #(
      .SpritePixelDataStartAddress(SpritePixelDataStartAddress),
      .SpriteWidth(SpriteWidth),
      .SpriteHeight(SpriteHeight),
      .SpriteSize(SpriteSize)
    )SpriteCommands1(
      .Clk(Clk),
      .Rst(Rst),
      //--------------SPI Interface-----------------//
      .SCLK(SCLK),
      .MOSI(MOSI),
      .MISO(MISO),
      .SS(SS),
      .ReadyForCommand(ReadyForCommand),
      //-----------Sprite Accelerator---------------//
      .FinishedRendering(FinishedRendering),
      .RenderNextFrame(RenderNextFrame),
      .NumSprites(NumSprites),
      //-----------Sprite Info BRAM---------------//
      .SpriteInfoAddress(WriteAddress),
      .SpriteInfoData(WriteData),
      .WriteEnable(WriteEnable),
      //---------------Frame Buffer-----------------//
      .FrameBuffer(FrameBuffer),
      .FrameBufferActive(FrameBufferActive),
      //--------------RAM Command Path--------------//
      .calib_done(calib_done),

      //Write Port
      .write_cmd_clk(WriteCommand_cmd_clk),
      .write_cmd_en(WriteCommand_cmd_en),
      .write_cmd_instr(WriteCommand_cmd_instr),
      .write_cmd_bl(WriteCommand_cmd_bl),
      .write_cmd_byte_addr(WriteCommand_cmd_byte_addr),
      .write_cmd_empty(WriteCommand_cmd_empty),
      .write_cmd_full(WriteCommand_cmd_full),

      .wr_clk(WrCommand_clk),
      .wr_en(WrCommand_en),
      .wr_mask(WrCommand_mask),
      .wr_data(WrCommand_data),
      .wr_full(WrCommand_full),
      .wr_empty(WrCommand_empty),
      .wr_count(WrCommand_count),
      .wr_underrun(WrCommand_underrun),
      .wr_error(WrCommand_error)
    );

    SpriteRenderer #(
      .Width(Width),
      .Height(Height),
      .FrameBufferZeroStartAddress(FrameBufferZeroStartAddress),
      .FrameBufferOneStartAddress(FrameBufferOneStartAddress),
      .SpritePixelDataStartAddress(SpritePixelDataStartAddress),
      .SpriteWidth(SpriteWidth),
      .SpriteHeight(SpriteHeight),
      .SpriteSize(SpriteSize)
    )SpriteRenderer1(
      .Clk(Clk),
      .Rst(Rst),
      .LED(LED),
      //-----------Sprite Accelerator---------------//
      .FinishedRendering(FinishedRendering),
      .RenderNextFrame(RenderNextFrame),
      .NumSprites(NumSprites),
      //-----------Sprite Info BRAM---------------//
      .SpriteInfoAddress(ReadAddress),
      .SpriteInfoData(ReadData),
      //---------------Frame Buffer-----------------//
      .FrameBufferActive(FrameBufferActive),
      //--------------RAM Command Path--------------//
      .calib_done(calib_done),

      //Write Port
      .write_cmd_clk(WriteRender_cmd_clk),
      .write_cmd_en(WriteRender_cmd_en),
      .write_cmd_instr(WriteRender_cmd_instr),
      .write_cmd_bl(WriteRender_cmd_bl),
      .write_cmd_byte_addr(WriteRender_cmd_byte_addr),
      .write_cmd_empty(WriteRender_cmd_empty),
      .write_cmd_full(WriteRender_cmd_full),

      .wr_clk(WrRender_clk),
      .wr_en(WrRender_en),
      .wr_mask(WrRender_mask),
      .wr_data(WrRender_data),
      .wr_full(WrRender_full),
      .wr_empty(WrRender_empty),
      .wr_count(WrRender_count),
      .wr_underrun(WrRender_underrun),
      .wr_error(WrRender_error),

      //Read Port
      .read_cmd_clk(ReadRender_cmd_clk),
      .read_cmd_en(ReadRender_cmd_en),
      .read_cmd_instr(ReadRender_cmd_instr),
      .read_cmd_bl(ReadRender_cmd_bl),
      .read_cmd_byte_addr(ReadRender_cmd_byte_addr),
      .read_cmd_empty(ReadRender_cmd_empty),
      .read_cmd_full(ReadRender_cmd_full),

      .rd_clk(RdRender_clk),
      .rd_en(RdRender_en),
      .rd_data(RdRender_data),
      .rd_full(RdRender_full),
      .rd_empty(RdRender_empty),
      .rd_count(RdRender_count),
      .rd_overflow(RdRender_overflow),
      .rd_error(RdRender_error)
    );
endmodule
