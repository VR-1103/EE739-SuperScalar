library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity lmsm_block is
	generic(len_PC: integer:= 5;
				len_data: integer:= 16);
	port(clk: in std_logic;
			instr1,instr2: in std_logic_vector(len_PC+len_data-1 downto 0);
			instr_valid1,instr_valid2: in std_logic;
			instr1_out,instr2_out: out std_logic_vector(len_PC+len_data-1 downto 0);
			instr_valid_out1,instr_valid_out2: out std_logic;
			disable:in std_logic;--from decoder
			was_lmsm: out std_logic;
			pc_to_fetch: out std_logic_vector(len_PC-1 downto 0);
			pc_to_temp: out std_logic_vector(len_PC-1 downto 0));
end entity;

architecture Struct of lmsm_block is
	signal status: std_logic:= '0';
	signal reg: integer:= 0;
	signal current_lmsm: std_logic_vector(len_PC+len_data-1 downto 0);
	signal imm: std_logic_vector(6-1 downto 0) := (others => '0');
begin
	op: process(clk)
	begin
		if rising_edge(clk) then
			if disable = '0' then
				if status = '0' then
					if instr1(len_data-1 downto len_data-3) /= "011" then
						instr1_out <= instr1;
						instr_valid_out1 <= instr_valid1;
		--				imm <= "000000";
		--				reg <= 0;
		--				was_lmsm <= '0';
						if instr2(len_data-1 downto len_data-3) /= "011" then
							instr2_out <= instr2;
							instr_valid_out2 <= instr_valid2;
							imm <= "000000";
							reg <= 0;
							was_lmsm <= '0';
						else
							was_lmsm <= '1';
							pc_to_fetch <= std_logic_vector(unsigned(instr2(len_PC+len_data-1 downto len_data)) + "00010");
							pc_to_temp <= std_logic_vector(unsigned(instr2(len_PC+len_data-1 downto len_data)) + "00110");
							status <= '1';
							current_lmsm(len_PC+len_data-1 downto len_data) <= instr2(len_PC+len_data-1 downto len_data);
							current_lmsm(len_data-1 downto len_data-7) <= instr1(len_data-1 downto len_data-7);
							current_lmsm(len_data-8 downto len_data-16) <= '0' & instr1(len_data-8 downto len_data-15);
							if (instr2(0) = '1') then
								instr2_out(len_PC+len_data-1 downto len_data) <= instr2(len_PC+len_data-1 downto len_data);
								instr2_out(len_data-1 downto len_data-4) <= "010" & instr2(len_data-4);
								instr2_out(len_data-5 downto len_data-7) <= std_logic_vector(to_unsigned(reg,3));
								instr2_out(len_data-8 downto len_data-10) <= instr2(len_data-5 downto len_data-7);
								instr2_out(len_data-11 downto len_data-16) <= imm;
								instr_valid_out2 <= '0';
							else
								instr2_out <= instr2;
								instr_valid_out2 <= '1';
							end if;
							reg <= reg+1;
							imm <= std_logic_vector(unsigned(imm) + "000001");
						end if;
					else
						was_lmsm <= '1';
						pc_to_fetch <= instr2(len_PC+len_data-1 downto len_data);
						pc_to_temp <= std_logic_vector(unsigned(instr2(len_PC+len_data-1 downto len_data)) + "00100");
						if (instr1(0) = '1') then
							instr1_out(len_PC+len_data-1 downto len_data) <= instr1(len_PC+len_data-1 downto len_data);
							instr1_out(len_data-1 downto len_data-4) <= "010" & instr1(len_data-4);
							instr1_out(len_data-5 downto len_data-7) <= std_logic_vector(to_unsigned(reg,3));
							instr1_out(len_data-8 downto len_data-10) <= instr1(len_data-5 downto len_data-7);
							instr1_out(len_data-11 downto len_data-16) <= imm;
							instr_valid_out1 <= '0';
							if instr1(1) = '1' then
								instr2_out(len_PC+len_data-1 downto len_data) <= instr1(len_PC+len_data-1 downto len_data);
								instr2_out(len_data-1 downto len_data-4) <= "010" & instr1(len_data-4);
								instr2_out(len_data-5 downto len_data-7) <= std_logic_vector(to_unsigned(reg+1,3));
								instr2_out(len_data-8 downto len_data-10) <= instr1(len_data-5 downto len_data-7);
								instr2_out(len_data-11 downto len_data-16) <= std_logic_vector(unsigned(imm) + "000001");
								instr_valid_out2 <= '0';
								status <= '1';
								current_lmsm(len_PC+len_data-1 downto len_data) <= instr1(len_PC+len_data-1 downto len_data);
								current_lmsm(len_data-1 downto len_data-7) <= instr1(len_data-1 downto len_data-7);
								current_lmsm(len_data-8 downto len_data-16) <= "00" & instr1(len_data-8 downto len_data-14);
								reg <= reg+2;
								imm <= std_logic_vector(unsigned(imm) + "000010");
							else
								instr2_out <= instr1;
								instr_valid_out2 <= '1';
								status <= '1';
								current_lmsm(len_PC+len_data-1 downto len_data) <= instr1(len_PC+len_data-1 downto len_data);
								current_lmsm(len_data-1 downto len_data-7) <= instr1(len_data-1 downto len_data-7);
								current_lmsm(len_data-8 downto len_data-16) <= "00" & instr1(len_data-8 downto len_data-14);
								reg <= reg+2;
								imm <= std_logic_vector(unsigned(imm) + "000010");
							end if;
							
						else
							instr1_out <= instr1;
							instr_valid_out1 <= '1';
							if instr1(1) = '1' then
								instr2_out(len_PC+len_data-1 downto len_data) <= instr1(len_PC+len_data-1 downto len_data);
								instr2_out(len_data-1 downto len_data-4) <= "010" & instr1(len_data-4);
								instr2_out(len_data-5 downto len_data-7) <= std_logic_vector(to_unsigned(reg+1,3));
								instr2_out(len_data-8 downto len_data-10) <= instr1(len_data-5 downto len_data-7);
								instr2_out(len_data-11 downto len_data-16) <= std_logic_vector(unsigned(imm) + "000001");
								instr_valid_out2 <= '0';
								status <= '1';
								current_lmsm(len_PC+len_data-1 downto len_data) <= instr1(len_PC+len_data-1 downto len_data);
								current_lmsm(len_data-1 downto len_data-7) <= instr1(len_data-1 downto len_data-7);
								current_lmsm(len_data-8 downto len_data-16) <= "00" & instr1(len_data-8 downto len_data-14);
								reg<= reg+2;
								imm <= std_logic_vector(unsigned(imm) + "000010");
							else
								instr2_out <= instr1;
								instr_valid_out2 <= '1';
								status <= '1';
								current_lmsm(len_PC+len_data-1 downto len_data) <= instr1(len_PC+len_data-1 downto len_data);
								current_lmsm(len_data-1 downto len_data-7) <= instr1(len_data-1 downto len_data-7);
								current_lmsm(len_data-8 downto len_data-16) <= "00" & instr1(len_data-8 downto len_data-14);
								reg <= reg+2;
								imm <= std_logic_vector(unsigned(imm) + "000010");
							end if;
						end if;
					end if;
				
				else --when status is 1--
					if current_lmsm(len_data-8 downto len_data-16) = "000000000" then
						status <= '0';
						was_lmsm <= '0';
						instr_valid_out1 <= '1';
						instr_valid_out2 <= '1';
						reg <= 0;
						imm <= "000000";
					else
						status <= '1';
						was_lmsm <= '1';
						if current_lmsm(0) = '1' then
							instr1_out(len_PC+len_data-1 downto len_data) <= current_lmsm(len_PC+len_data-1 downto len_data);
							instr1_out(len_data-1 downto len_data-4) <= "010" & current_lmsm(len_data-4);
							instr1_out(len_data-5 downto len_data-7) <= std_logic_vector(to_unsigned(reg,3));
							instr1_out(len_data-8 downto len_data-10) <= current_lmsm(len_data-5 downto len_data-7);
							instr1_out(len_data-11 downto len_data-16) <= imm;
							instr_valid_out1 <= '0';
							if current_lmsm(1) = '1' then
								instr2_out(len_PC+len_data-1 downto len_data) <= current_lmsm(len_PC+len_data-1 downto len_data);
								instr2_out(len_data-1 downto len_data-4) <= "010" & current_lmsm(len_data-4);
								instr2_out(len_data-5 downto len_data-7) <= std_logic_vector(to_unsigned(reg+1,3));
								instr2_out(len_data-8 downto len_data-10) <= current_lmsm(len_data-5 downto len_data-7);
								instr2_out(len_data-11 downto len_data-16) <= std_logic_vector(unsigned(imm) + "000001");
								instr_valid_out2 <= '0';
							else
								instr_valid_out2 <= '1';
							end if;
						else
							instr_valid_out1 <= '1';
						end if;
						reg <= reg+2;
						imm <= std_logic_vector(unsigned(imm) + "000010");
						current_lmsm(len_PC+len_data-1 downto len_data) <= current_lmsm(len_PC+len_data-1 downto len_data);
						current_lmsm(len_data-1 downto len_data-7) <= current_lmsm(len_data-1 downto len_data-7);
						current_lmsm(len_data-8 downto len_data-16) <= "00" & current_lmsm(len_data-8 downto len_data-14);
					end if;
				end if;
			else
				instr_valid_out1 <= '1';
				instr_valid_out2 <= '1';
				was_lmsm <= '0';
				reg <= 0;
				imm <= "000000";
				status <= '0';
			end if;

		else null;
		end if;		
	end process;

end architecture;