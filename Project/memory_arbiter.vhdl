library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory_arbiter is
	generic(len_mem_addr: integer:= 5;
				len_data: integer:= 16);
	port(clk: in std_logic;
			from_ls_pipeline: in std_logic;
			addr_from_ls: in std_logic_vector(len_mem_addr-1 downto 0);
			addr_to_mem_for_ls: out std_logic_vector(len_mem_addr-1 downto 0);
			data_to_ls: out std_logic_vector(len_data-1 downto 0);
			data_from_mem_for_ls: in std_logic_vector(len_data-1 downto 0);
			---store work---
			from_store_buffer: in std_logic;
			addr_from_store: in std_logic_vector(len_mem_addr-1 downto 0);
			addr_to_mem_for_store: out std_logic_vector(len_mem_addr-1 downto 0);
			data_to_mem_for_store: out std_logic_vector(len_data-1 downto 0);
			data_from_store: in std_logic_vector(len_data-1 downto 0);
			request_to_store: out std_logic;
			store_happened: out std_logic);
end entity;

architecture Struct of memory_arbiter is
	signal request: std_logic;
begin
	---Load work---
	addr_to_mem_for_ls <= addr_from_ls;
	data_to_ls <= data_from_mem_for_ls;
	---Store work
	addr_to_mem_for_store <= addr_from_store;
	data_to_mem_for_store <= data_from_store;
	---Did store even happen---
	request_to_store <= '0' when from_store_buffer = '0' else
								'0' when from_ls_pipeline = '1' else
								'1';
	request <= '0' when from_store_buffer = '0' else
								'0' when from_ls_pipeline = '1' else
								'1';
	op: process(clk)
	begin
		if rising_edge(clk) then
			if request = '1' then
				store_happened <= '1';
			else
				store_happened <= '0';
			end if;
		else null;
		end if;
	end process;
	
	
end architecture;