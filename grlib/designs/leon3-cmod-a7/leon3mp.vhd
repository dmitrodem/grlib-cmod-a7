library ieee;
use ieee.std_logic_1164.all;
library grlib, techmap;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use techmap.gencomp.all;
use techmap.allclkgen.all;
library gaisler;
use gaisler.memctrl.all;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.spi.all;
use gaisler.i2c.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.l2cache.all;
use gaisler.subsys.all;
-- pragma translate_off
use gaisler.sim.all;
library unisim;
use unisim.all;
-- pragma translate_on

library esa;
use esa.memoryctrl.all;

use work.config.all;

entity leon3mp is
  generic (
    fabtech : integer := CFG_FABTECH;
    memtech : integer := CFG_MEMTECH;
    padtech : integer := CFG_PADTECH;
    disas   : integer := CFG_DISAS;     -- Enable disassembly to console
    dbguart : integer := CFG_DUART;     -- Print UART on console
    pclow   : integer := CFG_PCLOW);
  port (
    sysclk : in std_logic;

    led    : out std_logic_vector (1 downto 0);
    led0_b : out std_logic;
    led0_g : out std_logic;
    led0_r : out std_logic;

    btn : in std_logic_vector (1 downto 0);

    ja  : inout std_logic_vector (7 downto 0);
    -- pio : inout std_logic_vector (48 downto 1);

    uart_rxd_out : out std_logic;
    uart_txd_in  : in  std_logic;

    crypto_sda : inout std_logic;

    -- spi_sck   : out std_logic; -- STARTUPE2 is used instead
    spi_csn   : out std_logic;
    spi_mosi  : out std_logic;
    spi_miso  : in  std_logic;
    spi_wpn   : out std_logic;
    spi_holdn : out std_logic;

    MemAdr : out   std_logic_vector (18 downto 0);
    MemDB  : inout std_logic_vector (7 downto 0);
    RamOEn : out   std_logic;
    RamWEn : out   std_logic;
    RamCEn : out   std_logic);
end;

architecture rtl of leon3mp is

  component STARTUPE2 is
    generic (
      PROG_USR      : string := "FALSE";
      SIM_CCLK_FREQ : real   := 0.0);
    port (
      CFGCLK    : out std_ulogic;
      CFGMCLK   : out std_ulogic;
      EOS       : out std_ulogic;
      PREQ      : out std_ulogic;
      CLK       : in  std_ulogic;
      GSR       : in  std_ulogic;
      GTS       : in  std_ulogic;
      KEYCLEARB : in  std_ulogic;
      PACK      : in  std_ulogic;
      USRCCLKO  : in  std_ulogic;
      USRCCLKTS : in  std_ulogic;
      USRDONEO  : in  std_ulogic;
      USRDONETS : in  std_ulogic);
  end component STARTUPE2;

  constant maxahbm : integer := 16;
  constant maxahbs : integer := 16;
  constant maxapbs : integer := CFG_IRQ3_ENABLE+CFG_GPT_ENABLE+CFG_GRGPIO_ENABLE+CFG_AHBSTAT+CFG_AHBSTAT;

  signal vcc, gnd : std_logic;
  signal memi     : memory_in_type;
  signal memo     : memory_out_type;
  signal wpo      : wprot_out_type;

  signal apbi  : apb_slv_in_type;
  signal apbo  : apb_slv_out_vector; -- := (others => apb_none);
  signal ahbsi : ahb_slv_in_type;
  signal ahbso : ahb_slv_out_vector; -- := (others => ahbs_none);
  signal ahbmi : ahb_mst_in_type;
  signal ahbmo : ahb_mst_out_vector; -- := (others => ahbm_none);

  signal sysi : leon_dsu_stat_base_in_type;
  signal syso : leon_dsu_stat_base_out_type;

  signal perf : l3stat_in_type;

  signal clkm, locked : std_ulogic;
  signal rstn, rstraw : std_ulogic;

  signal u1i : uart_in_type;
  signal u1o : uart_out_type;

  signal irqi : irq_in_vector(0 to CFG_NCPU-1);
  signal irqo : irq_out_vector(0 to CFG_NCPU-1);

  signal gpti : gptimer_in_type;
  signal gpto : gptimer_out_type;

  signal gpioi : gpio_in_type;
  signal gpioo : gpio_out_type;

  signal lclk, rst, ndsuact       : std_ulogic;

  signal stati : ahbstat_in_type;

  signal spmi : spimctrl_in_type;
  signal spmo : spimctrl_out_type;

