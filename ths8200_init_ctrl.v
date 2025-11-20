`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/12 13:41:34
// Design Name: 
// Module Name: ths8200_init_ctrl
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


module ths8200_init_ctrl(
    // Global Clock and Reset
    // 全局时钟和复位
    input               clk,
    input               rst_n,

    // DA Chip Interface
    // DA 芯片接口
    output  reg         da_reset_n,     // Active-low reset signal for the THS8200 chip / THS8200 芯片的低电平有效复位信号

    // I2C Interface (Outputs to I2C Driver, Inputs from I2C Driver)
    // I2C 接口 (输出到I2C驱动，输入来自I2C驱动)
    input       [7:0]   rd_data,        // Data read from I2C bus / 从 I2C 总线读取的数据
    input               rd_done,        // Signal indicating I2C read is complete / 指示 I2C 读取完成的信号
    output  reg [7:0]   rd_addr,        // Register address to read from / 要读取的寄存器地址
    output  reg         rd_en,          // Enable signal for I2C read operation / I2C 读操作使能信号
    input               wr_done,        // Signal indicating I2C write is complete / 指示 I2C 写入完成的信号
    output  reg         wr_en,          // Enable signal for I2C write operation / I2C 写操作使能信号
    output  reg [7:0]   wr_addr,        // Register address to write to / 要写入的寄存器地址
    output  reg [7:0]   wr_data,        // Data to write / 要写入的数据

    // Configuration ROM Interface
    // 配置 ROM 接口
    input      	[15:0]	config_data,    // 16-bit config data {addr, data} from ROM / 从 ROM 读出的16位配置数据 {地址, 数据}
    output  reg [7:0]	config_index,   // Index to address the config ROM / 用于寻址配置 ROM 的索引

    // User Interface
    // 用户接口
	output reg         da_init_done    // Signal that goes high when initialization is complete / 初始化完成时拉高的信号
    );

// State Machine Parameters
// 状态机参数
parameter   IDLE        =   4'd0;       // Initial state, holds DA chip in reset / 初始状态，保持 DA 芯片复位
parameter   DA_RD_ID    =   4'd1;       // State to read the DA chip's ID register / 读取 DA 芯片 ID 寄存器的状态
parameter   DA_INIT     =   4'd2;       // State to write all configuration registers / 写入所有配置寄存器的状态
parameter   DA_CFG_DONE =   4'd3;       // Final state, initialization is complete / 最终状态，初始化完成

/*------------------------------------------
--sync config data
-- 同步配置数据
-- Description: Registers the config data from the ROM to ensure clean timing.
-- 描述: 寄存来自 ROM 的配置数据以确保干净的时序。
------------------------------------------*/
reg [15:0]  sync_config_data;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_config_data <= 16'd0;
    else
        sync_config_data <= config_data;
end
/*------------------------------------------
--state machine
-- 状态机
------------------------------------------*/
reg [3:0]   current_state , next_state;
reg [5:0]   da_reset_cnt;               // Counter for DA chip reset pulse width / DA 芯片复位脉冲宽度计数器

// State Register
// 状态寄存器
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

// Next State Logic
// 下一状态逻辑
always@(*) begin
    case(current_state)
        IDLE:       begin
                        // Wait for the reset pulse to be long enough
                        // 等待复位脉冲足够长
                        if(da_reset_cnt == 6'd49)
                            next_state = DA_RD_ID;
                        else
                            next_state = IDLE;
                    end
        DA_RD_ID:   begin
                        // After reading, if the data is correct (0x04 is part of the chip ID), proceed to initialization
                        // 读取后，如果数据正确 (0x04 是芯片ID的一部分)，则进入初始化
                        if((rd_data == 8'h04) && (rd_done))
                            next_state = DA_INIT;
                        else
                            next_state = DA_RD_ID;
                    end
        DA_INIT:    begin
                        // Check if the last configuration word has been written
                        // 检查是否最后一个配置字已被写入
                        if((config_index == `DA_CFG_SIZE) && (wr_done)) // DA_CFG_SIZE is defined in system_parameter.v
                            next_state = DA_CFG_DONE;
                        else
                            next_state = DA_INIT;
                    end
        DA_CFG_DONE:begin
                        // Stay in the done state
                        // 停在完成状态
                        next_state = DA_CFG_DONE;
                    end
        default:    next_state = IDLE;
    endcase
