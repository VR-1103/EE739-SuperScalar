library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity decoder is
	generic(len_PC: integer:= 5;
				len_instr: integer:= 16;
				len_arf: integer:= 3;
				len_rrf: integer:= 6;
				len_data: integer:= 16;
				len_control: integer:= 5;---some random value rn
				len_status: integer:= 16;
				len_rob_dispatch: integer:= 5+4+3+6+1; ----PC, Opcode, ARF entry, RRF entry, disabled bit
				len_int_rs_dispatch: integer:= 5+4+5+1+16+1+16+6+1+16+6+1;
				----pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + status_valid(1) + status_reg(6) + status_destination(len_RRF) + ready(1)
				len_ls_rs_dispatch: integer:= 5+4+5+1+16+16+6+6+1
				----pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + Immediate(len_operand) + destination(len_RRF) + status_destination(len_RRF) + ready(1)
				);
	port(clk: in std_logic;
			fetch1,fetch2: in std_logic_vector(len_PC+len_instr-1 downto 0);
			fetch_disable1,fetch_disable2: in std_logic;
			rob_dispatch1,rob_dispatch2: out std_logic_vector(6+len_rob_dispatch-1 downto 0); --Appended with imm for load and store
			rob_valid1,rob_valid2: out std_logic;
			int_dispatch1,int_dispatch2: out std_logic_vector(len_int_rs_dispatch-1 downto 0);
			int_valid1,int_valid2: out std_logic;
			ls_valid1,ls_valid2: out std_logic;
			ls_dispatch1,ls_dispatch2: out std_logic_vector(len_ls_rs_dispatch-1 downto 0);
			load_dispatch1,load_dispatch2: out std_logic_vector(6+len_PC-1 downto 0);
			load_valid1,load_valid2: out std_logic;
			store_dispatch1,store_dispatch2: out std_logic_vector(len_PC+4+len_data+1-1 downto 0);
			store_valid1,store_valid2: out std_logic;
			disable_fetch: out std_logic;
			----requirements for working with prf----
			op_required1,op_required2: out std_logic_vector(1 downto 0); ---tells prf how many operands required
			op_addr1,op_addr2: out std_logic_vector(len_arf+len_arf-1 downto 0); ---at max can hold addr of 2 operands,if only 1 operand is asked, addr will be at (len_arf-1 downto 0)
			dest_required1,dest_required2: out std_logic; ---whether destination is required
			dest_addr1,dest_addr2: out std_logic_vector(len_arf-1 downto 0); ---arf addr of destination
			op_data1,op_data2: in std_logic_vector(len_data+len_data-1 downto 0); ---at max data of 2 operands, if only 1 operand is asked, send the data to (len_data-1 downto 0)
			op_valid1,op_valid2: in std_logic_vector(1 downto 0); ----similarly if only 1 oeprand, validity of 0'th bit will be considered
			dest_rrf1,dest_rrf2: in std_logic_vector(len_rrf-1 downto 0); ---addr of destination rrf
			cz_required1,cz_required2: out std_logic; ---00 if neither, 01 if z, 10 if c, 11 will never happen, honestly if prf has one status register, then ig it doesnt matter, only matters how pipeline is using the status register ka data
			cz1,cz2: in std_logic_vector(len_data-1 downto 0); ---whatever is asked, send that---
			cz_valid1,cz_valid2: in std_logic; ---whether its valid or not
			cz_dest_required1,cz_dest_required2: out std_logic; ---whenever the instr will change c/z/both, this will be high
			cz_rrf1,cz_rrf2: in std_logic_vector(len_rrf-1 downto 0)); ---send the rrf for new location of status register---
end entity;

