library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity rob is
    generic(len_PC :integer := 5;
              len_RRF: integer := 6;
              len_ARF: integer := 3;
              len_op: integer := 4;
              size_rob: integer := 64;
              log_size_rob: integer := 6;
              row_len: integer := (len_PC + len_op + len_ARF + len_RRF + 1 + 1)); -- This line is only valid for VHDL-2008.

    port(clk, rob_flush: in std_logic;
          dispatch_word1, dispatch_word2: in std_logic_vector(row_len - 1 downto 0); -- dispatch word has PC, Opcode, ARF entry, RRF entry, speculative bit, executed bit
          valid_dispatch1, valid_dispatch2 : in std_logic; -- RS might have to send just one word/ no words in case of not having ready instr
          tag1, tag2, tag3 : in std_logic_vector(len_PC - 1 downto 0); -- one from each pipeline (execution words come from pipeline)
          valid1, valid2, valid3: in std_logic; -- if the executed words are valid
          mispred1, mispred2: in std_logic; -- used specifically for branch statements to signify that we have to flush the instructions after them (2 of them since we have 2 integer pipelines)
          retire_word1, retire_word2: out std_logic_vector(len_RRF - 1 downto 0); -- sent to PRF to tell it to update ARF
          valid_retire1, valid_retire2: out std_logic; -- in case you can only retire one of the instructions, make that valid_retirei as 0
          rob_stall: out std_logic);
end entity;

architecture Struct of rob is
  type rob_row_type is array(0 to size_rob - 1) of std_logic_vector(row_len - 1 downto 0); -- notice that it 0, 1, ..., size_rob-1 and not the other way round.
  constant default_row : std_logic_vector(row_len - 1 downto 0) := (others => '0');
  signal rob_row : rob_row_type := (others => default_row);
  constant branch_op : std_logic_vector(1 downto 0) := "10";
  signal head: unsigned(log_size_rob - 1 downto 0) :=0; -- log_size_rob - 1 downto 0 refers to the integer written bitwise
  signal tail: unsigned(log_size_rob - 1 downto 0) :=1; -- these are written in this way to ensure we get modular arithmetic
  signal ctr: unsigned(1 downto 0) := 0; -- honestly I am just using unsigned to save space (it can only hold 0, 1, 2, 3 so we are good)
  signal i: unsigned(log_size_rob - 1 downto 0) :=0; -- temporary variable for our loops

  constant len_status: unsigned(7 downto 0) := 1 + 1; -- spec and ex bit
  constant pc_start: unsigned(7 downto 0) := row_len - 1; -- assuming row_len cannot exceed 64
  constant pc_end: unsigned(7 downto 0) := len_op + len_ARF + len_RRF + len_status;
  constant op_start: unsigned(7 downto 0) := len_op + len_ARF + len_RRF + len_status - 1;
  constant op_end: unsigned(7 downto 0) := len_ARF + len_RRF + len_status;
  constant arf_start: unsigned(7 downto 0) := len_ARF + len_RRF + len_status - 1;
  constant arf_end: unsigned(7 downto 0) := len_RRF + len_status;
  constant rrf_start: unsigned(7 downto 0) := len_RRF + len_status - 1;
  constant rrf_end: unsigned(7 downto 0) := len_status;

