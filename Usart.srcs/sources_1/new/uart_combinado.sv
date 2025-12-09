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

    // ================================
    // UART RX
    // ================================
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

    // ================================
    // UART TX
    // ================================
    logic [7:0] tx_data;
    logic       tx_ready;
    logic       tx_free;   // tdre de Tx

    Tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) uart_tx (
        .clk    (clk),
        .reset  (clr),
        .ready  (tx_ready),   // pulso de un ciclo
        .tx_data(tx_data),
        .TxD    (TxD),
        .tdre   (tx_free)
    );

    // ================================
    // Instancias PADOVAN y MOSER
    // ================================
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
    // Mensajes (ROMs simples)
    // ================================
    // Menú: "Elige una sucesion, donde 1 es Padovan y 2 es Moser:\r\n"
    localparam int MENU_LEN = 55;
    logic [7:0] menu_msg [0:MENU_LEN-1];
    logic [5:0] menu_idx;

    // Prompt Padovan: "Ingrese N numeros para Padovan:\r\n"
    localparam int PAD_MSG_LEN = 34;
    logic [7:0] padovan_msg [0:PAD_MSG_LEN-1];
    logic [5:0] pad_idx;

    // Prompt Moser: "Ingrese N numeros para Moser:\r\n"
    localparam int MOS_MSG_LEN = 34;
    logic [7:0] moser_msg [0:MOS_MSG_LEN-1];
    logic [5:0] mos_idx;

    // ================================
    // FSM principal
    // ================================
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
        S_SEND_RESULT_DIGIT,
        S_WAIT_RESULT_TX,
        S_SEND_CR,
        S_WAIT_CR_TX,
        S_SEND_LF,
        S_WAIT_LF_TX
    } state_t;

    state_t state;

    // Selección de sucesión: 1 = Padovan, 2 = Moser
    logic [1:0] seq_sel;
    logic [7:0] sel_reg;     // '1' o '2'
    logic       have_sel;    // se escribió opción válida

    // Buffer para N (decimal)
    logic [7:0] n_buffer;    // 0..255
    logic       have_n;      // al menos un dígito
    logic [7:0] n_user;      // N confirmado con Enter

    // Resultado
    logic [31:0] result_reg;
    logic [7:0]  result_chars [0:3];  // hasta 4 dígitos
    logic [1:0]  result_idx;

    logic [7:0]  ch;         // auxiliar para prompts

    // ================================
    // Lógica secuencial
    // ================================
    always_ff @(posedge clk) begin
        if (clr) begin
            // ---------- Reset global ----------
            state       <= S_SEND_MENU;
            tx_ready    <= 1'b0;
            menu_idx    <= 6'd0;
            pad_idx     <= 6'd0;
            mos_idx     <= 6'd0;
            seq_sel     <= 2'd0;
            sel_reg     <= 8'd0;
            have_sel    <= 1'b0;
            n_buffer    <= 8'd0;
            have_n      <= 1'b0;
            n_user      <= 8'd0;
            result_reg  <= 32'd0;
            result_idx  <= 2'd0;
            led         <= 8'd0;

            result_chars[0] <= 8'h00;
            result_chars[1] <= 8'h00;
            result_chars[2] <= 8'h00;
            result_chars[3] <= 8'h00;

            start_pad <= 1'b0;
            start_mos <= 1'b0;
            n_pad     <= 8'd0;
            n_mos     <= 8'd0;

            // ---------- Inicializar mensajes ----------
            // Menú
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

            // Prompt Padovan
            padovan_msg[0]  <= "I";  padovan_msg[1]  <= "n";
            padovan_msg[2]  <= "g";  padovan_msg[3]  <= "r";
            padovan_msg[4]  <= "e";  padovan_msg[5]  <= "s";
            padovan_msg[6]  <= "e";  padovan_msg[7]  <= " ";
            padovan_msg[8]  <= "N";  padovan_msg[9]  <= " ";
            padovan_msg[10] <= "n";  padovan_msg[11] <= "u";
            padovan_msg[12] <= "m";  padovan_msg[13] <= "e";
            padovan_msg[14] <= "r";  padovan_msg[15] <= "o";
            padovan_msg[16] <= "s";  padovan_msg[17] <= " ";
            padovan_msg[18] <= "p";  padovan_msg[19] <= "a";
            padovan_msg[20] <= "r";  padovan_msg[21] <= "a";
            padovan_msg[22] <= " ";  padovan_msg[23] <= "P";
            padovan_msg[24] <= "a";  padovan_msg[25] <= "d";
            padovan_msg[26] <= "o";  padovan_msg[27] <= "v";
            padovan_msg[28] <= "a";  padovan_msg[29] <= "n";
            padovan_msg[30] <= ":";  padovan_msg[31] <= " ";
            padovan_msg[32] <= 8'h0D; // CR
            padovan_msg[33] <= 8'h0A; // LF

            // Prompt Moser
            moser_msg[0]  <= "I";  moser_msg[1]  <= "n";
            moser_msg[2]  <= "g";  moser_msg[3]  <= "r";
            moser_msg[4]  <= "e";  moser_msg[5]  <= "s";
            moser_msg[6]  <= "e";  moser_msg[7]  <= " ";
            moser_msg[8]  <= "N";  moser_msg[9]  <= " ";
            moser_msg[10] <= "n";  moser_msg[11] <= "u";
            moser_msg[12] <= "m";  moser_msg[13] <= "e";
            moser_msg[14] <= "r";  moser_msg[15] <= "o";
            moser_msg[16] <= "s";  moser_msg[17] <= " ";
            moser_msg[18] <= "p";  moser_msg[19] <= "a";
            moser_msg[20] <= "r";  moser_msg[21] <= "a";
            moser_msg[22] <= " ";  moser_msg[23] <= "M";
            moser_msg[24] <= "o";  moser_msg[25] <= "s";
            moser_msg[26] <= "e";  moser_msg[27] <= "r";
            moser_msg[28] <= ":";  moser_msg[29] <= " ";
            moser_msg[30] <= 8'h0D; // CR
            moser_msg[31] <= 8'h0A; // LF

        end else begin
            // ---------- Ciclo normal ----------
            tx_ready   <= 1'b0;
            start_pad  <= 1'b0;
            start_mos  <= 1'b0;

            case (state)

                // ==========================
                //  MENÚ INICIAL
                // ==========================
                S_SEND_MENU: begin
                    if (menu_idx < MENU_LEN) begin
                        if (tx_free) begin
                            tx_data  <= menu_msg[menu_idx];
                            tx_ready <= 1'b1;
                            state    <= S_WAIT_MENU_TX;
                        end
                    end else begin
                        state <= S_WAIT_SELECTION;
                    end
                end

                S_WAIT_MENU_TX: begin
                    if (tx_free) begin
                        menu_idx <= menu_idx + 1'b1;
                        state    <= S_SEND_MENU;
                    end
                end

                // ==========================
                // ELECCIÓN DE SUCESIÓN
                // ==========================
                S_WAIT_SELECTION: begin
                    if (rx_valid) begin
                        // Echo
                        if (tx_free) begin
                            tx_data  <= rx_data;
                            tx_ready <= 1'b1;
                        end

                        // Procesar carácter
                        if (rx_data == "1" || rx_data == "2") begin
                            sel_reg  <= rx_data;
                            have_sel <= 1'b1;

                        end else if (rx_data == 8'h0D || rx_data == 8'h0A) begin
                            // Enter: confirmar selección si hay una válida
                            if (have_sel) begin
                                if (sel_reg == "1")
                                    seq_sel <= 2'd1; // Padovan
                                else
                                    seq_sel <= 2'd2; // Moser

                                pad_idx  <= 6'd0;
                                mos_idx  <= 6'd0;
                                n_buffer <= 8'd0;
                                have_n   <= 1'b0;
                                state    <= S_SEND_PROMPT;
                            end
                        end
                    end
                end

                // ==========================
                // PROMPT PARA N
                // ==========================
                S_SEND_PROMPT: begin
                    if (seq_sel == 2'd1) begin
                        ch = padovan_msg[pad_idx];
                        if (pad_idx < PAD_MSG_LEN) begin
                            if (tx_free) begin
                                tx_data  <= ch;
                                tx_ready <= 1'b1;
                                state    <= S_WAIT_PROMPT_TX;
                            end
                        end else begin
                            n_buffer <= 8'd0;
                            have_n   <= 1'b0;
                            state    <= S_WAIT_DIGIT;
                        end
                    end else begin
                        ch = moser_msg[mos_idx];
                        if (mos_idx < MOS_MSG_LEN) begin
                            if (tx_free) begin
                                tx_data  <= ch;
                                tx_ready <= 1'b1;
                                state    <= S_WAIT_PROMPT_TX;
                            end
                        end else begin
                            n_buffer <= 8'd0;
                            have_n   <= 1'b0;
                            state    <= S_WAIT_DIGIT;
                        end
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

                // ==========================
                // LECTURA DE N (multi-dígito, echo, Enter)
                // ==========================
                S_WAIT_DIGIT: begin
                    if (rx_valid) begin
                        // Echo del carácter que escribe el usuario
                        if (tx_free) begin
                            tx_data  <= rx_data;
                            tx_ready <= 1'b1;
                        end

                        if (rx_data >= "0" && rx_data <= "9") begin
                            n_buffer <= (n_buffer * 8'd10) + (rx_data - "0");
                            have_n   <= 1'b1;

                        end else if (rx_data == 8'h0D || rx_data == 8'h0A) begin
                            // Enter: si ya hay al menos un dígito, confirmamos N
                            if (have_n) begin
                                n_user   <= n_buffer;
                                n_buffer <= 8'd0;
                                have_n   <= 1'b0;
                                state    <= S_START_COMPUTE;
                            end
                        end
                        // Otros caracteres se ignoran
                    end
                end

                // ==========================
                // LANZAR CÁLCULO
                // ==========================
                S_START_COMPUTE: begin
                    if (seq_sel == 2'd1) begin
                        // PADOVAN: el usuario sigue la convención
                        // P_user(0)=0, P_user(1)=1, P_user(2)=1,...
                        // y tu módulo padovan hace P_hw(0)=1,1,1.
                        //
                        // Para n>=2, se cumple:
                        //   P_user(n) = P_hw(n-1)
                        //
                        // Así que:
                        if (n_user == 8'd0) begin
                            result_reg <= 32'd0;   // P(0)=0
                            led        <= 8'd0;
                            state      <= S_PREP_RESULT;
                        end else begin
                            n_pad     <= n_user - 8'd1; // map a índice del módulo
                            start_pad <= 1'b1;
                            state     <= S_WAIT_RESULT;
                        end

                    end else begin
                        // MOSER: directo, sin ajuste
                        n_mos     <= n_user;
                        start_mos <= 1'b1;
                        state     <= S_WAIT_RESULT;
                    end
                end

                // ==========================
                // ESPERAR RESULTADO
                // ==========================
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

                // ==========================
                // PREPARAR RESULTADO ASCII (0-9999)
                // ==========================
                S_PREP_RESULT: begin
                    if (result_reg >= 32'd1000) begin
                        result_chars[0] <= (result_reg / 32'd1000)                    + 8'h30;
                        result_chars[1] <= ((result_reg % 32'd1000) / 32'd100)       + 8'h30;
                        result_chars[2] <= ((result_reg % 32'd100)  / 32'd10)        + 8'h30;
                        result_chars[3] <= (result_reg % 32'd10)                     + 8'h30;
                    end else if (result_reg >= 32'd100) begin
                        result_chars[0] <= (result_reg / 32'd100)                    + 8'h30;
                        result_chars[1] <= ((result_reg % 32'd100) / 32'd10)         + 8'h30;
                        result_chars[2] <= (result_reg % 32'd10)                     + 8'h30;
                        result_chars[3] <= 8'h00;
                    end else if (result_reg >= 32'd10) begin
                        result_chars[0] <= (result_reg / 32'd10)                     + 8'h30;
                        result_chars[1] <= (result_reg % 32'd10)                     + 8'h30;
                        result_chars[2] <= 8'h00;
                        result_chars[3] <= 8'h00;
                    end else begin
                        result_chars[0] <= result_reg[7:0]                           + 8'h30;
                        result_chars[1] <= 8'h00;
                        result_chars[2] <= 8'h00;
                        result_chars[3] <= 8'h00;
                    end

                    result_idx <= 2'd0;
                    state      <= S_SEND_RESULT_DIGIT;
                end

                // ==========================
                // ENVIAR RESULTADO
                // ==========================
                S_SEND_RESULT_DIGIT: begin
                    if (result_idx < 4 && result_chars[result_idx] != 8'h00) begin
                        if (tx_free) begin
                            tx_data  <= result_chars[result_idx];
                            tx_ready <= 1'b1;
                            state    <= S_WAIT_RESULT_TX;
                        end
                    end else begin
                        state <= S_SEND_CR;
                    end
                end

                S_WAIT_RESULT_TX: begin
                    if (tx_free) begin
                        result_idx <= result_idx + 1'b1;
                        state      <= S_SEND_RESULT_DIGIT;
                    end
                end

                // ==========================
                // CR + LF
                // ==========================
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
                        n_buffer <= 8'd0;
                        have_n   <= 1'b0;
                        state    <= S_WAIT_DIGIT;
                    end
                end

                default: state <= S_SEND_MENU;

            endcase
        end
    end

endmodule