architecture struct of decoder is
	signal fetch1_prev,fetch2_prev: std_logic_vector(len_PC+len_instr-1 downto 0);
	signal fetch_disable1_prev,fetch_disable2_prev: std_logic;
	-----We need a pipelined thingy basically.----
	signal op_maybe1,op_maybe2: std_logic_vector(1 downto 0);
	signal dest_maybe1,dest_maybe2: std_logic;
	signal dest1,dest2: std_logic_vector(len_arf-1 downto 0);
	signal cz_maybe1,cz_maybe2: std_logic_vector(1 downto 0);
	signal control_maybe1,control_maybe2: std_logic_vector(len_control-1 downto 0):= (others => '0');
	signal instr1_jump,instr2_jump: std_logic;
	signal instr1_disable,instr2_disable: std_logic;
	signal is_int1,is_int2,is_ls1,is_ls2: std_logic;

begin
	----deciding how many operands required----
	op_maybe1 <= "10" when (fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11" or fetch1(len_instr-3 downto len_instr-4) = "00")) else
							"01" when (fetch1(len_instr-1 downto len_instr-4) = "0000" or fetch1(len_instr-1 downto len_instr-4) = "0100") else
							"10" when (fetch1(len_instr-1 downto len_instr-2) = "10") or fetch1(len_instr-1 downto len_instr-4) = "0101" else
							"01" when (fetch1(len_instr-1 downto len_instr-4) = "1101" or fetch1(len_instr-1 downto len_instr-4) = "1111") else
							"00";
	op_required1 <= op_maybe1 when fetch_disable1 = '0' else "00";
	op_maybe2 <= "10" when (fetch2(len_instr-1 downto len_instr-2) = "00" and not (fetch2(len_instr-3 downto len_instr-4) = "11" or fetch2(len_instr-3 downto len_instr-4) = "00")) else
							"01" when (fetch2(len_instr-1 downto len_instr-4) = "0000" or fetch2(len_instr-1 downto len_instr-4) = "0100") else
							"10" when (fetch2(len_instr-1 downto len_instr-2) = "10") or fetch1(len_instr-1 downto len_instr-4) = "0100" else
							"01" when (fetch2(len_instr-1 downto len_instr-4) = "1101" or fetch2(len_instr-1 downto len_instr-4) = "1111") else
							"00";
	op_required2 <= op_maybe2 when fetch_disable2 = '0' else "00";
	
	----alloting operand addresses to go to prf----
	----when only 1 operand is required, it will be op_addr(len_arf-1 downto 0), prf can ignore the rhs
	op_addr1(len_arf-1 downto 0) <= fetch1(len_instr-5 downto len_instr-7) when ((fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11")) or (fetch1(len_instr-1 downto len_instr-2) = "10") or (fetch1(len_instr-1 downto len_instr-4) = "1111") or fetch1(len_instr-1 downto len_instr-2) = "01") else
												fetch1(len_instr-8 downto len_instr-10) when (fetch1(len_instr-1 downto len_instr-4) = "1101");
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
	dest1 <= fetch1(len_instr-11 downto len_instr-13) when (fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11" or fetch1(len_instr-3 downto len_instr-4) = "00")) else
						fetch1(len_instr-8 downto len_instr-10) when fetch1(len_instr-1 downto len_instr-4) = "0000" else
						fetch1(len_instr-5 downto len_instr-7);
	dest_addr1 <= dest1;
	dest2 <= fetch2(len_instr-11 downto len_instr-13) when (fetch2(len_instr-1 downto len_instr-2) = "00" and not (fetch2(len_instr-3 downto len_instr-4) = "11" or fetch2(len_instr-3 downto len_instr-4) = "00")) else
						fetch2(len_instr-8 downto len_instr-10) when fetch2(len_instr-1 downto len_instr-4) = "0000" else
						fetch2(len_instr-5 downto len_instr-7);
	dest_addr2 <= dest2;
						
	----Whether C,Z required----
	cz_maybe1 <= "10" when (fetch1(len_instr-15) = '1' and (fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11" or fetch1(len_instr-3 downto len_instr-4) = "00"))) else
						"01" when (fetch1(len_instr-15 downto len_instr-16) = "01" and (fetch1(len_instr-1 downto len_instr-2) = "00" and not (fetch1(len_instr-3 downto len_instr-4) = "11" or fetch1(len_instr-3 downto len_instr-4) = "00"))) else
						"00";
	cz_required1 <= '0' when fetch_disable1 = '1' or cz_maybe1 = "00" else '1';
	cz_maybe2 <= "10" when (fetch2(len_instr-15) = '1' and (fetch2(len_instr-1 downto len_instr-2) = "00" and not (fetch2(len_instr-3 downto len_instr-4) = "11" or fetch2(len_instr-3 downto len_instr-4) = "00"))) else
						"01" when (fetch2(len_instr-15 downto len_instr-16) = "01" and (fetch2(len_instr-1 downto len_instr-2) = "00" and not (fetch2(len_instr-3 downto len_instr-4) = "11" or fetch2(len_instr-3 downto len_instr-4) = "00"))) else
						"00";
	cz_required2 <= '0' when fetch_disable2 = '1' or cz_maybe2 = "00" else '1';
	
	----Whether C,Z will be changed----
	cz_dest_required1 <= '1' when fetch1(len_instr-1 downto len_instr-2) = "00" and not fetch1(len_instr-3 downto len_instr-4) = "11" else
								'1' when fetch1(len_instr-1 downto len_instr-4) = "0100" else '0';
	cz_dest_required2 <= '1' when fetch2(len_instr-1 downto len_instr-2) = "00" and not fetch2(len_instr-3 downto len_instr-4) = "11" else
								'1' when fetch2(len_instr-1 downto len_instr-4) = "0100" else '0';
	
	----Disabling instructions----
	instr1_jump <= '1' when fetch1(len_instr-1 downto len_instr-2) = "11" and fetch_disable1 = '0' else '0';
	instr2_jump <= '1' when fetch2(len_instr-1 downto len_instr-2) = "11" and fetch_disable2 = '0' else '0';
	instr1_disable <= fetch_disable1;
	instr2_disable <= fetch_disable2 or instr1_jump;
	disable_fetch <= instr1_jump or instr2_jump;
	
	
	----Cyclically send data forward to RS,ROB,Store buffer,Load Queue
	operation: process(clk)
	begin
		if (rising_edge(clk)) then
			----Sending stuff to rob----
				rob_dispatch1(6+len_rob_dispatch-1 downto len_rob_dispatch) <= fetch1_prev(5 downto 0);
				rob_dispatch1(len_rob_dispatch-1 downto len_rob_dispatch-len_PC) <= fetch1_prev(len_PC+len_instr-1 downto len_instr);
				rob_dispatch1(len_rob_dispatch-len_PC-1 downto len_rob_dispatch-len_PC-4) <= fetch1_prev(len_instr-1 downto len_instr-4);
				rob_dispatch1(len_rob_dispatch-len_PC-5 downto len_rob_dispatch-len_PC-7) <= dest1;
				rob_dispatch1(len_rob_dispatch-len_PC-4-len_arf-1 downto len_rob_dispatch-len_PC-4-len_arf-len_rrf) <= dest_rrf1;
				if (fetch1_prev(len_instr-1 downto len_instr-2) = "11" and fetch_disable1_prev = '0') then
					rob_dispatch1(0) <= '1';
				else
					rob_dispatch1(0) <= '0';
				end if;
				rob_dispatch2(6+len_rob_dispatch-1 downto len_rob_dispatch) <= fetch2_prev(5 downto 0);
				rob_dispatch2(len_rob_dispatch-1 downto len_rob_dispatch-len_PC) <= fetch2_prev(len_PC+len_instr-1 downto len_instr);
				rob_dispatch2(len_rob_dispatch-len_PC-1 downto len_rob_dispatch-len_PC-4) <= fetch2_prev(len_instr-1 downto len_instr-4);
				rob_dispatch2(len_rob_dispatch-len_PC-5 downto len_rob_dispatch-len_PC-7) <= dest2;
				rob_dispatch2(len_rob_dispatch-len_PC-4-len_arf-1 downto len_rob_dispatch-len_PC-4-len_arf-len_rrf) <= dest_rrf2;
				if (fetch2_prev(len_instr-1 downto len_instr-2) = "11" and fetch_disable2_prev = '0') then
					rob_dispatch2(0) <= '1';
				else
					rob_dispatch2(0) <= '0';
				end if;
		
			----whether rob instr is valid or not----
				if (fetch1_prev(len_instr-1 downto len_instr-2) = "11" and fetch_disable1_prev = '0') then
					rob_valid1 <= '1';
				else rob_valid1 <= '0';
				end if;
				if (fetch2_prev(len_instr-1 downto len_instr-2) = "11" and fetch_disable2_prev = '0') then
					rob_valid2 <= '1';
				else rob_valid2 <= '0';
				end if;
				
			----Whether instr is int or ls----
				if (fetch1_prev(len_instr-1 downto len_instr-2) = "00" and not fetch1_prev(len_instr-3 downto len_instr-4) = "11") then
					is_int1 <= '1';
				elsif (fetch1_prev(len_instr-1) = '1') then
					is_int1 <= '1';
				else is_int1 <= '0';
				end if;
				is_ls1 <= not is_int1;
				if (fetch2_prev(len_instr-1 downto len_instr-2) = "00" and not fetch2_prev(len_instr-3 downto len_instr-4) = "11") then
					is_int2 <= '1';
				elsif (fetch2_prev(len_instr-1) = '1') then
					is_int2 <= '1';
				else is_int2 <= '0';
				end if;
				is_ls2 <= not is_int2;
				
				if fetch_disable1_prev = '1' then 
					int_valid1 <= '0';
				else int_valid1 <= is_int1;
				end if;
				if fetch_disable2_prev = '1' then 
					int_valid2 <= '0';
				else int_valid2 <= is_int2;
				end if;
				
				if fetch_disable1_prev = '1' then
					ls_valid1 <= '0';
				else ls_valid1 <= is_ls1;
				end if;
				if fetch_disable2_prev = '1' then
					ls_valid2 <= '0';
				else ls_valid2 <= is_ls2;
				end if;
				
			----Control Signals Assignment----
			
			----Sending stuff to int pipeline----
				int_dispatch1(len_int_rs_dispatch-1 downto len_int_rs_dispatch-len_PC) <= fetch1_prev(len_PC+len_instr-1 downto len_instr);
				int_dispatch1(len_int_rs_dispatch-len_PC-1 downto len_int_rs_dispatch-len_PC-4) <= fetch1_prev(len_instr-1 downto len_instr-4);
				int_dispatch1(len_int_rs_dispatch-len_PC-4-1 downto len_int_rs_dispatch-len_PC-4-len_control) <= control_maybe1;
				int_dispatch1(len_int_rs_dispatch-len_PC-4-len_control-1) <= op_valid1(0);
				int_dispatch1(len_int_rs_dispatch-len_PC-4-len_control-1-1 downto len_int_rs_dispatch-len_PC-4-len_control-1-len_data) <= op_data1(len_data-1 downto 0);
				if (fetch1_prev(len_instr-1 downto len_instr-4) = "0000") then
					int_dispatch1(len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1) <= '1';
					int_dispatch1(len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-1 downto len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-len_data) <= "0000000000" & fetch1_prev(5 downto 0);
				else
					int_dispatch1(len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1) <= op_valid1(1);
					int_dispatch1(len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-1 downto len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-len_data) <= op_data1(len_data+len_data-1 downto len_data);
				end if;
				int_dispatch1(len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-len_data-1 downto len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-len_data-len_rrf) <= dest_rrf1;
				int_dispatch1(1+len_status+len_rrf+1-1) <= cz_valid1;
				int_dispatch1(1+len_status+len_rrf+1-1-1 downto 1+len_status+len_rrf+1-1-len_status) <= cz1;
				int_dispatch1(len_rrf+1-1 downto len_rrf+1-len_rrf) <= cz_rrf1;
				int_dispatch1(0) <= op_valid1(1) and op_valid1(0);
				
				int_dispatch2(len_int_rs_dispatch-1 downto len_int_rs_dispatch-len_PC) <= fetch2_prev(len_PC+len_instr-1 downto len_instr);
				int_dispatch2(len_int_rs_dispatch-len_PC-1 downto len_int_rs_dispatch-len_PC-4) <= fetch2_prev(len_instr-1 downto len_instr-4);
				int_dispatch2(len_int_rs_dispatch-len_PC-4-1 downto len_int_rs_dispatch-len_PC-4-len_control) <= control_maybe2;
				int_dispatch2(len_int_rs_dispatch-len_PC-4-len_control-1) <= op_valid2(0);
				int_dispatch2(len_int_rs_dispatch-len_PC-4-len_control-1-1 downto len_int_rs_dispatch-len_PC-4-len_control-1-len_data) <= op_data2(len_data-1 downto 0);
				int_dispatch2(len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1) <= op_valid2(1);
				int_dispatch2(len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-1 downto len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-len_data) <= op_data2(len_data+len_data-1 downto len_data);
				int_dispatch2(len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-len_data-1 downto len_int_rs_dispatch-len_PC-4-len_control-1-len_data-1-len_data-len_rrf) <= dest_rrf2;
				int_dispatch2(1+len_status+len_rrf+1-1) <= cz_valid2;
				int_dispatch2(1+len_status+len_rrf+1-1-1 downto 1+len_status+len_rrf+1-1-len_status) <= cz2;
				int_dispatch2(len_rrf+1-1 downto len_rrf+1-len_rrf) <= cz_rrf2;
				int_dispatch2(0) <= op_valid2(1) and op_valid2(0);
				
			----Sending stuff to ls pipeline----
				ls_dispatch1(len_ls_rs_dispatch-1 downto len_ls_rs_dispatch-len_PC) <= fetch1_prev(len_PC+len_instr-1 downto len_instr);
				ls_dispatch1(len_ls_rs_dispatch-len_PC-1 downto len_ls_rs_dispatch-len_PC-4) <= fetch1_prev(len_instr-1 downto len_instr-4);
				ls_dispatch1(len_ls_rs_dispatch-len_PC-4-1 downto len_ls_rs_dispatch-len_PC-4-len_control) <= control_maybe1;
				ls_dispatch1(len_ls_rs_dispatch-len_PC-4-len_control-1) <= op_valid1(0);
				ls_dispatch1(len_ls_rs_dispatch-len_PC-4-len_control-1-1 downto len_ls_rs_dispatch-len_PC-4-len_control-1-len_data) <= op_data1(len_data-1 downto 0);
				if (fetch1_prev(len_instr-2) = '1') then
					ls_dispatch1(len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-1 downto len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-len_data) <= ("0000000000" & fetch1_prev(5 downto 0));
				else ls_dispatch1(len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-1 downto len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-len_data) <= ("0000000" & fetch1_prev(8 downto 0));
				end if;
				ls_dispatch1(len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-len_data-1 downto len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-len_data-len_rrf) <= dest_rrf1;
				ls_dispatch1(len_rrf+1-1 downto len_rrf+1-len_rrf) <= cz_rrf1;
				ls_dispatch1(0) <= op_valid1(0);

				ls_dispatch2(len_ls_rs_dispatch-1 downto len_ls_rs_dispatch-len_PC) <= fetch2_prev(len_PC+len_instr-1 downto len_instr);
				ls_dispatch2(len_ls_rs_dispatch-len_PC-1 downto len_ls_rs_dispatch-len_PC-4) <= fetch2_prev(len_instr-1 downto len_instr-4);
				ls_dispatch2(len_ls_rs_dispatch-len_PC-4-1 downto len_ls_rs_dispatch-len_PC-4-len_control) <= control_maybe2;
				ls_dispatch2(len_ls_rs_dispatch-len_PC-4-len_control-1) <= op_valid2(0);
				ls_dispatch2(len_ls_rs_dispatch-len_PC-4-len_control-1-1 downto len_ls_rs_dispatch-len_PC-4-len_control-1-len_data) <= op_data2(len_data-1 downto 0);
				if (fetch2_prev(len_instr-2) = '1') then
					ls_dispatch2(len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-1 downto len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-len_data) <= ("0000000000" & fetch2_prev(5 downto 0));
				else ls_dispatch2(len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-1 downto len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-len_data) <= ("0000000" & fetch2_prev(8 downto 0));
				end if;
				ls_dispatch2(len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-len_data-1 downto len_ls_rs_dispatch-len_PC-4-len_control-1-len_data-len_data-len_rrf) <= dest_rrf2;
				ls_dispatch2(len_rrf+1-1 downto len_rrf+1-len_rrf) <= cz_rrf2;
				ls_dispatch2(0) <= op_valid2(0);
				
			----Whether it is load or store----
				if ((fetch1_prev(len_instr-1 downto len_instr-4) = "0100" or fetch1_prev(len_instr-1 downto len_instr-4) = "0011") and fetch_disable1_prev = '0') then
					load_valid1 <= '1';
				else load_valid1 <= '0';
				end if;
				if ((fetch1_prev(len_instr-1 downto len_instr-4) = "0100" or fetch1_prev(len_instr-1 downto len_instr-4) = "0011") and fetch_disable1_prev = '0') then
					store_valid1 <= '1';
				else store_valid1 <= '0';
				end if;
				if ((fetch2_prev(len_instr-1 downto len_instr-4) = "0100" or fetch2_prev(len_instr-1 downto len_instr-4) = "0011") and fetch_disable2_prev = '0') then
					load_valid2 <= '1';
				else load_valid2 <= '0';
				end if;
				if ((fetch2_prev(len_instr-1 downto len_instr-4) = "0100" or fetch2_prev(len_instr-1 downto len_instr-4) = "0011") and fetch_disable2_prev = '0') then
					store_valid2 <= '1';
				else store_valid2 <= '0';
				end if;
			
			----Sending to load queue----
				load_dispatch1(6+len_PC-1 downto len_PC) <= fetch1_prev(len_instr-11 downto len_instr-16);
				load_dispatch1(len_PC-1 downto 0) <= fetch1_prev(len_PC+len_instr-1 downto len_instr);
				load_dispatch2(len_PC-1 downto 0) <= fetch2_prev(len_PC+len_instr-1 downto len_instr);
				load_dispatch2(6+len_PC-1 downto len_PC) <= fetch2_prev(len_instr-11 downto len_instr-16);
			
			----Sending to store buffer----
				store_dispatch1(len_PC+4+len_data+1-1 downto len_PC+4+len_data+1-len_PC) <= fetch1_prev(len_PC+len_instr-1 downto len_instr);
				store_dispatch1(len_PC+4+len_data+1-len_PC-1 downto len_PC+4+len_data+1-len_PC-4) <= fetch1_prev(len_instr-1 downto len_instr-4);
				store_dispatch1(len_PC+4+len_data+1-len_PC-4-1 downto len_PC+4+len_data+1-len_PC-4-len_data) <= op_data1(len_data-1 downto 0);
				store_dispatch1(1) <= op_valid1(0);
				if ((fetch1_prev(len_instr-1 downto len_instr-4) = "0101") and fetch_disable1_prev = '0') then
					store_dispatch1(0) <= '1';
				else store_dispatch1(0) <= '0';
				end if;

				store_dispatch2(len_PC+4+len_data+1-1 downto len_PC+4+len_data+1-len_PC) <= fetch2_prev(len_PC+len_instr-1 downto len_instr);
				store_dispatch2(len_PC+4+len_data+1-len_PC-1 downto len_PC+4+len_data+1-len_PC-4) <= fetch2_prev(len_instr-1 downto len_instr-4);
				store_dispatch1(len_PC+4+len_data+1-len_PC-4-1 downto len_PC+4+len_data+1-len_PC-4-len_data) <= op_data2(len_data-1 downto 0);
				store_dispatch1(1) <= op_valid2(0);
				if ((fetch2_prev(len_instr-1 downto len_instr-4) = "0101") and fetch_disable2_prev = '0') then
					store_dispatch2(0) <= '1';
				else store_dispatch2(0) <= '0';
				end if;	
			
			----Updating fetch----
				fetch1_prev <= fetch1;
				fetch2_prev <= fetch2;
				fetch_disable1_prev <= fetch_disable1;
				fetch_disable2_prev <= fetch_disable2;

		else null;
		end if;	
	end process;

end architecture;