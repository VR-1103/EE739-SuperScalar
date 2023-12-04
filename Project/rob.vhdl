library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

entity rob is
    generic(len_PC :integer := 5;
              len_RRF: integer := 6;
              len_ARF: integer := 3;
              len_op: integer := 4;
              size_rob: integer := 64;
              log_size_rob: integer := 6;
              len_imm : integer := 6;
              row_len: integer := (1 + 6 + 5 + 4 + 3 + 6 + 1 + 1 + 1)); -- busy_bit + len_imm + len_PC + len_op + len_ARF + len_RRF + mispred_bit + disabled_bit + executed_bit

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
end entity;

-- Row Len has
-- Busy bit, PC, Op_code, ARF, RRF, mispred bit, disabled bit, executed bit

architecture Struct of rob is

  type rob_row_type is array(0 to size_rob - 1) of std_logic_vector(row_len - 1 downto 0); -- notice that it 0, 1, ..., size_rob-1 and not the other way round.
  constant default_row : std_logic_vector(row_len - 1 downto 0) := (others => '0');
  signal rob_row : rob_row_type := (0 => "1000000000000001001000000000", 1 => "1000000000100010010000001001", 2 => "1000000001000010011000010000", 3 => "1000000001100001100000011001", 4 => "1000000010000001101000100001", 5 => "1000000010100010110000101001", others => default_row);
  constant branch_op : std_logic_vector(1 downto 0) := "10";
  signal head: unsigned(log_size_rob - 1 downto 0) := (others => '0'); -- log_size_rob - 1 downto 0 refers to the integer written bitwise
  signal tail: unsigned(log_size_rob - 1 downto 0) := to_unsigned(6, log_size_rob); -- these are written in this way to ensure we get modular arithmetic
  signal jump_location: std_logic_vector(len_PC - 1 downto 0) := std_logic_vector(to_unsigned(42, len_PC)); -- in case we have to flush, where exactly do we go to?
  signal jump_tag: std_logic_vector(len_PC - 1 downto 0) := (others=> '1'); -- to identify which instruction caused this jump location, by default it is set to the maximum value
  signal head_is_load, head_plus_is_load, head_is_store, head_plus_is_store : std_logic := '0'; -- used for L/S instruction ka retirement
  signal testing_debugger, testing_debugger_2 : std_logic := '0';
  signal what_is_tail : integer := 1;

  constant len_status: integer := 1 + 1 + 1; -- spec, disable, ex bit
  constant mispred_bit_loc: integer := 2;
  constant disable_bit_loc: integer := 1;
  constant ex_bit_loc: integer := 0;
  constant busy_bit_loc : integer := row_len - 1;
  constant tag_start : integer := row_len - 2;
  constant tag_end : integer := len_op + len_ARF + len_RRF + len_status;
  constant pc_start: integer := len_PC + len_op + len_ARF + len_RRF + len_status - 1;
  constant pc_end: integer := len_op + len_ARF + len_RRF + len_status;
  constant imm_start : integer := len_PC + len_op + len_ARF + len_RRF + len_status;
  constant imm_end : integer := row_len - 2;
  constant op_start: integer := len_op + len_ARF + len_RRF + len_status - 1;
  constant op_end: integer := len_ARF + len_RRF + len_status;
  constant arf_start: integer := len_ARF + len_RRF + len_status - 1;
  constant arf_end: integer := len_RRF + len_status;
  constant rrf_start: integer := len_RRF + len_status - 1;
  constant rrf_end: integer := len_status;