end
/*------------------------------------------
--da reset count
-- DA 复位计数器
-- Description: Generates a reset pulse of a specific duration for the THS8200 chip.
-- 描述: 为 THS8200 芯片生成一个特定持续时间的复位脉冲。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        da_reset_cnt <= 6'd0;
    else begin
        case(current_state)
            IDLE:       begin
                            if(da_reset_cnt == 6'd49)
                                da_reset_cnt <= 6'd0; // Reset counter for reuse if needed / 如果需要，重置计数器以备复用
                            else
                                da_reset_cnt <= da_reset_cnt + 1'b1;
                        end
            default:    da_reset_cnt <= 6'd0;
        endcase
    end
end
/*------------------------------------------
--step count
-- 步骤计数器
-- Description: A small counter to create multiple clock cycle delays between actions
--              within a single state (e.g., to sequence I2C enable and address signals).
-- 描述: 一个小计数器，用于在单个状态内的操作之间创建多个时钟周期的延迟
--       (例如，对I2C使能和地址信号进行排序)。
------------------------------------------*/
reg [3:0]   step_cnt;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        step_cnt <= 4'd0;
    else begin
        case(current_state)
            DA_RD_ID:   begin
                            // Reset the counter when the I2C read is done
                            // I2C 读取完成后复位计数器
                            if(rd_done)
                                step_cnt <= 4'd0;
                            else if(step_cnt == 4'd1)
                                step_cnt <= step_cnt; // Hold for a cycle / 保持一个周期
                            else
                                step_cnt <= step_cnt + 1'b1;
                        end
            DA_INIT:    begin
                            // Reset the counter when the I2C write is done
                            // I2C 写入完成后复位计数器
                            if(wr_done)
                                step_cnt <= 4'd0;
                            else if(step_cnt == 4'd5)
                                step_cnt <= step_cnt; // Hold for a cycle / 保持一个周期
                            else
                                step_cnt <= step_cnt + 1'b1;
                        end
            default:    step_cnt <= 4'd0;
        endcase
    end
end
/*------------------------------------------
--output da reset 
-- 输出 DA 复位信号
-- Description: Controls the actual da_reset_n pin. It is held low during the IDLE state.
-- 描述: 控制实际的 da_reset_n 引脚。在 IDLE 状态期间，它被保持为低电平。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        da_reset_n <= 1'b1;
    else begin
        case(current_state)
            IDLE:       da_reset_n <= 1'b0; // Assert reset / 拉低复位
            default:    da_reset_n <= 1'b1; // De-assert reset / 释放复位
        endcase
    end
end
/*------------------------------------------
--output read enable
-- 输出读使能
-- Description: Generates the rd_en pulse for the I2C driver in the DA_RD_ID state.
-- 描述: 在 DA_RD_ID 状态下为 I2C 驱动生成 rd_en 脉冲。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rd_en <= 1'b0;
    else begin
        case(current_state)
            DA_RD_ID:   begin
                            // Start a read on the first step
                            // 在第一步开始读取
                            if(step_cnt == 4'd0)
                                rd_en <= 1'b1;
                            else
                                rd_en <= 1'b0;
                        end
            default:    rd_en <= 1'b0;
        endcase
    end
end
/*------------------------------------------
--output read address
-- 输出读地址
-- Description: Provides the address (0x02, device ID register) for the I2C read operation.
-- 描述: 为 I2C 读操作提供地址（0x02，设备ID寄存器）。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rd_addr <= 8'd0;
    else begin
        case(current_state)
            DA_RD_ID:   begin
                            if(step_cnt == 4'd0)
                                rd_addr <= 8'h02; // Address of the device ID register / 设备ID寄存器的地址
                            else
                                rd_addr <= rd_addr;
                        end
            default:    rd_addr <= 8'd0;
        endcase
    end
end
/*------------------------------------------
--output config index
-- 输出配置索引
-- Description: Increments the config_index after each successful I2C write, effectively
--              stepping through the configuration ROM.
-- 描述: 在每次成功的 I2C 写入后递增 config_index，从而有效地
--       遍历配置ROM。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        config_index <= 8'd0;
    else begin
        case(current_state)
            DA_INIT:    begin
                            if((config_index == `DA_CFG_SIZE) && (wr_done))
                                config_index <= 8'd0; // Reset after finishing / 完成后复位
                            else if(wr_done)
                                config_index <= config_index + 1'b1; // Move to next config word / 移动到下一个配置字
                            else
                                config_index <= config_index;
                        end
            default:    config_index <= 8'd0;
        endcase    
    end
end
/*------------------------------------------
--output write enable
-- 输出写使能
-- Description: Generates the wr_en pulse for the I2C driver in the DA_INIT state.
-- 描述: 在 DA_INIT 状态下为 I2C 驱动生成 wr_en 脉冲。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        wr_en <= 1'b0;
    else begin
        case(current_state)
            DA_INIT:    begin
                            // Start a write after a few steps delay to allow config data to be valid
                            // 延迟几个步骤再开始写入，以确保配置数据有效
                            if(step_cnt == 4'd4)
                                wr_en <= 1'b1;
                            else
                                wr_en <= 1'b0;
                        end
            default:    wr_en <= 1'b0;
        endcase
    end
end
/*------------------------------------------
--output write address
-- 输出写地址
-- Description: Extracts the 8-bit register address from the 16-bit synchronized config data.
-- 描述: 从16位同步配置数据中提取8位寄存器地址。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        wr_addr <= 8'd0;
    else begin
        case(current_state)
            DA_INIT:    begin
                            if(step_cnt == 4'd4)
                                wr_addr <= sync_config_data[15:8]; // MSB is the address / 高8位是地址
                            else
                                wr_addr <= wr_addr;
                        end
            default:    wr_addr <= 8'd0;
        endcase
    end
end
/*------------------------------------------
--output write data
-- 输出写数据
-- Description: Extracts the 8-bit data from the 16-bit synchronized config data.
-- 描述: 从16位同步配置数据中提取8位数据。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        wr_data <= 8'd0;
    else begin
        case(current_state)
            DA_INIT:    begin
                            if(step_cnt == 4'd4)
                                wr_data <= sync_config_data[7:0]; // LSB is the data / 低8位是数据
                            else
                                wr_data <= wr_data;
                        end
            default:    wr_data <= 8'd0;
        endcase
    end
end
/*------------------------------------------
--output da init done
-- 输出 DA 初始化完成信号
-- Description: Asserts the final da_init_done signal when the state machine reaches the DA_CFG_DONE state.
-- 描述: 当状态机到达 DA_CFG_DONE 状态时，拉高最终的 da_init_done 信号。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        da_init_done <= 1'b0;
    else begin
        case(current_state)
            DA_CFG_DONE:    da_init_done <= 1'b1;
            default:        da_init_done <= 1'b0;
        endcase
    end
end

endmodule