begin

----------------------------------------------------------------------
---  Reset and Clock generation  -------------------------------------
----------------------------------------------------------------------

  vcc <= '1'; gnd <= '0';

  clk_pad : clkpad generic map (tech => padtech) port map (pad => sysclk, o => lclk);
  clkwiz0 : entity work.clk_wiz port map (clk_in => lclk, rst => gnd, clk_out => clkm,
                                          locked => locked);

  reset_pad : inpad generic map (tech     => padtech) port map (pad => btn(0), o => rst);
  rst0      : rstgen generic map (acthigh => 1, syncin => 1)
    port map (rstin     => rst, clk => clkm, clklock => locked, rstout => rstn,
              rstoutraw => rstraw, testrst => vcc, testen => gnd);

  ahb0 : ahbctrl                        -- AHB arbiter/multiplexer
    generic map (defmast => CFG_DEFMST, split => CFG_SPLIT,
                 rrobin  => CFG_RROBIN, ioaddr => CFG_AHBIO, fpnpen => CFG_FPNPEN,
                 nahbm   => maxahbm, nahbs => maxahbs, devid => XILINX_AC701)
    port map (rst    => rstn, clk => clkm,
              msti   => ahbmi, msto => ahbmo, slvi => ahbsi, slvo => ahbso,
              testen => gnd, testrst => vcc, testoen => vcc, testsig => (others => '0'));

  leon : leon_dsu_stat_base
    generic map (
      leon       => CFG_LEON, ncpu => CFG_NCPU, fabtech => fabtech, memtech => memtech,
      memtechmod => CFG_LEON_MEMTECH,
      nwindows   => CFG_NWIN, dsu => CFG_DSU, fpu => CFG_FPU, v8 => CFG_V8, cp => 0,
      mac        => CFG_MAC, pclow => pclow, notag => 0, nwp => CFG_NWP, icen => CFG_ICEN,
      irepl      => CFG_IREPL, isets => CFG_ISETS, ilinesize => CFG_ILINE,
      isetsize   => CFG_ISETSZ, isetlock => CFG_ILOCK, dcen => CFG_DCEN,
      drepl      => CFG_DREPL, dsets => CFG_DSETS, dlinesize => CFG_DLINE,
      dsetsize   => CFG_DSETSZ, dsetlock => CFG_DLOCK, dsnoop => CFG_DSNOOP,
      ilram      => CFG_ILRAMEN, ilramsize => CFG_ILRAMSZ, ilramstart => CFG_ILRAMADDR,
      dlram      => CFG_DLRAMEN, dlramsize => CFG_DLRAMSZ, dlramstart => CFG_DLRAMADDR,
      mmuen      => CFG_MMUEN, itlbnum => CFG_ITLBNUM, dtlbnum => CFG_DTLBNUM,
      tlb_type   => CFG_TLB_TYPE, tlb_rep => CFG_TLB_REP, lddel => CFG_LDDEL,
      disas      => disas, tbuf => CFG_ITBSZ, pwd => CFG_PWD, svt => CFG_SVT,
      rstaddr    => CFG_RSTADDR, smp => CFG_NCPU-1, cached => CFG_DFIXED,
      wbmask     => CFG_BWMASK, busw => CFG_CACHEBW, netlist => CFG_LEON_NETLIST,
      ft         => CFG_LEONFT_EN, npasi => CFG_NP_ASI, pwrpsr => CFG_WRPSR,
      rex        => CFG_REX, altwin => CFG_ALTWIN, mmupgsz => CFG_MMU_PAGE,
      grfpush    => CFG_GRFPUSH,
      dsu_hindex => 2, dsu_haddr => 16#900#, dsu_hmask => 16#F00#, atbsz => CFG_ATBSZ,
      stat       => CFG_STAT_ENABLE, stat_pindex => 13, stat_paddr => 16#100#,
      stat_pmask => 16#ffc#, stat_ncnt => CFG_STAT_CNT, stat_nmax => CFG_STAT_NMAX)
    port map (
      rstn       => rstn, ahbclk => clkm, cpuclk => clkm, hclken => vcc,
      leon_ahbmi => ahbmi, leon_ahbmo => ahbmo(CFG_NCPU-1 downto 0),
      leon_ahbsi => ahbsi, leon_ahbso => ahbso,
      irqi       => irqi, irqo => irqo,
      stat_apbi  => apbi, stat_apbo => apbo(13), stat_ahbsi => ahbsi,
      stati      => perf,
      dsu_ahbsi  => ahbsi, dsu_ahbso => ahbso(2),
      dsu_tahbmi => ahbmi, dsu_tahbsi => ahbsi,
      sysi       => sysi, syso => syso);

  perf <= l3stat_in_none;

  error_pad : outpad generic map (tech => padtech) port map (pad => led(0), i => syso.proc_error);
  sysi.dsu_enable <= vcc;

  dsui_break_pad : inpad generic map (level => cmos) port map (pad => btn(1), o => sysi.dsu_break);
  dsuact_pad     : outpad generic map (tech => padtech) port map (pad => led(1), i => ndsuact);
  ndsuact <= not syso.dsu_active;

  ahbjtaggen0 : if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => CFG_NCPU)
      port map(rst        => rstn, clk => clkm,
               tck        => gnd, tms => gnd, tdi => gnd, tdo => open,
               ahbi       => ahbmi, ahbo => ahbmo(CFG_NCPU),
               tapo_tck   => open, tapo_tdi => open, tapo_inst => open,
               tapo_rst   => open, tapo_capt => open, tapo_shft => open,
               tapo_upd   => open, tapi_tdo => gnd, trst => vcc,
               tdoen      => open, tckn => gnd, tapo_tckn => open,
               tapo_ninst => open, tapo_iupd => open);
  end generate;

  spimc : if CFG_SPIMCTRL = 1 generate
    spimctrl0 : spimctrl                -- SPI Memory Controller
      generic map (hindex     => 0, hirq => 1,
                   faddr      => 16#000#, fmask  => 16#ff8#,
                   ioaddr     => 16#000#, iomask => 16#ff8#,
                   spliten    => CFG_SPLIT, oepol => 0,
                   sdcard     => CFG_SPIMCTRL_SDCARD,
                   readcmd    => CFG_SPIMCTRL_READCMD,
                   dummybyte  => CFG_SPIMCTRL_DUMMYBYTE,
                   dualoutput => CFG_SPIMCTRL_DUALOUTPUT,
                   scaler     => CFG_SPIMCTRL_SCALER,
                   altscaler  => CFG_SPIMCTRL_ASCALER,
                   pwrupcnt   => CFG_SPIMCTRL_PWRUPCNT)
      port map (rstn  => rstn, clk => clkm,
                ahbsi => ahbsi, ahbso => ahbso(0),
                spii  => spmi, spio => spmo);
  end generate;


  nospimc : if CFG_SPIMCTRL = 0 generate
    spmo.mosi <= gnd;
    spmo.csn <= vcc;
    ahbso(0) <= ahbs_none;
  end generate;

  miso_pad       : inpad generic map (tech  => padtech) port map (pad => spi_miso, o => spmi.miso);
  mosi_pad       : outpad generic map (tech => padtech) port map (pad => spi_mosi, i => spmo.mosi);
  slvsel0_pad    : odpad generic map (tech  => padtech) port map (pad => spi_csn, i => spmo.csn);
  STARTUPE2_inst : STARTUPE2
    generic map (PROG_USR => "FALSE", SIM_CCLK_FREQ => 10.0)
    port map (CFGCLK   => open, CFGMCLK => open, EOS => open, PREQ => open,
              CLK      => gnd, GSR => gnd, GTS => gnd, KEYCLEARB => gnd, PACK => gnd,
              USRCCLKO => spmo.sck, USRCCLKTS => gnd, USRDONEO => vcc, USRDONETS => vcc);
  wpn_pad   : outpad generic map (tech => padtech) port map (pad => spi_wpn, i => vcc);
  holdn_pad : outpad generic map (tech => padtech) port map (pad => spi_holdn, i => vcc);

  mctrl0 : mctrl
    generic map (
      hindex  => 1, pindex => 0, paddr => 0,
      romaddr => 16#100#, rommask => 16#FFF#,
      ioaddr  => 16#101#, iomask => 16#FFF#,
      ramaddr => 16#400#, rammask => 16#FFF#,
      romasel => 28, sdrasel => 29,
      srbanks => 1,
      ram8    => 1, ram16 => 0,
      sden    => 0, oepol => 0)
    port map (
      rst   => rstn, clk => clkm,
      memi  => memi, memo => memo,
      ahbsi => ahbsi, ahbso => ahbso(1),
      apbi  => apbi, apbo => apbo(0),
      wpo   => wpo, sdo => open);

  wpo.wprothit <= gnd;

  address_pad : outpadv generic map (tech => padtech, width => 19)
    port map (pad => MemAdr, i => memo.address (18 downto 0));

  data_pad : iopadv generic map (tech => padtech, width => 8)
    port map (pad => MemDB, i => memo.data (31 downto 24),
              en  => memo.bdrive(0), o => memi.data (31 downto 24));
  memi.data(23 downto 0) <= (others => '0');
  ram_oen_pad : outpad generic map (tech => padtech)
    port map (pad => RamOEn, i => memo.oen);
  ram_wen_pad : outpad generic map (tech => padtech)
    port map (pad => RamWEn, i => memo.writen);
  ram_cen_pad : outpad generic map (tech => padtech)
    port map (pad => RamCEn, i => memo.ramsn(0));

  memi.brdyn <= vcc; memi.bexcn <= vcc; memi.writen <= vcc;
  memi.wrn   <= "1111"; memi.bwidth <= "10";
  memi.cb <= (others => '0'); memi.edac <= gnd;
  memi.scb <= (others => '0'); memi.sd <= (others => '0');


  apb0 : apbctrl                        -- AHB/APB bridge
    generic map (hindex => 3, haddr => CFG_APBADDR, nslaves => 16, debug => 2)
    port map (rst  => rstn, clk => clkm,
              ahbi => ahbsi, ahbo => ahbso(3),
              apbi => apbi, apbo => apbo);

  irqctrl : if CFG_IRQ3_ENABLE /= 0 generate
    irqctrl0 : irqmp                    -- interrupt controller
      generic map (pindex => 2, paddr => 2, ncpu => CFG_NCPU)
      port map (rst    => rstn, clk => clkm,
                apbi   => apbi, apbo => apbo(2),
                irqi   => irqo, irqo => irqi,
                cpurun => (others => '0'));
  end generate;
  irq3 : if CFG_IRQ3_ENABLE = 0 generate
    x : for i in 0 to CFG_NCPU-1 generate
      irqi(i).irl <= "0000";
    end generate;
    apbo(2) <= apb_none;
  end generate;

  gpt : if CFG_GPT_ENABLE /= 0 generate
    timer0 : gptimer                    -- timer unit
      generic map (pindex => 3, paddr => 3, pirq => CFG_GPT_IRQ,
                   sepirq => CFG_GPT_SEPIRQ, sbits => CFG_GPT_SW, ntimers => CFG_GPT_NTIM,
                   nbits  => CFG_GPT_TW, wdog => CFG_GPT_WDOGEN*CFG_GPT_WDOG)
      port map (rst => rstn, clk => clkm,
                apbi => apbi, apbo => apbo(3),
                gpti => gpti, gpto =>  gpto);
    gpti <= gpti_dhalt_drive(syso.dsu_tstop);
  end generate;

  nogpt : if CFG_GPT_ENABLE = 0 generate apbo(3) <= apb_none; end generate;

  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate  -- GPIO unit
    grgpio0 : grgpio
      generic map(pindex => 10, paddr => 10, imask => CFG_GRGPIO_IMASK, nbits => 32)
      port map(rst   => rstn, clk => clkm,
               apbi => apbi, apbo => apbo(10),
               gpioi => gpioi, gpioo => gpioo);
  end generate;

  nogpio0: if CFG_GRGPIO_ENABLE = 0 generate
    apbo(10) <= apb_none;
    gpioo.dout <= (others => '0');
    gpioo.oen <= (others => '1');
  end generate nogpio0;

  ja_pads : for i in 0 to 7 generate
    ja_pad : iopad generic map (tech => padtech)
      port map (pad => ja(i), i => gpioo.dout(i), en => gpioo.oen(i), o => gpioi.din(i));
  end generate;

  led_r_pad : outpad generic map (tech => padtech)
    port map (pad => led0_r, i => gpioo.dout(8));
  led_g_pad : outpad generic map (tech => padtech)
    port map (pad => led0_g, i => gpioo.dout(9));
  led_b_pad : outpad generic map (tech => padtech)
    port map (pad => led0_b, i => gpioo.dout(10));

  gpioi.din(31 downto 8) <= (others => '0');

  ua1 : if CFG_UART1_ENABLE /= 0 generate
    uart1 : apbuart                     -- UART 1
      generic map (pindex   => 1, paddr => 1, pirq => 2, console => dbguart,
                   fifosize => CFG_UART1_FIFO)
      port map (rst => rstn, clk => clkm,
                apbi => apbi, apbo => apbo(1),
                uarti => u1i, uarto => u1o);
  end generate;
  noua0 : if CFG_UART1_ENABLE = 0 generate
    apbo(1) <= apb_none;
    u1o.txd <= vcc;
  end generate;

  u1i.ctsn <= gnd; u1i.extclk <= gnd;
  uart_rxd_pad : inpad generic map (tech => padtech) port map (pad => uart_txd_in, o => u1i.rxd);
  uart_txd_pad : outpad generic map (tech => padtech) port map (pad => uart_rxd_out, i => u1o.txd);

  ahbs : if CFG_AHBSTAT = 1 generate    -- AHB status register
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat generic map (pindex => 15, paddr => 15, pirq => 7,
                                    nftslv => CFG_AHBSTATN)
      port map (rst => rstn, clk => clkm,
                ahbmi => ahbmi, ahbsi => ahbsi, stati => stati,
                apbi => apbi, apbo => apbo(15));
  end generate;
  noahbs : if CFG_AHBSTAT /= 1 generate
    apbo(15) <= apb_none;
  end generate noahbs;

