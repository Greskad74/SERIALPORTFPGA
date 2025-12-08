`timescale 1ns / 1ps

module Rx(
    input  logic        clk_fpga,   
    input  logic        reset,      
    input  logic        RxD,       
    output logic [7:0]  RxData,
    output logic        data_valid      
);

    parameter int clk_freq    = 100_000_000;
    parameter int baud_rate   = 115200;
    parameter int div_sample  = 4;
    parameter int div_counter = clk_freq / (baud_rate * div_sample);
    parameter int mid_sample  = div_sample / 2;
    parameter int div_bit     = 10; 

    typedef enum logic {IDLE=0, RECEIVING=1} state_t;

    state_t          state, nextstate;
    logic [3:0]      bit_counter;
    logic [1:0]      sample_counter;
    logic [13:0]     baudrate_counter;
    logic [9:0]      rxshift_reg;

    // Control signals
    logic shift;
    logic clear_bitcounter, inc_bitcounter;
    logic clear_samplecounter, inc_samplecounter;

    assign RxData = rxshift_reg[8:1];

    // ✅ SOLO UN always_ff para data_valid
    always_ff @(posedge clk_fpga or posedge reset) begin
        if (reset) begin
            state           <= IDLE;
            bit_counter     <= 0;
            sample_counter  <= 0;
            baudrate_counter<= 0;
            rxshift_reg     <= '1;
            data_valid      <= 1'b0;
        end else begin
            data_valid <= 1'b0; // ✅ Default: data_valid = 0
            
            baudrate_counter <= baudrate_counter + 1;

            if (baudrate_counter >= div_counter - 1) begin
                baudrate_counter <= 0;
                state            <= nextstate;

                if (shift)
                    rxshift_reg <= {RxD, rxshift_reg[9:1]};

                if (clear_samplecounter)
                    sample_counter <= 0;
                else if (inc_samplecounter)
                    sample_counter <= sample_counter + 1;

                if (clear_bitcounter)
                    bit_counter <= 0;
                else if (inc_bitcounter)
                    bit_counter <= bit_counter + 1;
                    
                // ✅ Solo activar data_valid cuando se completa la recepción
                if (state == RECEIVING && bit_counter == div_bit - 1 && sample_counter == div_sample - 1) begin
                    data_valid <= 1'b1;
                end
            end
        end
    end

    // Lógica combinacional
    always_comb begin
        shift               = 0;
        clear_samplecounter = 0;
        inc_samplecounter   = 0;
        clear_bitcounter    = 0;
        inc_bitcounter      = 0;
        nextstate           = state;

        case (state)
            IDLE: begin
                if (~RxD) begin 
                    nextstate           = RECEIVING;
                    clear_bitcounter    = 1;
                    clear_samplecounter = 1;
                end
            end

            RECEIVING: begin
                if (sample_counter == mid_sample - 1)
                    shift = 1;

                if (sample_counter == div_sample - 1) begin
                    if (bit_counter == div_bit - 1)
                        nextstate = IDLE;
                    inc_bitcounter    = 1;
                    clear_samplecounter = 1;
                end else begin
                    inc_samplecounter = 1;
                end
            end

            default: nextstate = IDLE;
        endcase
    end

endmodule