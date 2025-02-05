`timescale 1ns / 1ps

module Pixel_Driver (input CLK,               // 100MHz
                     input RST,               // middle button
                     input btnU,              // UP button
                     input btnL,              // LEFT button
                     input btnR,              // RIGHT button
                     input btnD,              // DOWN button
                     input in_display,        // from VGA Driver
                     input [9:0] x,           // from VGA Driver
                     input [9:0] y,           // from VGA Driver
                     output reg [11:0] RGB);  // to DAC
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // PARAMETERS
    //
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    // frequency
    localparam FREQUENCY = 100000000;
    
    // max coordinates for display
    localparam H_MAX = 639;                  // right border of display area
    localparam V_MAX = 479;                  // bottom border of display area
    
    // width and heigh of a grid cell
    localparam SIZE = 16;
    
    // maximum length of the snake in cells
    localparam LENGTH = 100;
    
    // start coordinates for the snake
    localparam START_H = SIZE * 20;
    localparam START_V = SIZE * 15;
    
    // color of objects
    localparam background_RGB = 12'b1010_1111_1000;  // light green
    localparam snake_RGB = 12'b0000_0111_0000;       // dark green
    localparam apple_RGB = 12'b0000_0000_1111;       // red
    localparam gameover_RGB = 12'b0000_0000_0011;    // dark red 
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // BUTTON REGISTERS
    //
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    reg RST_delay1, RST_delay2, RST_reg;
    reg btnU_delay1, btnU_delay2, btnU_reg;
    reg btnL_delay1, btnL_delay2, btnL_reg;
    reg btnR_delay1, btnR_delay2, btnR_reg;
    reg btnD_delay1, btnD_delay2, btnD_reg;
    
    // delay for button registers
    always @(posedge CLK) begin
        RST_delay1 <= RST;
        RST_delay2 <= RST_delay1;
        RST_reg <= RST_delay2;
        
        btnU_delay1 <= btnU;
        btnU_delay2 <= btnU_delay1;
        btnU_reg <= btnU_delay2;
        
        btnL_delay1 <= btnL;
        btnL_delay2 <= btnL_delay1;
        btnL_reg <= btnL_delay2;
        
        btnR_delay1 <= btnR;
        btnR_delay2 <= btnR_delay1;
        btnR_reg <= btnR_delay2;
        
        btnD_delay1 <= btnD;
        btnD_delay2 <= btnD_delay1;
        btnD_reg <= btnD_delay2;
    end
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // VARIABLES
    //
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    // frame counter for slowing snake movement
    // 2^27 = 134,217,728
    // well over 100,000,000 in case we wish to move the snake once per second (paramaterized)
    reg [26:0] frame_counter;
    reg frame_flag;
    
    // create a 60Hz refresh tick at the start of each frame 
    reg frame_refresh;
    always @(posedge CLK) begin
        if(((y == 481) && (x == 0)) == 1'b1) frame_refresh <= 1'b1;
        else frame_refresh <= 1'b0;
    end
    
    // gameplay states
    reg [1:0] state;
    localparam IDLE = 2'b00,
               ACTIVE = 2'b01,
               GAME_OVER = 2'b10;
    
    // direction states
    reg [1:0] direction;
    localparam UP = 2'b00,
               LEFT = 2'b01,
               RIGHT = 2'b10,
               DOWN = 2'b11;
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    // head position
    reg [9:0] head_h_pos;
    reg [9:0] head_v_pos;
    // body positions
    reg [9:0] body_h_pos [0 : LENGTH - 1];
    reg [9:0] body_v_pos [0 : LENGTH - 1];
    
    // enabled when drawing snake head
    reg drawHead;
    // enabled when drawing snake body, one bit per segment
    reg [0 : LENGTH - 1] drawBody;
    
    // current snake length
    reg [10:0] current_length;
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    // apple position
    reg [9:0] apple_h_pos;
    reg [9:0] apple_v_pos;
    
    // enabled when drawing apple
    reg drawApple;
    
    // counters to "randomize" apple location
    reg [5:0] apple_h_counter;
    reg [5:0] apple_v_counter;
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    reg drawGameOver;
    
    ////////////////////////////////////////////////////////////////////////////////////////////    
    
    // for loops
    integer i, j, k, l, m, n, o, p;
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // GENERAL MECHANICS
    //
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    always @(posedge CLK) begin
        // increment frame counter every cycle
        // assert flag high if ready to update frame
        if(frame_counter >= FREQUENCY / 10) begin
            frame_counter <= 0;
            frame_flag <= 1'b1;
        end
        else begin
            frame_counter <= frame_counter + 1;
        end
        
        // button pressed = 0, button released = 1
        // if current button is 0 and old button is 1
        if(!RST_reg && RST_delay2) begin
            state <= IDLE;
            frame_counter <= 0;
            frame_flag <= 1'b0;
            current_length <= 5;
            for(l = 0; l < LENGTH; l = l + 1) begin
                body_h_pos[l] <= START_H;
                body_v_pos[l] <= START_V;
            end
            apple_h_pos <= 31 * SIZE;
            apple_v_pos <= 41 * SIZE;
            apple_h_counter <= 0;
            apple_v_counter <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    // remain in center of the screen
                    head_h_pos <= START_H;
                    head_v_pos <= START_V;
                    current_length <= 5;
                    
                    drawGameOver <= 1'b0;
                    
                    // apple position counters to randomize location
                    if(apple_h_counter == 39) begin
                        apple_h_counter <= 0;
                    end
                    else begin
                        apple_h_counter <= (apple_h_counter + 1);
                    end
                    
                    if(apple_v_counter == 29) begin
                        apple_v_counter <= 0;
                    end
                    else begin
                        apple_v_counter <= (apple_v_counter + 1);
                    end
                    
                    // button pressed = 0, button released = 1
                    // if current button is 0 and old button is 1
                    
                    // check for any direction press
                    if(!btnU_reg && btnU_delay2) begin
                        direction <= UP;
                        head_v_pos <= head_v_pos - SIZE;
                        frame_counter <= 0;
                        apple_h_pos <= apple_h_counter * SIZE;
                        apple_v_pos <= apple_v_counter * SIZE;
                        state <= ACTIVE;
                    end
                    if(!btnL_reg && btnL_delay2) begin
                        direction <= LEFT;
                        head_h_pos <= head_h_pos - SIZE;
                        frame_counter <= 0;
                        apple_h_pos <= apple_h_counter * SIZE;
                        apple_v_pos <= apple_v_counter * SIZE;
                        state <= ACTIVE;
                    end
                    if(!btnR_reg && btnR_delay2) begin
                        direction <= RIGHT;
                        head_h_pos <= head_h_pos + SIZE;
                        frame_counter <= 0;
                        apple_h_pos <= apple_h_counter * SIZE;
                        apple_v_pos <= apple_v_counter * SIZE;
                        state <= ACTIVE;
                    end
                    if(!btnD_reg && btnD_delay2) begin
                        direction <= DOWN;
                        head_v_pos <= head_v_pos + SIZE;
                        frame_counter <= 0;
                        apple_h_pos <= apple_h_counter * SIZE;
                        apple_v_pos <= apple_v_counter * SIZE;
                        state <= ACTIVE;
                    end
                end
                
                ACTIVE: begin
                    // check if frame refreshed and flag enabled
                    if(frame_refresh == 1'b1 && frame_flag == 1'b1) begin
                        frame_flag <= 1'b0; // reset flag for next frame
                        
                        // apple position counters to randomize location
                        if(apple_h_counter == 39) begin
                            apple_h_counter <= 0;
                        end
                        else begin
                            apple_h_counter <= (apple_h_counter + 1);
                        end
                        
                        if(apple_v_counter == 29) begin
                            apple_v_counter <= 0;
                        end
                        else begin
                            apple_v_counter <= (apple_v_counter + 1);
                        end
                        
                        // snake moves based on direction
                        case(direction)
                            UP: head_v_pos <= head_v_pos - SIZE;
                            LEFT: head_h_pos <= head_h_pos - SIZE;
                            RIGHT: head_h_pos <= head_h_pos + SIZE;
                            DOWN: head_v_pos <= head_v_pos + SIZE;
                        endcase
                        
                        // update first body position to previous head position
                        body_h_pos[0] <= head_h_pos;
                        body_v_pos[0] <= head_v_pos;
                        
                        // update all other body positions to previous body position
                        for(i = 1; i < LENGTH; i = i + 1) begin
                            body_h_pos[i] <= body_h_pos[i-1];
                            body_v_pos[i] <= body_v_pos[i-1];
                        end
                    end
                    
                    // check if snake head over apple
                    if(head_h_pos == apple_h_pos && head_v_pos == apple_v_pos) begin
                        // grow snake
                        current_length <= current_length + 1;
                        // randomize apple position
                        apple_h_pos <= apple_h_counter * SIZE;
                        apple_v_pos <= apple_v_counter * SIZE;
                    end
                    
                    // check if snake head hits screen edge
                    if(head_h_pos == 2**10 - SIZE ||
                       head_h_pos == 40 * SIZE || 
                       head_v_pos == 30 * SIZE ||
                       head_v_pos == 2**10 - SIZE) begin
                            state <= GAME_OVER;
                    end
                    
                    // check if snake head hits any body part
                    for(m = 0; m < LENGTH; m = m + 1) begin
                        if(m < current_length && head_h_pos == body_h_pos[m] && head_v_pos == body_v_pos[m]) begin
                            state <= GAME_OVER;
                        end
                    end
                    
                    // check for any direction press
                    // button pressed = 0, button released = 1
                    // if current button is 0 and old button is 1
                    if(!btnU_reg && btnU_delay2 && direction != DOWN) direction <= UP;
                    if(!btnL_reg && btnL_delay2 && direction != RIGHT) direction <= LEFT;
                    if(!btnR_reg && btnR_delay2 && direction != LEFT) direction <= RIGHT;
                    if(!btnD_reg && btnD_delay2 && direction != UP) direction <= DOWN;
                end
                
                GAME_OVER: begin
                    drawGameOver <= 1'b1;
                end
            endcase
        end
    end
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    // DRAWING CONDITIONS
    //
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    // check if current pixel is in snake head bounding box
    always @* begin
        drawHead = (head_h_pos <= x) &&              // x is right of the left edge
                   (x <= head_h_pos + SIZE - 1) &&   // x is left of the right edge
                   (head_v_pos <= y) &&              // y is above the bottom edge
                   (y <= head_v_pos + SIZE - 1);     // y is under the top edge
    end
    
    // check if current pixel is in any body bounding box
    always @* begin
        for(j = 0; j < LENGTH; j = j + 1) begin
            if(j <= current_length - 1) begin
                drawBody[j] = (body_h_pos[j] <= x) &&              // x is right of the left edge
                              (x <= body_h_pos[j] + SIZE - 1) &&   // x is left of the right edge
                              (body_v_pos[j] <= y) &&              // y is above the bottom edge
                              (y <= body_v_pos[j] + SIZE - 1);     // y is under the top edge
            end
            else begin
                drawBody[j] = 1'b0;
            end
        end
    end
    
    // check if current pixel is in apple bounding box
    always @* begin
        drawApple = (apple_h_pos <= x) &&              // x is right of the left edge
                    (x <= apple_h_pos + SIZE - 1) &&   // x is left of the right edge
                    (apple_v_pos <= y) &&              // y is above the bottom edge
                    (y <= apple_v_pos + SIZE - 1);     // y is under the top edge
    end
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    
    // drawing screen
    always @* begin
        if(in_display == 1'b0) begin // if not in display area
            RGB = 12'h000; // draw black (required)
        end
        else begin
            RGB = background_RGB; // set color to background
            
            for(k = 0; k < LENGTH; k = k + 1) begin
                if(drawBody[k] == 1'b1) begin // if drawing body
                    RGB = snake_RGB; // set color to snake
                end
            end
            
            if(drawApple == 1'b1) begin // if drawing apple
                RGB = apple_RGB; // set color to apple
            end
            
            if(drawHead == 1'b1) begin // if drawing head
                RGB = snake_RGB; // set color to snake
            end
            
            if(drawGameOver == 1'b1) begin // if drawing game over
                RGB = gameover_RGB; // set color to game over screen
            end
        end
    end
    
endmodule