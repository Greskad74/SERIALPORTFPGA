`timescale 1ns / 1ps

module padovan (
    input  logic        clk,
    input  logic        clr,
    input  logic        start,
    input  logic [7:0]  n_in,      
    output logic [31:0] p_out,     // Resultado P(n)
    output logic        ready      // '1' cuando el resultado esta listo
);

    typedef enum logic [1:0] {
        IDLE,
        INIT, 
        CALC, 
        DONE
    } state_t;
    
    state_t state_reg, state_next;

    logic [31:0] p_n_1, p_n_2, p_n_3; 
    logic [7:0]  n_count;
    logic [31:0] p_out_reg;
    logic        ready_reg;

    logic [31:0] p_new;  // en vez de automatic dentro de CALC

    // FSM (Registros de estado) - reset SINCRÓNICO
    always_ff @(posedge clk) begin
        if (clr) 
            state_reg <= IDLE;
        else     
            state_reg <= state_next;
    end

    // Datapath (Registros)
    always_ff @(posedge clk) begin
        if (clr) begin
            p_n_1     <= '0;
            p_n_2     <= '0;
            p_n_3     <= '0;
            n_count   <= '0;
            p_out_reg <= '0;
            ready_reg <= 1'b0;
        end else begin
            
            ready_reg <= 1'b0; // Valor por defecto

            case (state_reg)
                IDLE: begin
                    if (start) begin
                        n_count <= n_in; // Carga n
                    end
                end

                INIT: begin
                    // Casos base P(0)=P(1)=P(2)=1
                    if (n_count == 0 || n_count == 1 || n_count == 2)     
                        p_out_reg <= 32'd1;
                    else begin
                        // Carga los registros para calcular P(3)
                        p_n_1   <= 32'd1; // P(2)
                        p_n_2   <= 32'd1; // P(1)
                        p_n_3   <= 32'd1; // P(0)
                        n_count <= n_count - 8'd2; // Iteraremos n-2 veces
                    end
                end

                CALC: begin
                    // P(n) = P(n-2) + P(n-3)
                    p_new   = p_n_2 + p_n_3;
                    p_n_3   <= p_n_2;
                    p_n_2   <= p_n_1;
                    p_n_1   <= p_new; 
                    n_count <= n_count - 8'd1;
                    if (n_count == 8'd1) begin
                        p_out_reg <= p_new;
                    end
                end
                
                DONE: begin
                    ready_reg <= 1'b1;
                end
            endcase
        end
    end
    
    // FSM (Lógica de siguiente estado)
    always_comb begin
        state_next = state_reg;
        case (state_reg)
            IDLE: if (start)        state_next = INIT;
            INIT: if (n_count <= 2) state_next = DONE;
                  else              state_next = CALC;
            CALC: if (n_count > 1)  state_next = CALC;
                  else              state_next = DONE;
            DONE:                   state_next = IDLE;
        endcase
    end
    
    assign p_out = p_out_reg;
    assign ready = ready_reg;

endmodule