begin
  normal_operation: process(clk, valid_dispatch1, valid_dispatch2, dispatch_word1, dispatch_word2)
  begin
		
	 if (rising_edge(clk)) then -- we don't want to do anything during the falling edge
		-- Flushing Cases -----------------------------------------
      if (rob_flush = '1') then --technically, a procedure could be more elegant but I don't know how to efficiently use it for a rob_row_type
        valid_fetch <= '1'; -- we want to send some location to fetch stage
        jump_location <= flush_location;
        jump_tag <= (others=> '1');
        head <= (others => '0');
        tail <= (others => '0');
        for i in size_rob - 1 downto 0 loop
          rob_row(i)(mispred_bit_loc downto ex_bit_loc) <= "000"; -- makes all of the status bits as zero; I could have made all of the rows into default_row but that is just unnecessary
          rob_row(i)(busy_bit_loc) <= '0'; -- every row is not "valid"
        end loop;
      
		else --adding this to reduce the number of inferred latches
        valid_fetch <= '0';
      end if;

      -- Welcoming dispatched instructions ---------------------
      what_is_tail <= to_integer(tail);
      if valid_dispatch1 = '1' and valid_dispatch2 = '1' then
        rob_row(to_integer(tail))(busy_bit_loc) <= '1';
        rob_row(to_integer(tail + 1))(busy_bit_loc) <= '1';
        rob_row(to_integer(tail))(disable_bit_loc) <= dispatch_word1(0);
        rob_row(to_integer(tail))(rrf_start downto rrf_end) <= dispatch_word1(len_RRF downto 1);
        rob_row(to_integer(tail))(arf_start downto arf_end) <= dispatch_word1(len_ARF + len_RRF downto len_RRF + 1);
        rob_row(to_integer(tail))(op_start downto op_end) <= dispatch_word1(len_ARF + len_RRF +len_op downto len_RRF + len_ARF + 1);
        rob_row(to_integer(tail))(tag_start downto tag_end) <= dispatch_word1(len_ARF + len_RRF + len_op + len_PC + len_imm downto  len_RRF + len_ARF + len_op + 1);
        rob_row(to_integer(tail))(ex_bit_loc) <= '0';
        rob_row(to_integer(tail))(mispred_bit_loc) <= '0';
        rob_row(to_integer(tail + 1))(disable_bit_loc) <= dispatch_word2(0);
        rob_row(to_integer(tail + 1))(rrf_start downto rrf_end) <= dispatch_word2(len_RRF downto 1);
        rob_row(to_integer(tail + 1))(arf_start downto arf_end) <= dispatch_word2(len_ARF + len_RRF downto len_RRF + 1);
        rob_row(to_integer(tail + 1))(op_start downto op_end) <= dispatch_word2(len_ARF + len_RRF +len_op downto len_RRF + len_ARF + 1);
        rob_row(to_integer(tail + 1))(tag_start downto tag_end) <= dispatch_word2(len_ARF + len_RRF +len_op + len_PC + len_imm downto  len_RRF + len_ARF + len_op + 1);
        rob_row(to_integer(tail + 1))(ex_bit_loc) <= '0';
        rob_row(to_integer(tail + 1))(mispred_bit_loc) <= '0';
        tail <= tail + 2;
      elsif valid_dispatch1 = '1' then
        rob_row(to_integer(tail))(busy_bit_loc) <= '1';
        rob_row(to_integer(tail))(disable_bit_loc) <= dispatch_word1(0);
        rob_row(to_integer(tail))(rrf_start downto rrf_end) <= dispatch_word1(len_RRF downto 1);
        rob_row(to_integer(tail))(arf_start downto arf_end) <= dispatch_word1(len_ARF + len_RRF downto len_RRF + 1);
        rob_row(to_integer(tail))(op_start downto op_end) <= dispatch_word1(len_ARF + len_RRF +len_op downto len_RRF + len_ARF + 1);
        rob_row(to_integer(tail))(tag_start downto tag_end) <= dispatch_word1(len_ARF + len_RRF +len_op + len_PC + len_imm downto  len_RRF + len_ARF + len_op + 1);
        rob_row(to_integer(tail))(ex_bit_loc) <= '0';
        rob_row(to_integer(tail))(mispred_bit_loc) <= '0';
        tail <= tail + 1;
      elsif valid_dispatch2 = '1' then
        rob_row(to_integer(tail))(busy_bit_loc) <= '1';
        rob_row(to_integer(tail))(disable_bit_loc) <= dispatch_word2(0);
        rob_row(to_integer(tail))(rrf_start downto rrf_end) <= dispatch_word2(len_RRF downto 1);
        rob_row(to_integer(tail))(arf_start downto arf_end) <= dispatch_word2(len_ARF + len_RRF downto len_RRF + 1);
        rob_row(to_integer(tail))(op_start downto op_end) <= dispatch_word2(len_ARF + len_RRF +len_op downto len_RRF + len_ARF + 1);
        rob_row(to_integer(tail))(tag_start downto tag_end) <= dispatch_word2(len_ARF + len_RRF +len_op + len_PC + len_imm downto  len_RRF + len_ARF + len_op + 1);
        rob_row(to_integer(tail))(ex_bit_loc) <= '0';
        rob_row(to_integer(tail))(mispred_bit_loc) <= '0';
        tail <= tail + 1;
      else --adding this to reduce the number of inferred latches
        rob_row(to_integer(tail))(busy_bit_loc) <= '0';
        tail <= tail;
      end if;

      for i in size_rob - 1 downto 0 loop
      -- Analysing executed instructions ------------------------
        if rob_row(i)(busy_bit_loc) = '1' then -- only checking valid rows

          if valid_execute2 = '1' and (rob_row(i)(pc_start downto pc_end) = execute_word2(len_PC + 1 + len_PC - 1 downto 1 + len_PC)) then -- we have a match on the ith row for the 2nd word
            rob_row(i)(ex_bit_loc) <= '1'; -- executed successfully
            rob_row((i + 1) mod size_rob)(mispred_bit_loc) <= execute_word2(1 + len_PC - 1); -- mispredict bit of execute word is now considered as the next row's mispredict bit
            if (execute_word2(1 + len_PC -1) = '1') and (unsigned(jump_tag) < unsigned(execute_word2 (len_PC + 1 + len_PC - 1 downto 1 + len_PC))) then -- we have a mispredicted branch which comes before the one we already have
              jump_tag <= execute_word2(len_PC + 1 + len_PC - 1 downto 1 + len_PC);
              jump_location <= execute_word2(len_PC - 1 downto 0); -- jump location updated

            else
              jump_tag <= jump_tag;
              jump_location <= jump_location;

            end if;

          elsif (valid_execute3 = '1') and (rob_row(i)(pc_start downto pc_end) = execute_word3(len_PC + 1 + len_PC - 1 downto 1 + len_PC)) then -- we have a match on the ith row for the 3rd word
            rob_row(i)(ex_bit_loc) <= '1'; -- executed successfully
            rob_row((i + 1) mod size_rob)(mispred_bit_loc) <= execute_word3(1 + len_PC - 1); -- mispredict bit of execute word is now considered as the next row's mispredict bit
            if (execute_word3(1 + len_PC -1) = '1') and (unsigned(jump_tag) < unsigned(execute_word3 (len_PC + 1 + len_PC - 1 downto 1 + len_PC))) then -- we have a mispredicted branch which comes before the one we already have
              jump_tag <= execute_word3(len_PC + 1 + len_PC - 1 downto 1 + len_PC);
              jump_location <= execute_word3(len_PC - 1 downto 0); -- jump location updated

            else
              jump_tag <= jump_tag;
              jump_location <= jump_location;

            end if;

          elsif ((valid_store1 = '1') and (rob_row(i)(tag_start downto tag_end) = execute_store1)) or
                ((valid_store2 = '1') and (rob_row(i)(tag_start downto tag_end) = execute_store2)) or
                ((valid_load1 = '1') and (rob_row(i)(tag_start downto tag_end) = execute_load1)) or
                ((valid_load2 = '1') and (rob_row(i)(tag_start downto tag_end) = execute_load2)) then -- we are having some or the correct load or store having executed
            rob_row(i)(ex_bit_loc) <= '1'; -- executed successfully

          elsif (valid_alias1 = '1') and (rob_row(i)(tag_start downto tag_end) = alias_tag1) then
            rob_row(i)(mispred_bit_loc) <= '1';
            jump_tag <= alias_tag1(len_PC - 1 downto 0);
            jump_location <= alias_tag1(len_PC - 1 downto 0);

          elsif (valid_alias2 = '1') and (rob_row(i)(tag_start downto tag_end) = alias_tag2) then
            rob_row(i)(mispred_bit_loc) <= '1';
            jump_tag <= alias_tag2(len_PC - 1 downto 0);
            jump_location <= alias_tag2(len_PC - 1 downto 0);

          else --i.e. if neither of the executed words match
            null;
          end if;

        else
          null; -- genuinely don't know what this will be synthesized as

        end if;

      end loop;

      -- Retiring mispredicted instructions -----------------------------------
      retire_word1 <= rob_row(to_integer(head))(rrf_start downto rrf_end);
      retire_word2 <= rob_row(to_integer(head + 1))(rrf_start downto rrf_end);
      retire_load1 <= rob_row(to_integer(head))(tag_start downto tag_end);
      retire_load2 <= rob_row(to_integer(head + 1))(tag_start downto tag_end);

		if rob_row(to_integer(head))(mispred_bit_loc) = '1' then -- I do not want to create 2 ROB flush cases (i.e. when everything has to be wiped vs everything except head). So I will try to make this into a 2-step process in case the head if non-speculative but the head + 1 is.)
        valid_fetch <= '1';
        jump_tag <= (others => '1'); -- we want to start off with a new slate
        head <= (others => '0'); --flush the entire ROB
        tail <= (others => '0');
        for i in size_rob - 1 downto 0 loop
          rob_row(i)(ex_bit_loc) <= '0'; -- makes all of the valid and execution bits as zero; I could have made all of the rows into default_row but that is just unnecessary
          rob_row(i)(busy_bit_loc) <= '0';
        end loop;

      elsif rob_row(to_integer(head + 1))(mispred_bit_loc) = '1' then
        rob_row(to_integer(head))(ex_bit_loc) <= '0'; -- We are lying about the execution status of (head + 1) to get one more cycle before we have to flush
        valid_fetch <= '0';
      else
        valid_fetch <= '0';
      end if;

      if (rob_row(to_integer(head + 1))(op_start downto op_end) = "0011" or rob_row(to_integer(head + 1))(op_start downto op_end) = "0100") and (rob_row(to_integer(head + 1))(mispred_bit_loc) = '0') then
          head_plus_is_load <= '1' and (not rob_row(to_integer(head + 1))(disable_bit_loc));
          head_plus_is_store <= '0';
      elsif (rob_row(to_integer(head + 1))(op_start downto op_end) = "0101") and (rob_row(to_integer(head + 1))(mispred_bit_loc) = '0') then
          head_plus_is_load <= '0';
          head_plus_is_store <= '1' and (not rob_row(to_integer(head + 1))(disable_bit_loc));
      else
          head_plus_is_load <= '0';
          head_plus_is_store <= '0';
      end if;

      if (rob_row(to_integer(head))(op_start downto op_end) = "0011" or rob_row(to_integer(head + 1))(op_start downto op_end) = "0100") and (rob_row(to_integer(head))(mispred_bit_loc) = '0') then
          head_is_load <= '1' and (not rob_row(to_integer(head))(disable_bit_loc));
          head_is_store <= '0';
      elsif rob_row(to_integer(head))(op_start downto op_end) = "0101" and (rob_row(to_integer(head))(mispred_bit_loc) = '0') then
          head_is_load <= '0';
          head_is_store <= '1' and (not rob_row(to_integer(head))(disable_bit_loc)); -- head isn't a store if it is disabled
      else
          head_is_load <= '0';
          head_is_store <= '0';
      end if;


      -- Retiring valid instructions -----------------------------------
      if (rob_row(to_integer(head))(ex_bit_loc) = '1') and (rob_row(to_integer(head + 1))(ex_bit_loc) = '1') and (rob_row(to_integer(head))(mispred_bit_loc) = '0') and (rob_row(to_integer(head + 1))(mispred_bit_loc) = '0') then -- we have zoomed in on the ex_bit for the word on the top and second-top
        valid_retire_load1 <= head_is_load xor head_plus_is_load;
        valid_retire_load2 <= head_is_load and head_plus_is_load; -- 00 if none, 01 if one, 10 if both
        retire_store(0) <= head_is_store xor head_plus_is_store;
        retire_store(1) <= head_is_store and head_plus_is_store; -- 00 if none, 01 if one, 10 if both
        valid_retire1 <= not (head_is_store or rob_row(to_integer(head))(disable_bit_loc));
        valid_retire2 <= not (head_plus_is_store or rob_row(to_integer(to_unsigned(to_integer(head) + 1, log_size_rob)))(disable_bit_loc));

        update_r0 <= rob_row(to_integer(to_unsigned(to_integer(head) + 1, log_size_rob)))(pc_start downto pc_end);
        valid_update <= '1';

        rob_row(to_integer(head))(busy_bit_loc) <= '0';
        rob_row(to_integer(head + 1))(busy_bit_loc) <= '0';
        rob_row(to_integer(head))(ex_bit_loc) <= '0';
        rob_row(to_integer(head + 1))(ex_bit_loc) <= '0';
        head <= head + 2; -- head is lowered

      elsif (rob_row(to_integer(head))(ex_bit_loc) = '1') and (rob_row(to_integer(head))(mispred_bit_loc) = '0') then -- only one word is retired
        valid_retire_load1 <= head_is_load;
        valid_retire_load2 <= '0';
        retire_store(0) <= head_is_store;
        retire_store(1) <= '0';
        valid_retire1 <= not (head_is_store or rob_row(to_integer(head))(disable_bit_loc));
        valid_retire2 <= '0';

        update_r0 <= rob_row(to_integer(head))(pc_start downto pc_end);
        valid_update <= '1';

        rob_row(to_integer(head))(busy_bit_loc) <= '0';
        rob_row(to_integer(head))(ex_bit_loc) <= '0';
        retire_store(0) <= head_is_store;
        retire_store(1) <= '0'; -- 00 if none, 01 if one
        head <= head + 1; -- head is lowered
      else
        retire_store <= "00";-- 00 always
        valid_retire_load1 <= '0';
        valid_retire_load2 <= '0';
        valid_retire1 <= '0';
        valid_retire2 <= '0';

        update_r0 <= rob_row(to_integer(head))(pc_start downto pc_end);
        valid_update <= '0';

        head <= head; -- symmetry helps ig?
      end if;

      -- Checking if we need to stall in next cycle ---------------
      if ((head = tail) and (rob_row(to_integer(head))(busy_bit_loc) = '1')) or (head = tail + 1) then -- stall condition (we don't accept anything even if we have just 1 slot free)
        rob_stall <= '1'; -- the and condition above comes from the case when rob is empty i.e. head = tail and there is no entry present
      else
        rob_stall <= '0';
      end if;

      -- sending the correct jump location to the fetch stage
      fetch_loc <= jump_location; -- we always only send the jump_location even if it is not valid right now
    end if;
  end process normal_operation;
end Struct;
