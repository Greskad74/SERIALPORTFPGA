`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/22/2025 09:56:05 PM
// Design Name: 
// Module Name: divisor_base
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


module divisor(
input  logic clk,        // 100 MHz
    input  logic reset,
    output logic clk_out     // ≈ 190 Hz
);

    logic [18:0] contador;   // 19 bits

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            contador <= 0;
        else
            contador <= contador + 1;
    end

    assign clk_out = contador[18];  // MSB de 19 bits → clk / 2^19

endmodule