`timescale 1ns / 1ps

module mqe(
    input  logic [3:0] n,
    input  logic clk, reset,go,
    output logic [7:0] sal
);

// FSM states
typedef enum logic [2:0] {s0, s1, s2, s3, s4} state_type;
state_type state_reg, state_next;

    logic [7:0] anteprev, prev, cur, nex;
    logic [3:0] i;
    logic [4:0] count;
always_ff @(posedge clk, posedge reset)
    if(reset)
        state_reg<=s0;
    else begin
        state_reg<=state_next;
        case(state_reg)
            s0:begin
                anteprev<=8'b00000001;
                prev<=8'b00000001;
                cur<=8'b00000001;
                nex<=8'b00000001;
             end
             s1: count<=5'b00011;
             s3: begin
                count<=count+1;
                nex=anteprev+prev;
                anteprev=prev;
                prev=cur;
                cur=nex;
             end
             
        endcase
    end
always_comb
    case(state_reg)
    s0:
        if(go)
            state_next<=s1;
        else
            state_next<=s0;
    s1:
        if(n<=4'h2)
            state_next<=s2;
        else
            state_next<=s3;
    s2: state_next<=s0;
    s3:
        if(count<(n+1))
            state_next<=s3;
        else
            state_next<=s4;
    s4: state_next<=s4;
    default: state_next<=s0;
    endcase
assign sal=prev;
endmodule
