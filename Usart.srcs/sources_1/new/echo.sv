`timescale 1ns / 1ps

module echo #(
    parameter integer CLOCK_FREQ = 100_000_000,
    parameter integer BAUD_RATE  = 115200
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        RxD,        // entrada serial desde PC
    output logic        TxD,        // salida serial hacia PC
    output logic [7:0]  led         // muestra el último dato recibido
);

    
    logic [7:0] received_data;
    logic       rx_valid;
    logic       rx_error;

    logic [7:0] tx_data;
    logic       tx_ready;
    logic       tx_free;   // transmisor libre (tdre)

    Rx #(
        .clk_freq(CLOCK_FREQ),
        .baud_rate(BAUD_RATE)
    ) uart_rx (
        .clk_fpga(clk),
        .reset(reset),
        .RxD(RxD),
        .RxData(received_data),
        .data_valid(rx_valid)
       
    );

    Tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx (
        .clk(clk),
        .reset(reset),
        .ready(tx_ready),
        .tx_data(tx_data),
        .TxD(TxD),
        .tdre(tx_free)
    );

    
    typedef enum logic [1:0] {
        IDLE,
        SEND_ECHO,
        WAIT_TX
    } state_t;

    state_t state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            tx_data   <= 8'd0;
            tx_ready  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx_ready <= 1'b0;
                    if (rx_valid && tx_free) begin
                        tx_data  <= received_data;
                        tx_ready <= 1'b1;   // mantener en 1 hasta que Tx arranque
                        state    <= SEND_ECHO;
                    end
                end

                SEND_ECHO: begin
                    // esperar a que Tx baje tdre (dato aceptado)
                    if (!tx_free) begin
                        tx_ready <= 1'b0;   // ahora sí bajar
                        state    <= WAIT_TX;
                    end
                end

                WAIT_TX: begin
                    // esperar a que Tx termine (tdre vuelve a 1)
                    if (tx_free) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    
    assign led = received_data;

endmodule
