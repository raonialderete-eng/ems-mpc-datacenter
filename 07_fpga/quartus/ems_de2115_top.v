// Top EMS: instancia o Qsys nios_system (gerar no lab com nios_system.tcl)
module ems_de2115_top (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,
    output wire [17:0] LEDR,
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire        UART_TXD,
    input  wire        UART_RXD
);
    wire rst = ~KEY[0];

    nios_system u0 (
        .clk_0_clk                        (CLOCK_50),
        .reset_reset_n                    (KEY[0]),
        .pio_led_external_connection_export (LEDR),
        .pio_sw_external_connection_export  (SW),
        .pio_key_external_connection_export (KEY),
        .pio_hex_external_connection_export ({HEX1, HEX0}),
        .uart_external_connection_rxd     (UART_RXD),
        .uart_external_connection_txd     (UART_TXD)
    );
endmodule
