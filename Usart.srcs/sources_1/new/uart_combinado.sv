`timescale 1ns / 1ps

module uart_padovan #(
    parameter integer CLOCK_FREQ = 100_000_000,
    parameter integer BAUD_RATE  = 115200
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        RxD,
    output logic        TxD,
    output logic [7:0]  led
);

    // Señales UART
    logic [7:0] received_data;
    logic       rx_valid;
    logic       tx_ready;
    logic       tx_free;
    logic [7:0] tx_data;

    // Instancias UART
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

    // Memoria para almacenar números ingresados
    logic [7:0] number_memory [0:63];
    logic [5:0] mem_write_ptr;
    logic [5:0] mem_read_ptr;
    logic mem_write_en;
    logic [3:0] current_n_value;

    // Mensaje de Padovan
    logic [7:0] padovan_msg [0:35];
    
    initial begin
        // "Ingrese N numeros para Padovan: "
        padovan_msg[0] = "I";  padovan_msg[1] = "n";  padovan_msg[2] = "g";  padovan_msg[3] = "r";
        padovan_msg[4] = "e";  padovan_msg[5] = "s";  padovan_msg[6] = "e";  padovan_msg[7] = " ";
        padovan_msg[8] = "N";  padovan_msg[9] = " ";  padovan_msg[10] = "n"; padovan_msg[11] = "u";
        padovan_msg[12] = "m"; padovan_msg[13] = "e"; padovan_msg[14] = "r"; padovan_msg[15] = "o";
        padovan_msg[16] = "s"; padovan_msg[17] = " "; padovan_msg[18] = "p"; padovan_msg[19] = "a";
        padovan_msg[20] = "r"; padovan_msg[21] = "a"; padovan_msg[22] = " "; padovan_msg[23] = "P";
        padovan_msg[24] = "a"; padovan_msg[25] = "d"; padovan_msg[26] = "o"; padovan_msg[27] = "v";
        padovan_msg[28] = "a"; padovan_msg[29] = "n"; padovan_msg[30] = ":"; padovan_msg[31] = " ";
        padovan_msg[32] = 8'h0D; // CR
        padovan_msg[33] = 8'h0A; // LF
        padovan_msg[34] = 8'h00; // NULL
        padovan_msg[35] = 8'h00; // NULL
    end

    // Instancia del módulo Padovan
    logic [7:0] padovan_result;
    logic padovan_go;
    logic padovan_busy;
    
    mqe padovan_calc (
        .n(current_n_value),
        .clk(clk),
        .reset(reset),
        .go(padovan_go),
        .sal(padovan_result)
    );

    // Estados del sistema
    typedef enum logic [3:0] {
        IDLE,
        SEND_MSG_INIT,
        SEND_MSG_CHAR,
        WAIT_MSG_TX,
        WAIT_NUMBERS,
        STORE_NUMBER,
        SEND_ECHO,
        WAIT_ECHO_TX,
        PROCESS_NUMBERS_INIT,
        CALC_PADOVAN,
        WAIT_PADOVAN,
        SEND_RESULT_INIT,
        SEND_RESULT_CHAR,
        WAIT_RESULT_TX
    } state_t;

    state_t state;

    // Registros de control
    logic [5:0] msg_char_idx;
    logic [7:0] echo_data;
    logic padovan_mode;
    logic [7:0] current_number;
    logic [5:0] process_ptr;
    logic [3:0] result_digits [0:2]; // Para almacenar dígitos del resultado
    logic [1:0] result_digit_idx;
    logic [7:0] result_chars [0:2];  // Caracteres ASCII del resultado

    // Conversión de número a caracteres ASCII
    always_comb begin
        for (int i = 0; i < 3; i++) begin
            result_chars[i] = result_digits[i] + 8'h30; // Convertir a ASCII
        end
    end

    // Escritura en memoria
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        msg_char_idx <= 0;
        mem_write_ptr <= 0;
        mem_read_ptr <= 0;
        tx_ready <= 0;
        tx_data <= 0;
        padovan_mode <= 0;
        current_number <= 0;
        mem_write_en <= 0;
        echo_data <= 0;
        padovan_go <= 0;
        process_ptr <= 0;
        result_digit_idx <= 0;
    end else begin
        tx_ready <= 0;
        mem_write_en <= 0;
        padovan_go <= 0;
        
        case (state)
            IDLE: begin
                if (rx_valid && received_data == 8'h31) begin // '1'
                    padovan_mode <= 1;
                    mem_write_ptr <= 0; // Reset memoria
                    state <= SEND_MSG_INIT;
                end else if (rx_valid && tx_free) begin
                    // Modo eco normal
                    echo_data <= received_data;
                    tx_data <= received_data;
                    tx_ready <= 1;
                    state <= SEND_ECHO;
                end
            end
            
            SEND_MSG_INIT: begin
                if (msg_char_idx < 36 && padovan_msg[msg_char_idx] != 8'h00) begin
                    state <= SEND_MSG_CHAR;
                end else begin
                    // Mensaje completo, esperar números
                    msg_char_idx <= 0;
                    state <= WAIT_NUMBERS;
                end
            end
            
            SEND_MSG_CHAR: begin
                if (tx_free) begin
                    tx_data <= padovan_msg[msg_char_idx];
                    tx_ready <= 1;
                    state <= WAIT_MSG_TX;
                end
            end
            
            WAIT_MSG_TX: begin
                tx_ready <= 0;
                if (tx_free) begin
                    msg_char_idx <= msg_char_idx + 1;
                    state <= SEND_MSG_INIT;
                end
            end
            
            WAIT_NUMBERS: begin
                if (rx_valid) begin
                    if (received_data == 8'h0D) begin // Enter
                        // Fin de entrada, procesar números
                        state <= PROCESS_NUMBERS_INIT;
                    end else if (received_data >= 8'h30 && received_data <= 8'h39) begin // Dígitos 0-9
                        current_number <= received_data;
                        state <= STORE_NUMBER;
                    end else begin
                        // Eco de otros caracteres
                        echo_data <= received_data;
                        tx_data <= received_data;
                        tx_ready <= 1;
                        state <= SEND_ECHO;
                    end
                end
            end
            
            STORE_NUMBER: begin
                if (mem_write_ptr < 63) begin
                    mem_write_en <= 1;
                    mem_write_ptr <= mem_write_ptr + 1;
                end
                // Eco del número
                echo_data <= current_number;
                tx_data <= current_number;
                tx_ready <= 1;
                state <= SEND_ECHO;
            end
            
            SEND_ECHO: begin
                if (!tx_free) begin
                    tx_ready <= 0;
                    state <= WAIT_ECHO_TX;
                end
            end
            
            WAIT_ECHO_TX: begin
                if (tx_free) begin
                    if (padovan_mode) begin
                        state <= WAIT_NUMBERS;
                    end else begin
                        state <= IDLE;
                    end
                end
            end
            
            PROCESS_NUMBERS_INIT: begin
                process_ptr <= 0;
                if (mem_write_ptr > 0) begin
                    state <= CALC_PADOVAN;
                end else begin
                    // No hay números, regresar a IDLE
                    padovan_mode <= 0;
                    state <= IDLE;
                end
            end
            
            CALC_PADOVAN: begin
                if (process_ptr < mem_write_ptr) begin
                    // Convertir ASCII a valor numérico y calcular Padovan
                    current_n_value <= number_memory[process_ptr] - 8'h30; // ASCII to number
                    padovan_go <= 1;
                    state <= WAIT_PADOVAN;
                end else begin
                    // Todos los números procesados
                    padovan_mode <= 0;
                    state <= IDLE;
                end
            end
            
            WAIT_PADOVAN: begin
                // Esperar a que el cálculo termine (podrías necesitar una señal de done)
                // Por ahora, asumimos que termina en 1 ciclo (ajustar según tu módulo)
                state <= SEND_RESULT_INIT;
                
                // Convertir resultado a dígitos decimales
                result_digits[0] <= padovan_result / 100;              // Centenas
                result_digits[1] <= (padovan_result % 100) / 10;       // Decenas  
                result_digits[2] <= padovan_result % 10;               // Unidades
            end
            
            SEND_RESULT_INIT: begin
                result_digit_idx <= 0;
                state <= SEND_RESULT_CHAR;
            end
            
            SEND_RESULT_CHAR: begin
                if (tx_free) begin
                    // Enviar dígito actual del resultado
                    tx_data <= result_chars[result_digit_idx];
                    tx_ready <= 1;
                    state <= WAIT_RESULT_TX;
                end
            end
            
            WAIT_RESULT_TX: begin
                tx_ready <= 0;
                if (tx_free) begin
                    if (result_digit_idx < 2) begin
                        result_digit_idx <= result_digit_idx + 1;
                        state <= SEND_RESULT_CHAR;
                    end else begin
                        // Enviar espacio entre resultados
                        tx_data <= 8'h20; // Space
                        tx_ready <= 1;
                        process_ptr <= process_ptr + 1;
                        state <= CALC_PADOVAN;
                    end
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end
    assign led = received_data;

endmodule