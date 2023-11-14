library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity store_buffer is
    generic(len_PC :integer := 5;
              len_mem_addr: integer := len_PC;
              len_data: integer := 16;
              size_store: integer := 16;
              log_size_store: integer := 4;
              row_len: integer := (1 + len_PC + len_mem_addr + len_data + 1 + 1)); -- This line is only valid for VHDL-2008.

    port(clk, store_buffer_flush : in std_logic; -- I don't know when you would need to flush an entire store queue but okay
          retire_word1, retire_word2 : in std_logic_vector(row_len - 1 downto 0); -- dispatch word has busy bit, PC, Memory Addr, Data, spec bit, executed bit
          valid_dispatch1, valid_dispatch2 : in std_logic; -- '1' only when RS has sent it specifically for store and is not garbage
          tag1 : in std_logic_vector(len_PC - 1 downto 0); -- one from L/S pipeline (execution words come from pipeline)
          addr1 : in std_logic_vector(len_mem_addr - 1 downto 0); -- data is already with the store buffer from dispatch
          valid_store_execute1 : in std_logic; -- if the executed words are actually meant for store buffer
          unbuffer_word1, unbuffer_word2 : in std_logic_vector(len_PC - 1 downto 0); -- when ROB retires a word, it sends that to store queue
          valid_unbuffer1, valid_unbuffer2 : in std_logic; -- '1' only if
          complete_word1 : out std_logic_vector(len_PC - 1 downto 0); -- sent to ROB to tell it that the row can be now executed pakka (this is required to ensure "data" in store buffer is actual data)
          valid_complete1 : out std_logic; -- in case you can only retire one of the instructions, make that valid_retirei as 0
          store_buffer_stall: out std_logic);
end entity;

------------ Format of the store_row -----------------------
-- busy bit: Is this entry garbage or not
-- PC : obvious
-- Memory Addr : Where we want to store the data
-- Data : What we want to store (can be data or addr of RRF)
-- Spec bit : Used to flush the store queue in case we find any issues
-- Executed bit : If the addr has been calculated by pipeline or if it is garbage
------------------------------------------------------------

architecture Struct of store_buffer is
  type store_row_type is array(0 to size_store - 1) of std_logic_vector(row_len - 1 downto 0); -- notice that it 0, 1, ..., size_rob-1 and not the other way round.
  constant default_row : std_logic_vector(row_len - 1 downto 0) := (others => '0');
  signal store_row : store_row_type := (others => default_row);
  constant branch_op : std_logic_vector(1 downto 0) := "10";
  signal head: unsigned(log_size_store - 1 downto 0) := 0; -- log_size_rob - 1 downto 0 refers to the integer written bitwise
  signal tail: unsigned(log_size_store - 1 downto 0) := 1; -- these are written in this way to ensure we get modular arithmetic
  signal i: unsigned(log_size_rob - 1 downto 0) :=0; -- temporary variable for our loops

  constant len_status: unsigned(7 downto 0) := 1 + 1; -- spec and ex bit
  constant pc_start: unsigned(7 downto 0) := row_len - 2; -- assuming row_len cannot exceed 64
  constant pc_end: unsigned(7 downto 0) := len_mem_addr + len_data + len_status;
  constant mem_addr_start: unsigned(7 downto 0) := len_mem_addr + len_data + len_status - 1;
  constant mem_addr_end: unsigned(7 downto 0) := len_data + len_status;
  constant data_start: unsigned(7 downto 0) := len_data + len_status - 1;
  constant data_end: unsigned(7 downto 0) := len_status;

begin
  normal_operation: process(clk)
  begin

    if(rising_edge(clk)) then -- we don't want to do anything during the falling edge

      -- Flushing Cases -----------------------------------------
      if (store_buffer_flush = '1') then --technically, a procedure could be more elegant but I don't know how to efficiently use it for a store_row_type
        head <= 0;
        tail <= 1;
        for i in size_rob - 1 downto 0 loop
          store_row(i)(1 downto 0) <= "00"; -- makes all of the status bits as zero; I could have made all of the rows into default_row but that is just unnecessary
          store_row(i)(row_len - 1) <= '0';
        end loop;
      else --adding this to reduce the number of inferred latches
        head <= head;
        tail <= tail;
      end if;

      -- Welcoming dispatched requests --------------------------
      if (valid_dispatch1 = '1' and tail/=head) then
        store_row(to_integer(tail)) <= dispatch_word1;
        tail <= tail + 1;
      else --adding this to reduce the number of inferred latches
        store_row(to_integer(tail)) <= dispatch_word1;
        tail <= tail;
      end if;

      if (valid_dispatch2 = '1' and tail/=head) then
        rob_row(to_integer(tail)) <= dispatch_word2;
        tail <= tail + 1;
      else --adding this to reduce the number of inferred latches
        rob_row(to_integer(tail)) <= dispatch_word2;
        tail <= tail;
      end if;

      -- Analysing executed addresses ----------------------------
      if valid_store_execute1 then -- we are, in fact, trying to reach the store buffer with this information
        for i in size_store - 1 downto 0 loop
          if (rob_row(i)(pc_start downto pc_end) = tag1) then -- we have a match on the ith row for the 1st word
            store_row(i)(mem_addr_start downto mem_addr_end) <= addr1;
            store_row(i)(0) <= '1'; -- executed successfully

          else --adding this to reduce the number of inferred latches
            null;
          end if;
          i <= i + 1;
        end loop;
      end if;
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
        store_buffer_stall <= '1';
      else
        store_buffer_stall <= '0';
      end if;

    end if;

  end process normal_operation;
end Struct;
