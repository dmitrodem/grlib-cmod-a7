# leon3-cmod-a7
This design is taylored for [Digilent CMOD A7](https://example.com) board.

# Design Specifics
- Onboard SRAM is connected to ESA MCTRL and is mapped to addresses `0x40000000..0x40001000`. Other memory areas decoded by MCTRL (PROM and IO) are left unconnected
- Onboard SPI flash device is connected to SPIMCTRL core and is mapped to addresses `0x00000000..0x00001000`.
- System reset is mapped to `btn[0]`
- DSU Break signal is mapped to `btn[1]`
- `led[0]` indicates if processor is in error mode
- `led[1]` shows state of DSU activity
- `ja[7:0]` pins are mapped to lower byte of GRGPIO
- `led0_r`, `led0_g`, `led0_b` are mapped to GRGPIO bits 8, 9 and 10, respectively.

# Simulation
Right now `testbench.vhd` is inconsistent.

# Synthesis
Synthesis has been carried out with Vivado 2017.x using command
```
make vivado
```
Generated firmware (leon3mp.bit file) can be uploaded to the target using `upload_bit.tcl` script:
```
vivado -mode batch -source upload_bit.tcl
```
Programming of the onboard SPI flash is accomplished by executing script `upload_mcs.tcl`:
```
vivado -mode batch -source upload_mcs.tcl
```
# Notes on GRMON
Digilent lacks information of how FT2232H is connected to the FPGA, however, it looks like it works like regular FTDI MPSSE-based JTAG device if the ADBUS7 is driven to high level. So, `grmon` can be run as
```
grmon -ftdi -ftdigpio 0x00800080 -u
```
Unfortunately, `grmon` exists if it finds substring "Digilent". So a simple patch for [libftdi-0.20](https://www.intra2net.com/en/developer/libftdi/download/libftdi-0.20.tar.gz) is needed at the moment:
```diff
--- b/src/ftdi.c        2012-03-15 13:58:44.000000000 +0400
+++ a/src/ftdi.c        2019-03-06 17:16:07.471637868 +0300
@@ -394,6 +394,14 @@
     if (ftdi_usb_close_internal (ftdi) != 0)
         ftdi_error_return(-10, usb_strerror());

+    if (getenv("GRMON_DIGILENT_HACK")) {
+      if (desc_len > 0) {
+        if (strcmp("Digilent Adept USB Device", description) == 0) {
+          strncpy(description, "FTDI", desc_len);
+        }
+      }
+    }
+
     return 0;
 }
```
It replaces "Digilent Adept USB device" string with generic "FTDI" if the environment variable `GRMON_DIGILENT_HACK` is set.

# GRMON example output
```
$ GRMON_DIGILENT_HACK=1 /tmp/grmon-eval-3.0.13/linux/bin64/grmon -ftdi -ftdigpio 0x00800080

  GRMON LEON debug monitor v3.0.13 64-bit eval version

  Copyright (C) 2018 Cobham Gaisler - All rights reserved.
  For latest updates, go to http://www.gaisler.com/
  Comments or bug-reports to support@gaisler.com

  This eval version will expire on 28/05/2019

JTAG chain (1): xc7a35t
  Device ID:           0xA701
  GRLIB build version: 4226
  Detected frequency:  75 MHz

  Component                            Vendor
  LEON3 SPARC V8 Processor             Cobham Gaisler
  JTAG Debug Link                      Cobham Gaisler
  SPI Memory Controller                Cobham Gaisler
  LEON2 Memory Controller              European Space Agency
  LEON3 Debug Support Unit             Cobham Gaisler
  AHB/APB Bridge                       Cobham Gaisler
  Generic UART                         Cobham Gaisler
  Multi-processor Interrupt Ctrl.      Cobham Gaisler
  Modular Timer Unit                   Cobham Gaisler
  General Purpose I/O port             Cobham Gaisler
  LEON3 Statistics Unit                Cobham Gaisler

  Use command 'info sys' to print a detailed report of attached cores

grmon3> info sys
  cpu0      Cobham Gaisler  LEON3 SPARC V8 Processor
            AHB Master 0
  ahbjtag0  Cobham Gaisler  JTAG Debug Link
            AHB Master 1
  spim0     Cobham Gaisler  SPI Memory Controller
            AHB: FFF00000 - FFF00100
            AHB: 00000000 - 00800000
            IRQ: 1
            SPI memory device read command: 0x0b
  mctrl0    European Space Agency  LEON2 Memory Controller
            AHB: 10000000 - 10100000
            AHB: 10100000 - 10200000
            AHB: 40000000 - 40100000
            APB: 80000000 - 80000100
            32-bit prom @ 0x10000000
            8-bit static ram: 1 * 1024 kbyte @ 0x40000000
  dsu0      Cobham Gaisler  LEON3 Debug Support Unit
            AHB: 90000000 - A0000000
            AHB trace: 256 lines, 32-bit bus
            CPU0:  win 8, nwp 4, itrace 256, V8 mul/div, lddel 1, GRFPU-lite
                   stack pointer 0x400ffff0
                   icache 2 * 4 kB, 16 B/line
                   dcache 2 * 4 kB, 16 B/line, snoop tags
  apbmst0   Cobham Gaisler  AHB/APB Bridge
            AHB: 80000000 - 80100000
  uart0     Cobham Gaisler  Generic UART
            APB: 80000100 - 80000200
            IRQ: 2
            Baudrate 38422, FIFO debug mode
  irqmp0    Cobham Gaisler  Multi-processor Interrupt Ctrl.
            APB: 80000200 - 80000300
  gptimer0  Cobham Gaisler  Modular Timer Unit
            APB: 80000300 - 80000400
            IRQ: 8
            8-bit scalar, 2 * 32-bit timers, divisor 75
  gpio0     Cobham Gaisler  General Purpose I/O port
            APB: 80000A00 - 80000B00
  l3stat0   Cobham Gaisler  LEON3 Statistics Unit
            APB: 80010000 - 80010400
            counters: 4, i/f index: 0

grmon3>
```
