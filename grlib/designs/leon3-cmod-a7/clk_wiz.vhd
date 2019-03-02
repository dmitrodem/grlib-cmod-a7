-------------------------------------------------------------------------------
--! @file      clk_wiz.vhd
--! @brief     Clock generator
--! @details   12MHz input clock, 750MHz VCO clock, 100MHz output clock
--! @author    Dmitriy Dyomin  <dmitrodem@gmail.com>
--! @date      2019-03-02
--! @version   0.1
--! @copyright Copyright (c) MIPT 2019
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

--pragma translate_off
library unisim;
use unisim.vcomponents.all;
--pragma translate_on

entity clk_wiz is
  port (
    clk_in  : in  std_logic;
    rst     : in  std_logic;            -- active high
    clk_out : out std_logic;
    locked  : out std_logic);           -- active high
end entity clk_wiz;

architecture rtl of clk_wiz is
  component MMCME2_ADV is
    generic (
      BANDWIDTH            : string  := "OPTIMIZED";
      CLKFBOUT_MULT_F      : real    := 5.000;
      CLKFBOUT_PHASE       : real    := 0.000;
      CLKFBOUT_USE_FINE_PS : boolean := FALSE;
      CLKIN1_PERIOD        : real    := 0.000;
      CLKIN2_PERIOD        : real    := 0.000;
      CLKOUT0_DIVIDE_F     : real    := 1.000;
      CLKOUT0_DUTY_CYCLE   : real    := 0.500;
      CLKOUT0_PHASE        : real    := 0.000;
      CLKOUT0_USE_FINE_PS  : boolean := FALSE;
      CLKOUT1_DIVIDE       : integer := 1;
      CLKOUT1_DUTY_CYCLE   : real    := 0.500;
      CLKOUT1_PHASE        : real    := 0.000;
      CLKOUT1_USE_FINE_PS  : boolean := FALSE;
      CLKOUT2_DIVIDE       : integer := 1;
      CLKOUT2_DUTY_CYCLE   : real    := 0.500;
      CLKOUT2_PHASE        : real    := 0.000;
      CLKOUT2_USE_FINE_PS  : boolean := FALSE;
      CLKOUT3_DIVIDE       : integer := 1;
      CLKOUT3_DUTY_CYCLE   : real    := 0.500;
      CLKOUT3_PHASE        : real    := 0.000;
      CLKOUT3_USE_FINE_PS  : boolean := FALSE;
      CLKOUT4_CASCADE      : boolean := FALSE;
      CLKOUT4_DIVIDE       : integer := 1;
      CLKOUT4_DUTY_CYCLE   : real    := 0.500;
      CLKOUT4_PHASE        : real    := 0.000;
      CLKOUT4_USE_FINE_PS  : boolean := FALSE;
      CLKOUT5_DIVIDE       : integer := 1;
      CLKOUT5_DUTY_CYCLE   : real    := 0.500;
      CLKOUT5_PHASE        : real    := 0.000;
      CLKOUT5_USE_FINE_PS  : boolean := FALSE;
      CLKOUT6_DIVIDE       : integer := 1;
      CLKOUT6_DUTY_CYCLE   : real    := 0.500;
      CLKOUT6_PHASE        : real    := 0.000;
      CLKOUT6_USE_FINE_PS  : boolean := FALSE;
      COMPENSATION         : string  := "ZHOLD";
      DIVCLK_DIVIDE        : integer := 1;
      REF_JITTER1          : real    := 0.0;
      REF_JITTER2          : real    := 0.0;
      SS_EN                : string  := "FALSE";
      SS_MODE              : string  := "CENTER_HIGH";
      SS_MOD_PERIOD        : integer := 10000;
      STARTUP_WAIT         : boolean := FALSE);
    port (
      CLKFBOUT     : out std_ulogic := '0';
      CLKFBOUTB    : out std_ulogic := '0';
      CLKFBSTOPPED : out std_ulogic := '0';
      CLKINSTOPPED : out std_ulogic := '0';
      CLKOUT0      : out std_ulogic := '0';
      CLKOUT0B     : out std_ulogic := '0';
      CLKOUT1      : out std_ulogic := '0';
      CLKOUT1B     : out std_ulogic := '0';
      CLKOUT2      : out std_ulogic := '0';
      CLKOUT2B     : out std_ulogic := '0';
      CLKOUT3      : out std_ulogic := '0';
      CLKOUT3B     : out std_ulogic := '0';
      CLKOUT4      : out std_ulogic := '0';
      CLKOUT5      : out std_ulogic := '0';
      CLKOUT6      : out std_ulogic := '0';
      DO           : out std_logic_vector (15 downto 0);
      DRDY         : out std_ulogic := '0';
      LOCKED       : out std_ulogic := '0';
      PSDONE       : out std_ulogic := '0';
      CLKFBIN      : in  std_ulogic;
      CLKIN1       : in  std_ulogic;
      CLKIN2       : in  std_ulogic;
      CLKINSEL     : in  std_ulogic;
      DADDR        : in  std_logic_vector(6 downto 0);
      DCLK         : in  std_ulogic;
      DEN          : in  std_ulogic;
      DI           : in  std_logic_vector(15 downto 0);
      DWE          : in  std_ulogic;
      PSCLK        : in  std_ulogic;
      PSEN         : in  std_ulogic;
      PSINCDEC     : in  std_ulogic;
      PWRDWN       : in  std_ulogic;
      RST          : in  std_ulogic);
  end component MMCME2_ADV;

  component BUFG is
    port (
      O : out std_ulogic;
      I : in  std_ulogic);
  end component BUFG;

  signal clkfbout, clkfbout_buf, clk_out0 : std_logic;

