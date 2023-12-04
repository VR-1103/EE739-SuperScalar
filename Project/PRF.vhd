library ieee ;
use ieee.std_logic_1164.all ;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;

entity PRF is

	generic (len_RRF: integer := 6;
				len_RRF_status: integer := 6;
				finder_table_size: integer := 8;
				len_ARF: integer := 3;
				len_data: integer := 16);
				
	port (-- Ports from rob
			rob_valid_update: in std_logic;
			rob_update_r0: in std_logic;
			rob_retire_valid1, rob_retre_valid2: in std_logic;
			rob_retire_word1, rob_retire_word2: in std_logic(0 to len_RRF + len_ARF - 1);
			
			-- Ports from integer pipeline
			Dest_Addr_Out1, Dest_Addr_Out2: in std_logic_vector(len_RRF-1 downto 0);
			Dest_CZ_Addr_Out1, Dest_CZ_Addr_Out2: in std_logic_vector(len_RRF_status-1 downto 0);
			Dest_Data1, Dest_Data2: in std_logic_vector(15 downto 0);
			Dest_CZ_Data1, Dest_CZ_Data2: in std_logic_vector(0 to 1);
			Dest_CZ_en1, Dest_CZ_en2, Dest_en1, Dest_en2: in std_logic;
			
			-- Ports from L/S pipeline
			LS_addr_in: in std_logic_vector(0 to len_RRF - 1);
			LS_data_in: in std_logic_vector(0 to len_data - 1);
			LS_status_data: in std_logic_vector(0 to 1);
			LS_status_addr: in std_logic_vector(0 to len_RRF - 1);
			LS_data_en, LS_status_en: in std_logic;
			
			-- Ports from decoder
			decoder_op_required1, decoder_op_required2: in std_logic_vector(1 downto 0); ---tells prf how many operands required
			decoder_op_addr1, decoder_op_addr2: in std_logic_vector(len_arf+len_arf-1 downto 0); ---at max can hold addr of 2 operands,if only 1 operand is asked, addr will be at (len_arf-1 downto 0)
			decoder_dest_required1,decoder_dest_required2: in std_logic; ---whether destination is required
			decoder_dest_addr1,decoder_dest_addr2: in std_logic_vector(len_arf-1 downto 0); ---arf addr of destination
			
			op_data1,op_data2: in std_logic_vector(len_data+len_data-1 downto 0); ---at max data of 2 operands, if only 1 operand is asked, send the data to (len_data-1 downto 0)
			op_valid1,op_valid2: in std_logic_vector(1 downto 0); ----similarly if only 1 oeprand, validity of 0'th bit will be considered
			dest_rrf1,dest_rrf2: in std_logic_vector(len_rrf-1 downto 0); ---addr of destination rrf
			cz_required1,cz_required2: out std_logic; ---00 if neither, 01 if z, 10 if c, 11 will never happen, honestly if prf has one status register, then ig it doesnt matter, only matters how pipeline is using the status register ka data
			cz1,cz2: in std_logic_vector(len_data-1 downto 0); ---whatever is asked, send that---
			cz_valid1,cz_valid2: in std_logic; ---whether its valid or not
			cz_dest_required1,cz_dest_required2: out std_logic; ---whenever the instr will change c/z/both, this will be high
			cz_rrf1,cz_rrf2: in std_logic_vector(len_rrf-1 downto 0); ---send the rrf for new location of status register---);
			
			-- Ports going out to components with just updated data
			data_out1, data_out_2, data_out3: out std_logic_vector(0 to len_RRF + len_data - 1);
			data_out_valid1, data_out_valid2, data_out_valid3: out std_logic;
			status_out1, status_out2, status_out3: out std_logic_vector(0 to len_RRF + 1);
			status_valid1, status_valid2, status_valid3: out std_logic);
end entity PRF;

