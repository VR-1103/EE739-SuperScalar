library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity pc_register is
	generic(len_PC: integer:= 5;
				len_data: integer:= 16;
				len_mem_addr: integer:= 5);
	port(clk: in std_logic;
			from_r0: in std_logic_vector(len_data-1 downto 0);
			from_fetch: in std_logic_vector(len_PC-1 downto 0);
			to_fetch: out std_logic_vector(len_PC-1 downto 0));
end entity;

architecture Struct of pc_register is
	signal beginning: std_logic:= '1';
begin
	op: process(clk)
	begin
		if beginning = '0' then
			to_fetch <= from_fetch;
		else
			to_fetch <= from_r0;
			beginning <= '0';
		end if;
	end process;
		
end Struct;