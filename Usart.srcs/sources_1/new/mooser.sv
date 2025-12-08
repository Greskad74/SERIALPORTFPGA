`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.11.2025 16:52:14
// Design Name: 
// Module Name: moser
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


/*
 * FSMD para calcular la secuencia Moser-de Bruijn
 * S(n) se obtiene tratando n binario como base 4.
 * S(5) = 101_2 -> 101_4 = 1*4^2 + 0*4^1 + 1*4^0 = 17
 * Implementacion iterativa (1 bit de 'n' por ciclo)
 */
module moser (
    input  logic clk,
    input  logic clr,
    input  logic start,
    input  logic [7:0] n_in,      // Valor de n (limitado a 8 bits)
    output logic [31:0] s_out,     // Resultado S(n)
    output logic ready      // '1' cuando el resultado esta listo
);

    typedef enum logic [1:0] {
        IDLE, 
        INIT, 
        CALC, 
        DONE
    } state_t;
    
    state_t state_reg, state_next;

    logic [7:0]  n_reg;
    logic [3:0]  i_count; // 0 a 7 (para 8 bits)
    logic [31:0] result_reg;
    logic ready_reg;
    
    logic [31:0] term; // Termino (n[i] * (4^i))
    logic [31:0] power_of_4; // (4^i)

    // FSM (Registros de estado)
    always_ff @(posedge clk) begin
        if (clr) 
        state_reg <= IDLE;
        else     
        state_reg <= state_next;
    end

    // Datapath (Registros)
    always_ff @(posedge clk) begin
        if (clr) begin
            n_reg      <= '0;
            i_count    <= '0;
            result_reg <= '0;
            ready_reg  <= 1'b0;
        end else begin
            
            ready_reg <= 1'b0;

            case (state_reg)
                IDLE: begin
                    if (start) begin
                        n_reg <= n_in;
                    end
                end
                
                INIT: begin
                    result_reg <= '0;
                    i_count    <= '0;
                end

                CALC: begin
                    result_reg <= result_reg + term; // Suma el termino
                    i_count    <= i_count + 1;
                end
                
                DONE: begin
                    ready_reg <= 1'b1;
                end
            endcase
        end
    end
    
    // Datapath (Logica combinacional)
    assign power_of_4 = 1 << (2 * i_count); // 4^i = 1 << (2*i)
    assign term = (n_reg[i_count]) ? power_of_4 : 32'b0;

    // FSM (Logica de siguiente estado)
    always_comb begin
        state_next = state_reg;
        
        case (state_reg)
            IDLE: begin
                if (start) state_next = INIT;
            end
            INIT: begin
                state_next = CALC;
            end
            CALC: begin
                if (i_count < 7) 
                state_next = CALC; // 8 bits (0 a 7)
                else             
                state_next = DONE;
            end
            DONE: begin
                state_next = IDLE;
            end
        endcase
    end
    
    assign s_out = result_reg;
    assign ready = ready_reg;

endmodule
