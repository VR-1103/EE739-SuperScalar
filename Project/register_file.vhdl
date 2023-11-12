library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_file is
	generic(len_rrf: integer:=63;
			log_size_rrf: integer:=6;
			len_rs: integer:=32;
			);
	port (clk: in std_logic;
			number_of_operands1,number_of_operands2: in std_logic(1 downto 0);--00: none, 01: one, 10:two
			operand_adds_11,operand_adds_12,operand_adds_21,operand_adds_22: in std_logic_vector(2 downto 0);
			carry_zero1, carry_zero2: in std_logic_vector(1 downto 0); --00:none, 01: zero, 10: carry, 11:both
			dest1,dest2: in std_logic_vector(2 downto 0);
			dest_reqd1, dest_reqd2: in std_logic;
			invalid_op1,invalid_op2: in std_logic_vector(16*len_rs-1 downto 0);
			invalidity_op1,invalidity_op2: in std_logic_vector(len_rs-1 downto 0); -- follow that valid is high, and invalid is low
			invalid_c,invalid_z: in std_logic_vector(16*len_rs-1 downto 0);
			invalidity_c,invalidity_z: in std_logic_vector(len_rs-1 downto 0);
			int_pipe_1,int_pipe_2: in std_logic_vector(log_size_rrf+16+1-1 downto 0); --rrf address,data,control signal
			rob1,rob2: in std_logic_vector(3+log_size_rrf+1-1 downto 0);
			queue1: in std_logic_vector(log_size_rrf-1 downto 0); --require at max 2 rrf in one cycle
			queue2: in std_logic_vector(log_size_rrf-1 downto 0);
			-------------------------------------------------------------------------------------------
			operand_words_11,operand_words_12,operand_words_21,operand_words_22: out std_logic_vector(15 downto 0);
			operand_valid_11,operand_valid_12,operand_valid_21,operand_valid_22: out std_logic;
			carry1,carry2,zero1,zero2: out std_logic_vector(15 downto 0);
			carry1_valid,carry2_valid,zero1_valid,zero2_valid: out std_logic;
			dest1_add,dest2_add: out std_logic_vector(log_size_rrf-1 downto 0);
			dest1_valid,dest2_valid: out std_logic;
			valid_op1,valid_op2: out std_logic_vector(16*len_rs-1 downto 0);
			validity_op1,validity_op2: out std_logic_vector(len_rs-1 downto 0);
			valid_c,valid_z: out std_logic_vector(16*len_rs-1 downto 0);
			validity_c,validity_z: out std_logic_vector(len_rs-1 downto 0));
			queue_used1: out std_logic;
			queue_used2: out std_logic;
			queue_out1: out std_logic_vector(log_size_rrf-1 downto 0);
			queue_out2: out std_logic_vector(log_size_rrf-1 downto 0);
end entity register_file;