architecture find of PRF is
	constant row_len: integer := 1 + len_RRF + len_RRF; -- Busy(1) + current_RRF_pointer(6) + current_ARF_pointer(6)
	type f_table is array(0 to finder_table_size - 1) of std_logic_vector(0 to row_len - 1);
	signal finder_table: f_table := (0 => "0000000000000"; 1=> "0000001000001", 2 => "0000010000010", 3 => "0000011000011", 4=> "0000100000100", 5=>"0000101000101", 6 => "0000110000110", 7 =>"0000111000111", others => (others => '0'));
	constant prf_row_len = 1 + 1 + len_data; -- Busy(1) + Valid(1) + Data(16)
	type p_table is array(0 to prf_table_size - 1) of std_logic_vector(0 to prf_row_len - 1);
	signal prf_rable: p_table := (others => "010000000000000000"); -- all registers are valid with value 0
	
	-- some indexes for ARF finder
	constant busy: integer := 0;
	constant rrf_addr_start: integer := 1; -- corresponds to register having most updated value 
	constant rrf_addr_end: integer := rrf_addr_start + len_RRF - 1;
	constant arf_addr_start: integer := rrf_addr_end; -- corresponds to register having value as seen by state
	constant arf_addr_end: integer := arf_addr_start + len_RRF - 1;
	
	-- for actual PRF
	constant valid: integer := 1;
	constant data_start: integer := 2;
	constant data_end : integer := data_start + len_data - 1;
	
