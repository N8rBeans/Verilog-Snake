`timescale 1ns / 1ps

module VGA_Driver (input CLK,          // 100 MHz
                   input RST,          // RST
                   output in_display,  // on when pixel is in display area
                   output hsync,       // horizontal sync
                   output vsync,       // vertical sync
                   output pixel_tick,  // 25MHz pixel/second, pixel tick
                   output [9:0] x,     // pixel x, [0-799]
                   output [9:0] y);    // pixel y, [0-524]
    
    // VGA screen is 640 pixels by 480 pixels at 60 Hz
    // must consider front/back porch and retrace width for horizontal and vertical
    // real output is 800 pixels by 525 pixels
    // 800 * 525 * 60 fps = 25,000,000 pixels/second
    
    // downscale 100 MHz clock to 25 MHz (1/4)
    // 25MHz "clock" used to generate pixel tick and HSync/ VSync outputs
    
    // horizontal pixels separated into sections
    localparam H_Display = 640;  // actual display width
    localparam H_Front = 48;     // front porch width
    localparam H_Sync = 96;      // HSync width
    localparam H_Back = 16;      // back porch width
    localparam H_Total = H_Display + H_Front + H_Sync + H_Back - 1; // total horizontal width = 799
    // vertical pixels separated into sections
    localparam V_Display = 480;  // actual display length
    localparam V_Front = 10;     // front porch length
    localparam V_Sync = 2;       // VSync length 
    localparam V_Back = 33;      // back porch length   
    localparam V_Total = V_Display + V_Front + V_Sync + V_Back - 1; // total vertical length = 524   
    
    // generating the 25 MHz new clock
    // counter only counts from 0-3 then overflows
	reg [1:0] counter_25MHz;
	reg clk_25MHz;
	
	// add once every clock cycle
	// overflows every 4
	always @(posedge CLK or posedge RST)
		if(RST)
		  counter_25MHz <= 0;
		else
		  counter_25MHz <= counter_25MHz + 1;
	
	// checks every time it overflows
	always @* begin
	   if(counter_25MHz == 0) begin
	       clk_25MHz = 1;
	   end
	   else begin
	       clk_25MHz = 0;
	   end
	end
	
    // pixel counter registers, 2^10 = 1024, greater than 799 and 524
    // two each to avoid glitches
    reg [9:0] h_count_reg, v_count_reg;
    reg [9:0] h_count_next, v_count_next;
    
    // outputs
    reg h_sync_reg, v_sync_reg;
    wire h_sync_next, v_sync_next;
    
    // assigning registers
    always @(posedge CLK or posedge RST)
        if(RST == 1'b1) begin
            h_count_reg <= 0;
            v_count_reg <= 0;
            h_sync_reg  <= 1'b0;
            v_sync_reg  <= 1'b0;
        end
        else begin
            h_count_reg <= h_count_next;
            v_count_reg <= v_count_next;
            h_sync_reg  <= h_sync_next;
            v_sync_reg  <= v_sync_next;
        end
         
    // horizontal counter
    always @(posedge clk_25MHz or posedge RST) begin
        if(RST == 1'b1) begin
            h_count_next = 0;
        end
        else begin
            if(h_count_reg == H_Total) begin // end of horizontal width
                h_count_next = 0;
            end
            else begin
                h_count_next = h_count_reg + 1;
            end
        end
    end
    
    // vertical counter
    always @(posedge clk_25MHz or posedge RST) begin
        if(RST == 1'b1) begin
            v_count_next = 0;
        end
        else begin
            if(h_count_reg == H_Total) begin // end of horizontal width
                if((v_count_reg == V_Total)) begin // end of vertical length
                    v_count_next = 0;
                end
                else begin
                    v_count_next = v_count_reg + 1;
                end
            end
        end
    end
        
    // h_sync_next asserted within the horizontal retrace area
    assign h_sync_next = (h_count_reg >= (H_Display + H_Back) && h_count_reg <= (H_Display + H_Back + H_Sync - 1));
    
    // v_sync_next asserted within the vertical retrace area
    assign v_sync_next = (v_count_reg >= (V_Display + V_Back) && v_count_reg <= (V_Display + V_Back + V_Sync - 1));
    
    // only 1 while pixel is in display area
    assign in_display = (h_count_reg < H_Display) && (v_count_reg < V_Display); // 0-639 and 0-479 respectively   
    // sync outputs
    assign hsync = h_sync_reg;
    assign vsync = v_sync_reg;
    // pixel tick overflows every other cycle, so it toggles per pixel
    assign pixel_tick = clk_25MHz;
    // horizontal and vertical count is same as coordinates
    assign x = h_count_reg;
    assign y = v_count_reg;     
endmodule