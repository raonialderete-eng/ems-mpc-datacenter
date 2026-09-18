# No laboratorio (Quartus no PATH):
#   quartus_sh -t create_project.tcl hello
#   quartus_sh -t create_project.tcl ems

set modo "hello"
if { $argc >= 1 } { set modo [lindex $argv 0] }

if { $modo eq "hello" } {
    project_open hello_led
    load_package flow
    execute_flow -compile
} elseif { $modo eq "ems" } {
    project_open ems_de2115
    load_package flow
    execute_flow -compile
} else {
    puts "uso: quartus_sh -t create_project.tcl [hello|ems]"
    exit 1
}
