library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity int_RS is
	 -- The RS only cares about the PC, control word, operands or the address of where to update them from, and maybe destination RRF? 
    generic(len_PC: integer := 5; -- Length of the PC which RS receives for each instruction
				len_control: integer := 16; -- Length of the control word for the integer pipeline
            len_RRF: integer := 6; -- Length of the destination RRF which the RS receives for each instruction
            len_operand: integer := 32; -- Length of the two operands. This is more than the length of the addresses in the PRF so that address can fit as well  
            size_rs: integer := 64; -- Size of RS table
				len_status: integer := 6; --status register. It is 6 so that renamed status reg can also be fitted. Actual CZ flag is to be put in the first two indexes 
            log_size_rs: integer := 6; -- log2 of size. UPDATE EVERYTIME YOU UPDATE SIZE
				input_RRF: integer := (len_RRF + len_operand); -- reg address + content
				len_out: integer := (len_pc + len_control + len_operand + len_operand + len_RRF + 2); -- output to pipeline. Status is just 2 here cause address won't be needed now
				input_len: integer := (len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1 + len_status + 1);
				-- This works like: pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + status_valid(1) + status_reg(6) + ready(1)
            row_len: integer:= (1 + input_len)); -- This line is only valid for VHDL-2008.
				-- This works like: busy(1) + pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + status_valid(1) + status_reg(6) + ready(1)

    port(clk, rs_flush: in std_logic; -- Clock and flush signal
			input_word1, input_word2: in std_logic_vector(0 to input_len - 1); -- Input from decoder 
			valid_in1, valid_in2: in std_logic; -- Whether input from decoder is valid/should be entered in the RS table
			prf_reg1, prf_reg2, prf_reg3: in std_logic_vector(0 to input_RRF - 1); -- Input of updated register from RRF. Contains address + content
			prf_valid1, prf_valid2, prf_valid3: in std_logic; -- Whether input from PRF is valid
			status_reg1, status_reg2, status_reg3: in std_logic_vector(0 to len_RRF + 1); -- Input of updated status register. Contains address + content
			status_valid1, status_valid2, status_valid3: in std_logic; -- Whether input from status reg is valid
			pipe1_busy, pipe2_busy: in std_logic; -- pipelines are busy so cant give instr
			pipe1_issue, pipe2_issue: out std_logic_vector(0 to len_out - 1); -- issue words to integer pipelines (2)
			pipe1_issue_valid, pipe2_issue_valid: out std_logic; -- are issue words valid
         RS_stall: out std_logic); -- 1 if RS is full, else 0
end entity;

