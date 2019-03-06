open_hw
connect_hw_server
open_hw_target
current_hw_device [get_hw_devices xc7a35t_0]
set dev [lindex [get_hw_devices xc7a35t_0] 0]

refresh_hw_device -update_hw_probes false $dev
create_hw_cfgmem -hw_device $dev [lindex [get_cfgmem_parts "n25q32-3.3v-spi-x1_x2_x4"] 0]

set cfgmem [get_property PROGRAM.HW_CFGMEM $dev]
set_property PROGRAM.BLANK_CHECK  0 $cfgmem
set_property PROGRAM.ERASE        1 $cfgmem
set_property PROGRAM.CFG_PROGRAM  1 $cfgmem
set_property PROGRAM.VERIFY       1 $cfgmem
set_property PROGRAM.CHECKSUM     0 $cfgmem
refresh_hw_device $dev

write_cfgmem -force -format mcs -size 4 -interface SPIx4 -loadbit {up 0x00000000 leon3mp.bit } -file leon3mp.mcs
set_property PROGRAM.ADDRESS_RANGE           {use_file} $cfgmem 
set_property PROGRAM.FILES                {leon3mp.mcs} $cfgmem
set_property PROGRAM.PRM_FILE                        {} $cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $cfgmem
set_property PROGRAM.BLANK_CHECK                      0 $cfgmem
set_property PROGRAM.ERASE                            1 $cfgmem
set_property PROGRAM.CFG_PROGRAM                      1 $cfgmem
set_property PROGRAM.VERIFY                           1 $cfgmem
set_property PROGRAM.CHECKSUM                         0 $cfgmem
if {![string equal [get_property PROGRAM.HW_CFGMEM_TYPE  $dev] [get_property MEM_TYPE [get_property CFGMEM_PART [ get_property PROGRAM.HW_CFGMEM $dev]]]] }  { 
    create_hw_bitstream -hw_device $dev [get_property PROGRAM.HW_CFGMEM_BITFILE $dev]
    program_hw_devices $dev
}
program_hw_cfgmem -hw_cfgmem $cfgmem
disconnect_hw_server