-----------------------------------------------------------------------
---  Test report module  ----------------------------------------------
-----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep generic map (hindex => 4, haddr => 16#200#)
    port map (rst => rstn, clk => clkm,
              ahbi => ahbsi, ahbo => ahbso(4));
  -- pragma translate_on

  -----------------------------------------------------------------------
  ---  Drive unused bus elements  ---------------------------------------
  -----------------------------------------------------------------------

  nam1 : for i in (CFG_NCPU+CFG_AHB_JTAG) to NAHBMST-1 generate
    ahbmo(i) <= ahbm_none;
  end generate;

  nas1 : for i in 4
           -- pragma translate_off
           + 1
           -- pragma translate_on
           to NAHBSLV-1 generate
    ahbso(i) <= ahbs_none;
  end generate nas1;

  apbo(4)  <= apb_none;
  apbo(5)  <= apb_none;
  apbo(6)  <= apb_none;
  apbo(7)  <= apb_none;
  apbo(8)  <= apb_none;
  apbo(9)  <= apb_none;
  apbo(11) <= apb_none;
  apbo(12) <= apb_none;
  apbo(14) <= apb_none;

  -----------------------------------------------------------------------
  ---  Boot message  ----------------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  x : report_design
    generic map (
      msg1    => "LEON3 Digileng CMOD A7 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
      );
-- pragma translate_on
end;
