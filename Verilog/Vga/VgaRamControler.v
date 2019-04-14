`timescale 1ns / 1ps

module VgaRamControler #(
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
    ) (
    input Clk,
    input Rst,
    output Ready,
    input FrameBuffer,
    output FrameBufferActive,
    //---------------------VGA PATHS----------------------------//
    input [$clog2(HorEndCnt) - 1:0] HPos,
    input [$clog2(VertEndCnt) - 1:0] VPos,
    output [15:0] Colour,
    //------------------RAM Command Path--------------------//
    input calib_done,
    //READ Ports
    //Command
    output read_cmd_clk,
    output read_cmd_en,
    output [2:0]read_cmd_instr,
    output [5:0]read_cmd_bl,
    output [29:0]read_cmd_byte_addr,
    input read_cmd_empty,
    input read_cmd_full,
    //Read Fifo
    output rd_clk,
    output rd_en,
    input [31:0] rd_data,
    input rd_full,
    input rd_empty,
    input [6:0] rd_count,
    input rd_overflow,
    input rd_error
  );
  assign read_cmd_clk = Clk;
  assign rd_clk = Clk;

  assign Ready = Ready_q;
  assign Colour = Colour_q;
  assign FrameBufferActive = FrameBufferActive_q;

  assign read_cmd_en = read_cmd_en_q;
  assign read_cmd_instr = 3'b001; //permanetly set to read
  assign read_cmd_bl = 6'd15;     //always read 16 32 bit words
  assign read_cmd_byte_addr = read_cmd_byte_addr_q;

  assign rd_en = rd_en_q;
  //--------------------REGISTERS--------------------------------//
  reg [15:0] Colour_q, Colour_d = 16'b0;
  reg Ready_q, Ready_d = 1'b0;
  reg pixel_counter_q, pixel_counter_d = 1'b0;
  reg FrameBufferActive_q, FrameBufferActive_d = 1'b0;
  //Read CMD
  reg read_cmd_en_q, read_cmd_en_d = 1'b0;
  reg [29:0] read_cmd_byte_addr_q, read_cmd_byte_addr_d = 30'b0;
  //Read FIFO
  reg rd_en_q, rd_en_d = 1'b0;
  //-----------------------STATE MACHINES--------------------------//
  localparam STATE_SIZE = 2;
  localparam InitalizeCMD = 0,
             InitalizeFIFO = 1,
             Stream = 2;
  reg [STATE_SIZE-1:0] state_q, state_d = InitalizeCMD;

	localparam ReadFifo_STATE_SIZE = 1;
  localparam ReadFifo_Check = 0,
						 ReadFifo_Disable = 1;
  reg [ReadFifo_STATE_SIZE-1:0] ReadFifo_state_q, ReadFifo_state_d = ReadFifo_Check;

  localparam ReadCMD_STATE_SIZE = 2;
  localparam ReadCMD_Check = 0,
						 ReadCMD_Disable = 1,
             ReadCMD_Wait = 2;
  reg [ReadCMD_STATE_SIZE-1:0] ReadCMD_state_q, ReadCMD_state_d = ReadCMD_Check;

  always @ ( * ) begin
    Colour_d = Colour_q;
    Ready_d = Ready_q;
    pixel_counter_d = pixel_counter_q;
    FrameBufferActive_d = FrameBufferActive_q;
    //State Machines
    state_d = state_q;
    ReadFifo_state_d = ReadFifo_state_q;
    ReadCMD_state_d = ReadCMD_state_q;

    //Read CMD
    read_cmd_en_d = read_cmd_en_q;
    read_cmd_byte_addr_d = read_cmd_byte_addr_q;

    //Read FIFO
    rd_en_d = rd_en_q;

    case (state_q)
      InitalizeCMD:begin
        read_cmd_en_d = 1'b1;
        state_d = InitalizeFIFO;
      end
      InitalizeFIFO:begin
        read_cmd_en_d = 1'b0;
        if(rd_count == 7'd16)begin  //wait until all the words have been loaded
          Ready_d = 1'b1;
          read_cmd_byte_addr_d = read_cmd_byte_addr_q + 7'd64;
          state_d = Stream;
        end
      end
      Stream:begin
        //Read CMD State Machine
        case (ReadCMD_state_q)
          ReadCMD_Check:begin
            if(rd_count < 7'd16)begin
              read_cmd_en_d = 1'b1;
              ReadCMD_state_d = ReadCMD_Disable;
            end
          end
          ReadCMD_Disable:begin
            //calculate the next address
            if(FrameBufferActive_q)begin
              if(read_cmd_byte_addr_q >= (FrameBufferOneEndAddress - 7'd64))begin
                if(~FrameBuffer)begin
                  FrameBufferActive_d = 1'b0;
                  read_cmd_byte_addr_d = 30'b0;
                end else begin
                  read_cmd_byte_addr_d = FrameBufferOneStartAddress;
                end
              end else begin
                read_cmd_byte_addr_d = read_cmd_byte_addr_q + 7'd64;
              end
            end else begin
              if(read_cmd_byte_addr_q >= (FrameBufferZeroEndAddress - 7'd64))begin
                if(FrameBuffer)begin
                  FrameBufferActive_d = 1'b1;
                  read_cmd_byte_addr_d = FrameBufferOneStartAddress;
                end else begin
                  read_cmd_byte_addr_d = FrameBufferZeroStartAddress;
                end
              end else begin
                read_cmd_byte_addr_d = read_cmd_byte_addr_q + 7'd64;
              end
            end

            read_cmd_en_d = 1'b0;
            ReadCMD_state_d = ReadCMD_Wait;
          end
          ReadCMD_Wait:begin
            if(rd_count > 7'd16)begin
              ReadCMD_state_d = ReadCMD_Check;
            end
          end
        endcase

        //Read Fifo State Machine
        case (ReadFifo_state_q)
          ReadFifo_Check:begin
            if((HPos < HorAddrVideoTime) && (VPos < VertAddrVideoTime))begin
              if(pixel_counter_q == 1'b0)begin
                rd_en_d = 1'b1;
                ReadFifo_state_d = ReadFifo_Disable;
              end
              pixel_counter_d = pixel_counter_q + 1'b1;
            end
          end
          ReadFifo_Disable:begin
            rd_en_d = 1'b0;
            pixel_counter_d = 1'b0;
            ReadFifo_state_d = ReadFifo_Check;
          end
        endcase

        case (pixel_counter_q)
          1'b0:Colour_d = rd_data[15:0];
          1'b1:Colour_d = rd_data[31:16];
        endcase
      end
    endcase
  end

  always @ (posedge Clk) begin
    if(Rst || ~calib_done)begin
      Colour_q <= 16'b0;
      Ready_q <= 1'b0;
      pixel_counter_q <= 1'b0;
      FrameBufferActive_q <= 1'b0;
      //State Machines
      state_q <= InitalizeCMD;
      ReadFifo_state_q <= ReadFifo_Check;
      ReadCMD_state_q <= ReadCMD_Check;
      //Read CMD
      read_cmd_en_q <= 1'b0;
      read_cmd_byte_addr_q <= 30'b0;
      rd_en_q <= 1'b0;
    end else begin
      Colour_q <= Colour_d;
      Ready_q <= Ready_d;
      pixel_counter_q <= pixel_counter_d;
      FrameBufferActive_q <= FrameBufferActive_d;
      //State Machines
      state_q <= state_d;
      ReadFifo_state_q <= ReadFifo_state_d;
      ReadCMD_state_q <= ReadCMD_state_d;

      //Read CMD
      read_cmd_en_q <= read_cmd_en_d;
      read_cmd_byte_addr_q <= read_cmd_byte_addr_d;
      //Read FIFO
      rd_en_q <= rd_en_d;

    end
  end
endmodule
