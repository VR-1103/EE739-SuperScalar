library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory_arbiter is
	port(clk: in std_logic;
			from_ls_pipeline: in std_logic;
			from_store_buffer: in std_logic;
			to_store_buffer: out std_logic);
end entity;

architecture Struct of memory_arbiter is
begin
	op:process(clk)
	begin
		if rising_edge(clk) then
			if from_ls_pipeline = '1' then
				to_store_buffer <= '0';
			else
				if from_store_buffer = '1' then
					to_store_buffer <= '1';
				else to_store_buffer <= '0';
				end if;
			end if;
		else null;
		end if;
end architecture;