begin  -- architecture rtl

  u0: MMCME2_ADV
    generic map (
      BANDWIDTH            => "OPTIMIZED",
      CLKFBOUT_MULT_F      => 62.5,
      CLKFBOUT_PHASE       => 0.000,
      CLKFBOUT_USE_FINE_PS => FALSE,
      CLKIN1_PERIOD        => 83.333,
      CLKIN2_PERIOD        => 0.000,
      CLKOUT0_DIVIDE_F     => 10.000,
      CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT0_PHASE        => 0.000,
      CLKOUT0_USE_FINE_PS  => FALSE,
      CLKOUT1_DIVIDE       => 1,
      CLKOUT1_DUTY_CYCLE   => 0.500,
      CLKOUT1_PHASE        => 0.000,
      CLKOUT1_USE_FINE_PS  => FALSE,
      CLKOUT2_DIVIDE       => 1,
      CLKOUT2_DUTY_CYCLE   => 0.500,
      CLKOUT2_PHASE        => 0.000,
      CLKOUT2_USE_FINE_PS  => FALSE,
      CLKOUT3_DIVIDE       => 1,
      CLKOUT3_DUTY_CYCLE   => 0.500,
      CLKOUT3_PHASE        => 0.000,
      CLKOUT3_USE_FINE_PS  => FALSE,
      CLKOUT4_CASCADE      => FALSE,
      CLKOUT4_DIVIDE       => 1,
      CLKOUT4_DUTY_CYCLE   => 0.500,
      CLKOUT4_PHASE        => 0.000,
      CLKOUT4_USE_FINE_PS  => FALSE,
      CLKOUT5_DIVIDE       => 1,
      CLKOUT5_DUTY_CYCLE   => 0.500,
      CLKOUT5_PHASE        => 0.000,
      CLKOUT5_USE_FINE_PS  => FALSE,
      CLKOUT6_DIVIDE       => 1,
      CLKOUT6_DUTY_CYCLE   => 0.500,
      CLKOUT6_PHASE        => 0.000,
      CLKOUT6_USE_FINE_PS  => FALSE,
      COMPENSATION         => "ZHOLD",
      DIVCLK_DIVIDE        => 1,
      REF_JITTER1          => 0.0,
      REF_JITTER2          => 0.0,
      SS_EN                => "FALSE",
      SS_MODE              => "CENTER_HIGH",
      SS_MOD_PERIOD        => 10000,
      STARTUP_WAIT         => FALSE)
    port map (
      CLKFBOUT     => clkfbout,
      CLKFBOUTB    => open,
      CLKFBSTOPPED => open,
      CLKINSTOPPED => open,
      CLKOUT0      => clk_out0,
      CLKOUT0B     => open,
      CLKOUT1      => open,
      CLKOUT1B     => open,
      CLKOUT2      => open,
      CLKOUT2B     => open,
      CLKOUT3      => open,
      CLKOUT3B     => open,
      CLKOUT4      => open,
      CLKOUT5      => open,
      CLKOUT6      => open,
      DO           => open,
      DRDY         => open,
      LOCKED       => locked,
      PSDONE       => open,
      CLKFBIN      => clkfbout_buf,
      CLKIN1       => clk_in,
      CLKIN2       => '0',
      CLKINSEL     => '1',
      DADDR        => "0000000",
      DCLK         => '0',
      DEN          => '0',
      DI           => "0000000000000000",
      DWE          => '0',
      PSCLK        => '0',
      PSEN         => '0',
      PSINCDEC     => '0',
      PWRDWN       => '0',
      RST          => rst);

  clk_buf : BUFG port map (O => clkfbout_buf, I => clkfbout);
  clk_out_buf : BUFG port map (O => clk_out, I => clk_out0);

end architecture rtl;
