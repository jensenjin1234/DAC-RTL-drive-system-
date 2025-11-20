`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:     ������ͬо���ӿƼ����޹�˾
// Engineer:    ����ʦ
// 
// Create Date: 2023/11/21 14:25:19
// Design Name: 
// Module Name: ths8200_init_config
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

// Module: ths8200_init_config
// 模块: ths8200_init_config
// Description: This module acts as a Read-Only Memory (ROM) to store the initialization
//              sequence for the THS8200 video DAC chip. It takes an index as input and
//              outputs the corresponding 16-bit configuration word. Each 16-bit word consists
//              of an 8-bit register address (MSB) and an 8-bit data value (LSB) to be written
//              to that address. This provides a centralized and organized way to manage the
//              large number of settings required to configure the THS8200 for a specific
//              video mode (e.g., 720p).
// 描述: 本模块作为一个只读存储器 (ROM)，用于存储 THS8200 视频 DAC 芯片的初始化序列。
//       它接收一个索引作为输入，并输出对应的16位配置字。每个16位字由一个8位的
//       寄存器地址 (高8位) 和一个8位的数据值 (低8位) 组成，该数据值将被写入对应的地址。
//       这种方式为管理配置 THS8200 特定视频模式（例如720p）所需的大量设置，
//       提供了一种集中且有条理的方法。
module ths8200_init_config(
	// Global Clock and Reset
	// 全局时钟和复位
	input				clk,            // System clock / 系统时钟
	input				rst_n,          // Active-low reset / 低电平有效复位

	// User Interface
	// 用户接口
	input		[7:0]	config_index,   // Input index to select the configuration word / 用于选择配置字的输入索引
	output	reg	[15:0]	config_data     // Output 16-bit configuration word {Address, Data} / 输出的16位配置字 {地址, 数据}
    );
/*------------------------------------------
--sync ths8200 config index
-- 同步 THS8200 配置索引
-- Description: Synchronizes the input index to the local clock domain. This is good practice
--              to ensure proper timing, especially if the index comes from a different
--              or complex logic block.
-- 描述: 将输入索引同步到本地时钟域。这是一种良好的实践，可以确保正确的时序，
--       特别是当索引来自不同或复杂的逻辑块时。
------------------------------------------*/
reg	[7:0]	sync_config_index;

always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		sync_config_index <= 8'd0;
	else
		sync_config_index <= config_index;
end
/*------------------------------------------
--output ths8200 config data
-- 输出 THS8200 配置数据
-- Description: A large combinational block (implemented as a case statement) that maps
--              the synchronized index to a specific 16-bit configuration value. This forms
--              the core of the ROM functionality.
-- 描述: 一个大型组合逻辑块 (用 case 语句实现)，将同步后的索引映射到一个特定的
--       16位配置值。这构成了此ROM功能的核心。
------------------------------------------*/	
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		config_data <= 16'd0;
	else begin
		case(sync_config_index)
            // Each line represents one I2C write operation.
            // Format: {8-bit Register Address, 8-bit Data Value}
            // 每一行代表一个I2C写操作。
            // 格式: {8位寄存器地址, 8位数据值}

			8'd0:	config_data	=	{8'h03, 8'h01};	// chip_ctl - high DLL freq range
			8'd1: 	config_data	= 	{8'h04, 8'h81};	// csc_r11	
			8'd2: 	config_data	= 	{8'h05, 8'hd5};	// csc_r12
			8'd3: 	config_data	= 	{8'h06, 8'h00}; // default 0x00
			8'd4: 	config_data	= 	{8'h07, 8'h00}; // default 0x00
			8'd5:	config_data	=	{8'h08, 8'h06}; // csc_r31
			8'd6:	config_data	=	{8'h09, 8'h29}; // csc_r32
			8'd7:	config_data	=	{8'h0a, 8'h04}; // csc_g11
			8'd8: 	config_data	= 	{8'h0b, 8'h00}; // default 0x00
			8'd9:	config_data	=	{8'h0c, 8'h04};	// csc_g21
			8'd10: 	config_data	= 	{8'h0d, 8'h00}; // default 0x00
			8'd11:	config_data	=	{8'h0e, 8'h04};	// csc_g31
			8'd12: 	config_data	= 	{8'h0f, 8'h00}; // default 0x00
			8'd13:	config_data	=	{8'h10, 8'h80};	// csc_b11
			8'd14:	config_data	=	{8'h11, 8'hbb};	// csc_b12
			8'd15:	config_data	=	{8'h12, 8'h07};	// csc_b21
			8'd16:	config_data	=	{8'h13, 8'h42};	// csc_b22
			8'd17: 	config_data	= 	{8'h14, 8'h00}; // default 0x00
			8'd18: 	config_data	= 	{8'h15, 8'h00};	// default 0x00
			8'd19:	config_data	=	{8'h16, 8'h14};	// csc_offs1
			8'd20:	config_data	=	{8'h17, 8'hae};	// csc_offs12	
			8'd21: 	config_data	= 	{8'h18, 8'h8b};	// csc_offs23
			// CSC setup - map YCbCr to FS RGB
			8'd22: 	config_data	= 	{8'h19, 8'h15}; // csc_offs3 - CSC not bypassed, under-/overflow protection on
			8'd23:	config_data	= 	{8'h1a, 8'h00}; // default 0x00
			8'd24:	config_data	= 	{8'h1b, 8'h00}; // default 0x00
			8'd25: 	config_data	= 	{8'h1c, 8'h5b}; // data_cntl - D1CLKO disabled, FSADJ1, 4:2:2 to 4:4:4 conversion,1x up-sampling, BT.656 output disabled, 20-bit 4:2:2 input format
			// output sync level amplitude control		
			8'd26:	config_data	= 	{8'h1d, 8'h00}; // dtg1_y_sync1_lsb (default)
			8'd27: 	config_data	= 	{8'h1e, 8'h00}; // dtg1_y_sync2_lsb (default)
			8'd28: 	config_data	= 	{8'h1f, 8'h00}; // dtg1_y_sync3_lsb (default)
			8'd29:	config_data	= 	{8'h20, 8'h00}; // default 0x00
			8'd30:	config_data	= 	{8'h21, 8'h00}; // default 0x00
			8'd31:	config_data	= 	{8'h22, 8'h00}; // default 0x00
			8'd32: 	config_data	= 	{8'h23, 8'h2a}; // dtg1_y_sync_msb
			8'd33: 	config_data	= 	{8'h24, 8'h00}; // dtg1_cbcr_sync_msb
			//timing setup
			8'd34:	config_data	=	{8'h25, 8'h28};	// dtg1_spec_a  136
			8'd35: 	config_data	= 	{8'h26, 8'h64};	// dtg1_spec_b  24 - 2
			8'd36: 	config_data	= 	{8'h27, 8'h00}; // dtg1_spec_c
			8'd37: 	config_data	= 	{8'h28, 8'h0E};	// dtg1_spec_d  296
			8'd38:	config_data	= 	{8'h29, 8'h00}; // default 0x00
			8'd39: 	config_data	= 	{8'h2a, 8'h00}; // dtg1_spec_e_lsb
			8'd40: 	config_data	= 	{8'h2b, 8'h80};	// dtg1_spec_h_msb
			8'd41:	config_data	= 	{8'h2c, 8'h00}; // default 0x00
			8'd42:	config_data	= 	{8'h2d, 8'h00}; // default 0x00
			8'd43:	config_data	= 	{8'h2e, 8'h00}; // default 0x00
			8'd44: 	config_data	= 	{8'h2f, 8'h64};	// dtg1_spec_k_lsb  24 - 2
			8'd45: 	config_data	= 	{8'h30, 8'h00};	// dtg1_spec_k_msb
			8'd46:	config_data	= 	{8'h31, 8'h00}; // default 0x00
			8'd47: 	config_data	= 	{8'h32, 8'h00}; // dtg1_speg_g_lsb, needed? ***0x58
			8'd48:	config_data	= 	{8'h33, 8'h00}; // default 0x00
			8'd49: 	config_data	=	{8'h34, 8'h06};	// dtg1_total_pixel_msb  1344 pixels
			8'd50: 	config_data	= 	{8'h35, 8'h72};	// dtg1_total_pixel_lsb
			8'd51: 	config_data	= 	{8'h36, 8'h00}; // dtg1_fieldflip_linecnt_msb (default)
			8'd52: 	config_data	= 	{8'h37, 8'h01};	// dtg1_linecnt_lsb (default)
			8'd53: 	config_data	= 	{8'h38, 8'h89}; // dtg1_mode - Generic SDTV mode
			8'd54: 	config_data	= 	{8'h39, 8'h22};	// dtg1_frame_field_msb   806 lines
			8'd55:	config_data = 	{8'h3a, 8'hEE};	// dtg1_frame_size_lsb
			8'd56:	config_data = 	{8'h3b, 8'hEE};	// dtg1_field_size_lsb
			8'd57:	config_data	= 	{8'h3c, 8'h00}; // default 0x80
			8'd58:	config_data	= 	{8'h3d, 8'h00}; // default 0x00
			8'd59:	config_data	= 	{8'h3e, 8'h00}; // default 0x00
			8'd60:	config_data	= 	{8'h3f, 8'h00}; // default 0x00
			8'd61:	config_data	= 	{8'h40, 8'h00}; // default 0x00
			8'd62:	config_data	= 	{8'h41, 8'h00}; // default 0x40
			8'd63:	config_data	= 	{8'h42, 8'h00}; // default 0x40
			8'd64:	config_data	= 	{8'h43, 8'h00}; // default 0x40
			8'd65:	config_data	= 	{8'h44, 8'h00}; // default 0x53
			8'd66:	config_data	= 	{8'h45, 8'h00}; // default 0x3F
			8'd67:	config_data	= 	{8'h46, 8'h00}; // default 0x3F
			8'd68:	config_data	= 	{8'h47, 8'h00}; // default 0x40
			8'd69:	config_data	= 	{8'h48, 8'h00}; // default 0x40
			8'd70:	config_data	= 	{8'h49, 8'h00}; // default 0x40
			8'd71: 	config_data	= 	{8'h4a, 8'hfc};	// csm_gy_cntl_mult_msb - G/Y multiply, shift, clip enabled
			8'd72: 	config_data	= 	{8'h4b, 8'h44}; // csm_mult_bcb_rcr_msb
			8'd73: 	config_data	= 	{8'h4c, 8'hac}; // csm_mult_gy_lsb
			8'd74: 	config_data	= 	{8'h4d, 8'hac}; // csm_mult_bcb_lsb
			8'd75: 	config_data	= 	{8'h4e, 8'hac}; // csm_mult_rcr_lsb
			8'd76: 	config_data	= 	{8'h4f, 8'hff}; // csm_rcr_bcb_cntl - R/Cr and B/Cb multiply, shift, clip enabled
			//generic mode line type setup. Set dtg_bp2_msb and lsb to 807 (lines per frame + 1)
			8'd77:	config_data	=	{8'h50, 8'h02};	// dtg2_bp1_2_msb
			8'd78:	config_data	=	{8'h51, 8'h00};	// default 0x00
			8'd79:	config_data	=	{8'h52, 8'h00};	// default 0x00
			8'd80:	config_data	=	{8'h53, 8'h00};	// default 0x00
			8'd81:	config_data	=	{8'h54, 8'h00};	// default 0x00
			8'd82:	config_data	=	{8'h55, 8'h00};	// default 0x00
			8'd83:	config_data	=	{8'h56, 8'h00};	// default 0x00
			8'd84:	config_data	=	{8'h57, 8'h00};	// default 0x00
			8'd85:	config_data	=	{8'h58, 8'h00};	// default 0x00
			8'd86: 	config_data	= 	{8'h59, 8'hEF};	// dtg2_bp2_lsb
			8'd87:	config_data	=	{8'h5a, 8'h00};	// default 0x00
			8'd88:	config_data	=	{8'h5b, 8'h00};	// default 0x00
			8'd89:	config_data	=	{8'h5c, 8'h00};	// default 0x00
			8'd90:	config_data	=	{8'h5d, 8'h00};	// default 0x00
			8'd91:	config_data	=	{8'h5e, 8'h00};	// default 0x00
			8'd92:	config_data	=	{8'h5f, 8'h00};	// default 0x00
			8'd93:	config_data	=	{8'h60, 8'h00};	// default 0x00
			8'd94:	config_data	=	{8'h61, 8'h00};	// default 0x00
			8'd95:	config_data	=	{8'h62, 8'h00};	// default 0x00
			8'd96:	config_data	=	{8'h63, 8'h00};	// default 0x00
			8'd97:	config_data	=	{8'h64, 8'h00};	// default 0x00
			8'd98:	config_data	=	{8'h65, 8'h00};	// default 0x00
			8'd99:	config_data	=	{8'h66, 8'h00};	// default 0x00
			8'd100:	config_data	=	{8'h67, 8'h00};	// default 0x00
			8'd101:	config_data	=	{8'h68, 8'h00};	// default 0x00
			8'd102: config_data	= 	{8'h69, 8'h00};	// default 0x00
			8'd103:	config_data	=	{8'h6a, 8'h00};	// default 0x00
			8'd104:	config_data	=	{8'h6b, 8'h00};	// default 0x00
			8'd105:	config_data	=	{8'h6c, 8'h00};	// default 0x00
			8'd106:	config_data	=	{8'h6d, 8'h00};	// default 0x00
			8'd107:	config_data	=	{8'h6e, 8'h00};	// default 0x00
			8'd108:	config_data	=	{8'h6f, 8'h00};	// default 0x00
			//discrete output sync control
			8'd109: config_data	= 	{8'h70, 8'h28};	// dtg2_hlength_lsb  136 pixels
			8'd110: config_data	= 	{8'h71, 8'h00}; // dtg2_hlength_msb_hdly_msb (default)
			8'd111: config_data	= 	{8'h72, 8'h08};	// dtg2_hdly_lsb - 8 pixels
			8'd112: config_data	= 	{8'h73, 8'h06};	// dtg2_vlength_lsb  6 + 1
			8'd113: config_data	= 	{8'h74, 8'h00}; // dtg2_vlength1_msb_vdly1_msb (default)
			8'd114: config_data	= 	{8'h75, 8'h01}; // dtg2_vdly1_lsb - 1 line
			8'd115: config_data	= 	{8'h76, 8'h00}; // dtg2_vlength2_lsb (default) - must be set to 0x00 for progressive modes
			8'd116: config_data	= 	{8'h77, 8'h07}; // dtg2_vlength2_msb_vdly2_msb (default) - must be set to 0x07 for progressive modes
			8'd117: config_data	= 	{8'h78, 8'hff}; // dtg2_vdly2_lsb (default) - must be set to 0xFF for progressive modes
			//discrete input sync control
			8'd118: config_data	= 	{8'h79, 8'h00};	// dtg2_hs_in_dly_msb
			8'd119: config_data	= 	{8'h7a, 8'h8E};	// dtg2_hs_in_dly_lsb  40 + 24 = 64 pixels
			8'd120: config_data	= 	{8'h7b, 8'h00};	// dtg2_vs_in_dly_msb
			8'd121: config_data	= 	{8'h7c, 8'h05};	// dtg2_vs_in_dly_lsb
			8'd122: config_data	= 	{8'h82, 8'h3B};	// dtg2_cntl, YPbPr mode, embedded syncs, -HS -VS
			8'd123:	config_data	=	{8'h83, 8'h00};	// default 0x00
			8'd124:	config_data	=	{8'h84, 8'h00};	// default 0x00
			8'd125:	config_data	=	{8'h85, 8'h00};	// default 0x00
			default:config_data	=	{8'h00, 8'h00}; // Default case, should not be reached in normal operation / 默认情况，正常操作中不应到达
		endcase
	end
end

endmodule
