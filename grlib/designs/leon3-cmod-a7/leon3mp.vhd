-----------------------------------------------------------------------------
--  LEON Xilinx AC701 Demonstration design
------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2018, Cobham Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library techmap;
use techmap.gencomp.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

library gaisler;
use gaisler.misc.all;
use gaisler.jtag.all;

use work.config.all;

entity leon3mp is
  generic (
    fabtech : integer := CFG_FABTECH;
    memtech : integer := CFG_MEMTECH;
    padtech : integer := CFG_PADTECH;
    clktech : integer := CFG_CLKTECH;
    disas   : integer := CFG_DISAS;     -- Enable disassembly to console
    dbguart : integer := CFG_DUART;     -- Print UART on console
    pclow   : integer := CFG_PCLOW);
  port (
    sysclk : in std_logic;
    btn    : in std_logic_vector (1 downto 0));
end;

architecture rtl of leon3mp is
  constant maxahbm : integer := 1;
  constant maxahbs : integer := 1;

  signal vcc, gnd : std_logic;

  signal ahbsi : ahb_slv_in_type;
  signal ahbso : ahb_slv_out_vector;
  signal ahbmi : ahb_mst_in_type;
  signal ahbmo : ahb_mst_out_vector;

  signal clkm         : std_ulogic;
  signal rstn, rstraw : std_ulogic;

  signal lock, lclk, rst : std_ulogic;

  attribute keep         : boolean;
  attribute keep of clkm : signal is true;
begin

  vcc <= '1'; gnd <= '0';

  clk_pad_ds : clkpad generic map (tech => padtech) port map (sysclk, lclk);
  clk_wiz_impl : entity work.clk_wiz port map (clk_out1 => clkm, reset => gnd,
                                               locked   => lock, clk_in1 => lclk);

  reset_pad : inpad generic map (tech => padtech) port map (btn(0), rst);

  rst0 : rstgen                         -- reset generator
    generic map (acthigh => 1, syncin => 0)
    port map (rst, clkm, lock, rstn, rstraw);

----------------------------------------------------------------------
---  AHB CONTROLLER --------------------------------------------------
----------------------------------------------------------------------

  ahb0 : ahbctrl                        -- AHB arbiter/multiplexer
    generic map (defmast => CFG_DEFMST, split => CFG_SPLIT,
                 rrobin  => CFG_RROBIN, ioaddr => CFG_AHBIO, fpnpen => CFG_FPNPEN,
                 nahbm   => maxahbm, nahbs => maxahbs)
    port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);

  ahbjtag0 : ahbjtag generic map(tech => fabtech, hindex => 0)
    port map(rstn, clkm, gnd, gnd, gnd, open, ahbmi, ahbmo(0),
             open, open, open, open, open, open, open, gnd);

  noahbs : for i in 0 to ahbso'left generate
    ahbso(i) <= ahbs_none;
  end generate noahbs;

  noahbm : for i in 1 to ahbmo'left generate
    ahbmo(i) <= ahbm_none;
  end generate noahbm;

end;
