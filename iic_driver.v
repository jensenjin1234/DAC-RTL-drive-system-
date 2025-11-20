`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/25 20:20:17
// Design Name: 
// Module Name: iic_driver
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
// Module: iic_driver
// 模块: iic_driver
// Description: This module implements an I2C master controller. It can perform write and read operations
//              to an I2C slave device. It is controlled by user signals like wr_en (write enable) and
//              rd_en (read enable). The module handles the I2C protocol, including START, STOP,
//              addressing, data transfer, and acknowledging.
// 描述: 本模块实现了一个 I2C 主机控制器。它可以对 I2C 从设备执行写操作和读操作。
//       该模块由用户信号控制，例如 wr_en (写使能) 和 rd_en (读使能)。
//       模块处理标准的 I2C 协议，包括 START, STOP, 设备寻址, 数据传输和应答信号。
`include    "../rtl/system_parameter.v"

module iic_driver(
    // Global Clock and Reset
    // 全局时钟和复位
    input               clk,        // System clock (e.g., 100MHz) / 系统时钟 (例如 100MHz)
    input               rst_n,      // Asynchronous active-low reset / 异步低电平有效复位

    // IIC Interface
    // IIC 接口
    output  reg         iic_scl,    // I2C Clock line (e.g., 100KHz) / I2C 时钟线 (例如 100KHz)
    inout               iic_sda,    // I2C Data line / I2C 数据线

    // User Write Interface
    // 用户写接口
    input               wr_en,      // Write enable, a pulse triggers a write operation / 写使能，一个脉冲触发一次写操作
    input       [7:0]   wr_addr,    // 8-bit register address to write to in the slave / 要写入的从设备8位寄存器地址
    input       [7:0]   wr_data,    // 8-bit data to write / 要写入的8位数据
    output  reg         wr_done,    // Signal indicating write operation is complete / 指示写操作完成的信号

    // User Read Interface
    // 用户读接口
    input               rd_en,      // Read enable, a pulse triggers a read operation / 读使能，一个脉冲触发一次读操作
    input       [7:0]   rd_addr,    // 8-bit register address to read from in the slave / 要读取的从设备8位寄存器地址
    output  reg [7:0]   rd_data,    // 8-bit data read from the slave / 从设备读取到的8位数据
    output  reg         rd_done,    // Signal indicating read operation is complete / 指示读操作完成的信号
    output  reg         slave_no_ack // Flag indicating that the slave did not acknowledge / 从设备未应答的标志
    );
// State machine parameters for I2C protocol
// I2C 协议的状态机参数
parameter   IDLE        =   4'd0;   // Idle state / 空闲状态
parameter   IIC_START   =   4'd1;   // Generate I2C START condition / 生成 I2C START 信号状态
parameter   SLAVE_ADDR  =   4'd2;   // Send slave address / 发送从设备地址状态
parameter   SLAVE_ACK1  =   4'd3;   // Wait for slave acknowledge 1 / 等待从设备应答1状态
parameter   SUB_ADDR    =   4'd4;   // Send sub-address (register address) / 发送子地址(寄存器地址)状态
parameter   SLAVE_ACK2  =   4'd5;   // Wait for slave acknowledge 2 / 等待从设备应答2状态
parameter   IIC_WRDATA  =   4'd6;   // Write data to slave / 向从设备写数据状态
parameter   SLAVE_ACK3  =   4'd7;   // Wait for slave acknowledge 3 / 等待从设备应答3状态
parameter   IIC_RDDATA  =   4'd8;   // Read data from slave / 从从设备读数据状态
parameter   M_NO_ACK    =   4'd9;   // Master generates NO ACK / 主机生成 NO ACK 状态
parameter   IIC_STOP    =   4'd10;  // Generate I2C STOP condition / 生成 I2C STOP 信号状态
parameter   S_NO_ACK    =   4'd11;  // Slave did not acknowledge error state / 从设备未应答错误状态

/*------------------------------------------
--sync write enable
-- 同步写使能信号
-- Description: Synchronize wr_en to the local clock domain.
-- 描述: 将 wr_en 同步到本地时钟域。
------------------------------------------*/
reg         sync_wr_en;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_wr_en <= 1'b0;
    else
        sync_wr_en <= wr_en;
