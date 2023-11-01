library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity rob is
    generic(len_PC:integer:=5; len_RRF, len_ARF:integer:= 3)
    port(dispatch_word1, dispatch_word2: in std_logic_vector(len_PC + len_ARF + len_RRF - 1 downto 0);
            rob_stall: out std_logic);
end entity;

architecture Struct of rob is
  signal A_BAR, B_BAR : std_logic;
begin

end Struct;
