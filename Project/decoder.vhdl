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
				len_status: integer:= 16;
				len_rob_dispatch: integer:= 1+len_PC+4+len_arf+len_rrf+1+1; ----valid bit, PC, Opcode, ARF entry, RRF entry, speculative bit, executed bit
				len_int_rs_dispatch: integer:= len_PC+4+len_control+1+len_data+1+len_data+len_rrf+1+len_status+len_rrf+1;
				----pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + status_valid(1) + status_reg(6) + status_destination(len_RRF) + ready(1)
				len_ls_rs_dispatch: integer:= len_PC+4+len_control+1+len_data+len_data+len_rrf+len_rrf+1
				----pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + Immediate(len_operand) + destination(len_RRF) + status_destination(len_RRF) + ready(1)
				);
	port(fetch1,fetch2: in std_logic_vector(len_PC+len_instr-1 downto 0);
			fetch_disable1,fetch_disable2: in std_logic;
			rob_dispatch1,rob_dispatch2: out std_logic_vector(len_rob_dispatch-1 downto 0);
			int_rs_dispatch1,int_rs_dispatch2: out std_logic_vector(len_int_rs_dispatch-1 downto 0);
			int_valid1,int_valid2: out std_logic;
			ls_valid1,ls_valid2: out std_logic;
			ls_rs_dispatch1,ls_rs_dispatch2: out std_logic_vector(len_ls_rs_dispatch-1 downto 0);
			load_dispatch1,load_dispatch2: out std_logic_vector(len_PC-1 downto 0);
			load_valid1,load_valid2: out std_logic;
			store_dispatch1,store_dispatch2: out std_logic_vector(len_PC+len_data+1-1 downto 0);
			store_valid1,store_valid2: out std_logic;
			disable_fetch: out std_logic;
			----requirements for working with prf----
			op_required1,op_required2: out std_logic_vector(1 downto 0); ---tells prf how many operands required
			op_addr1,op_addr2: out std_logic_vector(len_arf+len_arf-1 downto 0); ---at max can hold addr of 2 operands
			dest_required1,dest_required2: out std_logic; ---whether destination is required
			dest_addr1,dest_addr2: out std_logic_vector(len_arf-1 downto 0); ---arf addr of destination
			op_data1,op_data2: in std_logic_vector(len_data+len_data-1 downto 0); ---at max data of 2 operands
			dest_rrf1,dest_rrf3: in std_logic_vector(len_rrf-1 downto 0); ---addr of destination rrf
			cz_required1,cz_required2: out std_logic_vector(1 downto 0); ---Only C required:10, only Z: 01, both: 11, none: 00
			cz1,cz2: in std_logic_vector(len_data+len_data-1 downto 0));
end entity;

architecture struct of decoder is
	signal op_maybe1,op_maybe2: std_logic_vector(1 downto 0);
	signal dest_maybe1,dest_maybe2: std_logic;
	signal cz_mayb1,cz_maybe2: std_logic_vector(1 downto 0);