end
/*------------------------------------------
--sync read enable
-- 同步读使能信号
-- Description: Synchronize rd_en to the local clock domain.
-- 描述: 将 rd_en 同步到本地时钟域。
------------------------------------------*/
reg         sync_rd_en;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_rd_en <= 1'b0;
    else
        sync_rd_en <= rd_en;
end
/*------------------------------------------
--sync write addr
-- 同步写地址
-- Description: Synchronize wr_addr to the local clock domain.
-- 描述: 将 wr_addr 同步到本地时钟域。
------------------------------------------*/
reg [7:0]   sync_wr_addr;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_wr_addr <= 8'd0;
    else
        sync_wr_addr <= wr_addr;
end
/*------------------------------------------
--sync read addr
-- 同步读地址
-- Description: Synchronize rd_addr to the local clock domain.
-- 描述: 将 rd_addr 同步到本地时钟域。
------------------------------------------*/
reg [7:0]   sync_rd_addr;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_rd_addr <= 8'd0;
    else
        sync_rd_addr <= rd_addr;
end
/*------------------------------------------
--sync write data
-- 同步写数据
-- Description: Synchronize wr_data to the local clock domain.
-- 描述: 将 wr_data 同步到本地时钟域。
------------------------------------------*/
reg [7:0]   sync_wr_data;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_wr_data <= 8'd0;
    else
        sync_wr_data <= wr_data;
end
/*------------------------------------------
--register write addr
-- 寄存写/读地址
-- Description: Latches the address when a write or read enable is detected. This registered
--              address is used for the I2C transaction.
-- 描述: 在检测到写使能或读使能时锁存地址。该寄存器地址用于 I2C 传输。
------------------------------------------*/
reg [7:0]   wr_addr_r;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        wr_addr_r <= 8'd0;
    else if(sync_wr_en)
        wr_addr_r <= sync_wr_addr;
    else if(sync_rd_en)
        wr_addr_r <= sync_rd_addr;
    else
        wr_addr_r <= wr_addr_r;
end
/*------------------------------------------
--register write data
-- 寄存写数据
-- Description: Latches the data when a write enable is detected. This registered data
--              is used for the I2C transaction.
-- 描述: 在检测到写使能时锁存数据。该寄存器数据用于 I2C 传输。
------------------------------------------*/
reg [7:0]   wr_data_r;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        wr_data_r <= 8'd0;
    else if(sync_wr_en)
        wr_data_r <= sync_wr_data;
    else
        wr_data_r <= wr_data_r;
end
/*------------------------------------------
--read state flag
-- 读状态标志
-- Description: A flag that is set high during a read operation (from rd_en to rd_done).
--              It helps the state machine to distinguish between write and read sequences.
-- 描述: 在读操作期间（从 rd_en 到 rd_done）置为高的标志。
--       它帮助状态机区分写序列和读序列。
------------------------------------------*/
reg         rd_state_flag;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rd_state_flag <= 1'b0;
    else if(rd_done)
        rd_state_flag <= 1'b0;
    else if(sync_rd_en)
        rd_state_flag <= 1'b1;
    else
        rd_state_flag <= rd_state_flag;
end
/*------------------------------------------
--state machine
-- 状态机
-- Description: The main state machine that controls the I2C protocol.
-- 描述: 控制I2C协议的主状态机。
------------------------------------------*/
reg [3:0]   current_state , next_state;
reg [11:0]  iic_scl_cnt;    // Counter for generating iic_scl period / 用于生成iic_scl周期的计数器
reg [3:0]   iic_bit_cnt;    // Counter for bits in a byte transaction / 字节传输中的比特计数器
reg         slave_ack_r;    // Register to store slave's acknowledge signal / 用于存储从设备应答信号的寄存器
reg [1:0]   rd_start_cnt;   // Counter for START conditions during a read operation / 读操作期间START条件的计数器

// State registers
// 状态寄存器
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

