library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity store_buffer is
    generic(len_PC :integer := 5;
              len_mem_addr: integer := len_PC;
              len_data: integer := 16;
              size_load: integer := 16;
              log_size_load: integer := 4;
              row_len: integer := (1 + len_PC + len_mem_addr + 1 + 1 + 1)); -- busy bit+pc_add+mem_add+forwarded bit+alias bit+valid bit

    port(clk, load_queue_flush : in std_logic; -- we will use the flush to remove the "un-retired" instructions
          -- dispatch stage $$$$$$$$$$$$$$--
          dispatch_word1, dispatch_word2 : in std_logic_vector(len_PC - 1 downto 0); -- dispatch word has PC
			 dispatch_word1_validity,dispatch_word2_validity: in std_logic;
          -- post-execute stage $$$$$$$$$$--
          tag1 : in std_logic_vector(len_PC - 1 downto 0); -- one from L/S pipeline (execution words come from pipeline)
          addr1 : in std_logic_vector(len_mem_addr - 1 downto 0);
			 forwarded1: in std_logic;
          valid_load_execute1 : in std_logic; -- if the executed words are actually meant for load_queue
			 --checking from store buffer stage--
			 store_mem_addr : in std_logic_vector(lem_mem_addr-1 downto 0);
			 valid_store_addr: in std_logic; --if checking is actually required
			 --ROB stage--
			 valid_rob_instr: in std_logic; --if it is even a load instr at the top of rob
			 rob_pc_addr: in std_logic_vector(len_PC-1 downto 0);
			 validity_of_instr: out std_logic;
			 --post ROB stage--
			 retired_rob_pc_addr: in std_logic_vector(len_PC-1 downto 0);
			 valid_retirement: in std_logic);
end entity;

-- row word has busy bit, PC, Memory Addr, Data, executed bit, valid bit, completed bit
--############ Format of the store_row #####################--
-- busy bit: Is this entry garbage or not
-- PC : obvious
-- Memory Addr : Where we want to store the data
-- Data : What we want to store (can be data or addr of RRF)
-- Executed bit : If the addr has been calculated by pipeline or if it is garbage
-- Valid bit : If the data in store_buffer is valid or garbage
-- Completed bit : If ROB has retired the instruction thus making it free to be written into the memory port
--############################################################

architecture Struct of store_buffer is
	type load_row_type is array(0 to size_load - 1) of std_logic_vector(row_len - 1 downto 0); -- notice that it 0, 1, ..., size_rob-1 and not the other way round.
	constant default_row : std_logic_vector(row_len - 1 downto 0) := (others => '0');
	signal load_row : load_row_type := (others => default_row);
	variable status: std_logic;
begin
	normal_op: process(clk)
	begin
	----Dispatch---

		if(dispatch_word1_validity = '1') then
			status <= '0';
			L1: for i in 0 to size_load - 1 loop
			if (load_row(i)(row_len-1) = 0) then
				if status = '0' then
					load_row(i)(row_len-1-1 downto row_len-len_PC-1) <= dispatch_word1;
					load_row(i)(0) <= '0';
					load_row(i)(row_len-1) <= '1';
					status <= '1';
				else
					null;
				end if;
			else
				null;
			end if;
			end loop;
		else
			null;
		end if;
		if(dispatch_word2_validity = '1') then
			status <= '0';
			L2: for i in 0 to size_load-1 loop
			if (load_row(i)(row_len-1) = 0) then
				if status = '0' then
					load_row(i)(row_len-1-1 downto row_len-len_PC-1) <= dispatch_word2;
					load_row(i)(0) <= '0';
					load_row(i)(row_len-1) <= '1';
					status <= '1';
				else null;
				end if;
			else null;
			end if;
			end loop;
		else
			null;
		end if;
		
	----Flush----	
		if (load_queue_flush = '1') then
			L3: for i in 0 to size_load-1 loop
			load_row(i)(row_len-1) <= '0';
			end loop;
		else
			null;
		end if;
		
	----Post execute----
		if (valid_load_execute1 = '1') then
			status <= '0';
			L4: for i in 0 to size_load-1 loop
			if ((load_row(i)(row_len-1) = '1') and (load_row(i)(row_len-1-1 downto row_len-len_PC-1) = tag1)) then
				if status = '0' then
					load_row(i)(len_mem_addr+3-1  downto 3) <= addr1;
					load_row(i)(2) <= forwarded1;
					load_row(i)(0) <= '0';
					status <= '1';
				else null;
				end if;
			else
				null;
			end if;
			end loop;
		end if;
		
	----Checking for aliasing----
		if (valid_store_addr = '1') then
			status <= '0';
			L5: for i in 0 to size_load-1 loop
			if ((load_row(i)(row_len-1) = '1') and (load_row(i)(len_mem_addr+3-1  downto 3) = store_mem_addr)) then
				if status = '0' then
					if (load_row(i)(2) = '0') then
						load_row(i)(1) <= '1';
						load_row(i)(0) <= '0';
						status <= '1';
					else null;
					end if;
				else null;
				end if;
			else
				null;
			end if;
			end loop;
		else
			null;
		end if;
		
	----ROB----
		if (valid_rob_instr = '1') then
		`	status <= '0';
			L6: for i in 0 to size_load-1 loop
			if ((load_row(i)(row_len-1) = '1') and (load_row(i)(row_len-1-1 downto row_len-len_PC-1) = rob_pc_addr)) then
				if status = '0' then
					if (load_row(i)(1) = '1') then
						validity_of_instr <= '0';
					else
						validity_of_instr <= '1';
					end if;
					status <= '1';
				else null;
				end if;
			else null;
			end if;
			end loop;
		else null;
		end if;
		
	----Post ROB----
		if (valid_retirement = '1') then
			status <= '0';
			L7: for i in 0 to size_load-1 loop
			if ((load_row(i)(row_len-1) = '1') and (load_row(i)(row_len-1-1 downto row_len-len_PC-1) = retired_rob_pc_addr)) then
				if status = '0' then
					load_row(i)(row_len-1) <= '0';
					status <= '1';
				else null;
				end if;
			else null;
			end if;
			end loop;
		else null;
		end if;
		
	end process;	
	
end Struct;
