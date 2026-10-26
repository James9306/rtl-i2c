# Recreates the Vivado project in build/ from version-controlled sources.
# Usage (from repo root): vivado -mode batch -source scripts/create_project.tcl
set proj_name rtl_i2c
set part      xc7a35tcpg236-1 ;# TODO: set to your target device

set root [file normalize [file join [file dirname [info script]] ..]]
create_project $proj_name [file join $root build] -part $part -force

set hdl [glob -nocomplain -directory [file join $root src hdl] *.v *.sv *.vhd]
if {[llength $hdl]} { add_files -fileset sources_1 -norecurse $hdl }

set xdc [glob -nocomplain -directory [file join $root src constrs] *.xdc]
if {[llength $xdc]} { add_files -fileset constrs_1 -norecurse $xdc }

set xci [glob -nocomplain -directory [file join $root src ip] */*.xci]
if {[llength $xci]} { add_files -norecurse $xci }

set tb [glob -nocomplain -directory [file join $root sim tb] *.v *.sv *.vhd]
if {[llength $tb]} { add_files -fileset sim_1 -norecurse $tb }

update_compile_order -fileset sources_1