// Next state logic
// 下一状态逻辑
always@(*) begin
    case(current_state)
        IDLE:       begin
                        if(sync_wr_en)
                            next_state = IIC_START;
                        else if(sync_rd_en)
                            next_state = IIC_START;
                        else
                            next_state = IDLE;
                    end
        IIC_START:  begin
                        if(iic_scl_cnt == `IIC_SCL_PERIOD)
                            next_state = SLAVE_ADDR;
                        else
                            next_state = IIC_START;
                    end
        SLAVE_ADDR: begin
                        if((iic_bit_cnt == 4'd7) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                            next_state = SLAVE_ACK1;
                        else
                            next_state = SLAVE_ADDR;
                    end
        SLAVE_ACK1: begin
                        if((slave_ack_r == 1'b0) && (iic_scl_cnt == `IIC_SCL_PERIOD) && (rd_start_cnt == 2'd2))
                            next_state = IIC_RDDATA;
                        else if((slave_ack_r == 1'b0) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                            next_state = SUB_ADDR;
                        else if(iic_scl_cnt == `IIC_SCL_PERIOD)
                            next_state = S_NO_ACK;
                        else
                            next_state = SLAVE_ACK1;
                    end
        SUB_ADDR:   begin
                        if((iic_bit_cnt == 4'd7) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                            next_state = SLAVE_ACK2;
                        else
                            next_state = SUB_ADDR;
                    end
        SLAVE_ACK2: begin
                        if((slave_ack_r == 1'b0) && (iic_scl_cnt == `IIC_SCL_PERIOD) && (rd_state_flag))
                            next_state = IIC_STOP;
                        else if((slave_ack_r == 1'b0) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                            next_state = IIC_WRDATA;
                        else if(iic_scl_cnt == `IIC_SCL_PERIOD)
                            next_state = S_NO_ACK;
                        else
                            next_state = SLAVE_ACK2;
                    end
        IIC_WRDATA: begin
                        if((iic_bit_cnt == 4'd7) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                            next_state = SLAVE_ACK3;
                        else
                            next_state = IIC_WRDATA;
                    end
        SLAVE_ACK3: begin
                        if((slave_ack_r == 1'b0) && ((iic_scl_cnt == `IIC_SCL_PERIOD)))
                            next_state = IIC_STOP;
                        else if(iic_scl_cnt == `IIC_SCL_PERIOD)
                            next_state = S_NO_ACK;
                        else
                            next_state = SLAVE_ACK3;
                    end
        IIC_RDDATA: begin
                        if((iic_bit_cnt == 4'd7) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                            next_state = M_NO_ACK;
                        else
                            next_state = IIC_RDDATA;
                    end
        M_NO_ACK:   begin
                        if(iic_scl_cnt == `IIC_SCL_PERIOD)
                            next_state = IIC_STOP;
                        else
                            next_state = M_NO_ACK;
                    end
        IIC_STOP:   begin
                        if((iic_scl_cnt == `IIC_SCL_PERIOD) && (rd_state_flag) && (rd_start_cnt == 2'd2))
                            next_state = IDLE;
                        else if((iic_scl_cnt == `IIC_SCL_PERIOD) && (rd_state_flag))
                            next_state = IIC_START;
                        else if(iic_scl_cnt == `IIC_SCL_PERIOD)
                            next_state = IDLE;
                        else
                            next_state = IIC_STOP;
                    end
        default:    next_state = IDLE;
    endcase
end
/*------------------------------------------
--regsiter slave ack
-- 寄存从设备应答信号
-- 0              mean               ack (ack)
-- 1              mean             no ack (nack)
-- Description: Samples iic_sda line when scl is high to check for slave's ACK.
--              ACK is when the slave pulls sda low.
-- 描述: 在scl为高电平时采样iic_sda线以检查从设备的ACK。
--       当从设备将sda拉低时，表示ACK。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        slave_ack_r <= 1'b1;
    else begin
        case(current_state)
            SLAVE_ACK1: begin
                            if((iic_scl_cnt == `IIC_SCL_CENTER) && (iic_sda == 1'b0))
                                slave_ack_r <= 1'b0;
                            else
                                slave_ack_r <= slave_ack_r;
                        end
            SLAVE_ACK2: begin
                            if((iic_scl_cnt == `IIC_SCL_CENTER) && (iic_sda == 1'b0))
                                slave_ack_r <= 1'b0;
                            else
                                slave_ack_r <= slave_ack_r;
                        end
            SLAVE_ACK3: begin
                            if((iic_scl_cnt == `IIC_SCL_CENTER) && (iic_sda == 1'b0))
                                slave_ack_r <= 1'b0;
                            else
                                slave_ack_r <= slave_ack_r;
                        end
            default:    slave_ack_r <= 1'b1;
        endcase 
    end
end
/*------------------------------------------
--read start count
-- 读操作START信号计数器
-- Description: A read operation in I2C requires two START conditions. This counter tracks them.
--              1. START -> SLAVE_ADDR(W) -> SUB_ADDR
--              2. Re-START -> SLAVE_ADDR(R) -> RDDATA
-- 描述: I2C中的读操作需要两个START条件。该计数器用于跟踪它们。
--       1. START -> 从设备地址(写) -> 子地址
--       2. Re-START -> 从设备地址(读) -> 读数据
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rd_start_cnt <= 2'd0;
    else begin
        case(current_state)
            IIC_START:  begin
                            if((iic_scl_cnt == `IIC_SCL_PERIOD) && (rd_state_flag))
                                rd_start_cnt <= rd_start_cnt + 1'b1;
                            else
                                rd_start_cnt <= rd_start_cnt;
                        end
            IIC_STOP:   begin
                            if((iic_scl_cnt == `IIC_SCL_PERIOD) && (rd_state_flag) && (rd_start_cnt == 2'd2))
                                rd_start_cnt <= 2'd0;
                            else
                                rd_start_cnt <= rd_start_cnt;
                        end
            default:    rd_start_cnt <= rd_start_cnt;
        endcase 
    end
end
/*------------------------------------------
--iic bit count
-- iic 比特计数器
-- Description: Counts the 8 bits being transferred for address and data bytes.
-- 描述: 计数正在传输的地址和数据字节的8个比特。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        iic_bit_cnt <= 4'd0;
    else begin
        case(current_state)
            SLAVE_ADDR: begin
                            if((iic_bit_cnt == 4'd7) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                                iic_bit_cnt <= 4'd0;
                            else if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_bit_cnt <= iic_bit_cnt + 1'b1;
                            else
                                iic_bit_cnt <= iic_bit_cnt;
                        end
            SUB_ADDR:   begin
                            if((iic_bit_cnt == 4'd7) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                                iic_bit_cnt <= 4'd0;
                            else if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_bit_cnt <= iic_bit_cnt + 1'b1;
                            else
                                iic_bit_cnt <= iic_bit_cnt;
                        end
            IIC_WRDATA: begin
                            if((iic_bit_cnt == 4'd7) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                                iic_bit_cnt <= 4'd0;
                            else if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_bit_cnt <= iic_bit_cnt + 1'b1;
                            else
                                iic_bit_cnt <= iic_bit_cnt;
                        end
            IIC_RDDATA: begin
                            if((iic_bit_cnt == 4'd7) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                                iic_bit_cnt <= 4'd0;
                            else if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_bit_cnt <= iic_bit_cnt + 1'b1;
                            else
                                iic_bit_cnt <= iic_bit_cnt;
                        end
            default:    iic_bit_cnt <= 4'd0;
        endcase
    end
end
/*------------------------------------------
--iic scl count
-- iic scl 计数器
-- Description: Generates the timing for the I2C SCL clock signal based on `IIC_SCL_PERIOD`.
-- 描述: 基于 `IIC_SCL_PERIOD` 生成I2C SCL时钟信号的时序。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        iic_scl_cnt <= 12'd0;
    else begin
        case(current_state)
            IIC_START:  begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            SLAVE_ADDR: begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            SLAVE_ACK1: begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            SUB_ADDR:   begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            SLAVE_ACK2: begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            IIC_WRDATA: begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            SLAVE_ACK3: begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            IIC_RDDATA: begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            M_NO_ACK:   begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            IIC_STOP:   begin
                            if(iic_scl_cnt == `IIC_SCL_PERIOD)
                                iic_scl_cnt <= 12'd0;
                            else
                                iic_scl_cnt <= iic_scl_cnt + 1'b1;
                        end
            default:    iic_scl_cnt <= 12'd0;
        endcase
    end
end
/*------------------------------------------
--output iic scl
-- 输出 iic_scl
-- Description: Drives the iic_scl output based on the iic_scl_cnt.
--              Generates a clock with a specific duty cycle.
-- 描述: 根据iic_scl_cnt驱动iic_scl输出。
--       生成具有特定占空比的时钟。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        iic_scl <= 1'b1;
    else begin
        case(current_state)
            IIC_START:  begin
                            if(iic_scl_cnt <= `IIC_SCL_NEGEDGE)
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            SLAVE_ADDR: begin
                            if((iic_scl_cnt > `IIC_SCL_POSDEGE) && (iic_scl_cnt <= `IIC_SCL_NEGEDGE))
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            SLAVE_ACK1: begin
                            if((iic_scl_cnt > `IIC_SCL_POSDEGE) && (iic_scl_cnt <= `IIC_SCL_NEGEDGE))
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            SUB_ADDR:   begin
                            if((iic_scl_cnt > `IIC_SCL_POSDEGE) && (iic_scl_cnt <= `IIC_SCL_NEGEDGE))
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            SLAVE_ACK2: begin
                            if((iic_scl_cnt > `IIC_SCL_POSDEGE) && (iic_scl_cnt <= `IIC_SCL_NEGEDGE))
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            IIC_WRDATA: begin
                            if((iic_scl_cnt > `IIC_SCL_POSDEGE) && (iic_scl_cnt <= `IIC_SCL_NEGEDGE))
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            SLAVE_ACK3: begin
                            if((iic_scl_cnt > `IIC_SCL_POSDEGE) && (iic_scl_cnt <= `IIC_SCL_NEGEDGE))
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            IIC_RDDATA: begin
                            if((iic_scl_cnt > `IIC_SCL_POSDEGE) && (iic_scl_cnt <= `IIC_SCL_NEGEDGE))
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            M_NO_ACK:   begin
                            if((iic_scl_cnt > `IIC_SCL_POSDEGE) && (iic_scl_cnt <= `IIC_SCL_NEGEDGE))
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            IIC_STOP:   begin
                            if(iic_scl_cnt > `IIC_SCL_POSDEGE)
                                iic_scl <= 1'b1;
                            else
                                iic_scl <= 1'b0;
                        end
            default:    iic_scl <= 1'b1;
        endcase
    end
end
/*------------------------------------------
--output no ack
-- 输出无应答信号
-- Description: Generates a pulse on `slave_no_ack` if the slave fails to acknowledge.
-- 描述: 如果从设备未能应答，则在 `slave_no_ack` 上生成一个脉冲。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        slave_no_ack <= 1'b0;
    else begin
        case(current_state)
            S_NO_ACK:   slave_no_ack <= 1'b1;
            default:    slave_no_ack <= 1'b0;
        endcase
    end
end
/*------------------------------------------
--iic sda dir
-- iic sda 方向控制
-- 0             mean            input (高阻态)
-- 1             mean            output (驱动)
-- Description: Controls the direction of the bidirectional iic_sda line. It's an output
--              when the master is sending data, and an input when receiving.
-- 描述: 控制双向iic_sda线的方向。当主机发送数据时为输出，
--       接收数据时为输入(高阻)。
------------------------------------------*/
reg         iic_sda_dir;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        iic_sda_dir <= 1'b0;
    else begin
        case(current_state)
            IIC_START:  iic_sda_dir <= 1'b1;
            SLAVE_ADDR: iic_sda_dir <= 1'b1;
            SUB_ADDR:   iic_sda_dir <= 1'b1;
            IIC_WRDATA: iic_sda_dir <= 1'b1;
            M_NO_ACK:   iic_sda_dir <= 1'b1;
            IIC_STOP:   iic_sda_dir <= 1'b1;
            default:    iic_sda_dir <= 1'b0;
        endcase
    end
end
/*------------------------------------------
--register iic sda
-- 寄存 iic_sda
-- Description: This register holds the value to be driven on the iic_sda line when it's an output.
--              It generates START/STOP conditions and sends address/data bits.
-- 描述: 该寄存器保存在iic_sda线作为输出时要驱动的值。
--       它生成START/STOP条件并发送地址/数据位。
------------------------------------------*/
reg         iic_sda_r;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        iic_sda_r <= 1'b1;
    else begin
        case(current_state)
            IIC_START:  begin
                            if(iic_scl_cnt > `IIC_SCL_POSDEGE)
                                iic_sda_r <= 1'b0;
                            else
                                iic_sda_r <= 1'b1;
                        end
            SLAVE_ADDR: begin
                            case(iic_bit_cnt)
                                4'd0:   iic_sda_r <= 1'b0;
                                4'd1:   iic_sda_r <= 1'b1;
                                4'd2:   iic_sda_r <= 1'b0;
                                4'd3:   iic_sda_r <= 1'b0;
                                4'd4:   iic_sda_r <= 1'b0;
                                4'd5:   iic_sda_r <= 1'b0;
                                4'd6:   iic_sda_r <= 1'b0;
                                4'd7:   begin
                                            case(rd_start_cnt)
                                                2'd1:   iic_sda_r <= 1'b0;
                                                2'd2:   iic_sda_r <= 1'b1;
                                                default:iic_sda_r <= 1'b0;
                                            endcase
                                        end
                                default:iic_sda_r <= 1'b0;
                            endcase
                        end
           SUB_ADDR:	begin
							case(iic_bit_cnt)
								4'd0:	iic_sda_r <= wr_addr_r[7];
								4'd1:	iic_sda_r <= wr_addr_r[6];
								4'd2:	iic_sda_r <= wr_addr_r[5];
								4'd3:	iic_sda_r <= wr_addr_r[4];
								4'd4:	iic_sda_r <= wr_addr_r[3];
								4'd5:	iic_sda_r <= wr_addr_r[2];
								4'd6:	iic_sda_r <= wr_addr_r[1];
								4'd7:	iic_sda_r <= wr_addr_r[0];
								default:iic_sda_r <= iic_sda_r;
							endcase
						end
			IIC_WRDATA:	begin
							case(iic_bit_cnt)
								4'd0:	iic_sda_r <= wr_data_r[7];
								4'd1:	iic_sda_r <= wr_data_r[6];
								4'd2:	iic_sda_r <= wr_data_r[5];
								4'd3:	iic_sda_r <= wr_data_r[4];
								4'd4:	iic_sda_r <= wr_data_r[3];
								4'd5:	iic_sda_r <= wr_data_r[2];
								4'd6:	iic_sda_r <= wr_data_r[1];
								4'd7:	iic_sda_r <= wr_data_r[0];
								default:iic_sda_r <= iic_sda_r;
							endcase
						end
		    M_NO_ACK:   iic_sda_r <= 1'b1;
		    IIC_STOP:   begin
		                    if(iic_scl_cnt > `IIC_SCL_NEGEDGE)
		                        iic_sda_r <= 1'b1;
		                    else
		                        iic_sda_r <= 1'b0;
		                end
            default:    iic_sda_r <= 1'b1;
        endcase
    end
end
/*------------------------------------------
--register iic read data
-- 寄存 iic 读数据
-- Description: When reading from the slave, this register latches the incoming data
--              bit by bit from the iic_sda line.
-- 描述: 从从设备读取时，此寄存器从iic_sda线逐位锁存输入数据。
------------------------------------------*/
reg [7:0]   rd_data_r;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rd_data_r <= 8'd0;
    else begin
        case(current_state)
            IDLE:       rd_data_r <= 8'd0;
            IIC_RDDATA: begin
                            case(iic_bit_cnt)
                                4'd0:   begin
                                            if(iic_scl_cnt == `IIC_SCL_CENTER)
                                                rd_data_r[7] <= iic_sda;
                                            else
                                                rd_data_r    <= rd_data_r;
                                        end
                                4'd1:   begin
                                            if(iic_scl_cnt == `IIC_SCL_CENTER)
                                                rd_data_r[6] <= iic_sda;
                                            else
                                                rd_data_r    <= rd_data_r;
                                        end
                                4'd2:   begin
                                            if(iic_scl_cnt == `IIC_SCL_CENTER)
                                                rd_data_r[5] <= iic_sda;
                                            else
                                                rd_data_r    <= rd_data_r;
                                        end
                                4'd3:   begin
                                            if(iic_scl_cnt == `IIC_SCL_CENTER)
                                                rd_data_r[4] <= iic_sda;
                                            else
                                                rd_data_r    <= rd_data_r;
                                        end
                                4'd4:   begin
                                            if(iic_scl_cnt == `IIC_SCL_CENTER)
                                                rd_data_r[3] <= iic_sda;
                                            else
                                                rd_data_r    <= rd_data_r;
                                        end
                                4'd5:   begin
                                            if(iic_scl_cnt == `IIC_SCL_CENTER)
                                                rd_data_r[2] <= iic_sda;
                                            else
                                                rd_data_r    <= rd_data_r;
                                        end
                                4'd6:   begin
                                            if(iic_scl_cnt == `IIC_SCL_CENTER)
                                                rd_data_r[1] <= iic_sda;
                                            else
                                                rd_data_r    <= rd_data_r;
                                        end
                                4'd7:   begin
                                            if(iic_scl_cnt == `IIC_SCL_CENTER)
                                                rd_data_r[0] <= iic_sda;
                                            else
                                                rd_data_r    <= rd_data_r;
                                        end
                                default:rd_data_r <= rd_data_r;
                            endcase
                        end
            default:    rd_data_r <= rd_data_r;
        endcase 
    end
end
/*------------------------------------------
--output write done
-- 输出写完成信号
-- Description: Generates a pulse on `wr_done` when a write transaction is successfully completed.
-- 描述: 当写事务成功完成时，在 `wr_done` 上生成一个脉冲。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        wr_done <= 1'b0;
    else begin
        case(current_state)
            IIC_STOP:   begin
                            if((iic_scl_cnt == `IIC_SCL_PERIOD) && (rd_state_flag == 1'b0))
                                wr_done <= 1'b1;
                            else
                                wr_done <= 1'b0;
                        end
            default:    wr_done <= 1'b0;
        endcase
    end
end
/*------------------------------------------
--output read data
-- 输出读数据
-- Description: Outputs the latched read data (`rd_data_r`) to the user interface.
-- 描述: 将锁存的读取数据 (`rd_data_r`) 输出到用户接口。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rd_data <= 8'd0;
    else begin
        case(current_state)
            IIC_RDDATA: begin
                            if((iic_bit_cnt == 4'd7) && (iic_scl_cnt == `IIC_SCL_PERIOD))
                                rd_data <= rd_data_r;
                            else
                                rd_data <= rd_data;
                        end
            default:    rd_data <= rd_data;
        endcase
    end
end
/*------------------------------------------
--output read done
-- 输出读完成信号
-- Description: Generates a pulse on `rd_done` when a read transaction is successfully completed.
-- 描述: 当读事务成功完成时，在 `rd_done` 上生成一个脉冲。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rd_done <= 1'b0;
    else begin
        case(current_state)
            IIC_STOP:   begin
                            if((iic_scl_cnt == `IIC_SCL_PERIOD) && (rd_state_flag) && (rd_start_cnt == 2'd2))
                                rd_done <= 1'b1;
                            else
                                rd_done <= 1'b0;
                        end
            default:    rd_done <= 1'b0;
        endcase
    end
end

// Tristate buffer for iic_sda
// iic_sda 的三态缓冲器
// If iic_sda_dir is 1 (output), drive iic_sda with iic_sda_r.
// If iic_sda_dir is 0 (input), iic_sda is high impedance (Z).
// 如果 iic_sda_dir 是 1 (输出), 用 iic_sda_r 驱动 iic_sda。
// 如果 iic_sda_dir 是 0 (输入), iic_sda 是高阻态 (Z)。
assign  iic_sda = iic_sda_dir ? (iic_sda_r ? 1'bz : 1'b0) : 1'bz;

endmodule
