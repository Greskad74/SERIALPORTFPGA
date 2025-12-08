`timescale 1ns / 1ps

module uart_padovan #(
    parameter integer CLOCK_FREQ = 100_000_000,
    parameter integer BAUD_RATE  = 115200
)(
    input  logic       clk,
    input  logic       clr,    // reset sincrónico
    input  logic       RxD,
    output logic       TxD,
    output logic [7:0] led     // debug: parte baja del resultado
);

    // UART RX
    logic [7:0] rx_data;
    logic       rx_valid;

    Rx #(
        .clk_freq (CLOCK_FREQ),
        .baud_rate(BAUD_RATE)
    ) uart_rx (
        .clk_fpga  (clk),
        .reset     (clr),
        .RxD       (RxD),
        .RxData    (rx_data),
        .data_valid(rx_valid)
    );

    logic [7:0] rx_byte_reg;
    logic       rx_pending;

    // UART TX
    logic [7:0] tx_data;
    logic       tx_ready;
    logic       tx_free;   // tdre

    Tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) uart_tx (
        .clk    (clk),
        .reset  (clr),
        .ready  (tx_ready),
        .tx_data(tx_data),
        .TxD    (TxD),
        .tdre   (tx_free)
    );

    // Instancias: PADOVAN y MOSER
    logic        start_pad;
    logic [7:0]  n_pad;
    logic [31:0] pad_out;
    logic        ready_pad;

    padovan pad_inst (
        .clk   (clk),
        .clr   (clr),
        .start (start_pad),
        .n_in  (n_pad),
        .p_out (pad_out),
        .ready (ready_pad)
    );

    logic        start_mos;
    logic [7:0]  n_mos;
    logic [31:0] mos_out;
    logic        ready_mos;

    moser mos_inst (
        .clk   (clk),
        .clr   (clr),
        .start (start_mos),
        .n_in  (n_mos),
        .s_out (mos_out),
        .ready (ready_mos)
    );

    // ================================
    // Mensajes
    // ================================

    // Menú: "Elige una sucesion, donde 1 es Padovan y 2 es Moser:\r\n"
    logic [7:0] menu_msg [0:63];
    logic [5:0] menu_idx;

    // Prompt Padovan: "Ingrese N numeros para Padovan:\r\n"
    logic [7:0] padovan_msg [0:35];
    logic [5:0] pad_idx;

    // Prompt Moser: "Ingrese N numeros para Moser:\r\n"
    logic [7:0] moser_msg [0:35];
    logic [5:0] mos_idx;

    // FSM principal
    typedef enum logic [3:0] {
        S_SEND_MENU,
        S_WAIT_MENU_TX,
        S_WAIT_SELECTION,
        S_SEND_PROMPT,
        S_WAIT_PROMPT_TX,
        S_WAIT_DIGIT,
        S_START_COMPUTE,
        S_WAIT_RESULT,
        S_PREP_RESULT,
        S_SEND_DIGIT,
        S_WAIT_DIGIT_TX,
        S_SEND_CR,
        S_WAIT_CR_TX,
        S_SEND_LF,
        S_WAIT_LF_TX
    } state_t;

    state_t state;

    // 1 = Padovan, 2 = Moser
    logic [1:0] seq_sel;

    // Resultado en común
    logic [31:0] result_reg;
    logic [7:0]  result_chars [0:3]; // hasta 4 dígitos
    logic [1:0]  result_idx;

    always_ff @(posedge clk) begin
        if (clr) begin
            // ---------- Reset ----------
            state      <= S_SEND_MENU;
            tx_ready   <= 1'b0;
            rx_byte_reg<= 8'd0;
            rx_pending <= 1'b0;
            menu_idx   <= 6'd0;
            pad_idx    <= 6'd0;
            mos_idx    <= 6'd0;
            seq_sel    <= 2'd0;
            result_reg <= 32'd0;
            result_idx <= 2'd0;
            led        <= 8'd0;

            result_chars[0] <= 8'h00;
            result_chars[1] <= 8'h00;
            result_chars[2] <= 8'h00;
            result_chars[3] <= 8'h00;

            start_pad <= 1'b0;
            start_mos <= 1'b0;
            n_pad     <= 8'd0;
            n_mos     <= 8'd0;


            // Menú: "Elige una sucesion, donde 1 es Padovan y 2 es Moser:\r\n"
            menu_msg[0]  <= "E";
            menu_msg[1]  <= "l";
            menu_msg[2]  <= "i";
            menu_msg[3]  <= "g";
            menu_msg[4]  <= "e";
            menu_msg[5]  <= " ";
            menu_msg[6]  <= "u";
            menu_msg[7]  <= "n";
            menu_msg[8]  <= "a";
            menu_msg[9]  <= " ";
            menu_msg[10] <= "s";
            menu_msg[11] <= "u";
            menu_msg[12] <= "c";
            menu_msg[13] <= "e";
            menu_msg[14] <= "s";
            menu_msg[15] <= "i";
            menu_msg[16] <= "o";
            menu_msg[17] <= "n";
            menu_msg[18] <= ",";
            menu_msg[19] <= " ";
            menu_msg[20] <= "d";
            menu_msg[21] <= "o";
            menu_msg[22] <= "n";
            menu_msg[23] <= "d";
            menu_msg[24] <= "e";
            menu_msg[25] <= " ";
            menu_msg[26] <= "1";
            menu_msg[27] <= " ";
            menu_msg[28] <= "e";
            menu_msg[29] <= "s";
            menu_msg[30] <= " ";
            menu_msg[31] <= "P";
            menu_msg[32] <= "a";
            menu_msg[33] <= "d";
            menu_msg[34] <= "o";
            menu_msg[35] <= "v";
            menu_msg[36] <= "a";
            menu_msg[37] <= "n";
            menu_msg[38] <= " ";
            menu_msg[39] <= "y";
            menu_msg[40] <= " ";
            menu_msg[41] <= "2";
            menu_msg[42] <= " ";
            menu_msg[43] <= "e";
            menu_msg[44] <= "s";
            menu_msg[45] <= " ";
            menu_msg[46] <= "M";
            menu_msg[47] <= "o";
            menu_msg[48] <= "s";
            menu_msg[49] <= "e";
            menu_msg[50] <= "r";
            menu_msg[51] <= ":";
            menu_msg[52] <= " ";
            menu_msg[53] <= 8'h0D; // CR
            menu_msg[54] <= 8'h0A; // LF
            menu_msg[55] <= 8'h00; // terminador
            // limpiar resto
            for (int i = 56; i < 64; i++) menu_msg[i] <= 8'h00;

            padovan_msg[0]  <= "I";  padovan_msg[1]  <= "n";
            padovan_msg[2]  <= "g";  padovan_msg[3]  <= "r";
            padovan_msg[4]  <= "e";  padovan_msg[5]  <= "s";
            padovan_msg[6]  <= "e";  padovan_msg[7]  <= " ";
            padovan_msg[8]  <= "N";  padovan_msg[9]  <= " ";
            padovan_msg[10] <= "n";  padovan_msg[11] <= "u";
            padovan_msg[12] <= "m";  padovan_msg[13] <= "e";
            padovan_msg[14] <= "r";  padovan_msg[15] <= "o";
            padovan_msg[16] <= "s"; padovan_msg[17] <= " ";
            padovan_msg[18] <= "p"; padovan_msg[19] <= "a";
            padovan_msg[20] <= "r"; padovan_msg[21] <= "a";
            padovan_msg[22] <= " "; padovan_msg[23] <= "P";
            padovan_msg[24] <= "a"; padovan_msg[25] <= "d";
            padovan_msg[26] <= "o"; padovan_msg[27] <= "v";
            padovan_msg[28] <= "a"; padovan_msg[29] <= "n";
            padovan_msg[30] <= ":"; padovan_msg[31] <= " ";
            padovan_msg[32] <= 8'h0D; // CR
            padovan_msg[33] <= 8'h0A; // LF
            padovan_msg[34] <= 8'h00; // FIN
            padovan_msg[35] <= 8'h00;
            moser_msg[34]   <= 8'h00;
            moser_msg[35]   <= 8'h00;

            moser_msg[0]  <= "I";  moser_msg[1]  <= "n";
            moser_msg[2]  <= "g";  moser_msg[3]  <= "r";
            moser_msg[4]  <= "e";  moser_msg[5]  <= "s";
            moser_msg[6]  <= "e";  moser_msg[7]  <= " ";
            moser_msg[8]  <= "N";  moser_msg[9]  <= " ";
            moser_msg[10] <= "n";  moser_msg[11] <= "u";
            moser_msg[12] <= "m";  moser_msg[13] <= "e";
            moser_msg[14] <= "r";  moser_msg[15] <= "o";
            moser_msg[16] <= "s"; moser_msg[17] <= " ";
            moser_msg[18] <= "p"; moser_msg[19] <= "a";
            moser_msg[20] <= "r"; moser_msg[21] <= "a";
            moser_msg[22] <= " "; moser_msg[23] <= "M";
            moser_msg[24] <= "o"; moser_msg[25] <= "s";
            moser_msg[26] <= "e"; moser_msg[27] <= "r";
            moser_msg[28] <= ":"; moser_msg[29] <= " ";
            moser_msg[30] <= 8'h0D; // CR
            moser_msg[31] <= 8'h0A; // LF
            moser_msg[32] <= 8'h00; // FIN
            moser_msg[33] <= 8'h00;

        end else begin
            tx_ready   <= 1'b0;
            start_pad  <= 1'b0;
            start_mos  <= 1'b0;

            // Latch RX (un byte pendiente a la vez)
            if (rx_valid && !rx_pending) begin
                rx_byte_reg <= rx_data;
                rx_pending  <= 1'b1;
            end

            case (state)

                // Enviar menú inicial
                S_SEND_MENU: begin
                    if (menu_msg[menu_idx] != 8'h00) begin
                        if (tx_free) begin
                            tx_data  <= menu_msg[menu_idx];
                            tx_ready <= 1'b1;
                            state    <= S_WAIT_MENU_TX;
                        end
                    end else begin
                        state    <= S_WAIT_SELECTION;
                    end
                end

                S_WAIT_MENU_TX: begin
                    if (tx_free) begin
                        menu_idx <= menu_idx + 1'b1;
                        state    <= S_SEND_MENU;
                    end
                end

                // Espera selección: '1' o '2'
                S_WAIT_SELECTION: begin
                    if (rx_pending) begin
                        if (rx_byte_reg == "1") begin
                            seq_sel    <= 2'd1;   // Padovan
                            rx_pending <= 1'b0;
                            pad_idx    <= 6'd0;
                            state      <= S_SEND_PROMPT;
                        end else if (rx_byte_reg == "2") begin
                            seq_sel    <= 2'd2;   // Moser
                            rx_pending <= 1'b0;
                            mos_idx    <= 6'd0;
                            state      <= S_SEND_PROMPT;
                        end else begin
                            // ignora cualquier otra cosa
                            rx_pending <= 1'b0;
                        end
                    end
                end

                // Enviar prompt según seq_sel
                S_SEND_PROMPT: begin
                    logic [7:0] ch;
                    if (seq_sel == 2'd1)
                        ch = padovan_msg[pad_idx];
                    else
                        ch = moser_msg[mos_idx];

                    if (ch != 8'h00) begin
                        if (tx_free) begin
                            tx_data  <= ch;
                            tx_ready <= 1'b1;
                            state    <= S_WAIT_PROMPT_TX;
                        end
                    end else begin
                        // prompt terminado
                        state <= S_WAIT_DIGIT;
                    end
                end

                S_WAIT_PROMPT_TX: begin
                    if (tx_free) begin
                        if (seq_sel == 2'd1)
                            pad_idx <= pad_idx + 1'b1;
                        else
                            mos_idx <= mos_idx + 1'b1;
                        state <= S_SEND_PROMPT;
                    end
                end

                // Espera dígito N ('0'..'9')
                S_WAIT_DIGIT: begin
                    if (rx_pending) begin
                        if (rx_byte_reg >= "0" && rx_byte_reg <= "9") begin
                            if (seq_sel == 2'd1)
                                n_pad <= rx_byte_reg - "0";
                            else
                                n_mos <= rx_byte_reg - "0";

                            rx_pending <= 1'b0;
                            state      <= S_START_COMPUTE;
                        end else begin
                            // no es dígito, descartar
                            rx_pending <= 1'b0;
                        end
                    end
                end

                // Lanzar el cálculo
                S_START_COMPUTE: begin
                    if (seq_sel == 2'd1)
                        start_pad <= 1'b1;
                    else
                        start_mos <= 1'b1;

                    state <= S_WAIT_RESULT;
                end

                // Espera resultado listo
                S_WAIT_RESULT: begin
                    if (seq_sel == 2'd1) begin
                        if (ready_pad) begin
                            result_reg <= pad_out;
                            led        <= pad_out[7:0];
                            state      <= S_PREP_RESULT;
                        end
                    end else begin
                        if (ready_mos) begin
                            result_reg <= mos_out;
                            led        <= mos_out[7:0];
                            state      <= S_PREP_RESULT;
                        end
                    end
                end

                // -------------------------
                // Preparar ASCII (máx 4 dígitos)
                // -------------------------
                S_PREP_RESULT: begin
                    if (result_reg >= 32'd1000) begin
                        result_chars[0] <= (result_reg / 32'd1000)                     + 8'h30;
                        result_chars[1] <= ((result_reg % 32'd1000) / 32'd100)        + 8'h30;
                        result_chars[2] <= ((result_reg % 32'd100)  / 32'd10)         + 8'h30;
                        result_chars[3] <= (result_reg % 32'd10)                      + 8'h30;
                    end else if (result_reg >= 32'd100) begin
                        result_chars[0] <= (result_reg / 32'd100)                     + 8'h30;
                        result_chars[1] <= ((result_reg % 32'd100) / 32'd10)          + 8'h30;
                        result_chars[2] <= (result_reg % 32'd10)                      + 8'h30;
                        result_chars[3] <= 8'h00;
                    end else if (result_reg >= 32'd10) begin
                        result_chars[0] <= (result_reg / 32'd10)                      + 8'h30;
                        result_chars[1] <= (result_reg % 32'd10)                      + 8'h30;
                        result_chars[2] <= 8'h00;
                        result_chars[3] <= 8'h00;
                    end else begin
                        result_chars[0] <= result_reg[7:0]                            + 8'h30;
                        result_chars[1] <= 8'h00;
                        result_chars[2] <= 8'h00;
                        result_chars[3] <= 8'h00;
                    end

                    result_idx <= 2'd0;
                    state      <= S_SEND_DIGIT;
                end

                // -------------------------
                // Enviar dígitos del resultado
                // -------------------------
                S_SEND_DIGIT: begin
                    if (result_idx < 4 && result_chars[result_idx] != 8'h00) begin
                        if (tx_free) begin
                            tx_data  <= result_chars[result_idx];
                            tx_ready <= 1'b1;
                            state    <= S_WAIT_DIGIT_TX;
                        end
                    end else begin
                        state <= S_SEND_CR;
                    end
                end

                S_WAIT_DIGIT_TX: begin
                    if (tx_free) begin
                        result_idx <= result_idx + 1'b1;
                        state      <= S_SEND_DIGIT;
                    end
                end

                // -------------------------
                // CR + LF
                // -------------------------
                S_SEND_CR: begin
                    if (tx_free) begin
                        tx_data  <= 8'h0D;
                        tx_ready <= 1'b1;
                        state    <= S_WAIT_CR_TX;
                    end
                end

                S_WAIT_CR_TX: begin
                    if (tx_free) begin
                        state <= S_SEND_LF;
                    end
                end

                S_SEND_LF: begin
                    if (tx_free) begin
                        tx_data  <= 8'h0A;
                        tx_ready <= 1'b1;
                        state    <= S_WAIT_LF_TX;
                    end
                end

                S_WAIT_LF_TX: begin
                    if (tx_free) begin
                        // volvemos a pedir N para la misma sucesión
                        state <= S_WAIT_DIGIT;
                    end
                end

                default: state <= S_SEND_MENU;

            endcase
        end
    end

endmodule
