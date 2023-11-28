library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity decoder is
	generic(len_PC: integer:= 5;
				len_instr: integer:= 16;
				len_arf: integer:= 3;
				len_rrf: integer:= 6;
				len_data: integer:= 16;
				len_control: integer:= 5;---some random value rn
				len_status: integer:= 6;
				len_rob_dispatch: integer:= 1+len_PC+4+len_arf+len_rrf+1+1; ----valid bit, PC, Opcode, ARF entry, RRF entry, speculative bit, executed bit
				len_int_rs_dispatch: integer:= len_PC+4+len_control+1+len_data+1+len_data+len_rrf+1+len_status+len_rrf+1;
				----pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + status_valid(1) + status_reg(6) + status_destination(len_RRF) + ready(1)
				len_ls_rs_dispatch: integer:= len_PC+4+len_control+1+len_data+len_data+len_rrf+len_rrf+1
				----pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + Immediate(len_operand) + destination(len_RRF) + status_destination(len_RRF) + ready(1)
				);
	port(fetch1,fetch2: in std_logic_vector(len_PC+len_instr-1 downto 0);
			rob_dispatch1,rob_dispatch2: out std_logic_vector(len_rob_dispatch-1 downto 0);
			int_rs_dispatch1,int_rs_dispatch2: out std_logic_vector(len_int_rs_dispatch-1 downto 0);
			ls_rs_dispatch1,ls_rs_dispatch2: out std_logic_vector(len_ls_rs_dispatch-1 downto 0);
			disable_fetch: out std_logic;
			----requirements for ports working with prf----
			op_required1,op_required2: out std_logic_vector(1 downto 0);
			op_addr1,op_addr2: out std_logic_vector(len_arf+len_arf-1 downto 0);
			dest_required1,dest_required2: out std_logic;
			dest_addr1,dest_addr2: out std_logic_vector(len_arf-1 downto 0);
			op_data1,op_data2: in std_logic_vector(len_data+len_data-1 downto 0);
			dest_rrf1,dest_rrf3: in std_logic_vector(len_rrf-1 downto 0);
			cz_required1,cz_required2: out std_logic_vector(1 downto 0);
			cz1,cz2: in std_logic_vector(len_data+len_data-1 downto 0));
end entity;

architecture struct of decoder is

end architecture;