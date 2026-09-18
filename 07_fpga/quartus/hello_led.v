// hello_led.v — primeiro teste na DE2-115 sem Nios (prova pinout)
module hello_led (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,
    output wire [17:0] LEDR,
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire        UART_TXD,
    input  wire        UART_RXD
);
    wire unused_rx = UART_RXD;
    wire rst_n = KEY[0];
    reg [25:0] cnt;
    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n)
            cnt <= 26'd0;
        else
            cnt <= cnt + 26'd1;
    end
    assign LEDR[0]    = cnt[25];
    assign LEDR[1]    = SW[0];
    assign LEDR[17:2] = 16'd0;
    assign HEX0 = 7'b1000000; // "0" ativo-baixo aproximado
    assign HEX1 = 7'b1111001; // "1"
    assign UART_TXD = 1'b1;
endmodule
