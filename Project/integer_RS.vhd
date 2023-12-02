library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity int_RS is
	 -- The integer RS only cares about the PC, control word, operands or the address of where to update them from, and the destination RRF (both operand and status)
    generic(len_PC: integer := 5; -- Length of the PC which RS receives for each instruction
				len_control: integer := 16; -- Length of the control word for the integer pipeline
            len_RRF: integer := 6; -- Length of the destination RRF which the RS receives for each instruction
            len_operand: integer := 16; -- Length of the two operands. This is more than the length of the addresses in the PRF so that address can fit as well  
            size_rs: integer := 64; -- Size of RS table
				len_status: integer := 6; --status register. It is 6 so that renamed status reg can also be fitted. Actual CZ flag is to be put in the first two indexes 
            log_size_rs: integer := 6; -- log2 of size. UPDATE EVERYTIME YOU UPDATE SIZE
				input_RRF: integer := (6 + 16); -- reg address + content (len_RRF + len_operand)
				len_out: integer := (5 + 16 + 16 + 16 + 6 + 6 + 2); -- output to pipeline. Status is just 2 here cause address won't be needed now ((len_pc + len_control + len_operand + len_operand + len_RRF + len_RRF + 2))
				input_len: integer := (5 + 4 + 16 + 1 + 16 + 1 + 16 + 6 + 1 + 6 + 6 + 1);
				-- (len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1 + len_status + len_RRF + 1);
				-- This works like: pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + status_valid(1) + status_reg(6) + status_destination(len_RRF) + ready(1)
            row_len: integer:= (1 + 5 + 4 + 16 + 1 + 16 + 1 + 16 + 6 + 1 + 6 + 6 + 1));
				-- This works like: busy(1) + input

    port(clk, RS_flush: in std_logic; -- Clock and flush signal
			input_word1, input_word2: in std_logic_vector(0 to input_len - 1); -- Input from decoder 
			valid_in1, valid_in2: in std_logic; -- Whether input from decoder is valid/should be entered in the RS table
			rrf_reg1, rrf_reg2, rrf_reg3: in std_logic_vector(0 to input_RRF - 1); -- Input of updated register from RRF. Contains address + content
			rrf_valid1, rrf_valid2, rrf_valid3: in std_logic; -- Whether input from PRF is valid
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
	signal pipe1_done, pipe2_done: std_logic := '0'; -- whether pipeline has already been assigned something
	signal stall_determine: std_logic := '0'; -- determine stall based on predetermined indexes given above 
	signal pipe1_out, pipe2_out: std_logic_vector(0 to len_out - 1) := (others => '0'); --buffer for output to pipeline
	
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
	constant status_end_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1 + 1;
	constant status_end_addr_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1 + len_status - 1;
	constant status_dest_start_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1 + len_status;
	constant status_dest_end_i : integer := 1 + len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1 + len_status + len_RRF - 1;
	
	begin
	RS_proc: process(clk)
	begin
		if(rising_edge(clk)) then
		
			-- Clear pipeline assigned variables
			pipe1_done <= '0';
			pipe2_done <= '0';
			
			-- flush if necessary
			if (RS_flush = '1') then 
				flush_loop: for i in 0 to size_rs - 1 loop
					int_RS_table(i)(busy_i) <= '0'; -- row no longer busy and is ready to be overwritten
				end loop flush_loop;
			end if; --dunno what to put into else
			
			-- insert incoming instructions if they are valid and there is no stall. Indexes are determined from previous cycle
			if (stall_determine = '0' and RS_flush = '0') then -- Ideally after a flush, input valid bits should be 0
				if (valid_in1 = '1') then
					int_RS_table(in1_index) <= '1' & input_word1;
					in1_index_valid <= '0';
				end if;
				if (valid_in2 = '1') then
					int_RS_table(in2_index) <= '1' & input_word2;
					in2_index_valid <= '0';
				end if;
			end if;
			
		-- start traversing table. This is done regardless of a stall in RS  
			traverse_loop: for i in 0 to size_rs -1 loop -- im fucking breaking my head over this loop
					
				if (int_RS_table(i)(busy_i) = '1') then --row is busy so contains an instr
				
				-- Update operands and status and check if instr is ready
					if (int_RS_table(i)(row_len - 1) = '0') then -- instruction is not ready
						
						-- check if opr1 is valid
						if (int_RS_table(i)(valid1_i) = '0') then 
							if (int_RS_table(i)(opr1_start_i to opr1_end_addr_i) = rrf_reg1(0 to len_RRF - 1) and rrf_valid1 = '1') then
								int_RS_table(i)(valid1_i) <= '1'; -- update opr1 to prf_1
								int_RS_table(i)(opr1_start_i to opr1_end_i) <= rrf_reg1(len_RRF to input_RRF - 1);
							end if;
							if (int_RS_table(i)(opr1_start_i to opr1_end_addr_i) = rrf_reg2(0 to len_RRF - 1) and rrf_valid2 = '1') then
								int_RS_table(i)(valid1_i) <= '1'; -- update opr1 to prf_2
								int_RS_table(i)(opr1_start_i to opr1_end_i) <= rrf_reg2(len_RRF to input_RRF - 1);
							end if;
							if (int_RS_table(i)(opr1_start_i to opr1_end_addr_i) = rrf_reg3(0 to len_RRF - 1) and rrf_valid3 = '1') then
								int_RS_table(i)(valid1_i) <= '1'; -- update opr1 to prf_3
								int_RS_table(i)(opr1_start_i to opr1_end_i) <= rrf_reg3(len_RRF to input_RRF - 1);
							end if;
						end if;
						
						-- check if opr2 is valid
						if (int_RS_table(i)(valid2_i) = '0') then 
							if (int_RS_table(i)(opr2_start_i to opr2_end_addr_i) = rrf_reg1(0 to len_RRF - 1) and rrf_valid1 = '1') then
								int_RS_table(i)(valid2_i) <= '1'; -- update opr2 to prf_1
								int_RS_table(i)(opr2_start_i to opr2_end_i) <= rrf_reg1(len_RRF to input_RRF - 1);
							end if;
							if (int_RS_table(i)(opr2_start_i to opr2_end_addr_i) = rrf_reg2(0 to len_RRF - 1) and rrf_valid2 = '1') then
								int_RS_table(i)(valid2_i) <= '1'; -- update opr2 to prf_2
								int_RS_table(i)(opr2_start_i to opr2_end_i) <= rrf_reg2(len_RRF to input_RRF - 1);
							end if;
							if (int_RS_table(i)(opr2_start_i to opr2_end_addr_i) = rrf_reg3(0 to len_RRF - 1) and rrf_valid3 = '1') then
								int_RS_table(i)(valid2_i) <= '1'; -- update opr2 to prf_3
								int_RS_table(i)(opr2_start_i to opr2_end_i) <= rrf_reg3(len_RRF to input_RRF - 1);
							end if;
						end if;
						
						-- check if status is valid
						if (int_RS_table(i)(status_valid_i) = '0') then 
							if (int_RS_table(i)(status_start_i to status_end_addr_i) = status_reg1(0 to len_RRF - 1) and status_valid1 = '1') then
								int_RS_table(i)(status_valid_i) <= '1'; --update status to status_reg1
								int_RS_table(i)(status_start_i to status_end_i) <= status_reg1(len_RRF to len_RRF + 1);
							end if;
							if (int_RS_table(i)(status_start_i to status_end_addr_i) = status_reg2(0 to len_RRF - 1) and status_valid2 = '1') then
								int_RS_table(i)(status_valid_i) <= '1'; --update status to status_reg2
								int_RS_table(i)(status_start_i to status_end_i) <= status_reg2(len_RRF to len_RRF + 1);
							end if;
							if (int_RS_table(i)(status_start_i to status_end_addr_i) = status_reg3(0 to len_RRF - 1) and status_valid3 = '1') then
								int_RS_table(i)(status_valid_i) <= '1'; --update status to status_reg3
								int_RS_table(i)(status_start_i to status_end_i) <= status_reg3(len_RRF to len_RRF + 1);
							end if;
						end if;
						
						--update ready bit
						int_RS_table(i)(row_len - 1) <= int_RS_table(i)(valid1_i) and int_RS_table(i)(valid2_i) and int_RS_table(i)(status_valid_i);
					end if;
					
					-- Check if instruction is ready now after update/ was already ready
					if (int_RS_table(i)(row_len - 1) = '1') then
						if (pipe1_done = '0' and pipe1_busy = '0') then
							pipe1_out <= int_RS_table(i)(pc_start_i to pc_end_i) & int_RS_table(i)(control_start_i to control_end_i) & int_RS_table(i)(opr1_start_i to opr1_end_i) & int_RS_table(i)(opr2_start_i to opr2_end_i) & int_RS_table(i)(dest_start_i to dest_end_i) & int_RS_table(i)(status_dest_start_i to status_dest_end_i) & int_RS_table(i)(status_start_i to status_end_i);
							pipe1_done <= '1'; --mark as valid
							int_RS_table(i)(busy_i) <= '0'; -- make slot available
						else 
							if (pipe2_done = '0' and pipe2_busy = '0') then
								pipe2_out <= int_RS_table(i)(pc_start_i to pc_end_i) & int_RS_table(i)(control_start_i to control_end_i) & int_RS_table(i)(opr1_start_i to opr1_end_i) & int_RS_table(i)(opr2_start_i to opr2_end_i) & int_RS_table(i)(dest_start_i to dest_end_i) & int_RS_table(i)(status_dest_start_i to status_dest_end_i) & int_RS_table(i)(status_start_i to status_end_i);
								pipe2_done <= '1'; -- mark as valid
								int_RS_table(i)(busy_i) <= '0'; -- make slot available
							end if;
						end if;
					end if;
				end if;
				
				-- check if row is now free and assign a predetermined index for decoded instrs if it is
				if (int_RS_table(i)(busy_i) = '0') then --row is free, can use for an input instruction in the next cycle
					if (in1_index_valid <= '0') then 
						in1_index <= i;
						in1_index_valid <= '1';
					else 
						if (in2_index_valid <= '0') then
							in2_index <= i;
							in2_index_valid <= '1';
						end if;
					end if;
				end if;	
			end loop traverse_loop;
			
			-- Determine stall for next cycle and assign an output
			stall_determine <= not(in1_index_valid and in2_index_valid); -- stall if there is not atleast two spaces available
			
		end if;
	end process RS_proc;
	
	-- Output to pipelines
	pipe1_issue <= pipe1_out;
	pipe2_issue <= pipe2_out;
	
	-- Valid signals to pipelines 
	pipe1_issue_valid <= pipe1_done;
	pipe2_issue_valid <= pipe2_done;
	
	-- Stall output
	RS_stall <= stall_determine;
	
end architecture int_RS_arch;