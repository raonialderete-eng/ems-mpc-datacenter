# Gera o Qsys nios_system.qsys (Quartus Prime Lite 20.1.1).
# Uso:
#   qsys-script --script=nios_system.tcl
# ou Platform Designer 20.1 → File → Execute Script.

package require -exact qsys 20.1

set sys_name nios_system
create_system $sys_name

add_instance clk_0 clock_source
set_instance_parameter_value clk_0 clockFrequency {50000000}
set_instance_parameter_value clk_0 clockFrequencyKnown {1}

add_instance onchip altera_avalon_onchip_memory2
set_instance_parameter_value onchip memorySize {262144}
set_instance_parameter_value onchip dataWidth {32}
set_instance_parameter_value onchip dualPort {false}

# Quartus 20.1: o tipo de catalogo e altera_nios2_gen2 (nao o alias nios2_gen2).
add_instance nios altera_nios2_gen2
set_instance_parameter_value nios impl {Fast}
set_instance_parameter_value nios resetSlave {onchip.s1}
set_instance_parameter_value nios resetOffset {0x0}

add_instance jtag_uart altera_avalon_jtag_uart
add_instance uart altera_avalon_uart
set_instance_parameter_value uart baud {115200}

add_instance timer altera_avalon_timer
set_instance_parameter_value timer period {1}
set_instance_parameter_value timer periodUnits {USEC}

add_instance pio_led altera_avalon_pio
set_instance_parameter_value pio_led width {18}
set_instance_parameter_value pio_led direction {Output}

add_instance pio_sw altera_avalon_pio
set_instance_parameter_value pio_sw width {18}
set_instance_parameter_value pio_sw direction {Input}

add_instance pio_key altera_avalon_pio
set_instance_parameter_value pio_key width {4}
set_instance_parameter_value pio_key direction {Input}

add_instance pio_hex altera_avalon_pio
set_instance_parameter_value pio_hex width {14}
set_instance_parameter_value pio_hex direction {Output}

add_instance sysid altera_avalon_sysid_qsys
set_instance_parameter_value sysid id {0x0000E115}

# Relogio / reset
add_connection clk_0.clk nios.clk
add_connection clk_0.clk onchip.clk1
add_connection clk_0.clk jtag_uart.clk
add_connection clk_0.clk uart.clk
add_connection clk_0.clk timer.clk
add_connection clk_0.clk pio_led.clk
add_connection clk_0.clk pio_sw.clk
add_connection clk_0.clk pio_key.clk
add_connection clk_0.clk pio_hex.clk
add_connection clk_0.clk sysid.clk

add_connection clk_0.clk_reset nios.reset
add_connection clk_0.clk_reset onchip.reset1
add_connection clk_0.clk_reset jtag_uart.reset
add_connection clk_0.clk_reset uart.reset
add_connection clk_0.clk_reset timer.reset
add_connection clk_0.clk_reset pio_led.reset
add_connection clk_0.clk_reset pio_sw.reset
add_connection clk_0.clk_reset pio_key.reset
add_connection clk_0.clk_reset pio_hex.reset
add_connection clk_0.clk_reset sysid.reset

add_connection nios.data_master onchip.s1
add_connection nios.instruction_master onchip.s1
add_connection nios.data_master jtag_uart.avalon_jtag_slave
add_connection nios.data_master uart.s1
add_connection nios.data_master timer.s1
add_connection nios.data_master pio_led.s1
add_connection nios.data_master pio_sw.s1
add_connection nios.data_master pio_key.s1
add_connection nios.data_master pio_hex.s1
add_connection nios.data_master sysid.control_slave

set_connection_parameter_value nios.data_master/onchip.s1 baseAddress {0x00000000}
set_connection_parameter_value nios.instruction_master/onchip.s1 baseAddress {0x00000000}
set_connection_parameter_value nios.data_master/jtag_uart.avalon_jtag_slave baseAddress {0x00041000}
set_connection_parameter_value nios.data_master/uart.s1 baseAddress {0x00041100}
set_connection_parameter_value nios.data_master/timer.s1 baseAddress {0x00041200}
set_connection_parameter_value nios.data_master/pio_led.s1 baseAddress {0x00041300}
set_connection_parameter_value nios.data_master/pio_sw.s1 baseAddress {0x00041400}
set_connection_parameter_value nios.data_master/pio_key.s1 baseAddress {0x00041500}
set_connection_parameter_value nios.data_master/pio_hex.s1 baseAddress {0x00041600}
set_connection_parameter_value nios.data_master/sysid.control_slave baseAddress {0x00041700}

add_connection nios.data_master nios.debug_mem_slave
add_connection nios.instruction_master nios.debug_mem_slave
set_connection_parameter_value nios.data_master/nios.debug_mem_slave baseAddress {0x00041800}
set_connection_parameter_value nios.instruction_master/nios.debug_mem_slave baseAddress {0x00041800}

add_connection nios.irq jtag_uart.irq
add_connection nios.irq timer.irq
add_connection nios.irq uart.irq
set_connection_parameter_value nios.irq/jtag_uart.irq irqNumber {0}
set_connection_parameter_value nios.irq/timer.irq irqNumber {1}
set_connection_parameter_value nios.irq/uart.irq irqNumber {2}

set_instance_parameter_value nios exceptionSlave {onchip.s1}
set_interface_property clk_0 EXPORT_OF clk_0.clk_in
# Porta exportada no HDL 20.1: clk_0_clk (o top usa esse nome).
set_interface_property reset EXPORT_OF clk_0.clk_in_reset
set_interface_property pio_led_external_connection EXPORT_OF pio_led.external_connection
set_interface_property pio_sw_external_connection EXPORT_OF pio_sw.external_connection
set_interface_property pio_key_external_connection EXPORT_OF pio_key.external_connection
set_interface_property pio_hex_external_connection EXPORT_OF pio_hex.external_connection
set_interface_property uart_external_connection EXPORT_OF uart.external_connection

save_system ${sys_name}.qsys
