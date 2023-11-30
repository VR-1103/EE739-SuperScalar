library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity store_buffer is
    generic(len_PC :integer := 5;
            len_opcode : integer := 4;
            len_mem_addr: integer := len_PC;
            len_data: integer := 16;
            size_store: integer := 16;
            log_size_store: integer := 4;
            row_len: integer := (1 + len_PC + len_mem_addr + len_data + 1 + 1)); -- This line is only valid for VHDL-2008.

    port(clk, store_buffer_flush : in std_logic; -- we will use the flush to remove the "un-retired" instructions
          -- dispatch stage $$$$$$$$$$$$$$--
          dispatch_word1, dispatch_word2 : in std_logic_vector(len_PC + len_opcode + len_data + 1 - 1 downto 0); -- dispatch word has PC, Opcode, RRF address/ data, disable bit
          valid_dispatch1, valid_dispatch2 : in std_logic; -- '1' only when RS has sent it specifically for store and is not garbage
          -- post-execute stage $$$$$$$$$$--
          execute_word1 : in std_logic_vector(len_PC + len_mem_addr - 1 downto 0); -- one from L/S pipeline (execution words come from pipeline)
          valid_execute1 : in std_logic; -- if the executed words are actually meant for store buffer
          -- waiting for data stage $$$$$$--
          valid_prf_update1: in std_logic;
          tag_prf_update1: in std_logic_vector(len_data - 1 downto 0);
          data_prf_update1: in std_logic_vector(len_data - 1 downto 0);
          valid_prf_update2: in std_logic;
          tag_prf_update2: in std_logic_vector(len_data - 1 downto 0);
          data_prf_update2: in std_logic_vector(len_data - 1 downto 0);
          valid_prf_update3: in std_logic;
          tag_prf_update3: in std_logic_vector(len_data - 1 downto 0);
          data_prf_update3: in std_logic_vector(len_data - 1 downto 0);
          -- pre- ROB stage $$$$$$$$$$$$$$--
          valid_complete1, valid_complete2 : out std_logic; -- that we do need to retire it
          complete_word1, complete_word2 : out std_logic_vector(len_PC - 1 downto 0); -- sent to ROB to tell it that the row can be now executed pakka (this is required to ensure "data" in store buffer is actual data)
          -- post- ROB stage $$$$$$$$$$$$$--
          rob_retire_execute_word1, rob_retire_tag2 : in std_logic_vector(len_PC - 1 downto 0); -- when ROB retires a word, it sends that to store queue
          valid_rob_retire1, valid_rob_retire2 : in std_logic; -- '1' only if
          -- pre-memory stage $$$$$$$$$$$$--
          port_free_bit : in std_logic; -- tells store_buffer that it can now control the memory port
          kucch_dena_hai : out std_logic; -- '0' if there is no completed store at the head
          port_kya_dega : out std_logic_vector(len_data - 1 downto 0);
          port_kaha_dega : out std_logic_vector(len_mem_addr - 1 downto 0);
          -- load forwarding stage $$$$$$$--
          valid_load_fwd_request : in std_logic;
          load_foward_tag : in std_logic_vector(len_mem_addr - 1 downto 0);
          valid_forward : out std_logic;
          load_forward : out std_logic_vector(len_data - 1 downto 0);

          store_buffer_stall: out std_logic);
end entity;

-- row word has busy bit, PC, Memory Addr, Data, executed bit, valid bit, completed bit
-- ############ Format of the store_row #####################--
-- busy bit: Is this entry garbage or not
-- PC : obvious
-- Memory Addr : Where we want to store the data
-- Data : What we want to store (can be data or addr of RRF)
-- Executed bit : If the addr has been calculated by pipeline or if it is garbage
-- Valid bit : If the data in store_buffer is valid or garbage
-- Disable bit : If the instruction needs to be actually written into the memory
-- Completed bit : If ROB has retired the instruction thus making it free to be written into the memory port
-- ############################################################

