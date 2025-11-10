module Tx #(
    parameter integer CLOCK_FREQ = 100_000_000,
    parameter integer BAUD_RATE  = 115200
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        ready,      // debe mantenerse activa hasta que tdre=0
    input  logic [7:0]  tx_data,
    output logic        TxD,
    output logic        tdre        // 1 = listo para nuevo dato
);

    localparam real REAL_CYCLES_PER_BIT = real'(CLOCK_FREQ) / real'(BAUD_RATE);
    localparam integer CYCLES_PER_BIT = int'(REAL_CYCLES_PER_BIT + 0.5);
    localparam integer BAUD_MAX = (CYCLES_PER_BIT == 0) ? 0 : (CYCLES_PER_BIT - 1);
    localparam integer BAUD_CNT_WIDTH = $clog2(BAUD_MAX + 1);

    typedef enum logic [1:0] {
        S_MARK,
        S_START,
        S_DATA,
        S_STOP
    } state_t;

    state_t state, next_state;

    logic [7:0] txbuff;
    logic [2:0] bit_count;
    logic [BAUD_CNT_WIDTH-1:0] baud_count;
    logic ready_synced;

    // Sincronización de la señal ready
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            ready_synced <= 0;
        end else begin
            ready_synced <= ready;
        end
    end

    // FSM register
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= S_MARK;
        else
            state <= next_state;
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            S_MARK:  if (ready_synced && tdre) next_state = S_START;
            S_START: if (baud_count == BAUD_MAX) next_state = S_DATA;
            S_DATA:  if ((baud_count == BAUD_MAX) && (bit_count == 3'd7)) 
                         next_state = S_STOP;
            S_STOP:  if (baud_count == BAUD_MAX) next_state = S_MARK;
            default: next_state = S_MARK;
        endcase
    end

    // Datapath
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            TxD        <= 1'b1;
            tdre       <= 1'b1;
            baud_count <= '0;
            bit_count  <= '0;
            txbuff     <= '0;
        end else begin
            case (state)
                S_MARK: begin
                    TxD <= 1'b1;
                    baud_count <= '0;
                    bit_count <= '0;
                    
                    if (ready_synced && tdre) begin
                        txbuff <= tx_data;
                        tdre <= 1'b0;
                    end else begin
                        tdre <= 1'b1;
                    end
                end

                S_START: begin
                    TxD <= 1'b0;
                    if (baud_count == BAUD_MAX) begin
                        baud_count <= '0;
                    end else begin
                        baud_count <= baud_count + 1;
                    end
                end

                S_DATA: begin
                    TxD <= txbuff[0];
                    if (baud_count == BAUD_MAX) begin
                        baud_count <= '0;
                        txbuff <= {1'b0, txbuff[7:1]}; // Shift right
                        bit_count <= bit_count + 1;
                    end else begin
                        baud_count <= baud_count + 1;
                    end
                end

                S_STOP: begin
                    TxD <= 1'b1;
                    if (baud_count == BAUD_MAX) begin
                        baud_count <= '0;
                    end else begin
                        baud_count <= baud_count + 1;
                    end
                end

                default: begin
                    TxD <= 1'b1;
                    tdre <= 1'b1;
                    baud_count <= '0;
                    bit_count <= '0;
                end
            endcase
        end
    end

endmodule