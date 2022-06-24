link
uniquify

# Setting Design and I/O Environment
set_operating_conditions -min_library fast_vdd1v2 -min PVT_1P32V_0C \
                        -max_library slow_vdd1v2 -max PVT_1P08V_125C

current_design lenet
# Assume outputs go to DFF and inputs also come from DFF
set all_inputs_except_clk \
    [remove_from_collection [all_inputs] [get_ports {clk}]]
set_drive [drive_of "slow_vdd1v2/DFFHQX1/Q"] \
    [get_ports $all_inputs_except_clk]
set_load [load_of "slow_vdd1v2/DFFHQX1/D"] [all_outputs]

create_clock -name clk -period $cycle  [get_ports clk]
set_fix_hold clk
set_dont_touch_network clk

# I/O delay should depend on the real enironment. Here only shows an example of setting
set_input_delay  [expr $cycle*0.5] -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay [expr $cycle*0.5] -clock clk [all_outputs] 

# Setting DRC Constraint
set_max_fanout 20.0 lenet

# Area Constraint
set_max_area   0

# before synthesis settings
set case_analysis_with_logic_constants true
set_fix_multiple_port_nets -all -buffer_constants [get_designs * -h]

# check design
check_design > report/check_design.log
check_timing > report/check_timing.log

set_clock_gating_style -max_fanout 10

compile

# remove dummy ports
remove_unconnected_ports [get_cells -hierarchical *]
remove_unconnected_ports [get_cells -hierarchical *] -blast_buses

# Netlist files
write -format ddc -hierarchy -output netlist/DnCNN_syn.ddc
write_file -format verilog -hierarchy -output netlist/DnCNN_syn.v
write_sdf -version 2.1 -significant_digits 4 -context verilog netlist/DnCNN_syn.sdf
write_sdc netlist/DnCNN_syn.sdc
write_saif -output netlist/DnCNN_syn.saif 

# Timing report
report_timing -delay min -max_paths 4 > report/report_hold_time.log
report_timing -delay max -max_paths 4 > report/report_setup_time.log
report_timing -path full -delay max -max_paths 1 -nworst 1 -significant_digits 4 > report/report_time.log

# Area report =====
report_area -hier  > report/report_area.log

# Power report =====
report_power -hier > report/report_power.log

# violations
report_constraint -all_violators > report/report_violation.log

exit


