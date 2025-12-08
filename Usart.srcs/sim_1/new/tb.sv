`timescale 1ns/1ps

module tb_uart_padovan;

    // Señales del DUT
    logic clk;
    logic reset;
    logic RxD;
    wire  TxD;
    wire [7:0] led;

    // Instancia del DUT
    uart_padovan #(
        .CLOCK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) dut (
        .clk(clk),
        .reset(reset),
        .RxD(RxD),
        .TxD(TxD),
        .led(led)
    );

    // Reloj 100 MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Tiempo de bit UART para 115200 baudios (aprox en ns)
    localparam integer BIT_TIME = 8680;

    // Tarea para enviar un byte por RxD (LSB first)
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            // start bit
            RxD <= 0;
            #(BIT_TIME);
            // data bits
            for (i = 0; i < 8; i = i + 1) begin
                RxD <= data[i];
                #(BIT_TIME);
            end
            // stop bit
            RxD <= 1;
            #(BIT_TIME);
            // pequeño gap
            #(BIT_TIME/2);
        end
    endtask

    // Sniffer / decodificador de TxD
    string uart_output;
    logic [7:0] rx_byte;

    initial begin
        uart_output = "";
        rx_byte = 8'h00;
        forever begin
            // esperar start bit (TxD baja)
            @(negedge TxD);
            #(BIT_TIME/2); // muestreo en el centro del bit

            // capturar 8 bits
            for (int i = 0; i < 8; i = i + 1) begin
                #(BIT_TIME);
                rx_byte[i] = TxD;
            end

            // esperar stop bit
            #(BIT_TIME);

            // acumular y mostrar
            uart_output = {uart_output, rx_byte};
            $display("t=%0t | TXD_BYTE = 0x%02h (%c)", $time, rx_byte, rx_byte);
        end
    end

    // Monitor interno para padovan_n, go y done
    initial begin
        forever @(posedge clk) begin
            // imprimir cuando se genera el pulso go (observando la señal en el DUT)
            if (dut.padovan_go) $display("t=%0t | padovan_go asserted, padovan_n=%0d", $time, dut.padovan_n);
            if (dut.padovan_done) $display("t=%0t | padovan_done, result=%0d", $time, dut.padovan_result);
        end
    end

    // Estímulos principales
    initial begin
        // init
        RxD = 1;
        reset = 1;
        #100;
        reset = 0;

        // esperar que el DUT se estabilice
        #100000;

        // activar modo Padovan
        send_uart_byte("1");

        // enviar números: 3,4,5 y CR
        send_uart_byte("3");
        send_uart_byte("4");
        send_uart_byte("5");
        send_uart_byte(8'h0D); // CR

        // esperar suficiente tiempo para procesar y transmitir
        #2000000;

        // imprimir buffer completo
        $display("\n=== UART OUTPUT COMPLETO ===\n%s\n", uart_output);

        $finish;
    end

endmodule