`timescale 1ns / 1ps

module Main(
      input CLK_IN_PAD,
      input RstSw,
      output [7:0]LED,
      //------------VGA---------------//
      output HSync,
      output VSync,
      output [2:0] Red,
      output [2:0] Green,
      output [1:0] Blue,
      //-----MCU -> FPGA Interface-------//
      input SCLK,
	    input MOSI,
	    output MISO,
	    input SS,
      output ReadyForCommand,
      //------------RAM---------------//
      inout [15:0] mcb3_dram_dq,
      output [12:0] mcb3_dram_a,
      output  [1:0] mcb3_dram_ba,
      output  mcb3_dram_cke,
      output mcb3_dram_ras_n,
      output  mcb3_dram_cas_n,
      output  mcb3_dram_we_n,
      output  mcb3_dram_dm,
      inout mcb3_dram_udqs,
      inout mcb3_rzq,
      output  mcb3_dram_udm,
      inout mcb3_dram_dqs,
      output  mcb3_dram_ck,
      output  mcb3_dram_ck_n
    );
  //default 640*480 resolution
  //horizontal timing (Line)
  parameter HorSyncTime = 96;
  parameter HorBackPorch = 48;
  parameter HorFrontPorch = 16;
  parameter HorAddrVideoTime = 640;
  parameter HorEndCnt = 800;
  //vertical timing (Frame)
  parameter VertSyncTime = 2;
  parameter VertBackPorch = 32;
  parameter VertFrontPorch = 10;
  parameter VertAddrVideoTime = 480;
  parameter VertEndCnt = 525;
  //FrameBuffer
  parameter FrameBufferZeroStartAddress = 0;
  parameter FrameBufferZeroEndAddress = 614400;
  parameter FrameBufferOneStartAddress = 614400;
  parameter FrameBufferOneEndAddress = 1228800;
  //Sprite Pixel Data
  parameter SpritePixelDataStartAddress = 1228801;
  parameter SpriteWidth = 32;
  parameter SpriteHeight = 32;
  parameter SpriteSize = SpriteWidth * SpriteHeight * 2; //width * height * 2

  wire SystClk;  //100mhz input clock
  wire LogicClk; //100mhz
  wire LogicRst; //active high
  wire PixelClk; //25 mhz

  wire FrameBuffer;
  wire FrameBufferActive;
  //---------------------------------------------------------------//
  //-----Frame Buffer Read Port #2-----
  wire FrameBuffer_read_cmd_clk;
  wire FrameBuffer_read_cmd_en;
  wire [2:0]FrameBuffer_read_cmd_instr;
  wire [5:0]FrameBuffer_read_cmd_bl;
  wire [29:0]FrameBuffer_read_cmd_byte_addr;
  wire FrameBuffer_read_cmd_empty;
  wire FrameBuffer_read_cmd_full;

  wire FrameBuffer_rd_clk;
  wire FrameBuffer_rd_en;
  wire [31:0]FrameBuffer_rd_data;
  wire FrameBuffer_rd_full;
  wire FrameBuffer_rd_empty;
  wire [6:0]FrameBuffer_rd_count;
  wire FrameBuffer_rd_overflow;
  wire FrameBuffer_rd_error;

  //-----Sprite Render Write Port #3-----
  wire Sprite_WriteRender_cmd_clk;
  wire Sprite_WriteRender_cmd_en;
  wire [2:0]Sprite_WriteRender_cmd_instr;
  wire [5:0]Sprite_WriteRender_cmd_bl;
  wire [29:0]Sprite_WriteRender_cmd_byte_addr;
  wire Sprite_WriteRender_cmd_empty;
  wire Sprite_WriteRender_cmd_full;

  wire Sprite_WrRender_clk;
  wire Sprite_WrRender_en;
  wire [3:0]Sprite_WrRender_mask;
  wire [31:0]Sprite_WrRender_data;
  wire Sprite_WrRender_full;
  wire Sprite_WrRender_empty;
  wire [6:0]Sprite_WrRender_count;
  wire Sprite_WrRender_underrun;
  wire Sprite_WrRender_error;

  //-----Sprite Render Read Port #4-----
  wire Sprite_ReadRender_cmd_clk;
  wire Sprite_ReadRender_cmd_en;
  wire [2:0]Sprite_ReadRender_cmd_instr;
  wire [5:0]Sprite_ReadRender_cmd_bl;
  wire [29:0]Sprite_ReadRender_cmd_byte_addr;
  wire Sprite_ReadRender_cmd_empty;
  wire Sprite_ReadRender_cmd_full;

  wire Sprite_RdRender_clk;
  wire Sprite_RdRender_en;
  wire [31:0]Sprite_RdRender_data;
  wire Sprite_RdRender_full;
  wire Sprite_RdRender_empty;
  wire [6:0]Sprite_RdRender_count;
  wire Sprite_RdRender_overflow;
  wire Sprite_RdRender_error;

  //-----Sprite Command Write Port #5-----
  wire Sprite_WriteCommand_cmd_clk;
  wire Sprite_WriteCommand_cmd_en;
  wire [2:0]Sprite_WriteCommand_cmd_instr;
  wire [5:0]Sprite_WriteCommand_cmd_bl;
  wire [29:0]Sprite_WriteCommand_cmd_byte_addr;
  wire Sprite_WriteCommand_cmd_empty;
  wire Sprite_WriteCommand_cmd_full;

  wire Sprite_WrCommand_clk;
  wire Sprite_WrCommand_en;
  wire [3:0]Sprite_WrCommand_mask;
  wire [31:0]Sprite_WrCommand_data;
  wire Sprite_WrCommand_full;
  wire Sprite_WrCommand_empty;
  wire [6:0]Sprite_WrCommand_count;
  wire Sprite_WrCommand_underrun;
  wire Sprite_WrCommand_error;

  ClockDiv PixelClkGen(
    .clk(LogicClk),
    .rst(LogicRst),
    .ClockDiv(32'd4),
    .toggle(PixelClk)
    );

  SpriteAccelerator #(
    .Width(HorAddrVideoTime),
    .Height(VertAddrVideoTime),
    .FrameBufferZeroStartAddress(FrameBufferZeroStartAddress),
    .FrameBufferOneStartAddress(FrameBufferOneStartAddress),
    .SpritePixelDataStartAddress(SpritePixelDataStartAddress),
    .SpriteWidth(SpriteWidth),
    .SpriteHeight(SpriteHeight),
    .SpriteSize(SpriteSize)
  )SpriteAccelerator1(
    .Clk(LogicClk),
    .Rst(LogicRst),
    .LED(LED),
    //--------------SPI Interface-----------------//
    .SCLK(SCLK),
    .MOSI(MOSI),
    .MISO(MISO),
    .SS(SS),
    .ReadyForCommand(ReadyForCommand),
    //---------------Frame Buffer-----------------//
    .FrameBuffer(FrameBuffer),
    .FrameBufferActive(FrameBufferActive),
    //--------------RAM Command Path--------------//
    .calib_done(calib_done),

    //Write Render Port
    .WriteRender_cmd_clk(Sprite_WriteRender_cmd_clk),
    .WriteRender_cmd_en(Sprite_WriteRender_cmd_en),
    .WriteRender_cmd_instr(Sprite_WriteRender_cmd_instr),
    .WriteRender_cmd_bl(Sprite_WriteRender_cmd_bl),
    .WriteRender_cmd_byte_addr(Sprite_WriteRender_cmd_byte_addr),
    .WriteRender_cmd_empty(Sprite_WriteRender_cmd_empty),
    .WriteRender_cmd_full(Sprite_WriteRender_cmd_full),

    .WrRender_clk(Sprite_WrRender_clk),
    .WrRender_en(Sprite_WrRender_en),
    .WrRender_mask(Sprite_WrRender_mask),
    .WrRender_data(Sprite_WrRender_data),
    .WrRender_full(Sprite_WrRender_full),
    .WrRender_empty(Sprite_WrRender_empty),
    .WrRender_count(Sprite_WrRender_count),
    .WrRender_underrun(Sprite_WrRender_underrun),
    .WrRender_error(Sprite_WrRender_error),

    //Read Render Port
    .ReadRender_cmd_clk(Sprite_ReadRender_cmd_clk),
    .ReadRender_cmd_en(Sprite_ReadRender_cmd_en),
    .ReadRender_cmd_instr(Sprite_ReadRender_cmd_instr),
    .ReadRender_cmd_bl(Sprite_ReadRender_cmd_bl),
    .ReadRender_cmd_byte_addr(Sprite_ReadRender_cmd_byte_addr),
    .ReadRender_cmd_empty(Sprite_ReadRender_cmd_empty),
    .ReadRender_cmd_full(Sprite_ReadRender_cmd_full),

    .RdRender_clk(Sprite_RdRender_clk),
    .RdRender_en(Sprite_RdRender_en),
    .RdRender_data(Sprite_RdRender_data),
    .RdRender_full(Sprite_RdRender_full),
    .RdRender_empty(Sprite_RdRender_empty),
    .RdRender_count(Sprite_RdRender_count),
    .RdRender_overflow(Sprite_RdRender_overflow),
    .RdRender_error(Sprite_RdRender_error),

    //Write Command Port
    .WriteCommand_cmd_clk(Sprite_WriteCommand_cmd_clk),
    .WriteCommand_cmd_en(Sprite_WriteCommand_cmd_en),
    .WriteCommand_cmd_instr(Sprite_WriteCommand_cmd_instr),
    .WriteCommand_cmd_bl(Sprite_WriteCommand_cmd_bl),
    .WriteCommand_cmd_byte_addr(Sprite_WriteCommand_cmd_byte_addr),
    .WriteCommand_cmd_empty(Sprite_WriteCommand_cmd_empty),
    .WriteCommand_cmd_full(Sprite_WriteCommand_cmd_full),

    .WrCommand_clk(Sprite_WrCommand_clk),
    .WrCommand_en(Sprite_WrCommand_en),
    .WrCommand_mask(Sprite_WrCommand_mask),
    .WrCommand_data(Sprite_WrCommand_data),
    .WrCommand_full(Sprite_WrCommand_full),
    .WrCommand_empty(Sprite_WrCommand_empty),
    .WrCommand_count(Sprite_WrCommand_count),
    .WrCommand_underrun(Sprite_WrCommand_underrun),
    .WrCommand_error(Sprite_WrCommand_error)
  );

  VGADriver #(
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
  )VGADriver1(
    .PixelClk(PixelClk),
    .Rst(LogicRst),   //active high
    //---------------Frame Buffer-----------------//
    .FrameBuffer(FrameBuffer),
    .FrameBufferActive(FrameBufferActive),
    //-------------------VGA IO-----------------------------//
    .HSync(HSync),
    .VSync(VSync),
    .Red(Red),
    .Green(Green),
    .Blue(Blue),
    //------------------RAM Command Path--------------------//
    .calib_done(calib_done),

    .read_cmd_clk(FrameBuffer_read_cmd_clk),
    .read_cmd_en(FrameBuffer_read_cmd_en),
    .read_cmd_instr(FrameBuffer_read_cmd_instr),
    .read_cmd_bl(FrameBuffer_read_cmd_bl),
    .read_cmd_byte_addr(FrameBuffer_read_cmd_byte_addr),
    .read_cmd_empty(FrameBuffer_read_cmd_empty),
    .read_cmd_full(FrameBuffer_read_cmd_full),

    .rd_clk(FrameBuffer_rd_clk),
    .rd_en(FrameBuffer_rd_en),
    .rd_data(FrameBuffer_rd_data),
    .rd_full(FrameBuffer_rd_full),
    .rd_empty(FrameBuffer_rd_empty),
    .rd_count(FrameBuffer_rd_count),
    .rd_overflow(FrameBuffer_rd_overflow),
    .rd_error(FrameBuffer_rd_error)
  );

  Ram # (
    .C3_P0_MASK_SIZE(4),
    .C3_P0_DATA_PORT_SIZE(32),
    .C3_P1_MASK_SIZE(4),
    .C3_P1_DATA_PORT_SIZE(32),
    .DEBUG_EN(0),
    .C3_MEMCLK_PERIOD(6666),
    .C3_CALIB_SOFT_IP("TRUE"),
    .C3_SIMULATION("FALSE"),
    .C3_RST_ACT_LOW(0),
    .C3_INPUT_CLK_TYPE("SINGLE_ENDED"),
    .C3_MEM_ADDR_ORDER("ROW_BANK_COLUMN"),
    .C3_NUM_DQ_PINS(16),
    .C3_MEM_ADDR_WIDTH(13),
    .C3_MEM_BANKADDR_WIDTH(2)
  )VgaRam (
    //LPDDR RAM PINS
    .mcb3_dram_dq(mcb3_dram_dq),
    .mcb3_dram_a(mcb3_dram_a),
    .mcb3_dram_ba(mcb3_dram_ba),
    .mcb3_dram_ras_n(mcb3_dram_ras_n),
    .mcb3_dram_cas_n(mcb3_dram_cas_n),
    .mcb3_dram_we_n(mcb3_dram_we_n),
    .mcb3_dram_cke(mcb3_dram_cke),
    .mcb3_dram_ck(mcb3_dram_ck),
    .mcb3_dram_ck_n(mcb3_dram_ck_n),
    .mcb3_dram_dqs(mcb3_dram_dqs),
    .mcb3_dram_udqs(mcb3_dram_udqs),
    .mcb3_dram_udm(mcb3_dram_udm),
    .mcb3_dram_dm(mcb3_dram_dm),
    .mcb3_rzq(mcb3_rzq),

    //Clock and Reset and other stuff
    .c3_sys_clk(CLK_IN_PAD),
    .c3_sys_rst_i(~RstSw),
    .c3_clk0(LogicClk),
    .c3_rst0(LogicRst),
    .c3_calib_done(calib_done),

    //Frame Buffer READ PORT
    .c3_p2_cmd_clk(FrameBuffer_read_cmd_clk),
    .c3_p2_cmd_en(FrameBuffer_read_cmd_en),
    .c3_p2_cmd_instr(FrameBuffer_read_cmd_instr),
    .c3_p2_cmd_bl(FrameBuffer_read_cmd_bl),
    .c3_p2_cmd_byte_addr(FrameBuffer_read_cmd_byte_addr),
    .c3_p2_cmd_empty(FrameBuffer_read_cmd_empty),
    .c3_p2_cmd_full(FrameBuffer_read_cmd_full),

    .c3_p2_rd_clk(FrameBuffer_rd_clk),
    .c3_p2_rd_en(FrameBuffer_rd_en),
    .c3_p2_rd_data(FrameBuffer_rd_data),
    .c3_p2_rd_full(FrameBuffer_rd_full),
    .c3_p2_rd_empty(FrameBuffer_rd_empty),
    .c3_p2_rd_count(FrameBuffer_rd_count),
    .c3_p2_rd_overflow(FrameBuffer_rd_overflow),
    .c3_p2_rd_error(FrameBuffer_rd_error),

    //Sprite Write Render PORT
    .c3_p3_cmd_clk(Sprite_WriteRender_cmd_clk),
    .c3_p3_cmd_en(Sprite_WriteRender_cmd_en),
    .c3_p3_cmd_instr(Sprite_WriteRender_cmd_instr),
    .c3_p3_cmd_bl(Sprite_WriteRender_cmd_bl),
    .c3_p3_cmd_byte_addr(Sprite_WriteRender_cmd_byte_addr),
    .c3_p3_cmd_empty(Sprite_WriteRender_cmd_empty),
    .c3_p3_cmd_full(Sprite_WriteRender_cmd_full),

    .c3_p3_wr_clk(Sprite_WrRender_clk),
    .c3_p3_wr_en(Sprite_WrRender_en),
    .c3_p3_wr_mask(Sprite_WrRender_mask),
    .c3_p3_wr_data(Sprite_WrRender_data),
    .c3_p3_wr_full(Sprite_WrRender_full),
    .c3_p3_wr_empty(Sprite_WrRender_empty),
    .c3_p3_wr_count(Sprite_WrRender_count),
    .c3_p3_wr_underrun(Sprite_WrRender_underrun),
    .c3_p3_wr_error(Sprite_WrRender_error),

    //Sprite Read Renderer Port
    .c3_p4_cmd_clk(Sprite_ReadRender_cmd_clk),
    .c3_p4_cmd_en(Sprite_ReadRender_cmd_en),
    .c3_p4_cmd_instr(Sprite_ReadRender_cmd_instr),
    .c3_p4_cmd_bl(Sprite_ReadRender_cmd_bl),
    .c3_p4_cmd_byte_addr(Sprite_ReadRender_cmd_byte_addr),
    .c3_p4_cmd_empty(Sprite_ReadRender_cmd_empty),
    .c3_p4_cmd_full(Sprite_ReadRender_cmd_full),

    .c3_p4_rd_clk(Sprite_RdRender_clk),
    .c3_p4_rd_en(Sprite_RdRender_en),
    .c3_p4_rd_data(Sprite_RdRender_data),
    .c3_p4_rd_full(Sprite_RdRender_full),
    .c3_p4_rd_empty(Sprite_RdRender_empty),
    .c3_p4_rd_count(Sprite_RdRender_count),
    .c3_p4_rd_overflow(Sprite_RdRender_overflow),
    .c3_p4_rd_error(Sprite_RdRender_error),

    //Sprite Write Command Port
    .c3_p5_cmd_clk(Sprite_WriteCommand_cmd_clk),
    .c3_p5_cmd_en(Sprite_WriteCommand_cmd_en),
    .c3_p5_cmd_instr(Sprite_WriteCommand_cmd_instr),
    .c3_p5_cmd_bl(Sprite_WriteCommand_cmd_bl),
    .c3_p5_cmd_byte_addr(Sprite_WriteCommand_cmd_byte_addr),
    .c3_p5_cmd_empty(Sprite_WriteCommand_cmd_empty),
    .c3_p5_cmd_full(Sprite_WriteCommand_cmd_full),

    .c3_p5_wr_clk(Sprite_WrCommand_clk),
    .c3_p5_wr_en(Sprite_WrCommand_en),
    .c3_p5_wr_mask(Sprite_WrCommand_mask),
    .c3_p5_wr_data(Sprite_WrCommand_data),
    .c3_p5_wr_full(Sprite_WrCommand_full),
    .c3_p5_wr_empty(Sprite_WrCommand_empty),
    .c3_p5_wr_count(Sprite_WrCommand_count),
    .c3_p5_wr_underrun(Sprite_WrCommand_underrun),
    .c3_p5_wr_error(Sprite_WrCommand_error)
  );
endmodule