architecture Struct of store_buffer is
  type store_row_type is array(0 to size_store - 1) of std_logic_vector(row_len - 1 downto 0); -- notice that it 0, 1, ..., size_rob-1 and not the other way round.
  constant default_row : std_logic_vector(row_len - 1 downto 0) := (others => '0');
  signal store_row : store_row_type := (others => default_row);
  constant branch_op : std_logic_vector(1 downto 0) := "10";
  signal head: unsigned(log_size_store - 1 downto 0) := 0; -- log_size_rob - 1 downto 0 refers to the integer written bitwise
  signal tail: unsigned(log_size_store - 1 downto 0) := 0; -- these are written in this way to ensure we get modular arithmetic
  signal i: unsigned(log_size_rob - 1 downto 0) :=0; -- temporary variable for our loops
  signal passed : std_logic := '0'; -- temporary variable with multiple uses

  constant len_status: integer := 1 + 1 + 1; -- ex, valid, disable, completed bit
  constant disable_bit_loc : integer := 1;
  constant completed_bit_loc : integer := 0;
  constant valid_bit_loc : integer := 3;
  constant executed_bit_loc : integer := 2;
  constant pc_start: integer := row_len - 2; -- assuming row_len cannot exceed 64
  constant pc_end: integer := len_mem_addr + len_data + len_status;
  constant mem_addr_start: integer := len_mem_addr + len_data + len_status - 1;
  constant mem_addr_end: integer := len_data + len_status;
  constant data_start: integer := len_data + len_status - 1;
  constant data_end: integer := len_status;

