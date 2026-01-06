`timescale 1ns / 1ps

module hw1_2cnters(
    input i_clk,
    input i_rst,
    input [7:0] i_upperBound1,
    input [7:0] i_upperBound2,
    output o_state
    );
    
    reg [7:0] cnt1, cnt2;
    reg state;
    
    assign o_state = state; 
        
    //FSM
    always@(negedge i_rst or posedge i_clk)
    begin
        if(i_rst == 0) 
            state <= 0;
        else
         case (state)
            1'b0 : //counter1 is counting
                if (cnt1 >= i_upperBound1)
                    state <= 1;                
            1'b1 ://counter2 is counting
                if (cnt2 >= i_upperBound2)
                    state <= 0;                
            default : state <= 0;
         endcase
    end

    //counter1
    always@(negedge i_rst or posedge i_clk)
    begin
        if(i_rst == 0) 
            cnt1 <= 0;
        else
         case (state)
            1'b0 : //counter1 is counting
                cnt1 <= cnt1 + 1;            
            1'b1 ://counter2 is counting
                cnt1 <= 0;
            default : cnt1 <= 0;  // 修正：應該是cnt1而不是state
         endcase
    end
    
    //counter2
    always@(negedge i_rst or posedge i_clk)
    begin
        if(i_rst == 0) 
            cnt2 <= 0;
        else
         case (state)
            1'b0 : //counter1 is counting
                cnt2 <= 0;           
            1'b1 ://counter2 is counting
                cnt2 <= cnt2 + 1;
            default : cnt2 <= 0;  // 修正：應該是cnt2
         endcase
    end
endmodule