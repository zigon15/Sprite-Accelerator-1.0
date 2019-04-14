`timescale 1ns / 1ps

module SpriteRenderer #(
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
    //-----------Sprite Accelerator---------------//
    output FinishedRendering,
    input RenderNextFrame,
    input [11:0]NumSprites,
    //-----------Sprite Info BRAM---------------//
    output [11:0]SpriteInfoAddress,
    input [29:0]SpriteInfoData,
    //---------------Frame Buffer-----------------//
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
    input wr_error,

    //READ Port
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
    assign LED = LED_q;
    reg [7:0] LED_q, LED_d = 8'b0;
    //-----------Sprite Accelerator---------------//
    assign FinishedRendering = FinishedRendering_q;

    reg FinishedRendering_q, FinishedRendering_d = 1'b0;
    reg [5:0] XCounter_q, XCounter_d = 6'b0;
    reg [5:0] YCounter_q, YCounter_d = 6'b0;
    reg [5:0] YReadCounter_q, YReadCounter_d = 6'b0;
    reg [4:0] XStop_q, XStop_d = 5'b0;
    reg [4:0] YStop_q, YStop_d = 5'b0;
    reg [29:0] SpriteStartAddress_q, SpriteStartAddress_d = 30'b0;
    reg [31:0] IntermediateCalculation_q, IntermediateCalculation_d = 32'b0;

    //if a pixels is this colour it won't be rendered
    parameter TransparentPixelColour = 16'hD11C;
    //-----------Sprite Info BRAM---------------//
    assign SpriteInfoAddress = SpriteCounter_q;
    reg [11:0] SpriteCounter_q, SpriteCounter_d = 12'b0;

    wire [9:0] XPos;
    wire [8:0] YPos;
    wire [9:0] ImageNum;
    wire SpriteVisible;
    assign XPos = SpriteInfoData[9:0];
    assign YPos = SpriteInfoData[18:10];
    assign ImageNum = SpriteInfoData[28:19];
    assign SpriteVisible = SpriteInfoData[29];

    //--------------RAM Command Path--------------//
    //Write/Read Command
    assign write_cmd_bl = cmd_bl_q;
    assign read_cmd_bl = cmd_bl_q;
    reg [5:0] cmd_bl_q, cmd_bl_d = 6'b0;

    //Write Command/Fifo
    assign write_cmd_clk = Clk;
    assign write_cmd_en = write_cmd_en_q;
    assign write_cmd_instr = 3'b000; //permanetly set to write
    assign write_cmd_byte_addr = write_cmd_byte_addr_q;
    assign wr_clk = Clk;
    assign wr_en = wr_en_q;
    assign wr_mask = wr_mask_q;
    assign wr_data = wr_data_q;

    reg write_cmd_en_q, write_cmd_en_d = 1'b0;
    reg [29:0]write_cmd_byte_addr_q, write_cmd_byte_addr_d;
    reg wr_en_q, wr_en_d = 1'b0;
    reg [3:0]wr_mask_q, wr_mask_d = 4'b0;
    reg [31:0]wr_data_q, wr_data_d = 32'b0;

    //Read Command/Fifo
    assign read_cmd_clk = Clk;
    assign read_cmd_en = read_cmd_en_q;
    assign read_cmd_instr = 3'b001; //permanetly set to read
    assign read_cmd_byte_addr = read_cmd_byte_addr_q;
    assign rd_clk = Clk;
    assign rd_en = rd_en_q;

    reg read_cmd_en_q, read_cmd_en_d = 1'b0;
    reg [29:0]read_cmd_byte_addr_q, read_cmd_byte_addr_d = 30'b0;
    reg rd_en_q, rd_en_d = 1'b0;

    //--------------------State Machines-------------------//
    localparam STATE_SIZE = 1;
    localparam Wait = 0,
               RenderFrame = 1;
    reg [STATE_SIZE-1:0] state_q, state_d = Wait;

    localparam Read_STATE_SIZE = 2;
    localparam Read_Calculate = 0,
               Read_Enable = 1,
               Read_Wait = 2;
    reg [Read_STATE_SIZE-1:0] Read_state_q, Read_state_d = Read_Calculate;

    localparam Write_STATE_SIZE = 2;
    localparam Write_Wait = 0,
               Write_LoadFifo = 1,
               Write_LoadFifoWait = 2,
               Write_CMDEnable = 3;
    reg [Write_STATE_SIZE-1:0] Write_state_q, Write_state_d = Write_Wait;

    localparam Counter_STATE_SIZE = 2;
    localparam Counter_GetInfo = 0,
               Counter_Calculate = 1,
               Counter_RenderSprite = 2;
    reg [Counter_STATE_SIZE-1:0] Counter_state_q, Counter_state_d = Counter_GetInfo;

    always @ ( * ) begin
      LED_d = LED_q;

      FinishedRendering_d = FinishedRendering_q;
      SpriteCounter_d = SpriteCounter_q;
      XCounter_d = XCounter_q;
      YCounter_d = YCounter_q;
      YReadCounter_d = YReadCounter_q;
      XStop_d = XStop_q;
      YStop_d = YStop_q;
      SpriteStartAddress_d = SpriteStartAddress_q;
      IntermediateCalculation_d = IntermediateCalculation_q;

      //Write/Read
      cmd_bl_d = cmd_bl_q;

      //Write
      write_cmd_en_d = write_cmd_en_q;
      write_cmd_byte_addr_d = write_cmd_byte_addr_q;
      wr_en_d = wr_en_q;
      wr_mask_d = wr_mask_q;
      wr_data_d = wr_data_q;

      //Read
      read_cmd_en_d = read_cmd_en_q;
      read_cmd_byte_addr_d = read_cmd_byte_addr_q;
      rd_en_d = rd_en_q;

      //State Machines
      state_d = state_q;
      Read_state_d = Read_state_q;
      Write_state_d = Write_state_q;
      Counter_state_d = Counter_state_q;

      case (state_q)
        Wait:begin
          FinishedRendering_d = 1'b0;
          SpriteCounter_d = 12'b0;

          if(RenderNextFrame)begin
            state_d = RenderFrame;
          end
        end
        RenderFrame:begin
          case (Counter_state_q)
            Counter_GetInfo:begin//wait one clock cycle for the BRAM to output the new data
              if(SpriteCounter_q < NumSprites)begin //check to see if all the sprites have been rendered
                Counter_state_d = Counter_Calculate;

                XCounter_d = 6'b0;
                YCounter_d = 6'b0;
                YReadCounter_d = 6'b0;
              end else begin  //once the frame has been fully rendered
                FinishedRendering_d = 1'b1; //high for only 1 clock cycle
                state_d = Wait;
              end
            end
            Counter_Calculate:begin //BRAM values should all be up to date
              if(SpriteVisible)begin
                //Can use bitshift instead of multiply as Sprite size is a factor of 2
                SpriteStartAddress_d = SpritePixelDataStartAddress + (ImageNum * SpriteSize);

                cmd_bl_d = 6'd15; //16 32 bit words, 16bpp so 32 pixels
                XStop_d = 5'd31;
                YStop_d = 5'd31;
                Counter_state_d = Counter_RenderSprite;
              end else begin
                SpriteCounter_d = SpriteCounter_q + 1'b1;
                Counter_state_d = Counter_GetInfo;
              end
            end
            Counter_RenderSprite:begin
              case (Write_state_q)
                Write_Wait:begin
                  write_cmd_en_d = 1'b0;
                  if(YCounter_q <= YStop_q)begin  //check to see if the whole sprite has been rendered yet
                    if(rd_count > cmd_bl_q)begin  //make sure there is at least a whole line buffered
                      IntermediateCalculation_d = (YPos + YCounter_q) * Width;
                      Write_state_d = Write_LoadFifo;
                    end
                  end else begin  //once the sprite has been fully rendered
                    SpriteCounter_d = SpriteCounter_q + 1'b1;

                    Read_state_d = Read_Calculate;
                    Write_state_d = Write_Wait;
                    Counter_state_d = Counter_GetInfo;
                  end
                end
                Write_LoadFifo:begin
                  if(FrameBufferActive)begin
                    write_cmd_byte_addr_d = FrameBufferZeroStartAddress + ((IntermediateCalculation_d + XPos) << 1);
                  end else begin
                    write_cmd_byte_addr_d = FrameBufferOneStartAddress + ((IntermediateCalculation_d + XPos) << 1);
                  end
                  rd_en_d = 1'b1;
                  Write_state_d = Write_LoadFifoWait;
                end
                Write_LoadFifoWait:begin
                  if(XCounter_q <= cmd_bl_q)begin //whole line needs to be in fifo
                    wr_data_d = rd_data;

                    //check if a pixel is equal to the TransparentPixelColour and if so mask it out
                    if(rd_data == {TransparentPixelColour,TransparentPixelColour})begin
                      wr_mask_d = 4'b1111;
                    end else if (rd_data[31:16] == TransparentPixelColour) begin
                      wr_mask_d = 4'b1100;
                    end else if (rd_data[15:0] == TransparentPixelColour) begin
                      wr_mask_d = 4'b0011;
                    end else begin
                      wr_mask_d = 4'b000;
                    end

                    wr_en_d = 1'b1;
                    if(cmd_bl_q <= XCounter_q)begin
                      rd_en_d = 1'b0;
                    end
                    XCounter_d = XCounter_q + 1'd1; //operates on 2 pixels at once which is equal to 1 word
                  end else begin
                    wr_en_d = 1'b0;
                    rd_en_d = 1'b0;
                    YCounter_d = YCounter_q + 1'b1;
                    XCounter_d = 6'b0;
                    write_cmd_en_d = 1'b1;
                    Write_state_d = Write_CMDEnable;
                  end
                end
                Write_CMDEnable:begin
                  write_cmd_en_d = 1'b0;
                  if(wr_count <= 7'd5)begin
                    Write_state_d = Write_Wait;
                  end
                end
              endcase

              case (Read_state_q)
                Read_Calculate:begin
                  if(YReadCounter_q <= YStop_q)begin
                    if(rd_count < 7'd16)begin
                      read_cmd_byte_addr_d = SpriteStartAddress_q + ((YReadCounter_q * SpriteWidth) << 1);
                      Read_state_d = Read_Enable;
                    end
                  end
                end
                Read_Enable:begin
                  read_cmd_en_d = 1'b1;
                  YReadCounter_d = YReadCounter_q + 1'b1;
                  Read_state_d = Read_Wait;
                end
                Read_Wait:begin
                  read_cmd_en_d = 1'b0;
                  if(rd_count >= 7'd16)begin
                    Read_state_d = Read_Calculate;
                  end
                end
              endcase
            end
          endcase
        end
      endcase
    end

    always @ (posedge Clk) begin
      if(Rst || ~calib_done)begin
        LED_q <= 8'b0;

        FinishedRendering_q <= 1'b0;
        SpriteCounter_q <= 12'b0;
        XCounter_q <= 6'b0;
        YCounter_q <= 6'b0;
        YReadCounter_q <= 5'b0;
        XStop_q <= 5'b0;
        YStop_q <= 5'b0;
        SpriteStartAddress_q <= 30'b0;
        IntermediateCalculation_q <= 32'b0;

        //Write/Read
        cmd_bl_q <= 6'b0;

        //Write
        write_cmd_en_q <= 1'b0;
        write_cmd_byte_addr_q <= 30'b0;
        wr_en_q <= 1'b0;
        wr_mask_q <= 4'b0;
        wr_data_q <= 32'b0;

        //Read
        read_cmd_en_q <= 1'b0;
        read_cmd_byte_addr_q <= 30'b0;
        rd_en_q <= 1'b0;

        //State Machines
        state_q <= Wait;
        Read_state_q <= Read_Calculate;
        Write_state_q <= Write_Wait;
        Counter_state_q <= Counter_GetInfo;
      end else begin
        LED_q <= LED_d;

        FinishedRendering_q <= FinishedRendering_d;
        SpriteCounter_q <= SpriteCounter_d;
        XCounter_q <= XCounter_d;
        YCounter_q <= YCounter_d;
        YReadCounter_q <= YReadCounter_d;
        XStop_q <= XStop_d;
        YStop_q <= YStop_d;
        SpriteStartAddress_q <= SpriteStartAddress_d;
        IntermediateCalculation_q <= IntermediateCalculation_d;

        //Write/Read
        cmd_bl_q <= cmd_bl_d;

        //Write
        write_cmd_en_q <= write_cmd_en_d;
        write_cmd_byte_addr_q <= write_cmd_byte_addr_d;
        wr_en_q <= wr_en_d;
        wr_mask_q <= wr_mask_d;
        wr_data_q <= wr_data_d;

        //Read
        read_cmd_en_q <= read_cmd_en_d;
        read_cmd_byte_addr_q <= read_cmd_byte_addr_d;
        rd_en_q <= rd_en_d;

        //State Machines
        state_q <= state_d;
        Read_state_q <= Read_state_d;
        Write_state_q <= Write_state_d;
        Counter_state_q <= Counter_state_d;
      end
    end

endmodule
