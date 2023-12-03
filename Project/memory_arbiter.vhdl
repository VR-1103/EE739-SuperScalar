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
			port_is_free: out std_logic);
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
	---Is port free?---
	port_is_free <= not from_ls_pipeline;
	---Does store buffer want to store---
	request_to_store <= from_store_buffer;
	
	
end architecture;