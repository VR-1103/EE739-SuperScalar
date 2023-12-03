library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_generic is
	generic (data_width : integer);
	port(
		clk, en, reset: in std_logic;
		Din: in std_logic_vector(data_width-1 downto 0);
		init: in std_logic_vector(data_width-1 downto 0);
		Dout: out std_logic_vector(data_width-1 downto 0));
end entity;

architecture reg of reg_generic is
begin
	process(clk, reset)	
	begin
		if(clk'event and clk='1') then
			if (en='1') then
				Dout <= Din;
			end if;
		end if;
		if(reset = '1') then
			Dout <= init;
		end if;
	end process;
	
end reg;	

library ieee ;
use ieee.std_logic_1164.all ;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;

entity int_alu is
	generic(len_PC: integer:= 16);
	port(
		ALU_A, ALU_B: in std_logic_vector(15 downto 0);
		ALU_op: in std_logic_vector(3 downto 0);
		ALU_Imm: in std_logic_vector(15 downto 0);
		ALU_Conditions: in std_logic_vector(2 downto 0);
		ALU_Carry_In: in std_logic;
		ALU_Zero_In: in std_logic;
		PC_Current: in std_logic_vector(len_PC-1 downto 0);
		ALU_C: out std_logic_vector(15 downto 0);
		ALU_Zero_Out, ALU_Carry_Out : out std_logic;
		shld_PC_change: out std_logic;
		isaBranch: out std_logic;
		Dest_en, C_en, Z_en: out std_logic;
		PC_Final: out std_logic_vector(len_PC-1 downto 0));
end entity;

architecture implementation of int_alu is 
	signal output_temp, ALU_B_temp, tmp1: std_logic_vector(15 downto 0);
	signal tmp0: std_logic_vector(16 downto 0);
	signal cin_temp, cout_temp, zout_temp: std_logic;
	signal Dest_en_tmp, C_en_temp, Z_en_temp, shld_PC_change_temp, isaBranch_temp: std_logic;
	signal PC_Branch,PC_JRI,PC_plus_2, PC_temp: std_logic_vector(len_PC-1 downto 0);
	
begin
	ALU_B_temp <= (not ALU_B) when (ALU_Conditions(2) = '1' and (ALU_op = "0001" or ALU_op = "0010")) else ALU_B;
	cin_temp <= ALU_Carry_In when (ALU_op = "0001" and ALU_Conditions(1 downto 0) = "11") else '0';
	tmp0 <= std_logic_vector(unsigned(ALU_A) + unsigned(ALU_B_temp) + unsigned(cin_temp));
	tmp1 <= not(ALU_A and ALU_B_temp);
	PC_Branch <= std_logic_vector(signed('0' & PC_Current) + signed(ALU_Imm) + signed(ALU_Imm));
	PC_plus_2 <= std_logic_vector(unsigned(PC_Current) + unsigned(2));
	PC_JRI <= std_logic_vector(signed('0' & ALU_A) + signed(ALU_Imm) + signed(ALU_Imm));
	
	process(ALU_A, ALU_B, ALU_op, ALU_Conditions, ALU_Carry_In, ALU_Zero_In, ALU_Imm, PC_Current)
	begin
		
		if (ALU_op = "0000") then
			PC_Final <= PC_plus_2;
			shld_PC_change_temp <= '0';
			isaBranch_temp <= '0';
			output_temp <= tmp0(15 downto 0);
			Dest_en_temp <= '1';
			C_en_temp <= '1';
			Z_en_temp <= '1';
			
		elsif (ALU_op = "0001") then
			PC_Final <= PC_plus_2;
			shld_PC_change_temp <= '0';
			isaBranch_temp <= '0';
			if (ALU_Conditions(1 downto 0) = "00") then
				output_temp <= tmp0(15 downto 0);
				Dest_en_temp <= '1';
				C_en_temp <= '1';
				Z_en_temp <= '1';
			elsif (ALU_Conditions(1 downto 0) = "10" and ALU_Carry_In = '1') then
				output_temp <= tmp0(15 downto 0);
				Dest_en_temp <= '1';
				C_en_temp <= '1';
				Z_en_temp <= '1';
			elsif (ALU_Conditions(1 downto 0) = "01" and ALU_Zero_In = '1') then
				output_temp <= tmp0(15 downto 0);
				Dest_en_temp <= '1';
				C_en_temp <= '1';
				Z_en_temp <= '1';
			elsif (ALU_Conditions(1 downto 0) = "11") then
				output_temp <= tmp0(15 downto 0);
				Dest_en_temp <= '1';
				C_en_temp <= '1';
				Z_en_temp <= '1';
			else
				output_temp <= tmp0(15 downto 0);
				Dest_en_temp <= '0';
				C_en_temp <= '0';
				Z_en_temp <= '0';
			end if;
			
		elsif (ALU_op = "0010") then
			PC_Final <= PC_plus_2;
			shld_PC_change_temp <= '0';
			isaBranch_temp <= '0';
			if (ALU_Conditions(1 downto 0) = "00") then
				output_temp <= tmp1;
				Dest_en_temp <= '1';
				C_en_temp <= '1';
				Z_en_temp <= '1';
			elsif (ALU_Conditions(1 downto 0) = "10" and ALU_Carry_In = '1') then
				output_temp <= tmp1;
				Dest_en_temp <= '1';
				C_en_temp <= '1';
				Z_en_temp <= '1';
			elsif (ALU_Conditions(1 downto 0) = "01" and ALU_Zero_In = '1') then
				output_temp <= tmp1;
				Dest_en_temp <= '1';
				C_en_temp <= '1';
				Z_en_temp <= '1';
			else
				output_temp <= tmp1;
				Dest_en_temp <= '0';
				C_en_temp <= '0';
				Z_en_temp <= '0';
			end if;
		
		elsif (ALU_op = "1000") then
			isaBranch_temp <= '1';
			output_temp <= (others => '0');
			Dest_en_temp <= '0';
			C_en_temp <= '0';
			Z_en_temp <= '0';
			if (unsigned(ALU_A) = unsigned(ALU_B)) then
				PC_temp <= PC_Branch;
				shld_PC_change_temp <= '1';
			else
				PC_temp <= PC_plus_2;
				shld_PC_change_temp <= '0';
			end if;
		
		elsif (ALU_op = "1001") then
			isaBranch_temp <= '1';
			output_temp <= (others => '0');
			Dest_en_temp <= '0';
			C_en_temp <= '0';
			Z_en_temp <= '0';
			if (unsigned(ALU_A) < unsigned(ALU_B)) then
				PC_temp <= PC_Branch;
				shld_PC_change_temp <= '1';
			else
				PC_temp <= PC_plus_2;
				shld_PC_change_temp <= '0';
			end if;
		
		elsif (ALU_op = "1010") then
			isaBranch_temp <= '1';
			output_temp <= (others => '0');
			Dest_en_temp <= '0';
			C_en_temp <= '0';
			Z_en_temp <= '0';
			if (unsigned(ALU_A) <= unsigned(ALU_B)) then
				PC_temp <= PC_Branch;
				shld_PC_change_temp <= '1';
			else
				PC_temp <= PC_plus_2;
				shld_PC_change_temp <= '0';
			end if;
		
		elsif (ALU_op = "1100") then
			isaBranch_temp <= '0';
			shld_PC_change_temp <= '1';
			output_temp <= PC_plus_2;
			Dest_en_temp <= '1';
			C_en_temp <= '0';
			Z_en_temp <= '0';
			PC_temp <= PC_Branch;
		
		elsif (ALU_op = "1101") then
			isaBranch_temp <= '0';
			shld_PC_change_temp <= '1';
			output_temp <= PC_plus_2;
			Dest_en_temp <= '1';
			C_en_temp <= '0';
			Z_en_temp <= '0';
			PC_temp <= ALU_B;
		
		elsif (ALU_op = "1111") then
			isaBranch_temp <= '0';
			shld_PC_change_temp <= '1';
			output_temp <= (others => '0');
			Dest_en_temp <= '0';
			C_en_temp <= '0';
			Z_en_temp <= '0';
			PC_temp <= PC_JRI;
		else
			isaBranch_temp <= '0';
			shld_PC_change_temp <= '0';
			output_temp <= (others => '0');
			Dest_en_temp <= '0';
			C_en_temp <= '0';
			Z_en_temp <= '0';
			PC_temp <= PC_plus_2;
		end if;
	end process;
	
	ALU_Carry_Out <= output_temp(16);
	ALU_Zero_Out <= '1' when (to_integer(unsigned(output_temp)) = 0) else '0';
	isaBranch <= isaBranch_temp;
	shld_PC_change <= shld_PC_change_temp;
	ALU_C <= output_temp;
	PC_Final <= PC_temp;
	Dest_en <= Dest_en_temp;
	Z_en <= Z_en_temp;
	C_en <= C_en_temp;
	
end architecture;

library ieee ;
use ieee.std_logic_1164.all ;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;

entity integer_pipeline is
	generic(len_PC: integer:= 16;
	len_RRF: integer:= 6;
	len_RRF_status: integer:= 4);
	port(
		flush: in std_logic;
		garbage_input: in std_logic;
		Opr1, Opr2: in std_logic_vector(15 downto 0);
		opcode: in std_logic_vector(3 downto 0);
		conditions: in std_logic_vector(3 downto 0);
		Immediate: in std_logic_vector(15 downto 0);
		PC_Current: in std_logic_vector(len_PC-1 downto 0);
		Dest_Addr_In: in std_logic_vector(len_RRF-1 downto 0);
		Dest_C_Addr_In, Dest_Z_Addr_In: in std_logic_vector(len_RRF_status-1 downto 0);
		C_RS, Z_RS: in std_logic;
		Dest_Addr_Out: out std_logic_vector(len_RRF-1 downto 0);
		Dest_C_Addr_Out, Dest_Z_Addr_Out: out std_logic_vector(len_RRF_status-1 downto 0);
		Dest_Data: out std_logic_vector(15 downto 0);
		Dest_C_Data, Dest_Z_Data: out std_logic_vector;
		Dest_C_en, Dest_Z_en, Dest_en : out std_logic;
		PC_Branch: out std_logic_vector(len_PC-1 downto 0);
		isaBranch, shld_PC_change: out std_logic);
end entity;

architecture implementation of integer_pipeline is 
	
component int_alu is
	generic(len_PC: integer:= 16);
	port(
		ALU_A, ALU_B: in std_logic_vector(15 downto 0);
		ALU_op: in std_logic_vector(3 downto 0);
		ALU_Imm: in std_logic_vector(15 downto 0);
		ALU_Conditions: in std_logic_vector(2 downto 0);
		ALU_Carry_In: in std_logic;
		ALU_Zero_In: in std_logic;
		PC_Current: in std_logic_vector(len_PC-1 downto 0);
		ALU_C: out std_logic_vector(15 downto 0);
		ALU_Zero_Out, ALU_Carry_Out : out std_logic;
		shld_PC_change: out std_logic;
		isaBranch: out std_logic;
		Dest_en, C_en, Z_en: out std_logic;
		PC_Final: out std_logic_vector(len_PC-1 downto 0));
end component;

signal isaBranch_temp, shld_PC_change, Dest_en_temp, Dest_C_en_temp, Dest_Z_en_temp: std_logic;

begin

	int_alu1: int_alu
		generic map (16)
		port map (ALU_A => Opr1, ALU_B => Opr2, ALU_op => opcode, ALU_Imm => Immediate, ALU_Conditions => conditions,
		ALU_Carry_In => C_RS, ALU_Zero_In => Z_RS, PC_Current => PC_Current, ALU_C => Dest_Data, ALU_Zero_Out => Dest_Z_Data, ALU_Carry_Out => Dest_C_Data,
		shld_PC_change => shld_PC_change_temp, isaBranch => isaBranch_temp, Dest_en => Dest_en_temp, C_en => Dest_C_en_temp, Z_en => Dest_Z_en_temp, PC_Final => PC_Branch);
	
	Dest_Addr_Out <= Dest_Addr_In;
	Dest_C_Addr_Out <= Dest_C_Addr_In;
	Dest_Z_Addr_Out <= Dest_Z_Addr_In;
	shld_PC_change <= ((shld_PC_change_temp and (not flush)) and (not garbage_input));
	isaBranch <= ((isaBranch_temp and (not flush)) and (not garbage_input));
	Dest_en <= ((Dest_en_temp and (not flush)) and (not garbage_input));
	Dest_C_en <= ((Dest_C_en_temp and (not flush)) and (not garbage_input));
	Dest_Z_en <= ((Dest_Z_en_temp and (not flush)) and (not garbage_input));
	
end architecture;

library ieee ;
use ieee.std_logic_1164.all ;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;

entity load_alu1 is
	generic(len_PC: integer:= 16);
	port(
		ALU_A, ALU_B: in std_logic_vector(15 downto 0);
		ALU_op: in std_logic_vector(3 downto 0);
		ALU_Imm: in std_logic_vector(15 downto 0);
		PC_Current: in std_logic_vector(len_PC-1 downto 0);
		is_LMSM: in std_logIc;
		ALU_Addr: out std_logic_vector(len_PC-1 downto 0);
		PC_Final: out std_logic_vector(len_PC-1 downto 0));
end entity;

architecture implementation of load_alu1 is 
	signal output_temp: std_logic_vector(15 downto 0);
	
begin
	PC_Final <= PC_Current;
	
	process(ALU_A, ALU_B, ALU_op, ALU_Imm,, PC_Current)
	begin
		if (ALU_op = "0011") then
			output_temp <=  ALU_A;
		elsif (ALU_op = "0100") then
			output_temp <= std_logic_vector(signed('0' & ALU_B) + signed(ALU_Imm));
		elsif (ALU_op = "0101") then
			output_temp <= std_logic_vector(signed('0' & ALU_B) + signed(ALU_Imm));
		else
			output_temp <= (others <= '0');
		end if;
	end process;	
end architecture;

entity load_exe2 is
	generic(len_PC: integer:= 16);
	port(
		DataIn: in std_logic_vector(15 downto 0);
		PC_Current: in std_logic_vector(len_PC-1 downto 0);
		is_LMSM: in std_logic;
		Load_Z_out: out std_logic;
		Z_en: out std_logic;
		DataOut: out std_logic_vector(len_PC-1 downto 0);
		PC_Final: out std_logic_vector(len_PC-1 downto 0));
end entity;

architecture implementation of load_exe2 is 
	signal Z_out_temp: std_logic;
	
begin
	PC_Final <= PC_Current;
	DataOut <= DataIn;
	process(DataIn, PC_Current, is_LMSM)
	begin
		if (ALU_op = "0100" and is_LMSM = '0') then
			if (to_integer(unsigned(DataIn)) = 0) then
				Z_out_temp <= '1';
				Z_en <= '1';
			else
				Z_out_temp <= '0';
				Z_en <= '1';
			end if;
		else
			Z_out_temp <= '0';
			Z_en <= '0';
		end if;
	end process;	
end architecture;

library ieee ;
use ieee.std_logic_1164.all ;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;

entity load_pipeline is
	generic(len_PC: integer:= 16;
	len_RRF: integer:= 6;
	len_RRF_status: integer:= 4);
	port(
		clk: in std_logic;
		flush: in std_logic;
		garbage_input: in std_logic;
		ra, rb: in std_logic_vector(15 downto 0);
		opcode: in std_logic_vector(3 downto 0);
		Immediate: in std_logic_vector(15 downto 0);
		PC_Current: in std_logic_vector(len_PC-1 downto 0);
		LS_Reg_Addr_In: in std_logic_vector(len_RRF-1 downto 0);
		Dest_Z_Addr_In: in std_logic_vector(len_RRF_status-1 downto 0);
		LS_Reg_Addr_Out: out std_logic_vector(len_RRF-1 downto 0);
		Mem_Addr_Out: out std_logic_vector(len_PC-1 downto 0);
		Dest_Z_Addr_Out: out std_logic_vector(len_RRF_status-1 downto 0);
		Dest_Data: out std_logic_vector(15 downto 0);
		Dest_Z_Data: out std_logic_vector;
		Dest_Z_en, Dest_en : out std_logic;
		PC_Out: out std_logic_vector(len_PC-1 downto 0));
end entity;

architecture implementation of load_pipeline is 
	
component reg_generic is
	generic (data_width : integer);
	port(
		clk, en, reset: in std_logic;
		Din: in std_logic_vector(data_width-1 downto 0);
		init: in std_logic_vector(data_width-1 downto 0);
		Dout: out std_logic_vector(data_width-1 downto 0));
end component;

signal isaBranch_temp, shld_PC_change, Dest_en_temp, Dest_C_en_temp, Dest_Z_en_temp: std_logic;

begin
	
	int_alu1: int_alu
		generic map (16)
		port map (ALU_A => Opr1, ALU_B => Opr2, ALU_op => opcode, ALU_Imm => Immediate, ALU_Conditions => conditions,
		ALU_Carry_In => C_RS, ALU_Zero_In => Z_RS, PC_Current => PC_Current, ALU_C => Dest_Data, ALU_Zero_Out => Dest_Z_Data, ALU_Carry_Out => Dest_C_Data,
		shld_PC_change => shld_PC_change_temp, isaBranch => isaBranch_temp, Dest_en => Dest_en_temp, C_en => Dest_C_en_temp, Z_en => Dest_Z_en_temp, PC_Final => PC_Branch);
	
	Dest_Addr_Out <= Dest_Addr_In;
	Dest_C_Addr_Out <= Dest_C_Addr_In;
	Dest_Z_Addr_Out <= Dest_Z_Addr_In;
	shld_PC_change <= ((shld_PC_change_temp and (not flush)) and (not garbage_input));
	isaBranch <= ((isaBranch_temp and (not flush)) and (not garbage_input));
	Dest_en <= ((Dest_en_temp and (not flush)) and (not garbage_input));
	Dest_C_en <= ((Dest_C_en_temp and (not flush)) and (not garbage_input));
	Dest_Z_en <= ((Dest_Z_en_temp and (not flush)) and (not garbage_input));
	
end architecture;