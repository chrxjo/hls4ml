if {$opt(asic)} {
    project new -name Catapult_asic
} else {
    project new -name Catapult_fpga
}

#
# Reset the options to the factory defaults
#

solution new -state initial
solution options defaults

solution options set Flows/ModelSim/VLOG_OPTS {-suppress 12110}
solution options set Flows/ModelSim/VSIM_OPTS {-t ps -suppress 12110}
solution options set /Input/CppStandard c++11
#solution options set /Input/TargetPlatform x86_64
flow package require /SCVerify

directive set -DESIGN_GOAL area
#directive set -OLD_SCHED false
directive set -SPECULATE true
directive set -MERGEABLE true
directive set -REGISTER_THRESHOLD 4096
directive set -MEM_MAP_THRESHOLD 32
directive set -LOGIC_OPT false
directive set -FSM_ENCODING none
directive set -FSM_BINARY_ENCODING_THRESHOLD 64
directive set -REG_MAX_FANOUT 0
directive set -NO_X_ASSIGNMENTS true
directive set -SAFE_FSM false
directive set -REGISTER_SHARING_MAX_WIDTH_DIFFERENCE 8
directive set -REGISTER_SHARING_LIMIT 0
directive set -ASSIGN_OVERHEAD 0
directive set -TIMING_CHECKS true
directive set -MUXPATH true
directive set -REALLOC true
directive set -UNROLL no
directive set -IO_MODE super
directive set -CHAN_IO_PROTOCOL standard
directive set -ARRAY_SIZE 1024
directive set -REGISTER_IDLE_SIGNAL false
directive set -IDLE_SIGNAL {}
directive set -STALL_FLAG false
directive set -TRANSACTION_DONE_SIGNAL true
directive set -DONE_FLAG {}
directive set -READY_FLAG {}
directive set -START_FLAG {}
directive set -BLOCK_SYNC none
directive set -TRANSACTION_SYNC ready
directive set -DATA_SYNC none
directive set -CLOCKS {clk {-CLOCK_PERIOD 0.0 -CLOCK_EDGE rising -CLOCK_UNCERTAINTY 0.0 -RESET_SYNC_NAME rst -RESET_ASYNC_NAME arst_n -RESET_KIND sync -RESET_SYNC_ACTIVE high -RESET_ASYNC_ACTIVE low -ENABLE_ACTIVE high}}
directive set -RESET_CLEARS_ALL_REGS true
directive set -CLOCK_OVERHEAD 20.000000
directive set -OPT_CONST_MULTS use_library
directive set -CHARACTERIZE_ROM false
directive set -PROTOTYPE_ROM true
directive set -ROM_THRESHOLD 64
directive set -CLUSTER_ADDTREE_IN_COUNT_THRESHOLD 0
directive set -CLUSTER_OPT_CONSTANT_INPUTS true
directive set -CLUSTER_RTL_SYN false
directive set -CLUSTER_FAST_MODE false
directive set -CLUSTER_TYPE combinational
directive set -COMPGRADE fast

# Design specific options.
solution options set /Input/CompilerFlags -DMNTR_CATAPULT_HLS
solution options set /Input/SearchPath {../src}

# Add source files.
solution file add ../src/softmax.cc -type C++

go new

#
#
#

go analyze

#
#
#

# Set the top module and inline all of the other functions.
#directive set -DESIGN_HIERARCHY top_module

go compile

# Run C simulation.
if {$opt(csim)} {
    flow run /SCVerify/launch_make ./scverify/Verify_orig_cxx_osci.mk {} SIMTOOL=osci sim
}

#
#
#

# Run HLS.
if {$opt(hsynth)} {

    if {$opt(asic)} {
        solution library add nangate-45nm_beh -- -rtlsyntool DesignCompiler -vendor Nangate -technology 045nm
        solution library add ccs_sample_mem
    } else {
        solution library add mgc_Xilinx-KINTEX-u-2_beh -- -rtlsyntool Vivado -manufacturer Xilinx -family KINTEX-u -speed -2 -part xcku115-flva2104-2-i
        solution library add Xilinx_RAMS
        solution library add Xilinx_ROMS
        solution library add Xilinx_FIFO
    }

    go libraries

    #
    #
    #

    directive set -CLOCKS { \
        clk { \
            -CLOCK_PERIOD 5 \
            -CLOCK_EDGE rising \
            -CLOCK_HIGH_TIME 2.5 \
            -CLOCK_OFFSET 0.000000 \
            -CLOCK_UNCERTAINTY 0.0 \
            -RESET_KIND sync \
            -RESET_SYNC_NAME rst \
            -RESET_SYNC_ACTIVE high \
            -RESET_ASYNC_NAME arst_n \
            -RESET_ASYNC_ACTIVE low \
            -ENABLE_NAME {} \
            -ENABLE_ACTIVE high \
    } \
    }

    go assembly

    #
    #
    #

    go architect

    #
    #
    #

    go allocate

    #
    # RTL
    #

    go extract

    #
    #
    #

    if {$opt(rtlsim)} {
        flow run /SCVerify/launch_make ./scverify/Verify_rtl_v_msim.mk {} SIMTOOL=msim sim
        #####flow run /SCVerify/launch_make ./scverify/Verify_rtl_v_msim.mk {} SIMTOOL=msim simgui
    }

    if {$opt(lsynth)} {

        if {$opt(asic)} {
            flow run /DesignCompiler/dc_shell ./rtl.v.dc v
        } else {
            flow run /Vivado/synthesize -shell vivado/rtl.v.xv
        }

    }

}

project save
