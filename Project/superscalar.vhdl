library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Gates.all;

entity superscalar is
	port();
end entity;

architecture struct of superscalar is
	
	component register_file is
	end component register_file;
	
	signal g,p: std_logic_vector(31 downto 0);

	begin

end architecture struct;