begin
	----deciding how many operands required----
	op_maybe1 <= "10" when (fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11" or fetch1(len_instr-3 downto len_instr-4) = "00")) else
							"01" when (fetch1(len_instr-1 downto len_instr-4) = "0000" or fetch1(len_instr1-1 downto len_instr-3) = "010") else
							"10" when (fetch1(len_instr-1 downto len_instr-2) = "10") else
							"01" when (fetch1(len_instr-1 downto len_instr-4) = "1101" or fetch1(len_instr-1 downto len_instr-4) = "1111") else
							"00";
	op_required1 <= op_maybe1 when fetch_disable1 = '0' else "00";
	op_maybe2 <= "10" when (fetch2(len_instr-1 downto len_instr-2) = "00" and not (fetch2(len_instr-3 downto len_instr-4) = "11" or fetch2(len_instr-3 downto len_instr-4) = "00")) else
							"01" when (fetch2(len_instr-1 downto len_instr-4) = "0000" or fetch2(len_instr1-1 downto len_instr-3) = "010") else
							"10" when (fetch2(len_instr-1 downto len_instr-2) = "10") else
							"01" when (fetch2(len_instr-1 downto len_instr-4) = "1101" or fetch2(len_instr-1 downto len_instr-4) = "1111") else
							"00";
	op_required2 <= op_maybe2 when fetch_disable2 = '0' else "00";
	
	----alloting operand addresses to go to prf----
	----when only 1 operand is required, it will be op_addr(len_arf-1 downto 0), prf can ignore the rhs
	op_addr1(len_arf-1 downto 0) <= fetch1(len_instr-5 downto len_instr-7) when ((fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11")) or (fetch1(len_instr-1 downto len_instr-2) = "10") or (fetch1(len_instr-1 downto len_instr-4) = "1111")) else
												fetch1(len_instr-8 downto len_instr-10) when (fetch1(len_instr-1 downto len_instr-2) = "01" or fetch1(len_instr-1 downto len_instr-4) = "1101");
	op_addr1(len_arf+len_arf-1 downto len_arf) <= fetch1(len_instr-8 downto len_instr-10);
	--no worries since op_required takes care of whether to bother with the rhs of op_addr, and when its not "11"
	--we can ignore whats here
	op_addr2(len_arf-1 downto 0) <= fetch2(len_instr-5 downto len_instr-7) when ((fetch2(len_instr-1 downto len_instr-2) = "00" and not (fetch2(len_instr-3 downto len_instr-4) = "11")) or (fetch2(len_instr-1 downto len_instr-2) = "10") or (fetch2(len_instr-1 downto len_instr-4) = "1111")) else
												fetch2(len_instr-8 downto len_instr-10) when (fetch2(len_instr-1 downto len_instr-2) = "01" or fetch2(len_instr-1 downto len_instr-4) = "1101");
	op_addr2(len_arf+len_arf-1 downto len_arf) <= fetch2(len_instr-8 downto len_instr-10);
	
	----Whether destination is required----
	dest_maybe1 <= '1' when (fetch1(len_instr-1 downto len_instr-2) = "00" or fetch1(len_instr-1 downto len_instr-4) = "0100" or fetch1(len_instr-1 downto len_instr-3) = "110") else
						'0';
	dest_required1 <= dest_maybe1 when fetch_disable1 = '0' else '0';
	dest_maybe2 <= '1' when (fetch2(len_instr-1 downto len_instr-2) = "00" or fetch2(len_instr-1 downto len_instr-4) = "0100" or fetch2(len_instr-1 downto len_instr-3) = "110") else
						'0';
	dest_required2 <= dest_maybe2 when fetch_disable2 = '0' else '0';
	
	----Addr of destination----
	dest_addr1 <= fetch1(len_instr-11 downto len_instr-13) when (fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11" or fetch1(len_instr-3 downto len_instr-4) = "00")) else
						fetch1(len_instr-8 downto len_instr-10) when fetch1(len_instr-1 downto len_instr-4) = "0000" else
						fetch1(len_instr-5 downto len_instr-7);
	dest_addr2 <= fetch2(len_instr-11 downto len_instr-13) when (fetch2(len_instr-1 downto len_instr-2) = "00" and not (fetch2(len_instr-3 downto len_instr-4) = "11" or fetch2(len_instr-3 downto len_instr-4) = "00")) else
						fetch2(len_instr-8 downto len_instr-10) when fetch2(len_instr-1 downto len_instr-4) = "0000" else
						fetch2(len_instr-5 downto len_instr-7);
						
	----Whether C,Z required----
	cz_maybe1 <= "10" when (fetch1(len_instr-15) = "1" and (fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11" or fetch1(len_instr-3 downto len_instr-4) = "00"))) else
						"01" when (fetch1(len_instr-15 downto len_instr-16) = "01" and (fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11" or fetch1(len_instr-3 downto len_instr-4) = "00"))) else
						"00";
	cz_required1 <= cz_maybe1 when fetch_disable1 = '0' else "00";
	cz_maybe2 <= "10" when (fetch2(len_instr-15) = "1" and (fetch2(len_instr-1 downto len_instr-2) = "00" and not (fetch2(len_instr-3 downto len_instr-4) = "11" or fetch2(len_instr-3 downto len_instr-4) = "00"))) else
						"01" when (fetch2(len_instr-15 downto len_instr-16) = "01" and (fetch2(len_instr-1 downto len_instr-2) = "00" and not (fetch2(len_instr-3 downto len_instr-4) = "11" or fetch2(len_instr-3 downto len_instr-4) = "00"))) else
						"00";
	cz_required2 <= cz_maybe2 when fetch_disable2 = '0' else "00";
	
	----Control Signals Assignment----
	
	----Cyclically send data forward to RS,ROB,Store buffer,Load Queue
	operation: process(clk)
	begin
		
	
	end process;

end architecture;