architecture int_RS_arch of int_RS is
	type rs_table is array(0 to size_rs - 1) of std_logic_vector(0 to row_len - 1); 
	signal int_RS_table: rs_table := (others => (others=>'0'));
	signal i: integer := 0;
	signal in1_index : integer := 0; --predetermined index for where to put first of decoder output
	signal in2_index : integer := 1; --predetermined index for where to put second of decoder output
	signal in1_index_valid, in2_index_valid : std_logic := '1'; -- is predetermined index even valid?
	signal to_pipe1, to_pipe2: std_logic_vector(0 to len_out - 1) := (others => '0'); -- what to send to pipelines
	signal pipe1_done, pipe2_done: std_logic := '0'; -- whether pipeline has already been assigned something
	signal stall_determine: std_logic := '0'; -- determine stall based on predetermined indexes given above 
	signal current_row: std_logic_vector(0 to row_len - 1) := (others => '0');
	
	-- bunch of indexes
	constant busy_i : integer := 0;
	constant pc_start_i : integer := 1;
	constant pc_end_i : integer := len_pc;
	constant control_start_i : integer := 1 + len_pc + 4;
	constant control_end_i : integer := 1 + len_pc + 4 + len_control - 1;
	constant valid1_i : integer := 1 + len_pc + 4 + len_control;
	constant opr1_start_i : integer := 1 + len_pc + 4 + len_control + 1;
	constant opr1_end_addr_i : integer := 1 + len_pc + 4 + len_control + 1 + len_RRF - 1;
	constant opr1_end_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand - 1;
	constant valid2_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand;
	constant opr2_start_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1;
	constant opr2_end_addr_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_RRF - 1;
	constant opr2_end_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand - 1;
	constant dest_start_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand;
	constant dest_end_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF - 1;
	constant status_valid_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF;
	constant status_start_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1;
	constant status_end_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1 + 2;
	constant status_end_addr_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1 + len_status;
	begin
	--stall signal is not in process
	RS_proc: process(clk)
	begin
		if(rising_edge(clk)) then
		
			-- Clear pipeline assigned variables
			pipe1_done <= '0';
			pipe2_done <= '0';
			
			-- Note that the addresses for new instructions and the stall signal are determined from the previous cycle
			RS_stall <= stall_determine;
			
			-- flush if necessary
			if (rs_flush = '1') then 
				flush_loop: for i in 0 to size_rs - 1 loop
					int_RS_table(i)(busy_i) <= '0'; -- row no longer busy and is ready to be overwritten
				end loop flush_loop;
			end if; --dunno what to put into else
			
			-- insert incoming instructions if they are valid and there is no stall
			if (stall_determine = '0') then 
				if (valid_in1 = '1') then
					int_RS_table(in1_index) <= '1' & input_word1;
					in1_index_valid <= '0';
				end if;
				if (valid_in2 = '1') then
					int_RS_table(in2_index) <= '1' & input_word2;
					in2_index_valid <= '0';
				end if;
			end if;
			
		-- start traversing table 
			traverse_loop: for i in 0 to size_rs -1 loop -- im fucking breaking my head over this loop
				current_row <= int_RS_table(i);
				
			-- check if row is free and assign a predetermined index for decoded instrs if it is
				if (current_row(0) = '0') then
					if (in1_index_valid <= '0') then 
						in1_index := i;
						in1_index_valid <= '1';
					end if;
					if (in1_index /= i and in2_index_valid <= '0') then
						in2_index := i;
						in2_index_valid <= '1';
					end if;
					
				else --row is busy so contains an instr
				
				-- Update operands and status and check if instr is ready
					if (current_row(row_len - 1) = '0') then -- instruction is not ready
					
						if (current_row(valid1_i) = '0') then -- check if opr1 is not valid
							if (current_row(opr1_start_i to opr1_end_addr_i) = prf_reg1(0 to len_RRF - 1) and prf_valid1 = '1') then
								current_row(valid1_i) <= '1'; -- update opr1 to prf_1
								current_row(opr1_start_i to opr1_end_i) <= prf_reg1(len_RRF to input_RRF - 1);
							end if;
							if (current_row(opr1_start_i to opr1_end_addr_i) = prf_reg2(0 to len_RRF - 1) and prf_valid2 = '1') then
								current_row(valid1_i) <= '1'; -- update opr1 to prf_2
								current_row(opr1_start_i to opr1_end_i) <= prf_reg2(len_RRF to input_RRF - 1);
							end if;
							if (current_row(opr1_start_i to opr1_end_addr_i) = prf_reg3(0 to len_RRF - 1) and prf_valid3 = '1') then
								current_row(valid1_i) <= '1'; -- update opr1 to prf_3
								current_row(opr1_start_i to opr1_end_i) <= prf_reg3(len_RRF to input_RRF - 1);
							end if;
						end if;
						
						if (current_row(valid2_i) = '0') then -- check if opr2 is not valid
							if (current_row(opr2_start_i to opr2_end_addr_i) = prf_reg1(0 to len_RRF - 1) and prf_valid1 = '1') then
								current_row(valid2_i) <= '1'; -- update opr2 to prf_1
								current_row(opr2_start_i to opr2_end_i) <= prf_reg1(len_RRF to input_RRF - 1);
							end if;
							if (current_row(opr2_start_i to opr2_end_addr_i) = prf_reg2(0 to len_RRF - 1) and prf_valid2 = '1') then
								current_row(valid2_i) <= '1'; -- update opr2 to prf_2
								current_row(opr2_start_i to opr2_end_i) <= prf_reg2(len_RRF to input_RRF - 1);
							end if;
							if (current_row(opr2_start_i to opr2_end_addr_i) = prf_reg3(0 to len_RRF - 1) and prf_valid3 = '1') then
								current_row(valid2_i) <= '1'; -- update opr2 to prf_3
								current_row(opr2_start_i to opr2_end_i) <= prf_reg3(len_RRF to input_RRF - 1);
							end if;
						end if;
						
						if (current_row(status_valid_i) = '0') then -- check if status is not valid
							if (current_row(status_start_i to status_end_addr_i) = status_reg1(0 to len_RRF - 1) and status_valid1 = '1') then
								current_row(status_valid_i) <= '1'; --update status to status_reg1
								current_row(status_start_i to status_end_i) <= status_reg1(len_RRF to len_RRF + 1);
							end if;
							if (current_row(status_start_i to status_end_addr_i) = status_reg2(0 to len_RRF - 1) and status_valid2 = '1') then
								current_row(status_valid_i) <= '1'; --update status to status_reg1
								current_row(status_start_i to status_end_i) <= status_reg2(len_RRF to len_RRF + 1);
							end if;
							if (current_row(status_start_i to status_end_addr_i) = status_reg3(0 to len_RRF - 1) and status_valid3 = '1') then
								current_row(status_valid_i) <= '1'; --update status to status_reg1
								current_row(status_start_i to status_end_i) <= status_reg3(len_RRF to len_RRF + 1);
							end if;
						end if;
						
						--update ready bit
						current_row(row_len - 1) <= current_row(valid1_i) and current_row(valid2_i) and current_row(status_valid_i);
					end if;
					
					if (current_row(row_len - 1) = '1') then -- instruction was born/groomed ready
						if (pipe1_done = '0' and pipe1_busy = '0') then
							pipe1_issue <= current_row(pc_start_i to pc_end_i) & current_row(control_start_i to control_end_i) & current_row(opr1_start_i to opr1_end_i) & current_row(opr2_start_i to opr2_end_i) & current_row(dest_start_i to dest_end_i) & current_row(status_start_i to status_end_i);
							pipe1_done <= '1';
						else 
							if (pipe2_done = '0' and pipe2_busy = '0') then
								pipe2_issue <= current_row(pc_start_i to pc_end_i) & current_row(control_start_i to control_end_i) & current_row(opr1_start_i to opr1_end_i) & current_row(opr2_start_i to opr2_end_i) & current_row(dest_start_i to dest_end_i) & current_row(status_start_i to status_end_i);
								pipe2_done <= '1';
							end if;
						end if;
					end if;
				end if;
				int_RS_table(i) <= current_row;	
			end loop traverse_loop;
			
			--housekeeping signals
			pipe1_issue_valid <= pipe1_done;
			pipe2_issue_valid <= pipe2_done;
			stall_determine <= not(in1_index_valid and in2_index_valid); -- stall if there is not atleast two spaces available
		end if;
	end process RS_proc;
end architecture int_RS_arch;