begin
  normal_operation: process(clk)
  begin

    if(rising_edge(clk)) then -- we don't want to do anything during the falling edge
      port_kaha_dega <= store_row(head)(mem_addr_start downto mem_addr_end);
      port_kya_dega <= store_row(head)(data_start downto data_end);
      valid_complete1 <= '0';

      -- Flushing Cases #######################################--
      if (store_buffer_flush = '1') then --technically, a procedure could be more elegant but I don't know how to efficiently use it for a store_row_type
      tail <= head; -- to ensure the worst case is taken care of when no store instruction is completed
        for i in 0 to size_store - 1 loop
        i <= i + head;
          -- I have to implement a way to allocate a new location for the tail pointer
          if store_row(i)(0) then
            tail <= i;
            -- this basically ensures that tail is the last entry which is completed
          elsif not store_row(i)(0) then -- un-completed instructions are flushed
            store_row(i)(2 downto 0) <= "000"; -- makes all of the status bits as zero; I could have made all of the rows into default_row but that is just unnecessary
            store_row(i)(row_len - 1) <= '0';
          end if;
        end loop;
      else --adding this to reduce the number of inferred latches
        tail <= tail;
      end if;

      -- Welcoming dispatched requests ########################--
      if (valid_dispatch1 = '1' and dispatch_word1(len_opcode + len_data + 1 - 1 downto len_data + 1)) then
        store_row(to_integer(tail))(pc_start downto pc_end) <= dispatch_word1(len_PC + len_data downto len_data + 1);
        store_row(to_integer(tail))(data_start downto data_end) <= dispatch_word1(len_data downto 1);
        store_row(to_integer(tail))(1) <= dispatch_word1(0); -- valid bit
        store_row(to_integer(tail))(row_len - 1) <= '1'; -- busy bit
        -- strictly speaking we don't really need these 2 lines below but just for double safety
        store_row(to_integer(tail))(0) <= '0'; -- completed bit
        store_row(to_integer(tail))(2) <= '0'; -- executed bit
        tail <= tail + 1;
      else --adding this to reduce the number of inferred latches
        store_row(to_integer(tail))(pc_start downto pc_end) <= dispatch_word1(len_PC + len_data downto len_data + 1);
        store_row(to_integer(tail))(data_start downto data_end) <= dispatch_word1(len_data downto 1);
        store_row(to_integer(tail))(1) <= dispatch_word1(0); -- valid bit
        store_row(to_integer(tail))(row_len - 1) <= '0'; -- busy bit
        -- strictly speaking we don't really need these 2 lines below but just for double safety
        store_row(to_integer(tail))(0) <= '0'; -- completed bit
        store_row(to_integer(tail))(2) <= '0'; -- executed bit
        tail <= tail;
      end if;

      if (valid_dispatch2 = '1') then
        store_row(to_integer(tail))(pc_start downto pc_end) <= dispatch_word2(len_PC + len_data downto len_data + 1);
        store_row(to_integer(tail))(data_start downto data_end) <= dispatch_word2(len_data downto 1);
        store_row(to_integer(tail))(1) <= dispatch_word2(0); -- valid bit
        store_row(to_integer(tail))(row_len - 1) <= '1'; -- busy bit
        -- strictly speaking we don't really need these 2 lines below but just for double safety
        store_row(to_integer(tail))(0) <= '0'; -- completed bit
        store_row(to_integer(tail))(2) <= '0'; -- executed bit
        tail <= tail + 1;
      else --adding this to reduce the number of inferred latches
        store_row(to_integer(tail))(pc_start downto pc_end) <= dispatch_word2(len_PC + len_data downto len_data + 1);
        store_row(to_integer(tail))(data_start downto data_end) <= dispatch_word2(len_data downto 1);
        store_row(to_integer(tail))(1) <= dispatch_word2(0); -- valid bit
        store_row(to_integer(tail))(row_len - 1) <= '0'; -- busy bit
        -- strictly speaking we don't really need these 2 lines below but just for double safety
        store_row(to_integer(tail))(0) <= '0'; -- completed bit
        store_row(to_integer(tail))(2) <= '0'; -- executed bit
        tail <= tail;
      end if;

      passed <= '0';
      for i in size_store - 1 downto 0 loop -- one singular loop to decrease the number of potential loops

      -- Analysing executed addresses ##########################--
        if valid_execute1 and (store_row(i)(pc_start downto pc_end) = execute_word1) then -- we have a match on the ith row for the 1st word
          store_row(i)(mem_addr_start downto mem_addr_end) <= addr1;
          store_row(i)(2) <= '1'; -- executed successfully
        else --adding this to reduce the number of inferred latches
          null;
        end if;

      -- Waiting for valid data ################################--
        if valid_prf_update1 and store_row(i)(data_start downto data_end) = tag_prf_update1 and (not store_row(i)(1)) then -- we only check tag against the rrf addresses and not the valid data
          store_row(i)(data_start downto data_end) <= data_prf_update1;
          store_row(i)(1) <= '1'; -- got valid data successfully
        elsif valid_prf_update2 and store_row(i)(data_start downto data_end) = tag_prf_update2 and (not store_row(i)(1)) then
          store_row(i)(data_start downto data_end) <= data_prf_update2;
          store_row(i)(1) <= '1'; -- got valid data successfully
        elsif valid_prf_update3 and store_row(i)(data_start downto data_end) = tag_prf_update3 and (not store_row(i)(1)) then
          store_row(i)(data_start downto data_end) <= data_prf_update3;
          store_row(i)(1) <= '1'; -- got valid data successfully
        end if;

      -- Checking if any store is executable ###################--
        if store_row(i)(2 downto 1) = "11" and (not valid_complete1) then
          complete_word1 <= store_row(i)(pc_start downto pc_end);
          valid_complete1 <= '1';
          valid_complete2 <= '0';
        elsif store_row(i)(2 downto 1) = "11" and (not valid_complete2) then
          complete_word2 <= store_row(i)(pc_start downto pc_end);
          valid_complete1 <= '1';
          valid_complete2 <= '1';
        else
          valid_complete1 <= valid_complete1;
          valid_complete2 <= valid_complete2;
        end if;

      -- Checking if any store is completed ####################--
        if valid_rob_retire1 and store_row(i)(pc_start downto pc_end) = rob_retire_execute_word1 then
          store_row(i)(0) <= '1';
        elsif valid_rob_retire2 and store_row(i)(pc_start downto pc_end) = rob_retire_tag2 then
          store_row(i)(0) <= '1';
        else
          store_row(i)(0) <= store_row(i)(0);
        end if;

      -- Helping in load forwarding ############################--
        if store_row(i)(0) = '1' and valid_load_fwd_request and store_row(i)(mem_addr_start downto mem_addr_end) = load_foward_tag then -- we only allow load forwarding with retired instructions
          valid_forward <= '1';
          load_forward <= store_row(i)(data_start downto data_end);
        else
          valid_forward <= valid_forward;
        end if;

      end loop;
      passed <= '0'; -- this ensures that we have a clean slate in the next clock cycle

      -- Pushing the completed stores to memory port #####--
      if store_row(head)(0) and port_free_bit then
        kucch_dena_hai <= '1';
        head <= head - 1;
      else
        kucch_dena_hai <= '0';
      end if;

      -- Checking if we need to stall in next cycle ###############--
      if ( (head = tail and rob_row(to_integer(head))(row_len - 1)) or head = tail + 1 or head = tail + 2) then -- stall condition (we don't accept anything even if we have just 1 slot free)
        store_buffer_stall <= '1';
      else
        store_buffer_stall <= '0';
      end if;

    end if;

  end process normal_operation;
end Struct;
