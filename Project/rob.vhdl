library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity rob is
    generic(len_PC:integer:=5;
              len_RRF:integer:= 12;
              len_ARF:integer:= 3;
              size_rob:integer:=40);

    port(clk, rob_flush: in std_logic;
          dispatch_word1, dispatch_word2: in std_logic_vector(len_PC + len_ARF + len_RRF - 1 downto 0); -- dispatch word has PC, ARF entry, RRF entry
          executed_word1, executed_word2, executed_word3: in std_logic_vector(len_PC + len_RRF - 1 downto 0); -- one from each pipeline
          valid1, valid2, valid3: in std_logic; -- if the executed words are valid
          retire_word1, retire_word2: out std_logic_vector(len_RRF - 1 downto 0); -- sent to PRF to tell it to update ARF
          valid_retire1, valid_retire2: out std_logic; -- in case you can only retire one of the instructions, make that valid_retirei as 0
          rob_stall: out std_logic);
end entity;

architecture Struct of rob is
  type rob_row_type is array(size_rob - 1 downto 0) of std_logic_vector(len_ARF + len_RRF + len_PC - 1 downto 0);
  signal rob_row : rob_row_type;
  signal busy_array : std_logic_vector(size_rob - 1 downto 0) := (others=>'0');
  signal head: integer:=0;
  signal tail: integer:=1;
begin

end Struct;

--entity Memory_Code is
		--port(
				--clk, m_wr: in std_logic;
				--mem_addr: in std_logic_vector(15 downto 0);
				--mem_out: out std_logic_vector(15 downto 0)
			 --);
--end entity;

--architecture memorykakaam of Memory_Code is
		--type mem_vec is array(65535 downto 0) of std_logic_vector(15 downto 0);
		--signal memorykagyaan : mem_vec := (others => "0000000000000000");

--begin

  --mem_process : process (clk) is
  --begin
				--mem_out <= memorykagyaan(to_integer(unsigned(mem_addr)));
  --end  process;
--end  architecture;
