# FPGA and Dev Board used in Design
TECHNOLOGY=Artix7
PART=xc7a35t
PACKAGE=cpg236
PROTOBOARD=digilentinc.com:cmod_a7-35t:part0:1.1
SPEED=1
PROMGENPAR=-u 0 $(TOP).bit -p mcs -spi -w -o $(BOARD)

# For 'Vivado Synthesis' flow set:
VIVADO_SYNTH_FLOW="Vivado Synthesis 2017"
VIVADO_SYNTH_STRATEGY="Flow_PerfOptimized_high"

# Set Vivado Implementation strategy
VIVADO_IMPL_STRATEGY="Performance_ExtraTimingOpt"
