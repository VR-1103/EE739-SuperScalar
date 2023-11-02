library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity rob is
    generic(len_PC:integer:=5;
              len_RRF:integer:= 12;
              len_ARF:integer:= 3;
              size_rob:integer:=64;
              log_size_rob: integer:= 6;
              row_len: integer:= (len_PC + len_ARF + len_RRF + 1)); -- This line is only valid for VHDL-2008.

    port(clk, rob_flush: in std_logic;
          dispatch_word1, dispatch_word2: in std_logic_vector(row_len - 1 downto 0); -- dispatch word has PC, ARF entry, RRF entry, executed bit
          valid_dispatch1, valid_dispatch2 : in std_logic; -- RS might have to send just one word/ no words in case of not having ready instr
          tag1, tag2, tag3 : in std_logic_vector(len_PC - 1 downto 0); -- one from each pipeline (execution words come from pipeline)
          valid1, valid2, valid3: in std_logic; -- if the executed words are valid
          retire_word1, retire_word2: out std_logic_vector(len_RRF - 1 downto 0); -- sent to PRF to tell it to update ARF
          valid_retire1, valid_retire2: out std_logic; -- in case you can only retire one of the instructions, make that valid_retirei as 0
          rob_stall: out std_logic);
end entity;

architecture Struct of rob is
  type rob_row_type is array(0 to size_rob - 1) of std_logic_vector(row_len - 1 downto 0); -- notice that it 0, 1, ..., size_rob-1 and not the other way round.
  constant default_row : std_logic_vector(row_len - 1 downto 0) := (others => '0');
  signal rob_row : rob_row_type := (others => default_row);
  signal head: unsigned(log_size_rob - 1 downto 0) :=0; -- log_size_rob - 1 downto 0 refers to the integer written bitwise
  signal tail: unsigned(log_size_rob - 1 downto 0) :=1; -- these are written in this way to ensure we get modular arithmetic
  signal ctr: unsigned(1 downto 0) := 0; -- honestly I am just using unsigned to save space (it can only hold 0, 1, 2, 3 so we are good)
begin
  normal_operation: process(clk)
  begin
    retire_word1 <= rob_row(to_integer(head));
    retire_word2 <= rob_row(to_integer(head + 1)); -- irrespective of if it is valid or not, the RRF addresses would be sent to PRF

    if(rising_edge(clk)) then -- we don't want to do anything during the falling edge

      -- Flushing Cases -----------------------------------------
      if (rob_flush = '1') then
        head <= 0;
        tail <= 1;
        for i in size_rob - 1 downto 0 loop
          rob_row(i)(0) <= '0'; -- makes all of the execution bits as zero
        end loop;
      end if;

      -- Welcoming dispactched instructions----------------------
      if (valid_dispatch1 = '1' and tail/=head) then
        rob_row(to_integer(tail)) <= dispatch_word1;
        tail <= tail + 1;

      end if;
      if (valid_dispatch2 = '1' and tail/=head) then
        rob_row(to_integer(tail)) <= dispatch_word2;
        tail <= tail + 1;

      end if;

      -- Analysing executed instructions-------------------------
      ctr <= unsigned(valid1) + unsigned(valid2) + unsigned(valid3); -- so that we can break the cycle as soon as we don't have anything to match
      for i in 0 to size_rob - 1 loop
        if ((valid1 and rob_row(i)(row_len - 1 downto len_ARF + len_RRF + 1) = tag1) or
            (valid2 and rob_row(i)(row_len - 1 downto len_ARF + len_RRF + 1) = tag2) or
            (valid3 and rob_row(i)(row_len - 1 downto len_ARF + len_RRF + 1) = tag3)) -- we have a match on the ith row
          rob_row(i)(0) <= '1';
          ctr<= ctr - 1;
        end if;
        if (valid = '1') then
        end if;
      end loop;

      -- Retiring instructions -----------------------------------
      if (rob_row(to_integer(head))(0) = '1' and rob_row(to_integer(head + 1))(0) = '1') then -- we have zoomed in on the ex_bit for the word on the top and second-top
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
      end if;

      -- Checking if we need to stall in next cycle ---------------
      if (head = tail or head = tail + 1) then -- stall condition (we don't accept anything even if we have just 1 slot free)
          rob_stall <= '1';
      end if;
    end if;

  end process normal_operation;
end Struct;
