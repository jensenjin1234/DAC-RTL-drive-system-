`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:     ������ͬо���ӿƼ����޹�˾
// Engineer:    ����ʦ
// 
// Create Date: 2023/08/23 14:35:12
// Design Name: 
// Module Name: color_bayer_data
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


module color_bayer_data(
	// Global Clock and Reset Signals
	// 全局时钟和复位信号
	input				clk,            // System clock / 系统时钟
	input				rst_n,          // Asynchronous active-low reset / 异步低电平有效复位

	// DCFIFO Interface
	// DCFIFO 接口
	input				dcfifo_empty,   // Flag from DCFIFO, indicating if it's empty / 来自 DCFIFO 的标志, 表示其是否为空
	output	reg			dcfifo_wrreq,   // Write request signal to DCFIFO / 向 DCFIFO 写入请求信号
	output	reg	[31:0]	dcfifo_data,    // 32-bit data to be written into DCFIFO / 写入 DCFIFO 的32位数据

	// User Interface
	// 用户接口
	input				da_init_done    // Signal indicating that the DA chip initialization is complete / 指示 DA 芯片初始化完成的信号
    );

// State Machine Parameters
// 状态机参数定义
parameter	IDLE		=	4'd1;   // Idle state, waiting for initialization to complete / 空闲状态，等待初始化完成
parameter	COL_PIXEL	=	4'd2;   // State for generating pixel data for each column / 为每列生成像素数据的状态
parameter	ROW_COUNT	=	4'd3;   // State after one row of data is generated / 一行数据生成完毕后的状态
parameter	WAIT_EMPTY	=	4'd4;   // State to wait for DCFIFO to have space before generating the next row / 在生成下一行前，等待 DCFIFO 有空间的状态

/*------------------------------------------
--sync da init done
-- 同步 da_init_done 信号
-- Description: Synchronize the asynchronous da_init_done signal to the module's clock domain
--              to prevent metastability issues.
-- 描述: 将异步的 da_init_done 信号同步到模块的时钟域, 以防止亚稳态问题。
------------------------------------------*/
reg			sync_init_done;

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) 
		sync_init_done <= 1'b0;
	else 
		sync_init_done <= da_init_done;
end

/*------------------------------------------
--sync dcfifo empty
-- 同步 dcfifo_empty 信号
-- Description: Synchronize the asynchronous dcfifo_empty signal to the module's clock domain.
-- 描述: 将异步的 dcfifo_empty 信号同步到模块的时钟域。
------------------------------------------*/
reg			sync_dcfifo_empty;

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) 
		sync_dcfifo_empty <= 1'b0;
	else 
		sync_dcfifo_empty <= dcfifo_empty;
end

/*------------------------------------------
--ths8200 color bayer state machine
-- THS8200 彩条数据生成状态机
-- Description: A state machine to control the flow of color bar data generation.
-- 描述: 一个用于控制彩条数据生成流程的状态机。
------------------------------------------*/
reg	[3:0]	current_state , next_state; // State machine registers / 状态机寄存器
reg	[11:0]	col_cnt;                    // Column counter for pixels / 像素的列计数器

// State Register
// 状态寄存器
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		current_state <= IDLE;
	else
		current_state <= next_state;
end

// Combinational logic for next state transition
// 下一状态转移的组合逻辑
always@(*) begin
	case(current_state)
		IDLE:		begin
						if(sync_init_done)
							next_state = COL_PIXEL; // If initialization is done, start generating pixels / 如果初始化完成, 开始生成像素
						else 
							next_state = IDLE;      // Otherwise, remain in IDLE state / 否则, 保持在 IDLE 状态
					end
		COL_PIXEL:	begin
						if(col_cnt == 12'd639)
							next_state = ROW_COUNT; // Reached the end of a row (640 pixels) / 到达一行 (640个像素) 的末尾
						else
							next_state = COL_PIXEL; // Continue generating pixels for the current row / 继续为当前行生成像素
					end
		ROW_COUNT:	begin
						next_state = WAIT_EMPTY;    // After a row is done, wait for FIFO to be ready / 一行结束后, 等待 FIFO 准备就绪
					end
		WAIT_EMPTY:	begin
						if(sync_dcfifo_empty)
							next_state = COL_PIXEL; // If FIFO is not full (empty is high), start the next row / 如果 FIFO 未满 (empty 为高), 开始下一行
						else
							next_state = WAIT_EMPTY; // Otherwise, keep waiting / 否则, 继续等待
					end
		default:	next_state = IDLE;
	endcase
end

/*------------------------------------------
--col count
-- 列计数器
-- Description: Counts from 0 to 639 for each row.
-- 描述: 每一行从 0 计数到 639。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		col_cnt <= 12'd0;
	else begin
		case(current_state)
			COL_PIXEL:	col_cnt <= col_cnt + 1'b1; // Increment column counter in COL_PIXEL state / 在 COL_PIXEL 状态下, 列计数器加一
			default:	col_cnt <= 12'd0;           // Reset column counter in other states / 在其他状态下, 复位列计数器
		endcase
	end
end

/*------------------------------------------
--output dcfifo data
-- 输出 dcfifo 数据
-- Description: Generates the 32-bit pixel data for the color bar based on the column counter.
--              Each color is displayed for 80 pixels.
-- 描述: 根据列计数器的值生成彩条的32位像素数据。
--       每种颜色显示80个像素。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		dcfifo_data <= 32'd0;
	else begin
		case(current_state)
			COL_PIXEL:	begin
							case(col_cnt)
								// 0-79: Yellow / 黄色
								12'd0:	dcfifo_data <= 32'hA22CA28E;	//yellow
								12'd79:	dcfifo_data <= 32'hA22CA28E;	
								// 80-159: Cyan / 青色
								12'd80: dcfifo_data <= 32'h839C832C;	//cyan
								12'd159:dcfifo_data <= 32'h839C832C;
								// 160-239: Green / 绿色
								12'd160:dcfifo_data <= 32'h7048703A;	//green
								12'd239:dcfifo_data <= 32'h7048703A;
								// 240-319: Magenta / 品红色
								12'd240:dcfifo_data <= 32'h54B854C6;	//magenta
								12'd319:dcfifo_data <= 32'h54B854C6;
								// 320-399: Red / 红色
								12'd320:dcfifo_data <= 32'h416441D4;	//red
								12'd399:dcfifo_data <= 32'h416441D4;
								// 400-479: Blue / 蓝色
								12'd400:dcfifo_data <= 32'h23D42372;	//blue
								12'd479:dcfifo_data <= 32'h23D42372;
								// 480-559: Black / 黑色
								12'd480:dcfifo_data <= 32'h10801080;	//black
								12'd559:dcfifo_data <= 32'h10801080;	
								// 560-639: White / 白色
								12'd560:dcfifo_data <= 32'hB480B480;	//white
								12'd639:dcfifo_data <= 32'hB480B480;
								// For pixels between the start and end of a color block, hold the data value
								// 对于颜色块开始和结束之间的像素，保持数据值不变
								default:dcfifo_data <= dcfifo_data;
							endcase
						end
			default:	dcfifo_data <= 32'd0;
		endcase
	end
end

/*------------------------------------------
--output dcfifo wrreq
-- 输出 dcfifo 写请求
-- Description: Asserts the write request signal when the state machine is in the COL_PIXEL state.
-- 描述: 当状态机处于 COL_PIXEL 状态时, 拉高写请求信号。
------------------------------------------*/
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		dcfifo_wrreq <= 1'b0;
	else begin
		case(current_state)
			COL_PIXEL:	dcfifo_wrreq <= 1'b1; // Assert write request when generating pixel data / 生成像素数据时，发出写请求
			default:	dcfifo_wrreq <= 1'b0; // De-assert otherwise / 否则，取消写请求
		endcase
	end
end

endmodule
