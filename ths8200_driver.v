`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/16 15:31:32
// Design Name: 
// Module Name: ths8200_driver
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// Module: ths8200_driver
// 模块: ths8200_driver
// Description: This module drives the THS8200 video DAC (Digital-to-Analog Converter).
//              It takes pixel data from a DCFIFO and formats it according to the video timing
//              standards required by the THS8200. It generates the Y (luma) and CbCr (chroma)
//              output signals, along with control signals for blanking and synchronization,
//              to produce a 720p (1280x720) video signal.
// 描述: 本模块用于驱动 THS8200 视频 DAC (数模转换器)。
//       它从 DCFIFO 中获取像素数据，并根据 THS8200 所需的视频时序标准对其进行格式化。
//       它生成 Y (亮度) 和 CbCr (色度) 输出信号，以及用于消隐和同步的控制信号，
//       最终产生 720p (1280x720) 的视频信号。
module ths8200_driver(
    // Pixel Clock and Reset
    // 像素时钟和复位
    input               clk,            // Pixel clock (74.25MHz for 720p) / 像素时钟 (720p 为 74.25MHz)
    input               rst_n,          // Active-low reset for this clock domain / 此
    // DA Interface Outputs
    // DA 接口输出
    output  reg [7:0]   da_y,           // 8-bit Luma (Y) component output / 8位亮度 (Y) 分量输出
    output  reg [7:0]   da_cbcr,        // 8-bit Chroma (CbCr) component output / 8位色度 (CbCr) 分量输出

    // DCFIFO Interface
    // DCFIFO 接口
    input       [31:0]  dcfifo_dout,    // 32-bit data read from DCFIFO (contains multiple pixels) / 从DCFIFO读取的32位数据 (包含多个像素)
    output  reg         dcfifo_rden,    // Read enable signal to DCFIFO / 对 DCFIFO 的读使能信号

    // User Interface
    // 用户接口
    input               da_init_done,   // Signal indicating DA chip initialization is complete / 指示 DA 芯片初始化完成的信号
    output  reg         da_frame_done   // Signal indicating one full frame has been transmitted / 指示一帧完整图像已传输的信号
    );
/*------------------------------------------
--sync dcfifo data
-- 同步DCFIFO数据
-- Description: Registers the data from the DCFIFO to ensure clean timing within this module.
-- 描述: 寄存来自 DCFIFO 的数据，以确保本模块内的时序干净。
------------------------------------------*/
reg [31:0]  sync_dcfifo_dout;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_dcfifo_dout <= 32'd0;
    else
        sync_dcfifo_dout <= dcfifo_dout;
end
/*------------------------------------------
--col pixel count (Horizontal Timing)
-- 列像素计数器 (水平时序)
-- Description: This counter tracks the horizontal position within a line.
--              For 720p, a total of 1650 pixel clocks make up one horizontal line
--              (1280 active pixels + 370 blanking pixels).
-- 描述: 此计数器跟踪一行中的水平位置。
--       对于720p标准，每行总共由1650个像素时钟周期组成
--       (1280个有效像素 + 370个行消隐像素)。
------------------------------------------*/
reg [11:0]  col_cnt;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        col_cnt <= 12'd1;
    else if(col_cnt == 12'd1650)
        col_cnt <= 12'd1;           // Wrap around at the end of the line / 行尾回卷
    else if(da_init_done)
        col_cnt <= col_cnt + 1'b1;  // Increment on every pixel clock / 每个像素时钟周期加一
    else
        col_cnt <= col_cnt;
end
/*------------------------------------------
--row count (Vertical Timing)
-- 行计数器 (垂直时序)
-- Description: This counter tracks the vertical position (current line number).
--              For 720p, a total of 750 lines make up one frame
--              (720 active lines + 30 blanking lines).
-- 描述: 此计数器跟踪垂直位置 (当前行号)。
--       对于720p标准，每帧总共由750行组成
--       (720个有效行 + 30个场消隐行)。
------------------------------------------*/
reg [11:0]  row_cnt;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        row_cnt <= 12'd1;
    else if((row_cnt == 12'd750) && (col_cnt == 12'd1650))
        row_cnt <= 12'd1;           // Wrap around at the end of the frame / 帧尾回卷
    else if(col_cnt == 12'd1650)
        row_cnt <= row_cnt + 1'b1;  // Increment at the end of each line / 每行结束时加一
    else
        row_cnt <= row_cnt;
end
/*------------------------------------------
--output da y (Luma Component)
-- 输出 DA Y (亮度分量)
-- Description: Generates the Y component of the video signal.
--              During blanking intervals (both vertical and horizontal), it outputs sync and blanking level values.
--              During the active video period, it extracts Y data from the `sync_dcfifo_dout` register.
-- 描述: 生成视频信号的 Y 分量。
--       在消隐期间 (包括垂直和水平)，它输出同步和消隐电平值。
--       在有效视频期间，它从 `sync_dcfifo_dout` 寄存器中提取 Y 数据。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        da_y <= 8'h00;
    else if((row_cnt >= 12'd1) && (row_cnt <= 12'd30)) begin // Vertical Blanking period / 垂直消隐期间
        case(col_cnt) // Generate horizontal sync pulses / 生成水平同步脉冲
            12'd1:  da_y <= 8'hFF;
            12'd2:  da_y <= 8'h00;
            12'd3:  da_y <= 8'h00;
            12'd4:  da_y <= 8'hB6;
            12'd367:da_y <= 8'hFF;
            12'd368:da_y <= 8'h00;
            12'd369:da_y <= 8'h00;
            12'd370:da_y <= 8'hAB;
            default:da_y <= 8'h10; // Blanking level / 消隐电平
        endcase
    end
    else begin// Active video period: lines 31-750 / 有效视频期间: 31-750行
        case(col_cnt)
            // Horizontal Blanking and Sync / 水平消隐和同步
            12'd1:  da_y <= 8'hFF;
            12'd2:  da_y <= 8'h00;
            12'd3:  da_y <= 8'h00;
            12'd4:  da_y <= 8'h9D;
            12'd367:da_y <= 8'hFF;
            12'd368:da_y <= 8'h00;
            12'd369:da_y <= 8'h00;
            12'd370:da_y <= 8'h80;
            default:begin
                        // Active Pixel data area (1280 pixels from col 371 to 1650)
                        // 有效像素数据区域 (从第371列到1650列，共1280个像素)
                        if((col_cnt >= 12'd371) && (col_cnt <= 12'd1650)) begin
                            // The 32-bit FIFO data contains two pixels' worth of YCbCr data.
                            // We extract the Y component for each pixel on alternating clock cycles.
                            // 32位的FIFO数据包含两个像素的YCbCr数据。
                            // 我们在交替的时钟周期提取每个像素的Y分量。
                            case(col_cnt[0])
                                1'b1:   da_y <= sync_dcfifo_dout[31:24]; // First pixel's Y / 第一个像素的Y
                                1'b0:   da_y <= sync_dcfifo_dout[15:8];  // Second pixel's Y / 第二个像素的Y
                                default:;
                            endcase
                        end
                        else // Front/Back porch blanking / 前/后肩消隐
                            da_y <= 8'h10;
                    end
        endcase
    end
end
/*------------------------------------------
--output da cbcr (Chroma Component)
-- 输出 DA CbCr (色度分量)
-- Description: Generates the CbCr component of the video signal.
--              The logic is similar to the Y component generation. During blanking it outputs
--              a neutral chroma level (0x80), and during active video it extracts chroma data.
-- 描述: 生成视频信号的 CbCr 分量。
--       逻辑与Y分量的生成类似。在消隐期间，它输出一个中性的色度电平 (0x80)，
--       在有效视频期间，它提取色度数据。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        da_cbcr <= 8'h00;
    else if((row_cnt >= 12'd1) && (row_cnt <= 12'd30)) begin // Vertical Blanking / 垂直消隐
        case(col_cnt) // Generate horizontal sync pulses / 生成水平同步脉冲
            12'd1:  da_cbcr <= 8'hFF;
            12'd2:  da_cbcr <= 8'h00;
            12'd3:  da_cbcr <= 8'h00;
            12'd4:  da_cbcr <= 8'hB6;
            12'd367:da_cbcr <= 8'hFF;
            12'd368:da_cbcr <= 8'h00;
            12'd369:da_cbcr <= 8'h00;
            12'd370:da_cbcr <= 8'hAB;
            default:da_cbcr <= 8'h80; // Neutral chroma level / 中性色度电平
        endcase
    end
    else begin// Active video period: lines 31-750 / 有效视频期间: 31-750行
        case(col_cnt)
            // Horizontal Blanking and Sync / 水平消隐和同步
            12'd1:  da_cbcr <= 8'hFF;
            12'd2:  da_cbcr <= 8'h00;
            12'd3:  da_cbcr <= 8'h00;
            12'd4:  da_cbcr <= 8'h9D;
            12'd367:da_cbcr <= 8'hFF;
            12'd368:da_cbcr <= 8'h00;
            12'd369:da_cbcr <= 8'h00;
            12'd370:da_cbcr <= 8'h80;
            default:begin
                        // Active Pixel data area / 有效像素数据区域
                        if((col_cnt >= 12'd371) && (col_cnt <= 12'd1650)) begin
                            // Extract CbCr component for each pixel on alternating clock cycles.
                            // 在交替的时钟周期提取每个像素的CbCr分量。
                            case(col_cnt[0])
                                1'b1:   da_cbcr <= sync_dcfifo_dout[23:16]; // First pixel's CbCr / 第一个像素的CbCr
                                1'b0:   da_cbcr <= sync_dcfifo_dout[7:0];   // Second pixel's CbCr / 第二个像素的CbCr
                                default:;
                            endcase
                        end
                        else // Front/Back porch blanking / 前/后肩消隐
                            da_cbcr <= 8'h80;
                    end
        endcase
    end
end
/*------------------------------------------
--output dcfifo read enable
-- 输出 DCFIFO 读使能
-- Description: Generates the read enable signal for the DCFIFO.
--              A read is performed every two clock cycles during the active video display area
--              to fetch the next 32-bit data word (containing two pixels).
-- 描述: 生成 DCFIFO 的读使能信号。
--       在有效视频显示区域，每两个时钟周期执行一次读操作，
--       以获取下一个32位数据字 (包含两个像素)。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        dcfifo_rden <= 1'b0;
        // Active video area, excluding the very last few pixels to manage FIFO latency.
        // 有效视频区域，不包括最后几个像素以管理FIFO延迟。
    else if((row_cnt >= 12'd31) && (row_cnt <= 12'd750) && (col_cnt >= 12'd367) && (col_cnt <= 12'd1646)) begin
        case(col_cnt[0])
            1'b1:   dcfifo_rden <= 1'b1; // Assert read enable every other clock cycle / 每隔一个时钟周期拉高读使能
            default:dcfifo_rden <= 1'b0;
        endcase
    end
    else
        dcfifo_rden <= 1'b0;
end
/*------------------------------------------
--output frame done
-- 输出帧完成信号
-- Description: Asserts `da_frame_done` for one clock cycle at the very end of a complete frame.
-- 描述: 在一帧完整图像的最后一个时钟周期，将 `da_frame_done` 拉高一个时钟周期。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        da_frame_done <= 1'b0;
    else if((row_cnt == 12'd750) && (col_cnt == 12'd1650))
        da_frame_done <= 1'b1;
    else
        da_frame_done <= 1'b0;
end

endmodule
