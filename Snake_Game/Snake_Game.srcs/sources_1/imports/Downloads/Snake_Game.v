`timescale 1ns / 1ps

module Snake_Game (input CLK,              // 100 MHz
                   input RST,              // middle button
                   input btnU,             // UP button
                   input btnL,             // LEFT button
                   input btnR,             // RIGHT button
                   input btnD,             // DOWN button
                   output hsync,           // horizontal sync
                   output vsync,           // vertical sync
                   output [11:0] RGB,      // to DAC
                   output [3:0] seg_addr); // turn off segment display
    
    // set up wires to use between modules
    wire in_display, pixel_tick;
    wire [9:0] x, y;
    // for some reason it doesnt work if you capitalize RGB... cant figure out why after 10 hours
    wire [11:0] rgb_wire;
    reg [11:0] rgb_reg;
    
    // instantiate VGA controller
    VGA_Driver VGA_D (.CLK(CLK),                // input
                      .RST(RST),                // input
                      .in_display(in_display),  // output
                      .hsync(hsync),            // output
                      .vsync(vsync),            // output
                      .pixel_tick(pixel_tick),  // output
                      .x(x),                    // output
                      .y(y));                   // output
    
    // instantiate game mechanics to control pixels
    Pixel_Driver VGA_PD (.CLK(CLK),                // input
                         .RST(RST),                // input
                         .btnU(btnU),              // input
                         .btnL(btnL),              // input
                         .btnR(btnR),              // input
                         .btnD(btnD),              // input
                         .in_display(in_display),  // input
                         .x(x),                    // input
                         .y(y),                    // input
                         .RGB(rgb_wire));          // output
    
    // assigning asynchronous RGB wire output to reg
    always @(posedge CLK) begin
        if(pixel_tick == 1'b1) begin
            rgb_reg <= rgb_wire;
        end
    end
    
    // assign RGB output
    assign RGB = rgb_reg;
    
    // 1 means off, so all displays off
    assign seg_addr = 4'b1111;
endmodule