architecture trivial of register_file is
	type arf is array(7 downto 0) of std_logic_vector(15+1+log_size_rrf downto 0); --data+busy+tag
	type rrf is array(len_rrf-1 downto 0) of std_logic_vector(15+1+1 downto 0); --data+busy+valid
	signal ar: arf := (others => "1111110000000000000000");
	signal rr: rrf := (others => "00000000000000000");
	signal carry : std_logic_vector(15+1+log_size_rrf downto 0) := (others => "0000000000000000000000");
	signal zero : std_logic_vector(15+1+log_size_rrf downto 0) := (others => "0000000000000000000000");
	begin
	decoder_work: process(clk)
		begin
		if(number_of_operands1 = "01") then
			if (ar(to_integer(operand_adds_11))(16) = '0') then
				operand_words_11 <= ar(to_integer(operand_adds_11)(15 downto 0);
			else
				operand_words_11 <= "000000000" & ar(to_integer(operand_adds_11)(15+1+log_size_rrf downto 17); --basically want to append the address of the tag to 16 bits
			end if;
			
		elsif(number_of_operands1 = "10") then
			if (ar(to_integer(operand_adds_11))(16) = '0') then
				operand_words_11 <= ar(to_integer(operand_adds_11)(15 downto 0);
			else
				operand_words_11 <= "000000000" & ar(to_integer(operand_adds_11)(15+1+log_size_rrf downto 17); --basically want to append the address of the tag to 16 bits
			end if;			
			
			if (ar(to_integer(operand_adds_12))(16) = '0') then
				operand_words_12 <= ar(to_integer(operand_adds_12)(15 downto 0);
			else
				operand_words_12 <= "000000000" & ar(to_integer(operand_adds_12)(15+1+log_size_rrf downto 17); --basically want to append the address of the tag to 16 bits
			end if;	
		else
			null;
		end if;
		
		if(number_of_operands2 = "01") then
			if (ar(to_integer(operand_adds_21))(16) = '0') then
				operand_words_21 <= ar(to_integer(operand_adds_21)(15 downto 0);
			else
				operand_words_21 <= "000000000" & ar(to_integer(operand_adds_21)(15+1+log_size_rrf downto 17); --basically want to append the address of the tag to 16 bits
			end if;
			
		elsif(number_of_operands2 = "10") then
			if (ar(to_integer(operand_adds_21))(16) = '0') then
				operand_words_21 <= ar(to_integer(operand_adds_21)(15 downto 0);
			else
				operand_words_21 <= "000000000" & ar(to_integer(operand_adds_21)(15+1+log_size_rrf downto 17); --basically want to append the address of the tag to 16 bits
			end if;			
			
			if (ar(to_integer(operand_adds_22))(16) = '0') then
				operand_words_22 <= ar(to_integer(operand_adds_22)(15 downto 0);
			else
				operand_words_22 <= "000000000" & ar(to_integer(operand_adds_22)(15+1+log_size_rrf downto 17); --basically want to append the address of the tag to 16 bits
			end if;	
		else
			null;
		end if;
		
		if (carryzero1(0) = '1') then 
			if (zero(16) = '0') then
			-- What is supposed to be written here? I am writing a null here for the sake of syntax
				null;
			end if;
		end if;
		
		queue_used1 <= '0';
		if (dest_reqd1 = '1') then
			if(queue1 = "111111") then
				null;
			else
				ar(to_integer(dest1))(16) <= '1';
				ar(to_integer(dest1))(15+1+log_size_rrf downto 17) <= queue1;
				queue_used1 <= '1';
				rr(to_integer(queue1))(16) <= '1';
				rr(to_integer(queue1))(17) <= '0';
			end if;
		else
			null;
		end if;

		queue_used2 <= '0';
		if (dest_reqd2 = '1') then
			if(queue2 = "111111") then
				null;
			else
				ar(to_integer(dest2))(16) <= '1';
				ar(to_integer(dest2))(15+1+log_size_rrf downto 17) <= queue2;
				queue_used2 <= '1';
				rr(to_integer(queue2))(16) <= '1';
				rr(to_integer(queue2))(17) <= '0';
			end if;
		else
			null;
		end if;
		
	end process;
	
	rs_work: process(clk)
		begin
		L1: for i in 0 to len_rs loop
			if (invalidity_op1(i) = '0') then
				if (rr(to_integer(invalid_op1(i*16+log_size_rrf-1 downto i*16)))(17) = '1') then
					valid_op1(i*16+15 downto i*16) <= rr(to_integer(invalid_op1(i*16+log_size_rrf-1 downto i*16)))(15 downto 0)
					validity_op1(i) <= '1';
				else
					validity_op1(i) <= '0';
				end if;
			end if;
		end loop;
		L2: for i in 0 to len_rs loop
			if (invalidity_op2(i) = '0') then
				if (rr(to_integer(invalid_op2(i*16+log_size_rrf-1 downto i*16)))(17) = '1') then
					valid_op2(i*16+15 downto i*16) <= rr(to_integer(invalid_op2(i*16+log_size_rrf-1 downto i*16)))(15 downto 0)
					validity_op2(i) <= '1';
				else
					validity_op2(i) <= '0';
				end if;
			end if;
		end loop;
		
		--have to write for c and z
		
	end process;
	
	int_pipe: process(clk)
		begin
		if (int_pipe1(log_size_rrf+16+1-1) = '1') then
			rr(to_integer(int_pipe1(log_size_rrf+15 downto 16)))(15 downto 0) <= int_pipe1(15 downto 0);
			rr(to_integer(int_pipe1(log_size_rrf+15 downto 16)))(17) <= '1';
		else
			null;
		end if;
		if (int_pipe2(log_size_rrf+16+1-1) = '1') then
			rr(to_integer(int_pipe2(log_size_rrf+15 downto 16)))(15 downto 0) <= int_pipe2(15 downto 0);
			rr(to_integer(int_pipe2(log_size_rrf+15 downto 16)))(17) <= '1';
		else
			null;
		end if;
		
	end process;
	
	rob_work: process(clk)
		begin
		if (rob1(3+log_size_rrf+1-1) = '1') then
			ar(to_integer(rob1(3+log+size_rrf-1 downto log_size_rrf)))(15 downto 0) <= rr(to_integer(rob1(log_size_rrf-1 downto 0)))(15 downto 0);
			rr(to_integer(rob1(log_size_rrf-1 downto 0)))(16) <= '0';
			queue_out1 <= rob1(log_size_rrf-1 downto 0);
		else
			null;
		end if;
		if (rob2(3+log_size_rrf+1-1) = '1') then
			ar(to_integer(rob2(3+log+size_rrf-1 downto log_size_rrf)))(15 downto 0) <= rr(to_integer(rob2(log_size_rrf-1 downto 0)))(15 downto 0);
			rr(to_integer(rob2(log_size_rrf-1 downto 0)))(16) <= '0';
			queue_out2 <= rob2(log_size_rrf-1 downto 0);
		else
			null;
		end if;
		
	end process;
		

end architecture trivial;
