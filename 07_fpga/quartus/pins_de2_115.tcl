# Pinout Terasic DE2-115 (Cyclone IV E EP4CE115F29C7)
# Fonte: manual Terasic / exemplos oficiais do kit.

set_location_assignment PIN_Y2 -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50

# KEY ativo-baixo
set_location_assignment PIN_M23 -to KEY[0]
set_location_assignment PIN_M21 -to KEY[1]
set_location_assignment PIN_N21 -to KEY[2]
set_location_assignment PIN_R24 -to KEY[3]
set_instance_assignment -name IO_STANDARD "2.5 V" -to KEY[0]
set_instance_assignment -name IO_STANDARD "2.5 V" -to KEY[1]
set_instance_assignment -name IO_STANDARD "2.5 V" -to KEY[2]
set_instance_assignment -name IO_STANDARD "2.5 V" -to KEY[3]

set_location_assignment PIN_AB28 -to SW[0]
set_location_assignment PIN_AC28 -to SW[1]
set_location_assignment PIN_AC27 -to SW[2]
set_location_assignment PIN_AD27 -to SW[3]
set_location_assignment PIN_AB27 -to SW[4]
set_location_assignment PIN_AC26 -to SW[5]
set_location_assignment PIN_AD26 -to SW[6]
set_location_assignment PIN_AB26 -to SW[7]
set_location_assignment PIN_AC25 -to SW[8]
set_location_assignment PIN_AB25 -to SW[9]
set_location_assignment PIN_AC24 -to SW[10]
set_location_assignment PIN_AB24 -to SW[11]
set_location_assignment PIN_AB23 -to SW[12]
set_location_assignment PIN_AA24 -to SW[13]
set_location_assignment PIN_AA23 -to SW[14]
set_location_assignment PIN_AA22 -to SW[15]
set_location_assignment PIN_Y24  -to SW[16]
set_location_assignment PIN_Y23  -to SW[17]

set_location_assignment PIN_G19 -to LEDR[0]
set_location_assignment PIN_F19 -to LEDR[1]
set_location_assignment PIN_E19 -to LEDR[2]
set_location_assignment PIN_F21 -to LEDR[3]
set_location_assignment PIN_F18 -to LEDR[4]
set_location_assignment PIN_E18 -to LEDR[5]
set_location_assignment PIN_J19 -to LEDR[6]
set_location_assignment PIN_H19 -to LEDR[7]
set_location_assignment PIN_J17 -to LEDR[8]
set_location_assignment PIN_G17 -to LEDR[9]
set_location_assignment PIN_J15 -to LEDR[10]
set_location_assignment PIN_H17 -to LEDR[11]
set_location_assignment PIN_F15 -to LEDR[12]
set_location_assignment PIN_G15 -to LEDR[13]
set_location_assignment PIN_G16 -to LEDR[14]
set_location_assignment PIN_H15 -to LEDR[15]
set_location_assignment PIN_E21 -to LEDR[16]
set_location_assignment PIN_E22 -to LEDR[17]

# HEX0 ativo-baixo (SOC dezenas/unidades no firmware EMS)
set_location_assignment PIN_G18 -to HEX0[0]
set_location_assignment PIN_F22 -to HEX0[1]
set_location_assignment PIN_E17 -to HEX0[2]
set_location_assignment PIN_L26 -to HEX0[3]
set_location_assignment PIN_L25 -to HEX0[4]
set_location_assignment PIN_J22 -to HEX0[5]
set_location_assignment PIN_H22 -to HEX0[6]

set_location_assignment PIN_M24 -to HEX1[0]
set_location_assignment PIN_Y22 -to HEX1[1]
set_location_assignment PIN_W21 -to HEX1[2]
set_location_assignment PIN_W22 -to HEX1[3]
set_location_assignment PIN_W25 -to HEX1[4]
set_location_assignment PIN_U23 -to HEX1[5]
set_location_assignment PIN_U24 -to HEX1[6]

# UART RS-232 da placa
set_location_assignment PIN_G9  -to UART_TXD
set_location_assignment PIN_G12 -to UART_RXD
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to UART_TXD
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to UART_RXD
