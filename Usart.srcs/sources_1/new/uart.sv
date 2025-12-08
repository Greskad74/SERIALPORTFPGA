`timescale 1ns / 1ps

module uart  #(
    
) (
    input  logic        clk,
    input  logic        reset,
    input  logic [7:0]  sw,          // switches: sw[7:0]
    input  logic        send_btn,    
    input  logic        uart_rx_pin, // entrada serial desde PC
    output logic        uart_tx_pin, // salida serial hacia PC
    output logic [7:0]  led      // 
);

    logic [7:0] data;
    logic go;
    logic tx_tdre;

    // Detector de flanco para el botón
    edge_detect_moore Me (
        .clk(clk),
        .reset(reset),
        .level(send_btn),
        .tick(go)
    );

    // Transmisor UART
    Tx  uart_tx (
        .clk(clk),
        .reset(reset),   
        .ready(go),
        .tx_data(sw),
        .TxD(uart_tx_pin),
        .tdre(tx_tdre)
    );

    // Receptor UART
   Rx uart_rx (
        .clk_fpga(clk),
        .reset(reset),   
        .RxD(uart_rx_pin),
        .RxData(data)
    );
    assign  led = data ;



endmodule
