library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

entity store_buffer is
    generic(len_PC :integer := 5;
            len_opcode : integer := 4;
            len_mem_addr: integer := 5;
            len_data: integer := 16;
            size_store: integer := 16;
            log_size_store: integer := 4;
            row_len: integer := (1 + 5 + 5 + 16 + 1 + 1)); -- 1 + len_PC + len_mem_addr + len_data + 1 + 1

    port(clk, store_buffer_flush : in std_logic; -- we will use the flush to remove the "un-retired" instructions
          -- Interconnections with Decoder $$$$$$$$$$$$$$--
          dispatch_word1, dispatch_word2 : in std_logic_vector(len_PC + len_opcode + len_data + 2 - 1 downto 0); -- dispatch word has PC, Opcode, RRF address/ data, disable bit, valid bit
          valid_dispatch1, valid_dispatch2 : in std_logic; -- '1' only when RS has sent it specifically for store and is not garbage
          -- Interconnections with L/S Pipeline $$$$$$$$$$--
          execute_word1 : in std_logic_vector(len_PC + len_mem_addr - 1 downto 0); -- one from L/S pipeline (execution words come from pipeline)
          valid_execute1 : in std_logic; -- if the executed words are actually meant for store buffer
          -- Interconnections with PRF $$$$$$--
          valid_prf_update1: in std_logic;
          tag_prf_update1: in std_logic_vector(len_data - 1 downto 0);
          data_prf_update1: in std_logic_vector(len_data - 1 downto 0);
          valid_prf_update2: in std_logic;
          tag_prf_update2: in std_logic_vector(len_data - 1 downto 0);
          data_prf_update2: in std_logic_vector(len_data - 1 downto 0);
          valid_prf_update3: in std_logic;
          tag_prf_update3: in std_logic_vector(len_data - 1 downto 0);
          data_prf_update3: in std_logic_vector(len_data - 1 downto 0);
          -- Interconnections with ROB $$$$$$$$$$$$$$--
          valid_store1, valid_store2 : out std_logic; -- that we do need to retire it
          execute_store1, execute_store2 : out std_logic_vector(len_PC - 1 downto 0); -- sent to ROB to tell it that the row can be now executed pakka (this is required to ensure "data" in store buffer is actual data)
          retire_store : in std_logic_vector(1 downto 0);
          -- Interconnections with Memory Arbiter $$$$$$$$$$$$--
          port_free_bit : in std_logic; -- tells store_buffer that it can now control the memory port
          kucch_dena_hai : out std_logic; -- '0' if there is no completed store at the head
          port_kya_dega : out std_logic_vector(len_data - 1 downto 0);
          port_kaha_dega : out std_logic_vector(len_mem_addr - 1 downto 0);
          -- Interconnections with Load Queue $$$$$$$--
          valid_load_fwd_request : in std_logic;
          load_foward_tag : in std_logic_vector(len_mem_addr - 1 downto 0);
          valid_forward : out std_logic;
          load_forward : out std_logic_vector(len_data - 1 downto 0);
          alias_checker1, alias_checker2 : out std_logic_vector(len_data - 1 downto 0);
          valid_alias1, valid_alias2 : out std_logic;
          -- General Interconnections $$$$$$$$$$$$$$$$$--
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
  signal head: unsigned(log_size_store - 1 downto 0) := (others => '0'); -- log_size_rob - 1 downto 0 refers to the integer written bitwise
  signal tail: unsigned(log_size_store - 1 downto 0) := (others => '0'); -- these are written in this way to ensure we get modular arithmetic
  signal valid_store_temp1, valid_store_temp2 : std_logic := '0'; -- temporary variables
  signal passed : std_logic:= '0'; -- useful for flushing

  constant len_status: integer := 1 + 1 + 1 + 1; -- ex, valid, disable, completed bit
  constant disable_bit_loc : integer := 1;
  constant completed_bit_loc : integer := 0;
  constant valid_bit_loc : integer := 2;
  constant executed_bit_loc : integer := 3;
  constant busy_bit_loc : integer := row_len - 1;
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
      port_kaha_dega <= store_row(to_integer(head))(mem_addr_start downto mem_addr_end);
      port_kya_dega <= store_row(to_integer(head))(data_start downto data_end);
      valid_store1 <= valid_store_temp1;
      valid_store2 <= valid_store_temp2;
      alias_checker1 <= store_row(to_integer(head))(mem_addr_start downto mem_addr_end);
      alias_checker2 <= store_row(to_integer(head + 1))(mem_addr_start downto mem_addr_end);

      -- Flushing Cases #######################################--
      if (store_buffer_flush = '1') then --technically, a procedure could be more elegant but I don't know how to efficiently use it for a store_row_type
        for i in 0 to size_store - 1 loop
          -- I have to implement a way to allocate a new location for the tail pointer
          if (store_row(to_integer(tail))(completed_bit_loc) = '0') and (tail /= head) then
            store_row(to_integer(tail))(executed_bit_loc downto completed_bit_loc) <= "0000";
            store_row(to_integer(tail))(busy_bit_loc) <= '0';
            tail <= tail - 1;
          elsif (store_row(to_integer(tail))(completed_bit_loc) = '0') and (tail = head) then -- we still need to ensure that the head is flushed if it is uncompleted.
            store_row(to_integer(tail))(executed_bit_loc downto completed_bit_loc) <= "0000";
            store_row(to_integer(tail))(busy_bit_loc) <= '0';
            tail <= tail;
          else -- completed instructions are untouched
            tail <= tail;
          end if;
        end loop;
      else --adding this to reduce the number of inferred latches
        tail <= tail;
      end if;

      -- Welcoming dispatched requests ########################--
      if (valid_dispatch1 = '1') and (dispatch_word1(len_opcode + len_data + 1 - 1 downto len_data + 1) = "0101") and (dispatch_word1(1) = '0') then -- we only take in valid non-disabled store instructions
        store_row(to_integer(tail))(pc_start downto pc_end) <= dispatch_word1(len_PC + len_data + len_opcode + 1 downto len_opcode + len_data + 2);
        store_row(to_integer(tail))(data_start downto data_end) <= dispatch_word1(len_data + 1 downto 2);
        store_row(to_integer(tail))(valid_bit_loc) <= dispatch_word1(0); -- valid bit
        store_row(to_integer(tail))(busy_bit_loc) <= '1'; -- busy bit
        -- strictly speaking we don't really need these 2 lines below but just for double safety
        store_row(to_integer(tail))(completed_bit_loc) <= '0'; -- completed bit
        store_row(to_integer(tail))(executed_bit_loc) <= '0'; -- executed bit
        tail <= tail + 1;
      else --adding this to reduce the number of inferred latches
        store_row(to_integer(tail))(pc_start downto pc_end) <= dispatch_word1(len_PC + len_data + 1 downto len_data + 2);
        store_row(to_integer(tail))(data_start downto data_end) <= dispatch_word1(len_data + 1 downto 2);
        store_row(to_integer(tail))(valid_bit_loc) <= dispatch_word1(0); -- valid bit
        store_row(to_integer(tail))(busy_bit_loc) <= '0'; -- busy bit
        -- strictly speaking we don't really need these 2 lines below but just for double safety
        store_row(to_integer(tail))(completed_bit_loc) <= '0'; -- completed bit
        store_row(to_integer(tail))(executed_bit_loc) <= '0'; -- executed bit
        tail <= tail;
      end if;

      if (valid_dispatch2 = '1') and (dispatch_word2(len_opcode + len_data + 1 - 1 downto len_data + 1) = "0101") and (dispatch_word2(0) = '0') then -- we only take in valid non-disabled store instructions
        store_row(to_integer(tail))(pc_start downto pc_end) <= dispatch_word2(len_PC + len_data + 1 downto len_data + 2);
        store_row(to_integer(tail))(data_start downto data_end) <= dispatch_word2(len_data + 1 downto 2);
        store_row(to_integer(tail))(valid_bit_loc) <= dispatch_word2(0); -- valid bit
        store_row(to_integer(tail))(busy_bit_loc) <= '1'; -- busy bit

        store_row(to_integer(tail))(completed_bit_loc) <= '0'; -- completed bit
        store_row(to_integer(tail))(executed_bit_loc) <= '0'; -- executed bit
        tail <= tail + 1;
      else --adding this to reduce the number of inferred latches
        store_row(to_integer(tail))(pc_start downto pc_end) <= dispatch_word2(len_PC + len_data + 1 downto len_data + 2);
        store_row(to_integer(tail))(data_start downto data_end) <= dispatch_word2(len_data + 1 downto 2);
        store_row(to_integer(tail))(valid_bit_loc) <= dispatch_word2(0); -- valid bit
        store_row(to_integer(tail))(busy_bit_loc) <= '0'; -- busy bit

        store_row(to_integer(tail))(completed_bit_loc) <= '0'; -- completed bit
        store_row(to_integer(tail))(executed_bit_loc) <= '0'; -- executed bit
        tail <= tail;
      end if;

      valid_forward <= '0'; -- by default we don't forward any data unless we find it

      for i in size_store - 1 downto 0 loop -- one singular loop to decrease the number of potential loops

      -- Analysing executed addresses ##########################--
        if (valid_execute1 = '1') and (store_row(i)(pc_start downto pc_end) = execute_word1(len_PC + len_mem_addr - 1 downto len_mem_addr)) then -- we have a match on the ith row for the 1st word
          store_row(i)(mem_addr_start downto mem_addr_end) <= execute_word1(len_mem_addr - 1 downto 0);
          store_row(i)(executed_bit_loc) <= '1'; -- executed successfully
        else --adding this to reduce the number of inferred latches
          null;
        end if;

      -- Waiting for valid data ################################--
        if (valid_prf_update1 = '1') and store_row(i)(data_start downto data_end) = tag_prf_update1 and (store_row(i)(valid_bit_loc) = '0') then -- we only check tag against the rrf addresses and not the valid data
          store_row(i)(data_start downto data_end) <= data_prf_update1;
          store_row(i)(valid_bit_loc) <= '1'; -- got valid data successfully
        elsif (valid_prf_update2 = '1') and (store_row(i)(data_start downto data_end) = tag_prf_update2) and (store_row(i)(valid_bit_loc) = '0') then
          store_row(i)(data_start downto data_end) <= data_prf_update2;
          store_row(i)(valid_bit_loc) <= '1'; -- got valid data successfully
        elsif (valid_prf_update3 = '1') and (store_row(i)(data_start downto data_end) = tag_prf_update3) and (store_row(i)(valid_bit_loc) = '0') then
          store_row(i)(data_start downto data_end) <= data_prf_update3;
          store_row(i)(valid_bit_loc) <= '1'; -- got valid data successfully
        end if;

      -- Checking if any store is executable ###################--
        if (store_row(i)(executed_bit_loc) = '1') and (store_row(i)(valid_bit_loc) = '1') and (valid_store_temp1 = '0') then
          execute_store1 <= store_row(i)(pc_start downto pc_end);
          valid_store_temp1 <= '1';
          valid_store_temp2 <= '0';
        elsif (store_row(i)(executed_bit_loc) = '1') and (store_row(i)(valid_bit_loc) = '1') and (valid_store_temp2 = '0') then
          execute_store2 <= store_row(i)(pc_start downto pc_end);
          valid_store_temp1 <= '1';
          valid_store_temp2 <= '1';
        else
          valid_store_temp1 <= valid_store_temp1;
          valid_store_temp2 <= valid_store_temp2;
        end if;

      -- Helping in load forwarding ############################--
        if (store_row(i)(executed_bit_loc) = '1') and (store_row(i)(valid_bit_loc) = '1') and (valid_load_fwd_request = '1') and (store_row(i)(mem_addr_start downto mem_addr_end) = load_foward_tag) then -- we only allow load forwarding with proper data
          valid_forward <= '1';
          load_forward <= store_row(i)(data_start downto data_end);
        else
          null;
        end if;

      end loop;

      -- Checking if any store is completed ####################--
      if retire_store = "11" then
        store_row(to_integer(head))(completed_bit_loc) <= '1';
        valid_alias1 <= '1';
        store_row(to_integer(head + 1))(completed_bit_loc) <= '1';
        valid_alias2 <= '1';

      elsif retire_store(0) = '1' then
        store_row(to_integer(head))(completed_bit_loc) <= '1';
        store_row(to_integer(head + 1))(completed_bit_loc) <= store_row(to_integer(head + 1))(completed_bit_loc);
        valid_alias1 <= '1';
        valid_alias2 <= '0';
      else
        store_row(to_integer(head))(completed_bit_loc) <= store_row(to_integer(head))(completed_bit_loc);
        store_row(to_integer(head + 1))(completed_bit_loc) <= store_row(to_integer(head + 1))(completed_bit_loc);
        valid_alias1 <= '0';
        valid_alias2 <= '0';
      end if;

      -- Pushing the completed stores to memory port #####--
      if (store_row(to_integer(head))(completed_bit_loc) = '1') and (port_free_bit = '1') then
        kucch_dena_hai <= '1';
        store_row(to_integer(head))(busy_bit_loc) <= '0';
        store_row(to_integer(head))(executed_bit_loc downto completed_bit_loc) <= "0000"; --cleared up the entire row
        head <= head + 1;
      else
        kucch_dena_hai <= '0';
      end if;

      -- Checking if we need to stall in next cycle ###############--
      if ((head = tail) and (store_row(to_integer(head))(busy_bit_loc) = '1')) or (head = tail + 1) or (head = tail + 2) then -- stall condition (we don't accept anything even if we have just 1 slot free)
        store_buffer_stall <= '1';
      else
        store_buffer_stall <= '0';
      end if;

    end if;

  end process normal_operation;
end Struct;
