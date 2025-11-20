`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/22 15:13:09
// Design Name: 
// Module Name: sync_release
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


module sync_release(
    // System Clock and Reset
    // 系统时钟和复位
    input               clk,        // Target clock domain for synchronization / 目标同步时钟域
    input               rst_n,      // Asynchronous active-low reset input / 异步低电平有效复位输入

    // User Interface
    // 用户接口
    output  reg         sys_rst_n   // Synchronized active-low reset output / 同步后的低电平有效复位输出
    );
/*-----------------------------------------
--async reset flip1
-- 异步复位同步器第一级
-- Description: The first flip-flop in the synchronizer chain. It is asynchronously reset by rst_n.
--              Its purpose is to capture the asynchronous reset and begin the synchronization process.
--              The output (sync_rst_n) might be metastable for a short period when rst_n is de-asserted.
-- 描述: 同步器链中的第一个触发器。它被 rst_n 异步复位。
--       其目的是捕获异步复位信号并开始同步过程。
--       当 rst_n 被撤销时，其输出 (sync_rst_n) 可能会在短时间内处于亚稳态。
-----------------------------------------*/
reg         sync_rst_n;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_rst_n <= 1'b0;
    else
        sync_rst_n <= 1'b1;
end
/*-----------------------------------------
--async reset flip2
-- 异步复位同步器第二级
-- Description: The second flip-flop in the chain. It samples the output of the first flip-flop.
--              This stage resolves any potential metastability from the first stage, providing a clean,
--              stable, and synchronous reset signal (sys_rst_n) to the rest of the system.
-- 描述: 同步器链中的第二个触发器。它对第一个触发器的输出进行采样。
--       这一级解决了第一级可能存在的任何亚稳态问题，从而为系统的其余部分提供一个
--       干净、稳定且同步的复位信号 (sys_rst_n)。
-----------------------------------------*/
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sys_rst_n <= 1'b0;
    else
        sys_rst_n <= sync_rst_n;
end

endmodule
