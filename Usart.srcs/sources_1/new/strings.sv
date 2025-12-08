module Tx_string (
    input  logic clk,
    input  logic reset,
    output logic TxD
);

    
    logic [7:0] mensaje [0:5][0:7];
    
    
    initial begin
        // Fila 0: "Elige un"
        mensaje[0][0] = 8'h45;  // 'E'
        mensaje[0][1] = 8'h6C;  // 'l'
        mensaje[0][2] = 8'h69;  // 'i'
        mensaje[0][3] = 8'h67;  // 'g'
        mensaje[0][4] = 8'h65;  // 'e'
        mensaje[0][5] = 8'h20;  // ' '
        mensaje[0][6] = 8'h75;  // 'u'
        mensaje[0][7] = 8'h6E;  // 'n'

      
        mensaje[1][0] = 8'h61;  // 'a'
        mensaje[1][1] = 8'h20;  // ' '
        mensaje[1][2] = 8'h6F;  // 'o'
        mensaje[1][3] = 8'h70;  // 'p'
        mensaje[1][4] = 8'h65;  // 'e'
        mensaje[1][5] = 8'h72;  // 'r'
        mensaje[1][6] = 8'h61;  // 'a'
        mensaje[1][7] = 8'h63;  // 'c'

        mensaje[2][0] = 8'h69;  // 'i'
        mensaje[2][1] = 8'h6F;  // 'o'
        mensaje[2][2] = 8'h6E;  // 'n'
        mensaje[2][3] = 8'h1B;  // escape
        mensaje[2][4] = 8'h31;  // '1'
        mensaje[2][5] = 8'h2D;  // 'E'
        mensaje[2][6] = 8'h2D;  // 'E'
        mensaje[2][7] = 8'h2D;  // 'E'

       
        mensaje[3][0] = 8'h45;  // 'E'
        mensaje[3][1] = 8'h45;  // 'E'
        mensaje[3][2] = 8'h20;  // ' '
        mensaje[3][3] = 8'h50;  // 'P'
        mensaje[3][4] = 8'h61;  // 'a'
        mensaje[3][5] = 8'h64;  // 'd'
        mensaje[3][6] = 8'h6F;  // 'o'
        mensaje[3][7] = 8'h76;  // 'v'

       
        mensaje[4][0] = 8'h61;  // 'a'
        mensaje[4][1] = 8'h6E;  // 'n'
        mensaje[4][2] = 8'h1B;  // escape
        mensaje[4][3] = 8'h32;  // '2'
        mensaje[4][4] = 8'h2D;  // 'E'
        mensaje[4][5] = 8'h2D;  // 'E'
        mensaje[4][6] = 8'h2D;  // 'E'
        mensaje[4][7] = 8'h20;  // ' '

       
        mensaje[5][0] = 8'h4D;  // 'M'
        mensaje[5][1] = 8'h6F;  // 'o'
        mensaje[5][2] = 8'h73;  // 's'
        mensaje[5][3] = 8'h65;  // 'e'
        mensaje[5][4] = 8'h72;  // 'r'
        mensaje[5][5] = 8'h00;  // NULL (no definido)
        mensaje[5][6] = 8'h00;  // NULL (no definido) 
        mensaje[5][7] = 8'h00;  // NULL (no definido)
    end

    // Índices para recorrer el array 2D
    logic [2:0] fila_idx;    // 0-5 (3 bits)
    logic [2:0] columna_idx; // 0-7 (3 bits) 
    logic ready;
    logic tdre;
    logic [7:0] tx_data;

    Tx #(.CLOCK_FREQ(100_000_000), .BAUD_RATE(115200)) uart_tx (
        .clk(clk),
        .reset(reset),
        .ready(ready),
        .tx_data(tx_data),
        .TxD(TxD),
        .tdre(tdre)
    );

    typedef enum logic [1:0] {
        IDLE,
        SEND_CHAR,
        WAIT_COMPLETE
    } state_t;
    
    state_t state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            fila_idx <= 0;
            columna_idx <= 0;
            ready <= 0;
            tx_data <= 0;
        end else begin
            ready <= 0; // Por defecto en 0
            
            case (state)
                IDLE: begin
                    
                    if (fila_idx < 6) begin
                        state <= SEND_CHAR;
                    end
                    
                end
                
                SEND_CHAR: begin
                    if (tdre) begin
                        // Obtener carácter actual del array 2D
                        tx_data <= mensaje[fila_idx][columna_idx];
                        ready <= 1;
                        state <= WAIT_COMPLETE;
                    end
                end
                
                WAIT_COMPLETE: begin
                    ready <= 0; // Solo un pulso
                    
                   
                    if (tdre) begin
                       
                        if (columna_idx < 7) begin
                            
                            columna_idx <= columna_idx + 1;
                            state <= IDLE;
                        end else begin
                         
                            columna_idx <= 0;
                            fila_idx <= fila_idx + 1;
                            state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

endmodule