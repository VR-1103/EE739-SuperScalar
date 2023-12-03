-- A DUT entity is used to wrap your design so that we can combine it with testbench.
-- This example shows how you can do this for the OR Gate

library ieee;
use ieee.std_logic_1164.all;

entity DUT is
    port(input_vector: in std_logic_vector(4 downto 0);
       	output_vector: out std_logic_vector(1 downto 0));
end entity;

architecture DutWrap of DUT is
   component Fourtotwoencoder is
		port(a,b,c,d,e: in std_logic;
			y1, y0: out std_logic);
	end component Fourtotwoencoder;
begin

   -- input/output vector element ordering is critical,
   -- and must match the ordering in the trace file!
   add_instance: Fourtotwoencoder 
			port map (
					-- order of inputs B A
					a => input_vector(4),
					b => input_vector(3),
					c => input_vector(2),
					d => input_vector(1),
					e => input_vector(0),
               -- order of output OUTPUT
					y1 => output_vector(1),
					y0 => output_vector(0));
end DutWrap;