-- A DUT entity is used to wrap your design so that we can combine it with testbench.
-- This example shows how you can do this for the OR Gate

library ieee;
use ieee.std_logic_1164.all;

entity DUT is
	generic(len_PC :integer := 5;
              len_RRF: integer := 6;
              len_ARF: integer := 3;
              len_op: integer := 4;
              size_rob: integer := 64;
              log_size_rob: integer := 6;
              row_len: integer := (1 + 5 + 4 + 3 + 6 + 1 + 1 + 1)); -- 1 + len_PC + len_op + len_ARF + len_RRF + 1 + 1 + 1
    port(input_vector: in std_logic_vector(64 downto 0); 
	 output_vector: out std_logic_vector(1 downto 0));
end entity;

architecture DutWrap of DUT is
   component testing_rob is
		port(clk, rob_flush: in std_logic;
          flush_location: in std_logic_vector(len_PC - 1 downto 0); -- tells us where we should ask fetch to go to in the next cycle
          -- Interconnections with decoder $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          dispatch_word1, dispatch_word2: in std_logic_vector(row_len - 4 downto 0); -- dispatch word has PC, Opcode, ARF entry, RRF entry, disabled bit
          valid_dispatch1, valid_dispatch2 : in std_logic; -- decoder might have to send just one word/ no words in case of not having ready instr
          -- Interconnections with fetch stage $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          valid_fetch : out std_logic;
          fetch_loc : out std_logic_vector(len_PC - 1 downto 0);
          -- Interconnections with pipelines $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          execute_word2, execute_word3 : in std_logic_vector(len_PC + 1 + len_PC - 1 downto 0); -- PC tag, mispredict bit, jump_location
          valid_execute2, valid_execute3: in std_logic; -- if the executed words are valid (only come from the integer pipelines)
          -- Interconnections with PRF $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          retire_word1, retire_word2: out std_logic_vector(len_RRF - 1 downto 0); -- sent to PRF to tell it to update ARF
          valid_retire1, valid_retire2: out std_logic;
          update_r0 : out std_logic_vector(len_PC - 1 downto 0);
          valid_update : out std_logic;
          -- Interconnections with Store Buffer $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          retire_store: out std_logic_vector(1 downto 0);
          valid_store1, valid_store2 : in std_logic;
          execute_store1, execute_store2 : in std_logic_vector(len_PC -1 downto 0);
          -- Interconnections with Load Queue $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          valid_load1, valid_load2 : in std_logic;
          execute_load1, execute_load2 : in std_logic_vector(len_PC -1 downto 0);
          retire_load1, retire_load2 : out std_logic_vector(len_PC - 1 downto 0);
          valid_retire_load1, valid_retire_load2 : out std_logic;
          alias_tag1, alias_tag2 : in std_logic_vector(len_PC - 1 downto 0);
          valid_alias1, valid_alias2 : in std_logic;
          -- General port
          rob_stall: out std_logic);
	end component testing_rob;
	
	signal signal_valid_fetch, signal_valid_retire1, signal_valid_retire2, signal_valid_update, signal_valid_retire_load2, signal_valid_retire_load1, signal_rob_stall: std_logic := '0';
	signal signal_retire_load1, signal_retire_load2, signal_update_r0, signal_fetch_loc, signal_execute_load1, signal_execute_load2, signal_alias_tag1, signal_alias_tag2, signal_flush_location, signal_execute_store1, signal_execute_store2 : std_logic_vector(len_PC - 1 downto 0) := "00000";
	signal signal_retire_word1, signal_retire_word2: std_logic_vector(len_RRF - 1 downto 0) := "000000";
	signal signal_retire_store :std_logic_vector(1 downto 0) := "00";
	
begin
   -- input/output vector element ordering is critical,
   -- and must match the ordering in the trace file!
   add_instance: testing_rob 
			port map (clk =>input_vector(64), rob_flush => '0', 
						valid_dispatch1 =>input_vector(63),
						dispatch_word1 =>input_vector(62 downto 44), 
						valid_dispatch2 =>input_vector(43),
						dispatch_word2 =>input_vector(42 downto 24),
						valid_fetch => signal_valid_fetch,
						fetch_loc => signal_fetch_loc,
						valid_execute2 =>input_vector(23),
						execute_word2 =>input_vector(22 downto 12), 
						valid_execute3 =>input_vector(11),
						execute_word3 =>input_vector(10 downto 0),
						valid_retire1 => signal_valid_retire1,
						retire_word1 => signal_retire_word1,
						valid_retire2 => signal_valid_retire2,
						retire_word2 => signal_retire_word2,
						update_r0 => signal_update_r0,
						valid_update => signal_valid_update,
						retire_store => signal_retire_store,
						valid_retire_load1 => signal_valid_retire_load1,
						retire_load1 => signal_retire_load1,
						valid_retire_load2 => signal_valid_retire_load2,
						retire_load2 => signal_retire_load2,
						rob_stall => signal_rob_stall,
						valid_load1 =>'0',
						valid_load2 =>'0',
						valid_alias1 =>'0',
						valid_alias2 =>'0',
						flush_location => signal_flush_location,
						valid_store1 => '0',
						valid_store2 => '0',
						execute_store1 => signal_execute_store1,
						execute_store2 => signal_execute_store2,
						alias_tag1 => signal_alias_tag1,
						alias_tag2 => signal_alias_tag2,
						execute_load1 => signal_execute_load1,
						execute_load2 => signal_execute_load2);
						
end DutWrap;