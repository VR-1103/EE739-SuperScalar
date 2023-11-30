library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;
 
entity example_file_io_tb is
 
end example_file_io_tb;
 
 
architecture behave of example_file_io_tb is
 
  -----------------------------------------------------------------------------
  -- Declare the Component Under Test
  -----------------------------------------------------------------------------
  component int_RS is
     -- The integer RS only cares about the PC, control word, operands or the address of where to update them from, and the destination RRF (both operand and status)
    generic(len_PC: integer; -- Length of the PC which RS receives for each instruction
				len_control: integer; -- Length of the control word for the integer pipeline
            len_RRF: integer; -- Length of the destination RRF which the RS receives for each instruction
            len_operand: integer; -- Length of the two operands. This is more than the length of the addresses in the PRF so that address can fit as well  
            size_rs: integer; -- Size of RS table
				len_status: integer; --status register. It is 6 so that renamed status reg can also be fitted. Actual CZ flag is to be put in the first two indexes 
            log_size_rs: integer; -- log2 of size. UPDATE EVERYTIME YOU UPDATE SIZE
				input_RRF: integer; -- reg address + content
				len_out: integer; -- output to pipeline. Status is just 2 here cause address won't be needed now
				input_len: integer;
				-- This works like: pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + status_valid(1) + status_reg(6) + status_destination(len_RRF) + ready(1)
            row_len: integer -- This works like: busy(1) + input
				);

    port(clk, RS_flush: in std_logic; -- Clock and flush signal
			input_word1, input_word2: in std_logic_vector(0 to input_len - 1); -- Input from decoder 
			valid_in1, valid_in2: in std_logic; -- Whether input from decoder is valid/should be entered in the RS table
			rrf_reg1, rrf_reg2, rrf_reg3: in std_logic_vector(0 to input_RRF - 1); -- Input of updated register from RRF. Contains address + content
			rrf_valid1, rrf_valid2, rrf_valid3: in std_logic; -- Whether input from PRF is valid
			status_reg1, status_reg2, status_reg3: in std_logic_vector(0 to len_RRF + 1); -- Input of updated status register. Contains address + content
			status_valid1, status_valid2, status_valid3: in std_logic; -- Whether input from status reg is valid
			pipe1_busy, pipe2_busy: in std_logic; -- pipelines are busy so cant give instr
			pipe1_issue, pipe2_issue: out std_logic_vector(0 to len_out - 1); -- issue words to integer pipelines (2)
			pipe1_issue_valid, pipe2_issue_valid: out std_logic; -- are issue words valid
         RS_stall: out std_logic); -- 1 if RS is full, else 0
  end component int_RS;
 
 
  -----------------------------------------------------------------------------
  -- Testbench Internal Signals
  -----------------------------------------------------------------------------
  file file_VECTORS : text;
  file file_RESULTS : text;
  
  constant len_PC: integer := 5; -- Length of the PC which RS receives for each instruction
  constant len_control: integer := 16; -- Length of the control word for the integer pipeline
  constant len_RRF: integer := 6; -- Length of the destination RRF which the RS receives for each instruction
  constant len_operand: integer := 32; -- Length of the two operands. This is more than the length of the addresses in the PRF so that address can fit as well  
  constant size_rs: integer := 64; -- Size of RS table
  constant len_status: integer := 6; --status register. It is 6 so that renamed status reg can also be fitted. Actual CZ flag is to be put in the first two indexes 
  constant log_size_rs: integer := 6; -- log2 of size. UPDATE EVERYTIME YOU UPDATE SIZE
  constant input_RRF: integer := (len_RRF + len_operand); -- reg address + content
  constant len_out: integer := (len_pc + len_control + len_operand + len_operand + len_RRF + len_RRF + 2); -- output to pipeline. Status is just 2 here cause address won't be needed now
  constant input_len: integer := (len_pc + 4 + len_control + 1 + len_operand + 1 + len_operand + len_RRF + 1 + len_status + len_RRF + 1);
	-- This works like: pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + status_valid(1) + status_reg(6) + status_destination(len_RRF) + ready(1)
  constant row_len: integer:= (1 + input_len); 	-- This works like: busy(1) + input
	
  signal clk : std_logic := '0';
  signal RS_flush: std_logic := '0'; -- Clock and flush signal
  signal	input_word1: std_logic_vector(0 to input_len - 1) := (others => '0'); 
  signal input_word2: std_logic_vector(0 to input_len - 1) := (others =>'0'); -- Input from decoder 
  signal valid_in1:std_logic := '0'; 
  signal valid_in2: std_logic := '0'; -- Whether input from decoder is valid/should be entered in the RS table
  signal rrf_reg1:  std_logic_vector(0 to input_RRF - 1) := (others =>'0');  
  signal rrf_reg2:  std_logic_vector(0 to input_RRF - 1) := (others =>'0');  
  signal rrf_reg3:  std_logic_vector(0 to input_RRF - 1) := (others =>'0'); -- Input of updated register from RRF. Contains address + content
  signal rrf_valid1:  std_logic := '0';
  signal rrf_valid2:  std_logic := '0';
  signal rrf_valid3:  std_logic := '0'; -- Whether input from PRF is valid
  signal status_reg1: std_logic_vector(0 to len_RRF + 1) := (others => '0');
  signal status_reg2:  std_logic_vector(0 to len_RRF + 1) := (others => '0');
  signal status_reg3:  std_logic_vector(0 to len_RRF + 1) := (others => '0'); -- Input of updated status register. Contains address + content
  signal status_valid1: std_logic := '0';
  signal status_valid2:  std_logic := '0';
  signal status_valid3:  std_logic := '0'; -- Whether input from status reg is valid
  signal pipe1_busy: std_logic := '0';
  signal pipe2_busy:  std_logic := '0'; -- pipelines are busy so cant give instr
  
  --outputss
  signal pipe1_issue: std_logic_vector(0 to len_out - 1);
  signal pipe2_issue: std_logic_vector(0 to len_out - 1); -- issue words to integer pipelines (2)
  signal pipe1_issue_valid: std_logic; 
  signal pipe2_issue_valid: std_logic; -- are issue words valid
  signal RS_stall: std_logic;  
