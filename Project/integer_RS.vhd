library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity int_RS is
	 -- The RS only cares about the PC, control word, operands or the address of where to update them from, and maybe destination RRF? 
    generic(len_PC: integer := 5; -- Length of the PC which RS receives for each instruction
				len_control: integer := 16 -- Length of the control word for the integer pipeline
            len_RRF_dest: integer := 6; -- Length of the destination RRF which the RS receives for each instruction
            len_operand: integer := 32 -- Length of the two operands. This is more than the length of the addresses in the PRF so that address can fit as well  
            size_rs: integer := 64; -- Size of RS table
            log_size_rs: integer:= 6; -- log2 of size. UPDATE EVERYTIME YOU UPDATE SIZE
            row_len: integer:= (1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF_dest + 1); -- This line is only valid for VHDL-2008.
				-- This works like: busy(1) + pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF_dest) + ready(1)

    port(clk, rs_flush: in std_logic;
			input_word: in std_logic_vector()
          dispatch_word1, dispatch_word2: in std_logic_vector(row_len - 1 downto 0); -- dispatch word has PC, ARF entry, RRF entry, executed bit
          valid_dispatch1, valid_dispatch2 : in std_logic; -- RS might have to send just one word/ no words in case of not having ready instr
          tag1, tag2, tag3 : in std_logic_vector(len_PC - 1 downto 0); -- one from each pipeline (execution words come from pipeline)
          valid1, valid2, valid3: in std_logic; -- if the executed words are valid
          retire_word1, retire_word2: out std_logic_vector(len_RRF - 1 downto 0); -- sent to PRF to tell it to update ARF
          valid_retire1, valid_retire2: out std_logic; -- in case you can only retire one of the instructions, make that valid_retirei as 0
          rob_stall: out std_logic);
end entity;