begin
  normal_operation: process(clk)
  begin
    retire_word1 <= rob_row(to_integer(head))(rrf_start downto rrf_end);
    retire_word2 <= rob_row(to_integer(head + 1))(rrf_start downto rrf_end); -- irrespective of if it is valid or not, the RRF addresses would be sent to PRF

    if(rising_edge(clk)) then -- we don't want to do anything during the falling edge

      -- Flushing Cases -----------------------------------------
      if (rob_flush = '1') then --technically, a procedure could be more elegant but I don't know how to efficiently use it for a rob_row_type
        head <= 0;
        tail <= 1;
        for i in size_rob - 1 downto 0 loop
          rob_row(i)(0) <= '0'; -- makes all of the execution bits as zero; I could have made all of the rows into default_row but that is just unnecessary
        end loop;
      else --adding this to reduce the number of inferred latches
        head <= head;
        tail <= tail;
      end if;

      -- Welcoming dispatched instructions ---------------------
      if (valid_dispatch1 = '1' and tail/=head) then
        rob_row(to_integer(tail)) <= dispatch_word1;
        tail <= tail + 1;
      else --adding this to reduce the number of inferred latches
        rob_row(to_integer(tail)) <= dispatch_word1;
        tail <= tail;
      end if;

      if (valid_dispatch2 = '1' and tail/=head) then
        rob_row(to_integer(tail)) <= dispatch_word2;
        tail <= tail + 1;
      else --adding this to reduce the number of inferred latches
        rob_row(to_integer(tail)) <= dispatch_word2;
        tail <= tail;
      end if;

      -- Analysing executed instructions ------------------------
      ctr <= unsigned(valid1) + unsigned(valid2) + unsigned(valid3); -- so that we can break the cycle as soon as we don't have anything to match
      i <= 0;
      while ctr /= 0 loop
        if (valid1 and (rob_row(i)(pc_start downto pc_end) = tag1))) then -- we have a match on the ith row for the 1st word
          rob_row(i)(0) <= '1'; -- executed successfully
          ctr <= ctr - 1;
          if ((mispred1 = '1') and (rob_row(i)(op_start downto op_end + 2) = branch_op)) then -- zooming in on a mispredicted branch
            rob_row(i + 1)(1) = '1'; -- spec bit of next row is made 1
          end if;

        elsif (valid2 and (rob_row(i)(pc_start downto pc_end) = tag2)) then -- we have a match on the ith row for the 2nd word
          rob_row(i)(0) <= '1'; -- executed successfully
          ctr <= ctr - 1;
          if ((mispred2 = '1') and (rob_row(i)(op_start downto op_end + 2) = branch_op)) then -- zooming in on a mispredicted branch
            rob_row(i + 1)(1) = '1';
          end if;

        elsif (valid3 and (rob_row(i)(pc_start downto pc_end) = tag3)) then -- we have a match on the ith row for the 3rd word
          rob_row(i)(0) <= '1'; -- executed successfully
          ctr <= ctr - 1;

        else --adding this to reduce the number of inferred latches
          ctr <= ctr;
        end if;
        i <= i + 1;
      end loop;

      -- Retiring instructions -----------------------------------
      if (rob_row(to_integer(head))(1) = '1') then -- I do not want to create 2 ROB flush cases (i.e. when everything has to be wiped vs everything except head). So I will try to make this into a 2-step process in case the head if non-speculative but the head + 1 is.)
        head <= 0; --flushed the entire ROB
        tail <= 1;
        for i in size_rob - 1 downto 0 loop
          rob_row(i)(0) <= '0'; -- makes all of the execution bits as zero; I could have made all of the rows into default_row but that is just unnecessary
        end loop;

      elsif (rob_row(to_integer(head + 1))(1) = '1') then
        rob_row(to_integer(head + 1))(0) <= '0'; -- We are lying about the execution status of (head + 1) to get one more cycle before we have to flush

      else
        null; --idk what this does. I am just copying from Vedika

      end if;

      if (rob_row(to_integer(head))(0) and rob_row(to_integer(head + 1))(0) = '1') then -- we have zoomed in on the ex_bit for the word on the top and second-top
        valid_retire1 <= '1';
        valid_retire2 <= '1';
        head <= head + 2; -- head is lowered

      elsif (rob_row(to_integer(head))(0) = '1') then -- only one word is retired
        valid_retire1 <= '1';
        valid_retire2 <= '0';
        head <= head + 1; -- head is lowered
      else
        valid_retire1 <= '0';
        valid_retire2 <= '0';
        head <= head; -- symmetry helps ig?
      end if;

      -- Checking if we need to stall in next cycle ---------------
      if (head = tail or head = tail + 1) then -- stall condition (we don't accept anything even if we have just 1 slot free)
        rob_stall <= '1';
      else
        rob_stall <= '0';
      end if;

    end if;

  end process normal_operation;
end Struct;