begin
 
  -----------------------------------------------------------------------------
  -- Instantiate and Map UUT
  -----------------------------------------------------------------------------
  int_RS_inst : int_RS
    
	 generic map(
            len_PC => len_PC, -- Length of the PC which RS receives for each instruction
				len_control => len_control, -- Length of the control word for the integer pipeline
            len_RRF => len_RRF, -- Length of the destination RRF which the RS receives for each instruction
            len_operand => len_operand, -- Length of the two operands. This is more than the length of the addresses in the PRF so that address can fit as well  
            size_rs => size_rs, -- Size of RS table
				len_status => len_status, --status register. It is 6 so that renamed status reg can also be fitted. Actual CZ flag is to be put in the first two indexes 
            log_size_rs => log_size_rs, -- log2 of size. UPDATE EVERYTIME YOU UPDATE SIZE
				input_RRF => input_RRF, -- reg address + content
				len_out => len_out, -- output to pipeline. Status is just 2 here cause address won't be needed now
				input_len => input_len,
				-- This works like: pc(len_pc) + opcode(4) + control(len_control) + valid1(1) + opr1(len_operand) + valid2(1) + opr2(len_operand) + destination(len_RRF) + status_valid(1) + status_reg(6) + status_destination(len_RRF) + ready(1)
            row_len => row_len -- This works like: busy(1) + input
				)
				
    port map (
      clk => clk,
      RS_flush => RS_flush, -- Clock and flush signal
      input_word1 => input_word1,
      input_word2=> input_word2,-- Input from decoder 
      valid_in1 => valid_in1,
      valid_in2 => valid_in2, -- Whether input from decoder is valid/should be entered in the RS table
      rrf_reg1 => rrf_reg1,  
      rrf_reg2 => rrf_reg2,  
      rrf_reg3 => rrf_reg3, -- Input of updated register from RRF. Contains address + content
      rrf_valid1 => rrf_valid1, 
      rrf_valid2 => rrf_valid2, 
      rrf_valid3 => rrf_valid3,  -- Whether input from PRF is valid
      status_reg1 => status_reg1,
      status_reg2 => status_reg2,
      status_reg3 => status_reg3, -- Input of updated status register. Contains address + content
      status_valid1 => status_valid1,
      status_valid2 => status_valid2,
      status_valid3 => status_valid3, -- Whether input from status reg is valid
      pipe1_busy => pipe1_busy, 
      pipe2_busy => pipe2_busy,  -- pipelines are busy so cant give instr
      
      --outputss
      pipe1_issue => pipe1_issue, 
      pipe2_issue => pipe2_issue,  -- issue words to integer pipelines (2)
      pipe1_issue_valid => pipe1_issue_valid, 
      pipe2_issue_valid => pipe2_issue_valid, -- are issue words valid
      RS_stall => RS_stall  
      );
 
 
  ---------------------------------------------------------------------------
  -- This procedure reads the file input_vectors.txt which is located in the
  -- simulation project area.
  -- It will read the data in and send it to the ripple-adder component
  -- to perform the operations.  The result is written to the
  -- output_results.txt file, located in the same directory.
  ---------------------------------------------------------------------------
  process
    variable v_ILINE     : line;
    variable v_OLINE     : line;
    variable v_SPACE     : character;
    variable v_RS_flush: std_logic; -- Clock and flush signal
    variable v_input_word1: std_logic_vector(0 to input_len - 1); 
    variable v_input_word2: std_logic_vector(0 to input_len - 1); -- Input from decoder 
    variable v_valid_in1:std_logic; 
    variable v_valid_in2: std_logic; -- Whether input from decoder is valid/should be entered in the RS table
    variable v_rrf_reg1:  std_logic_vector(0 to input_RRF - 1);  
    variable v_rrf_reg2:  std_logic_vector(0 to input_RRF - 1);  
    variable v_rrf_reg3:  std_logic_vector(0 to input_RRF - 1); -- Input of updated register from RRF. Contains address + content
    variable v_rrf_valid1:  std_logic;
    variable v_rrf_valid2:  std_logic;
    variable v_rrf_valid3:  std_logic; -- Whether input from PRF is valid
    variable v_status_reg1: std_logic_vector(0 to len_RRF + 1);
    variable v_status_reg2:  std_logic_vector(0 to len_RRF + 1);
    variable v_status_reg3:  std_logic_vector(0 to len_RRF + 1); -- Input of updated status register. Contains address + content
    variable v_status_valid1: std_logic;
    variable v_status_valid2:  std_logic;
    variable v_status_valid3:  std_logic; -- Whether input from status reg is valid
    variable v_pipe1_busy: std_logic;
    variable v_pipe2_busy:  std_logic;
  begin
 
    file_open(file_VECTORS, "input_vectors.txt",  read_mode);
    file_open(file_RESULTS, "output_results.txt", write_mode);
 
    while not endfile(file_VECTORS) loop
      readline(file_VECTORS, v_ILINE);
      read(v_ILINE, v_RS_flush); -- Clock and flush signal
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_input_word1); 
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_input_word2); -- Input from decoder 
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_valid_in1); 
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_valid_in2); -- Whether input from decoder is valid/should be entered in the RS table
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_rrf_reg1);  
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_rrf_reg2);  
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_rrf_reg3); -- Input of updated register from RRF. Contains address + content
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_rrf_valid1);
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_rrf_valid2);
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_rrf_valid3); -- Whether input from PRF is valid
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_status_reg1);
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_status_reg2);
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_status_reg3); -- Input of updated status register. Contains address + content
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_status_valid1);
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_status_valid2);
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_status_valid3); -- Whether input from status reg is valid
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_pipe1_busy);
      read(v_ILINE, v_SPACE); -- read in the space character
      read(v_ILINE, v_pipe2_busy);
 
      -- Pass the variable to a signal to allow the ripple-carry to use it
      RS_flush <= v_RS_flush; -- Clock and flush signal
      input_word1 <= v_input_word1;
      input_word2<= v_input_word2;-- Input from decoder 
      valid_in1 <=v_valid_in1;
      valid_in2 <=v_valid_in2; -- Whether input from decoder is valid/should be entered in the RS table
      rrf_reg1 <=v_rrf_reg1;  
      rrf_reg2 <=v_rrf_reg2;  
      rrf_reg3 <=v_rrf_reg3; -- Input of updated register from RRF. Contains address + content
      rrf_valid1 <= v_rrf_valid1; 
      rrf_valid2 <= v_rrf_valid2; 
      rrf_valid3 <= v_rrf_valid3;  -- Whether input from PRF is valid
      status_reg1 <= v_status_reg1;
      status_reg2 <= v_status_reg2;
      status_reg3 <= v_status_reg3; -- Input of updated status register. Contains address + content
      status_valid1 <= v_status_valid1;
      status_valid2 <= v_status_valid2;
      status_valid3 <= v_status_valid3; -- Whether input from status reg is valid
      pipe1_busy <= v_pipe1_busy; 
      pipe2_busy <= v_pipe2_busy;

      clk <= not(clk); --clok ticks
      wait for 5 ns;
      clk <= not(clk);
      wait for 5 ns;
 
      write(v_OLINE, pipe1_issue, right, len_out  + 1);
      write(v_OLINE, pipe2_issue, right, len_out  + 1);
      write(v_OLINE, pipe1_issue_valid, right, 2);
      write(v_OLINE, pipe2_issue_valid, right, 2);
      write(v_OLINE, RS_stall, right, 2);
      writeline(file_RESULTS, v_OLINE);
    end loop;
 
    file_close(file_VECTORS);
    file_close(file_RESULTS);
     
    wait;
  end process;
 
end behave;