begin
	
	finder_proc: process(clk)
		variable i: integer := 0;
		variable arf_addr_in: integer;
		variable rrf_addr_in: std_logic_vector(0 to len_RRF - 1);
		variable rrf_addr_in_integer: integer;
		
		-- for dealing with decoder
		variable op1addr1, op1addr2, op2addr1, op2addr2: std_logic_vector(0 to len_arf - 1);
		variable dest_arf: std_logic_vector(0 to len_arf - 1);
		
		shared variable index_op1addr1: integer := 8;
		shared variable index_op1addr2: integer := 9;
		shared variable index_op2addr1: integer := 10 
		shared variable valid_op1addr1, valid_op1addr2, valid_op2addr1, valid_op2addr2, valid_dest1, valid_dest2: std_logic := '1';  
		
	begin
	
		if (rising_edge(clk)) then
		
			-- Take input from rob for word 1 
			if (rob_retire_valid1 = '1') then
				rrf_addr_in := rob_retire_word1(0 to len_RRF - 1);
				rrf_addr_in_integer := to_integer(unsigned(rrf_addr_in))
				arf_addr_in := to_integer(unsigned(rob_retire_word1(len RRF to len_RRF + lenARF - 1)));
				finder_table(arf_addr_in)(arf_addr_start to arf_addr_end) <= rrf_addr_in;
				if (rrf_addr_in = finder_table(arf_addr_in)(rrf_addr_start to rrf_addr_end)) then
					finder_table(arf_addr_in)(busy) <= '0';
				end if;
				prf_table(rrf_addr_in_integer)(busy) <= '0'; -- no longer need to hold this temporary value
			end if;
			
			-- Take input from rob for word2
			if (rob_retire_valid2 = '1') then
				rrf_addr_in := rob_retire_word2(0 to len_RRF - 1);
				rrf_addr_in_integer := to_integer(unsigned(rrf_addr_in))
				arf_addr_in := to_integer(unsigned(rob_retire_word2(len RRF to len_RRF + lenARF - 1)));
				finder_table(arf_addr_in)(arf_addr_start to arf_addr_end) <= rrf_addr_in;
				if (rrf_addr_in = finder_table(arf_addr_in)(rrf_addr_start to rrf_addr_end)) then
					finder_table(arf_addr_in)(busy) <= '0'; -- no longer need to hold this temporary value
				end if;
				prf_table(rrf_addr_in_integer)(busy) <= '0';
			end if;
			
			-- Take input from integer pipelines and send updated values
			if(Dest_en1 = '1') then
				rrf_addr_in := Dest_addr_out1;
				rrf_addr_in_integer := to_integer(unsigned(rrf_addr_in));
				prf_table(rrf_addr_in_integer)(data_start to _data_end) <= Dest_data1;
				prf_table(rrf_addr_in_integer)(valid) <= '1'; -- data in register can be used now
				data_out1 <= rrf_addr_in & Dest_data1;
				data_out_valid1 <= '1';
			else
				data_out1 <= rrf_addr_in & Dest_data1;
				data_out_valid1 <= '0';
			end if;
			
			if(Dest_en2 = '1') then
				rrf_addr_in := Dest_addr_out2;
				rrf_addr_in_integer := to_integer(unsigned(rrf_addr_in));
				prf_table(rrf_addr_in_integer)(data_start to _data_end) <= Dest_data2;
				prf_table(rrf_addr_in_integer)(valid) <= '1'; -- data in register can be used now
				data_out2 <= rrf_addr_in & Dest_data2;
				data_out_valid2 <= '1';
			else
				data_out2 <= rrf_addr_in & Dest_data2;
				data_out_valid2 <= '0';
			end if;
			
			if(Dest_CZ_en1 = '1') then
				rrf_addr_in := Dest_CZ_addr_out1;
				rrf_addr_in_integer := to_integer(unsigned(rrf_addr_in));
				prf_table(rrf_addr_in_integer)(data_start to _data_end) <= Dest_CZ_data1 & "00000000000000"; --only first two bits are useful
				prf_table(rrf_addr_in_integer)(valid) <= '1'; -- data in register can be used now
				status_out1 <= rrf_addr_in & Dest_CZ_data1;
				status_valid1 <= '1';
			else
				status_out1 <= rrf_addr_in & Dest_CZ_data1;
				status_valid1 <= '0';
			end if;
			
			if(Dest_CZ_en2 = '1') then
				rrf_addr_in := Dest_CZ_addr_out2;
				rrf_addr_in_integer := to_integer(unsigned(rrf_addr_in));
				prf_table(rrf_addr_in_integer)(data_start to _data_end) <= Dest_CZ_data2 & "00000000000000"; --only first two bits are useful
				prf_table(rrf_addr_in_integer)(valid) <= '1'; -- data in register can be used now
				status_out2 <= rrf_addr_in & Dest_CZ_data2;
				status_valid2 <= '1';
			else
				status_out2 <= rrf_addr_in & Dest_CZ_data2;
				status_valid2 <= '0';
			end if;
			
			-- Take input from L/S pipelines and send updated values
			if (LS_data_en = '1') then
				rrf_addr_in := LS_addr_in;
				rrf_addr_in_integer := to_integer(unsigned(rrf_addr_in));
				prf_table(rrf_addr_in_integer)(data_start to data_end) <= LS_data_in;
				prf_table(rrf_addr_in_integer)(valid) <= '1' --data can now be used
				data_out3 <= rrf_addr_in & LS_data_in;
				data_out_valid3 <= '1';
			else
				data_out3 <= rrf_addr_in & LS_data_in;
				data_out_valid3 <= '0';
			end if;
			
			if (LS_status_en = '1') then
				rrf_addr_in := LS_status_addr;
				rrf_addr_in_integer := to_integer(unsigned(rrf_addr_in));
				prf_table(rrf_addr_in_integer)(data_start to data_end) <= LS_status_data;
				prf_table(rrf_addr_in_integer)(valid) <= '1' --data can now be used
				status_out3 <= rrf_addr_in & LS_status_data;
				status_valid3 <= '1';
			else
				status_out3 <= rrf_addr_in & LS_status_data;
				status_valid3 <= '1';
			end if;
				
			-- Take input from decoder, figure out renamed registers and send back data
			if (decoder_op_required1 = "01" or decoder_op_required1 = "10") then
			-- I tried to figure out this logic but at this point my brain had stopped working so i have left this part blank
				
			
		end if;
end architecture;
	