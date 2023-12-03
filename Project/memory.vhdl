library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory is
	generic(len_mem_addr: integer:= 5;
				len_data: integer:= 16;
				size_mem: integer:= 32);
	port(clk: in std_logic;
			from_fetch1,from_fetch2: in std_logic_vector(len_mem_addr-1 downto 0);
			from_ls_pipeline: in std_logic_vector(len_mem_addr-1 downto 0); ---coming from arbiter---
			from_store_buffer: in std_logic_vector(len_mem_addr-1 downto 0); ---coming from arbiter---
			data_from_store: in std_logic_vector(len_data-1 downto 0); ---coming from arbiter---
			valid_store: in std_logic; ---connected to 'request_to_store' port of arbiter---
			to_fetch1,to_fetch2: out std_logic_vector(len_data-1 downto 0);
			to_ls_pipeline: out std_logic_vector(len_data-1 downto 0) ---going to arbiter---
			);
end entity;

architecture struct of memory is
	type mem_row_type is array(0 to size_mem-1) of std_logic_vector(len_data-1 downto 0);
	constant default_row : std_logic_vector(len_data - 1 downto 0) := (others => '0');
	signal mem_row: mem_row_type := (others => default_row);
begin
	op: process(clk)
	begin
		if rising_edge(clk) then
			to_fetch1 <= mem_row(to_integer(unsigned(from_fetch1)));
			to_fetch2 <= mem_row(to_integer(unsigned(from_fetch2)));
			to_ls_pipeline <= mem_row(to_integer(unsigned(from_ls_pipeline)));
			if valid_store = '1' then
				mem_row(to_integer(unsigned(from_store_buffer))) <= data_from_store;
			else null;
			end if;
		else null;
		end if;
	end process;
end architecture;