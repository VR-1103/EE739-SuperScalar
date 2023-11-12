library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity int_RS is
	 -- The RS only cares about the PC, control word, operands or the address of where to update them from, and maybe destination RRF? 
    generic(len_PC: integer := 5; -- Length of the PC which RS receives for each instruction
				len_control: integer := 16 -- Length of the control word for the integer pipeline
            len_RRF: integer := 6; -- Length of the destination RRF which the RS receives for each instruction
            len_operand: integer := 32 -- Length of the two operands. This is more than the length of the addresses in the PRF so that address can fit as well  
            size_rs: integer := 64; -- Size of RS table
				len_status: integer := 6; --status register. It is 6 so that renamed status reg can also be fitted 
            log_size_rs: integer := 6; -- log2 of size. UPDATE EVERYTIME YOU UPDATE SIZE
				input_PRF: integer := (len_RRF + len_operand); -- reg address + content
				len_out: integer := (len_pc + len_control + 2 + len_operand + len_operand + len_RRF); -- output to pipeline. Status is just 2 here cause address won't be needed now
				input_len: integer := (len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF);
				-- This works like: pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF)
            row_len: integer:= (1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1); -- This line is only valid for VHDL-2008.
				-- This works like: busy(1) + pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + ready(1)

    port(clk, rs_flush: in std_logic; -- Clock and flush signal
			input_word1, input_word2: in std_logic_vector(input_len - 1 downto 0); -- Input from decoder 
			valid_in1, valid_in2: in std_logic; -- Whether input from decoder is valid/should be entered in the RS table
			prf_reg1, prf_reg2, pref_reg3: in std_logic_vector(input_PRF - 1 downto 0); -- Input of updated register from PRF
			prf_valid1, prf_valid2, prf_valid3: in std_logic; -- Whether input from PRF is valid
			pipe1_busy, pipe2_busy: in std_logic; -- pipelines are busy so cant give instr
			pipe1_issue, pipe2_issue: out std_logic_vector(len_out - 1 downto 0); -- issue words to integer pipelines (2)
         RS_stall: out std_logic); -- 1 if RS is full, else 0. Just an AND of all busy bits
end entity;

architecture int_RS_arch of int_RS is
	type rs_table is array(size_rs - 1 downto 0) of std_logic_vector(row_len - 1 downto 0); 
	signal int_RS_table: rs_table := (others => (others=>'0'));
	signal i: integer := 0;
	
	-- bunch of indexes
	constant busy_i : integer := 0;
	constant pc_start_i : integer := 1;
	constant pc_end_i : integer := len_pc;
	constant control_start_i : integer := 1 + len_pc + 4;
	constant control_end_i : integer := 1 + len_pc + 4 + len_control - 1;
	constant valid1_i : integer := 1 + len_pc + 4 + len_control;
	constant opr1_start_i : integer := 1 + len_pc + 4 + len_control + 1;
	constant opr1_end_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand - 1;
	constant valid2_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand;
	constant opr2_start_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1;
	constant opr2_end_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand - 1;
	constant dest_start_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand;
	constant dest_end_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF - 1;
	constant ready_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF;
begin
	--stall signal is not in process
	RS_proc: process(clk)
	begin
		-- flush if necessary
		-- accept input from PRF
		-- start traversing table and update operands. If instruction is ready, send it into the pipeline. but but but
		-- RENAMED STATUS REGISTERS??????
	end process RS_proc;
end architecture int_RS_arch;