library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity fetch_block is ----this does not have the temp register for pc, that needs to be made separately----
	generic(len_PC: integer:=5;
				len_mem_addr: integer:=len_PC;
				len_data: integer:=16);
	port(clk: in std_logic;
			from_rob,from_temp_reg: in std_logic_vector(len_PC-1 downto 0);
			control_bit: in std_logic; ---to decide if instr addr is coming from rob or temp_reg
			disable_bit1,disable_bit2: in std_logic;
			to_mem1,to_mem2: out std_logic_vector(len_mem_addr-1 downto 0);
			from_mem1,from_mem2: in std_logic_vector(len_data-1 downto 0);
			instr1,instr2: out std_logic_vector(len_data+len_PC-1 downto 0);
			instr_validity1,instr_validity2: out std_logic;
			next_pc_addr: out std_logic_vector(len_PC-1 downto 0););
end entity fetch_block;

architecture struct of fetch_block is
	signal pc_addr1,pc_addr2: std_logic_vector(len_PC-1 downto 0);
	signal pc_addr2_temp,next_pc_addr_temp: std_logic_vector(len_PC downto 0);
	signal disable1,disable2: std_logic;
begin
	pc_addr1 <= from_rob when control_bit = '1' else
					from_temp_reg when control_bit = '0';
	disable1 <= '0' when control_bit = '1' else ----We dont need to care about whatever is in decoder when the new instr is coming from rob
					disable_bit1 when control_bit = '0';
	disable2 <= '0' when control_bit = '1' else
					disable_bit2 when control_bit = '0';
	pc_addr2_temp <= ('0' & pc_addr1) + "000100";
	next_pc_addr_temp <= pc_addr2_temp + "000100";
	pc_addr2 <= pc_addr2_temp(len_PC-1 downto 0);
	next_pc_addr <= next_pc_addr_temp(len_PC-1 downto 0);
	to_mem1 <= pc_addr1;
	to_mem2 <= pc_addr2;
	
	getting_instr_op: process(clk)
	begin
		instr1(len_data+len_PC-1 downto len_data) <= pc_addr1;
		instr2(len_data+len_PC-1 downto len_data) <= pc_addr2;
		instr1(len_data-1 downto 0) <= from_mem1;
		instr2(len_data-1 downto 0) <= from_mem2;
		instr_validity1 <= disable1;
		instr_validity2 <= disable2;
	end process;

end struct;