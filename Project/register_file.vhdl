library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_file is
	generic(len_rrf: integer:=64;
				log_size_rrf: integer:=6;
				len_rs: integer:=32;
				);
	port (clk: in std_logic;
			number_of_operands1,number_of_operands2: in std_logic(1 downto 0);--00: none, 01: one, 10:two
			operand_adds_11,operand_adds_12,operand_adds_21,operand_adds_22: in std_logic_vector(2 downto 0);
			carry_zero1, carry_zero2: in std_logic_vector(1 downto 0); --00:none, 01: zero, 10: carry, 11:both
			dest1,dest2: in std_logic_vector(2 downto 0);
			dest_reqd1, dest_reqd2: in std_logic;
			invalid_op1,invalid_op2: in std_logic_vector(16*len_rs-1 downto 0);
			invalidity_op1,invalidity_op2: in std_logic_vector(len_rs-1 downto 0); -- follow that valid is high, and invalid is low
			invalid_c,invalid_z: in std_logic_vector(16*len_rs-1 downto 0);
			invalidity_c,invalidity_z: in std_logic_vector(len_rs-1 downto 0);
			int_pipe_1,int_pipe_2: in std_logic_vector(log_size_rrf+16+1-1 downto 0); --rrf address,data,control signal
			rob1,rob2: in std_logic_vector(3+log_size_rrf+1-1 downto 0);
			---------
			operand_words_11,operand_words_12,operand_words_21,operand_words_22: out std_logic_vector(15 downto 0);
			operand_valid_11,operand_valid_12,operand_valid_21,operand_valid_22: out std_logic;
			carry1,carry2,zero1,zero2: out std_logic_vector(15 downto 0);
			carry1_valid,carry2_valid,zero1_valid,zero2_valid: out std_logic;
			dest1_add,dest2_add: out std_logic_vector(log_size_rrf-1 downto 0);
			dest1_valid,dest2_valid: out std_logic;
			valid_op1,valid_op2: in std_logic_vector(16*len_rs-1 downto 0);
			validity_op1,validity_op2: in std_logic_vector(len_rs-1 downto 0);
			valid_c,valid_z: in std_logic_vector(16*len_rs-1 downto 0);
			validity_c,validity_z: in std_logic_vector(len_rs-1 downto 0));
end entity register_file;

architecture trivial of register_file is
	begin
		

end architecture trivial;