library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

--declare entity
entity lcd_controller is
	port(clk, reset: in std_logic;
		mar_data, mdr_data, r0_data, r1_data: in std_logic_vector(7 downto 0);
		lcd_rs, lcd_en, lcd_on: out std_logic;
		lcd_rw: buffer std_logic;
		lcd_data: inout std_logic_vector(7 downto 0));
end lcd_controller;

architecture behavior of lcd_controller is
    -- signals to output to lcd display
    signal data_bus: std_logic_vector(7 downto 0);
    type lcd_message is array(1 to 32) of std_logic_vector(7 downto 0);

	--default message is "MAR:__ R0:__ ECE"
	--                   "MDR:__ R1:__ 495"
    signal lcd_mesg: lcd_message:= (
		x"4d", x"41", x"52", x"3a", x"5f", x"5f", x"20", x"52", x"30", x"3a", x"5f", x"5f", x"20", x"45", x"43", x"45", -- "MAR:__ R0:__ ECE"
    	x"4d", x"44", x"52", x"3a", x"5f", x"5f", x"20", x"52", x"31", x"3a", x"5f", x"5f", x"20", x"34", x"39", x"35"  -- "MDR:__ R1:__ 495"
	);

    -- states
    type states is (hold, func_set, display_on, mode_set, write_char, next_line, return_home, toggle_e, reset1, reset2, reset3, display_off, display_clear);
    signal state, next_command: states;
	signal trace : std_logic_vector(7 downto 0); 

    -- clock-related signals
    signal clk_count_400hz: std_logic_vector(19 downto 0);
    signal clk_400hz: std_logic;
	 
	 component ascii_decoder is
		port(hex_in: in std_logic_vector(3 downto 0);
			ascii_out: out std_logic_vector(7downto 0));
	 end component;
 
begin
    lcd_on <= '1';
	
	mar_high: ascii_decoder
		port map(hex_in => mar_data(7 downto 4), ascii_out => lcd_mesg(5));
	mar_low: ascii_decoder
		port map(hex_in => mar_data(3 downto 0), ascii_out => lcd_mesg(6));
	
	r0_high: ascii_decoder
		port map(hex_in => r0_data(7 downto 4), ascii_out => lcd_mesg(11));
	r0_low: ascii_decoder
		port map(hex_in => r0_data(3 downto 0), ascii_out => lcd_mesg(12));
		
	mdr_high: ascii_decoder
		port map(hex_in => mdr_data(7 downto 4), ascii_out => lcd_mesg(21));
	mdr_low: ascii_decoder
		port map(hex_in => mdr_data(3 downto 0), ascii_out => lcd_mesg(22));
		
	r1_high: ascii_decoder
		port map(hex_in => r1_data(7 downto 4), ascii_out => lcd_mesg(27));
	r1_low: ascii_decoder
		port map(hex_in => r1_data(3 downto 0), ascii_out => lcd_mesg(28));
		
    -- bidirectional tri-state lcd data bus
    lcd_data <= data_bus when lcd_rw = '0' else "ZZZZZZZZ";
 
    clk400_process: process
    begin 
		-- must slow down clock to 400hz for lcd use
		wait until rising_edge(clk);
		if reset = '0' then
			clk_count_400hz <= x"00000";
			clk_400hz <= '0';
		else
			if clk_count_400hz < x"0f424" then
				clk_count_400hz <= clk_count_400hz + 1;
			else
				clk_count_400hz <= x"00000";
				clk_400hz <= not clk_400hz;
			end if;
		end if;
    end process clk400_process;

    state_machine: process (clk_400hz, reset)
		variable ix: integer range 1 to 32:= 1;
    begin
		if reset = '0' then
            state <= reset1;
            data_bus <= x"38";
            next_command <= reset2;
            lcd_en <= '1';
            lcd_rs <= '0';
            lcd_rw <= '0';

        elsif rising_edge(clk_400hz) then
			case state is
                -- set function to 8-bit transfer and 2 line display with 5x8 font size
                -- see hitachi hd44780 family data sheet for lcd command and timing details
                when reset1 =>
                    lcd_en <= '1';
                    lcd_rs <= '0';
                    lcd_rw <= '0';
                    data_bus <= x"38";
                    state <= toggle_e;
                    next_command <= reset2;

                when reset2 =>
                    lcd_en <= '1';
                    lcd_rs <= '0';
                    lcd_rw <= '0';
                    data_bus <= x"38";
                    state <= toggle_e;
                    next_command <= reset3;
               
                when reset3 =>
                    lcd_en <= '1';
                    lcd_rs <= '0';
                    lcd_rw <= '0';
                    data_bus <= x"38";
                    state <= toggle_e;
                    next_command <= func_set;
               
                -- states above needed for pushbutton reset of lcd display
                when func_set =>
                    lcd_en <= '1';
                    lcd_rs <= '0';
                    lcd_rw <= '0';
                    data_bus <= x"38";
                    state <= toggle_e;
                    next_command <= display_off;

                -- turn off display and turn off cursor
                when display_off =>
                    lcd_en <= '1';
                    lcd_rs <= '0';
                    lcd_rw <= '0';
                    data_bus <= x"08";
                    state <= toggle_e;
                    next_command <= display_clear;
               
                -- turn on display and turn off cursor
                when display_clear =>
                    lcd_en <= '1';
                    lcd_rs <= '0';
                    lcd_rw <= '0';
                    data_bus <= x"01";
                    state <= toggle_e;
                    next_command <= display_on;
               
                -- turn on display and turn off cursor
                when display_on =>
                    lcd_en <= '1';
                    lcd_rs <= '0';
                    lcd_rw <= '0';
                    data_bus <= x"0c";
                    state <= toggle_e;
                    next_command <= mode_set;
               
                -- set write mode to auto increment address and move cursor to the right
                when mode_set =>
                    lcd_en <= '1';
                    lcd_rs <= '0';
                    lcd_rw <= '0';
                    data_bus <= x"06";
                    state <= toggle_e;
                    next_command <= write_char;

                -- write hex character in lcd per ix location
                when write_char =>
					lcd_en <= '1';
                    lcd_rs <= '1';
                    lcd_rw <= '0';
                    --load current index into databus and make the next state
                    data_bus <= lcd_mesg(ix);
                    state <= toggle_e;

                    --logic to increment the index and wrap-around, whilst getting the correct next_command value
					if ix < 32 then
						ix:= ix + 1;
						if ix = 17 then
							next_command <= next_line;
						else
							next_command <= write_char;
						end if;
					else
						ix:= 1;
						next_command <= return_home; 
					end if;

                when next_line =>
					lcd_en <= '1';
					lcd_rs <= '0';
					lcd_rw <= '0';
					data_bus <= x"C0";
					state <= toggle_e;
					next_command <= write_char;				
				
				-- return write address to first character position
                when return_home =>
                    lcd_en <= '1';
                    lcd_rs <= '0';
                    lcd_rw <= '0';
                    data_bus <= x"80";
                    state <= toggle_e;
                    next_command <= write_char;

                -- the next two states occur at the end of each command to the lcd
                -- toggle e line - falling edge loads inst/data to lcd controller
                when toggle_e =>
                    lcd_en <= '0';
                    state <= hold;

                -- hold lcd inst/data valid after falling edge of e line
                when hold =>
                    state <= next_command;
            end case;
        end if;
    end process state_machine;
 end behavior;
