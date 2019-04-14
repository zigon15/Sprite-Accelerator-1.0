`timescale 1ns / 1ps
//https://ws0.org/how-to-generate-a-vga-signal-with-a-fpga/
//https://learn.digilentinc.com/Documents/269
//http://tinyvga.com/vga-timing/640x480@60Hz
//https://timetoexplore.net/blog/video-timings-vga-720p-1080p

module VGADriver #(
    //default 640 * 480 resolution
    //horizontal timing (Line)
    parameter HorSyncTime = 96,
    parameter HorBackPorch = 48,
    parameter HorFrontPorch = 16,
    parameter HorAddrVideoTime = 640,
    parameter HorEndCnt = 800,
    //vertical timing (Frame)
    parameter VertSyncTime = 2,
    parameter VertBackPorch = 32,
    parameter VertFrontPorch = 10,
    parameter VertAddrVideoTime = 480,
    parameter VertEndCnt = 525,
    //FrameBuffer
    parameter FrameBufferZeroStartAddress = 0,
    parameter FrameBufferZeroEndAddress = 614400,
    parameter FrameBufferOneStartAddress = 614400,
    parameter FrameBufferOneEndAddress = 1228800
    )(
  input PixelClk,
  input Rst,
  input FrameBuffer,
  output FrameBufferActive,
  //------------------IO--------------------//
  output HSync,
  output VSync,
  output reg [2:0] Red,
  output reg [2:0] Green,
  output reg [1:0] Blue,
  //------------------RAM Command Path--------------------//
  input calib_done,

  //READ Ports
  output read_cmd_clk,
  output read_cmd_en,
  output [2:0]read_cmd_instr,
  output [5:0]read_cmd_bl,
  output [29:0]read_cmd_byte_addr,
  input read_cmd_empty,
  input read_cmd_full,

  output rd_clk,
  output rd_en,
  input [31:0] rd_data,
  input rd_full,
  input rd_empty,
  input [6:0] rd_count,
  input rd_overflow,
  input rd_error
  );
  wire [15:0] Colour;
  wire Ready;

  reg [$clog2(HorEndCnt) - 1:0] HPos_q, HPos_d = 0;
  reg [$clog2(VertEndCnt) - 1:0] VPos_q,VPos_d = 0;

  //Dither Counters
  reg[1:0] TwoBitCounter_q, TwoBitCounter_d;

  //generate the HSync and VSync signals
  assign HSync = ((HPos_q > (HorAddrVideoTime + HorFrontPorch)) && (HPos_q < (HorAddrVideoTime + HorFrontPorch + HorSyncTime))) ? 1'b1 : 1'b0;
  assign VSync = ((VPos_q > (VertAddrVideoTime + VertFrontPorch)) && (VPos_q < (VertAddrVideoTime + VertFrontPorch + VertSyncTime))) ? 1'b1 : 1'b0;

  always @ ( * ) begin
    HPos_d = HPos_q;
    VPos_d = VPos_q;
    TwoBitCounter_d = TwoBitCounter_q;

    if(HPos_q < HorEndCnt)begin         //checks to see if still clocking out the line
        HPos_d = HPos_q + 1;            //line not done yet so increase HPos by 1
    end else begin                      //if line completed
        HPos_d = 0;                     //reset the HPos counter coz on a new line
        if(VPos_q < VertEndCnt)begin    //checks to see if the fram is completed or not
          VPos_d = VPos_q + 1;          //frame not done yet so increase VPOS by 1
        end else begin                  //if the fram is done
          VPos_d = 0;                   //reset the VPos counter coz on a new frame
        end
    end
    TwoBitCounter_d = TwoBitCounter_q + 1'b1;

    //if in the display area
    if((HPos_q > HorAddrVideoTime) || (VPos_q > VertAddrVideoTime))begin
      Red <= 3'b000;
      Green <= 3'b000;
      Blue <= 2'b00;
    end else begin
      if((TwoBitCounter_q < Colour[12:11]) && (Colour[15:13] != 3'b111))begin
        Red <= Colour[15:13] + 1'b1;
      end else begin
        Red <= Colour[15:13];
      end

      if((TwoBitCounter_q < Colour[7:6]) && (Colour[10:8] != 3'b111))begin
        Green <= Colour[10:8] + 1'b1;
      end else begin
        Green <= Colour[10:8];
      end

      if((TwoBitCounter_q < Colour[2:1]) && (Colour[4:3] != 2'b11))begin
        Blue <= Colour[4:3] + 1'b1;
      end else begin
        Blue <= Colour[4:3];
      end
    end
  end

  always @ (posedge PixelClk) begin
    if(Rst || ~Ready)begin
      HPos_q <= 0;
      VPos_q <= 0;
      TwoBitCounter_q <= 2'b0;
    end else begin
      HPos_q <= HPos_d;
      VPos_q <= VPos_d;
      TwoBitCounter_q <= TwoBitCounter_d;
    end
  end

  VgaRamControler #(
      .HorSyncTime(HorSyncTime),
      .HorBackPorch(HorBackPorch),
      .HorFrontPorch(HorFrontPorch),
      .HorAddrVideoTime(HorAddrVideoTime),
      .HorEndCnt(HorEndCnt),
      .VertSyncTime(VertSyncTime),
      .VertBackPorch(VertBackPorch),
      .VertFrontPorch(VertFrontPorch),
      .VertAddrVideoTime(VertAddrVideoTime),
      .VertEndCnt(VertEndCnt),
      .FrameBufferZeroStartAddress(FrameBufferZeroStartAddress),
      .FrameBufferZeroEndAddress(FrameBufferZeroEndAddress),
      .FrameBufferOneStartAddress(FrameBufferOneStartAddress),
      .FrameBufferOneEndAddress(FrameBufferOneEndAddress)
    )RamPixelMemory(
    .Clk(PixelClk),
    .Rst(Rst),
    .Ready(Ready),
    .FrameBuffer(FrameBuffer),
    .FrameBufferActive(FrameBufferActive),
    //VGA INFO
    .HPos(HPos_q),
    .VPos(VPos_q),
    .Colour(Colour),

    //------------------RAM Command Path--------------------//
    .calib_done(calib_done),

    .read_cmd_clk(read_cmd_clk),
    .read_cmd_en(read_cmd_en),
    .read_cmd_instr(read_cmd_instr),
    .read_cmd_bl(read_cmd_bl),
    .read_cmd_byte_addr(read_cmd_byte_addr),
    .read_cmd_empty(read_cmd_empty),
    .read_cmd_full(read_cmd_full),

    .rd_clk(rd_clk),
    .rd_en(rd_en),
    .rd_data(rd_data),
    .rd_full(rd_full),
    .rd_empty(rd_empty),
    .rd_count(rd_count),
    .rd_overflow(rd_overflow),
    .rd_error(rd_error)
  );
endmodule
