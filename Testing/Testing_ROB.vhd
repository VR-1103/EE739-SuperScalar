library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

entity testing_rob is
    generic(len_imm : integer := 6;
				len_PC :integer := 5;
				len_RRF: integer := 6;
				len_ARF: integer := 3;
				len_op: integer := 4;
				size_rob: integer := 64;
				log_size_rob: integer := 6;
				row_len: integer := (1 + 6 + 5 + 4 + 3 + 6 + 1 + 1 + 1)); -- 1 + len_imm + len_PC + len_op + len_ARF + len_RRF + 1 + 1 + 1

    port(clk : in std_logic;
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
          -- Interconnections with Load Queue $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          retire_load1, retire_load2 : out std_logic_vector(len_imm + len_PC - 1 downto 0);
          valid_retire_load1, valid_retire_load2 : out std_logic;
          rob_stall : out std_logic);
end entity;

-- Row Len has
-- Busy bit, PC, Op_code, ARF, RRF, spec bit, disabled bit, executed bit

architecture Struct of testing_rob is
	component rob is
		port(clk, rob_flush: in std_logic;
          flush_location: in std_logic_vector(len_PC - 1 downto 0); -- tells us where we should ask fetch to go to in the next cycle
          -- Interconnections with decoder $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          dispatch_word1, dispatch_word2: in std_logic_vector(row_len - 4 downto 0); -- dispatch word has imm, PC, Opcode, ARF entry, RRF entry, disabled bit
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
          execute_store1, execute_store2 : in std_logic_vector(len_imm + len_PC -1 downto 0);
          -- Interconnections with Load Pipeline $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          valid_load1, valid_load2 : in std_logic;
          execute_load1, execute_load2 : in std_logic_vector(len_imm + len_PC - 1 downto 0);
          -- Interconnections with Load Queue $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          retire_load1, retire_load2 : out std_logic_vector(len_imm + len_PC - 1 downto 0);
          valid_retire_load1, valid_retire_load2 : out std_logic;
          alias_tag1, alias_tag2 : in std_logic_vector(len_imm + len_PC - 1 downto 0);
          valid_alias1, valid_alias2 : in std_logic;
          -- General port
          rob_stall: out std_logic);
	end component;
	
	for all:rob
		use entity work.rob(Struct);
		
	signal i: integer := 0;
		
	begin
		
		the_rob: component rob
			port map(clk, '0',
				 "00000",
				 -- Interconnections with decoder $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
				 dispatch_word1, dispatch_word2,
				 '0', '0',
				 -- Interconnections with fetch stage $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
				 valid_fetch,
				 fetch_loc,
				 -- Interconnections with pipelines $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
				 execute_word2, execute_word3,
					'1', '1',
				 -- Interconnections with PRF $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
				 retire_word1, retire_word2,
				 valid_retire1, valid_retire2,
				 update_r0,
				 valid_update,
				 -- Interconnections with Store Buffer $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
				 retire_store,
				 '0', '0',
				 "00000000000", "00000000000",
				 -- Interconnections with Load Queue $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
				 '0', '0',
				 "00000000000", "00000000000",
				 retire_load1, retire_load2,
				 valid_retire_load1, valid_retire_load2,
				 "00000000000", "00000000000",
				 '0', '0',
				 -- General port
				 rob_stall);
		
end Struct;
