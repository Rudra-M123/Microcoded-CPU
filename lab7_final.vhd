library ieee; use ieee.std_logic_1164.all;
library lpm; use lpm.lpm_components.all;

entity lab7_final is
	port(clk, clk_pause: in std_logic;
		lcd_rs, lcd_en, lcd_on: out std_logic;
		lcd_data: inout std_logic_vector(7 downto 0);
		lcd_rw: buffer std_logic;
		uops: out std_logic_vector(0 to 20);
		addr_out: out std_logic_vector(8 downto 0);
		zSeg1, irSeg1, irSeg2, pcSeg1, pcSeg2, spSeg1, spSeg2: out std_logic_vector(0 to 6)); -- seven segment displays
end lab7_final;

architecture structural of lab7_final is
	-- add component declaration of lab7_useq
	component lab7_useq is
		generic (uROM_width: integer;
			uROM_file: string);
		port (opcode: in std_logic_vector(3 downto 0);
			uop: out std_logic_vector(1 to (uROM_width-9));
			debug_map_addr: out std_logic_vector(8 downto 0); -- for debugging
			enable, clear: in std_logic;
			clock: in std_logic);
	end component;

	-- add component declaration for seven-segment decoder
	component seven_decoder is
		port(data: in std_logic_vector(3 downto 0);
			segments: out std_logic_vector(0 to 6));
	end component;
	
	component lcd_controller is
		port(clk, reset: in std_logic;
			mar_data, mdr_data, r0_data, r1_data: in std_logic_vector(7 downto 0);
			lcd_rs, lcd_en, lcd_on: out std_logic;
			lcd_rw: buffer std_logic;
			lcd_data: inout std_logic_vector(7 downto 0));
	end component;

	-- signals section --------------------------------------------------------------------------------------------------
	-- clock signal
	signal pb_clk: std_logic;
	
	-- microsequencer signals
	signal enable, useq_enable: std_logic;
	signal uop_out: std_logic_vector(0 to 20);

	-- control signals
	signal pc_inc, pc_cnt, pc_load, pc_clear, sp_inc, sp_cnt, sp_load, mar_load, ram_wr, mdr_load, ir_load, reg_enable, z_load : std_logic;

	-- intermediary signals
	signal pc_out, mar_in, mar_out, sp_out, mem_out, mdr_in, mdr_out, result_in, reg_out, reg_bar_out, reg0_out, reg1_out, add8_sum, ir_out: std_logic_vector(7 downto 0);
	signal v: std_logic;
	signal z_in, z_out : std_logic_vector(0 downto 0);

	-- mux data signals
	signal mar_in_data, mdr_in_data : std_logic_2D(2 downto 0, 7 downto 0);
	signal reg_in_data : std_logic_2D(3 downto 0, 7 downto 0);
	signal reg_out_data, reg_bar_out_data : std_logic_2D(1 downto 0, 7 downto 0);
	signal z_in_data : std_logic_2D(1 downto 0, 0 downto 0);

	-- mux select signals
	signal mar_in_sel, mdr_in_sel, reg_in_sel : std_logic_vector(1 downto 0);
	signal reg_sel, z_sel : std_logic_vector(0 downto 0);
begin
	-- 8-to-1 OR gate, ADDER setup, other assignments -------------------------------------------------------------------
	v <= reg_out(7) or reg_out(6) or reg_out(5) or reg_out(4) or reg_out(3) or reg_out(2) or reg_out(1) or reg_out(0);
	reg_sel <= ir_out(0 downto 0);
	
	adder8: lpm_add_sub
		generic map(lpm_width => 8)
		port map(dataa => reg_out, datab => reg_bar_out, result => add8_sum);

	-- multiplexer section ----------------------------------------------------------------------------------------------
	-- setup all the mux
	mux_setup: for i in 0 to 7 generate
		-- setup the data for mar_in
		mar_in_data(0,i) <= sp_out(i);
		mar_in_data(1,i) <= pc_out(i);
		mar_in_data(2,i) <= mdr_out(i);

		-- setup the data for mdr_in
		mdr_in_data(0,i) <= reg_out(i);
		mdr_in_data(1,i) <= pc_out(i);
		mdr_in_data(2,i) <= mem_out(i);
		
		-- setup the data for reg_in
		reg_in_data(0,i) <= reg_out(i) xor reg_bar_out(i);
		reg_in_data(1,i) <= add8_sum(i);
		reg_in_data(2,i) <= reg_bar_out(i);
		reg_in_data(3,i) <= mdr_out(i);
		
		-- setup the data for reg_out
		reg_out_data(0,i) <= reg0_out(i);
		reg_out_data(1,i) <= reg1_out(i);
		
		-- setup the data for reg_bar_out
		reg_bar_out_data(0,i) <= reg1_out(i);
		reg_bar_out_data(1,i) <= reg0_out(i);
	end generate;

	-- setup the data for z_in
	z_in_data(0,0) <= v;
	z_in_data(1,0) <= not v;

	mar_in_mux: lpm_mux
		generic map(lpm_width => 8, lpm_size => 3, lpm_widths => 2)
		port map(result => mar_in, data => mar_in_data, sel => mar_in_sel);

	mdr_in_mux: lpm_mux
		generic map(lpm_width => 8, lpm_size => 3, lpm_widths => 2)
		port map(result => mdr_in, data => mdr_in_data, sel => mdr_in_sel);

	reg_in_mux: lpm_mux
		generic map(lpm_width => 8, lpm_size => 4, lpm_widths => 2)
		port map(result => result_in, data => reg_in_data, sel => reg_in_sel);

	reg_out_mux: lpm_mux
		generic map(lpm_width => 8, lpm_size => 2, lpm_widths => 1)
		port map(result => reg_out, data => reg_out_data, sel => reg_sel);

	reg_bar_out_mux: lpm_mux
		generic map(lpm_width => 8, lpm_size => 2, lpm_widths => 1)
		port map(result => reg_bar_out, data => reg_bar_out_data, sel => reg_sel);

	z_in_mux: lpm_mux
		generic map(lpm_width => 1, lpm_size => 2, lpm_widths => 1)
		port map(result => z_in, data => z_in_data, sel => z_sel);

	-- register and ram section -----------------------------------------------------------------------------------------
	-- port map statements for all the register and the ram
	mar: lpm_ff
		generic map(lpm_width => 8)
		port map(data => mar_in, q => mar_out, clock => pb_clk, enable => mar_load);
	
	ram: lpm_ram_dq
		generic map(lpm_widthad => 8, lpm_width => 8, lpm_file => "./lab7_ram.mif")
		port map(address => mar_out, q => mem_out, inclock => pb_clk, outclock => pb_clk, we => ram_wr, data => mdr_out);

	mdr: lpm_ff
		generic map(lpm_width => 8)
		port map(data => mdr_in, q => mdr_out, clock => pb_clk, enable => mdr_load);
	
	ir: lpm_ff
		generic map(lpm_width => 8)
		port map(data => mdr_out, q => ir_out, clock => pb_clk, enable => ir_load);
	
	pc: lpm_counter
		generic map(lpm_width => 8)
		port map(data => mdr_out, sclr => pc_clear, cnt_en => pc_cnt, updown => pc_inc, sload => pc_load, clock => pb_clk, q => pc_out);

	sp: lpm_counter
		generic map(lpm_width => 8)
		port map(data => mdr_out, cnt_en => sp_cnt, sload => sp_load, updown => sp_inc, clock => pb_clk, q => sp_out);	
	
	r0: lpm_ff
		generic map(lpm_width => 8)
		port map(data => result_in, q => reg0_out, clock => pb_clk, enable => not reg_sel(0) and reg_enable);
	
	r1: lpm_ff
		generic map(lpm_width => 8)
		port map(data => result_in, q => reg1_out, clock => pb_clk, enable => reg_sel(0) and reg_enable);
	
	z: lpm_ff
		generic map(lpm_width => 1)
		port map(data => z_in, q => z_out, clock => pb_clk, enable => z_load);

	-- control signals section ------------------------------------------------------------------------------------------
	simulated_pb: lpm_counter
		generic map(lpm_width => 25)
		port map(clock => clk, cout => pb_clk);
	
	-- delay made using lpm_counter
	delay: lpm_counter generic map(lpm_width=>2) port map(clock=> not pb_clk, cout=> enable, cnt_en=> not clk_pause);
	useq_enable <= enable and not pc_clear;

	-- port map statement for microsequencer
	useq0: lab7_useq
		generic map(uROM_width => 30, uROM_file => "./lab7_urom_final.mif")
		port map(opcode => ir_out(7 downto 4), uop => uop_out, clear => '0', enable => useq_enable, clock => pb_clk, debug_map_addr => addr_out);
	
	-- declare control signals
	pc_inc <= uop_out(0) and useq_enable;
	pc_cnt <= uop_out(1) and useq_enable;
	pc_load <= uop_out(2) and useq_enable and (not uop_out(20) or z_out(0)); -- unconditional and conditional jump operations
	pc_clear <= uop_out(3) and enable;-- and useq_enable;
	sp_inc <= uop_out(4) and useq_enable;
	sp_cnt <= uop_out(5) and useq_enable;
	sp_load <= uop_out(6) and useq_enable;
	mar_in_sel(1) <= uop_out(7) and useq_enable;
	mar_in_sel(0) <= uop_out(8) and useq_enable;
	mar_load <= uop_out(9) and useq_enable;
	ram_wr <= uop_out(10) and useq_enable;
	mdr_in_sel(1) <= uop_out(11) and useq_enable;
	mdr_in_sel(0) <= uop_out(12) and useq_enable;
	mdr_load <= uop_out(13) and useq_enable;
	ir_load <= uop_out(14) and useq_enable;
	reg_in_sel(1) <= uop_out(15) and useq_enable;
	reg_in_sel(0) <= uop_out(16) and useq_enable;
	reg_enable <= uop_out(17) and useq_enable;
	z_sel(0) <= uop_out(18) and useq_enable;
	z_load <= uop_out(19) and useq_enable;
	
	l: for i in uop_out'range generate
		uops(i) <= uop_out(i) and useq_enable;
	end generate;
	
	-- outputs section --------------------------------------------------------------------------------------------------
	-- z value in seven-segment notation
	z_1: seven_decoder
		port map(data => "000" & z_out, segments => zSeg1); -- concatenation in order to fulfill 4-bit data requirement

	-- ir value in seven-segment notation
	ir_2: seven_decoder
		port map(data => ir_out(7 downto 4), segments => irSeg2);
	ir_1: seven_decoder
		port map(data => ir_out(3 downto 0), segments => irSeg1);
		
	-- pc value in seven-segment notation
	pc_2: seven_decoder
		port map(data => pc_out(7 downto 4), segments => pcSeg2);
	pc_1: seven_decoder
		port map(data => pc_out(3 downto 0), segments => pcSeg1);
		
	-- sp value in seven-segment notation
	sp_2: seven_decoder
		port map(data => sp_out(7 downto 4), segments => spSeg2);
	sp_1: seven_decoder
		port map(data => sp_out(3 downto 0), segments => spSeg1);
		
	-- mar, mdr, r0, and r1 values sent and displayed on lcd screen
	lcd_1: lcd_controller
		port map(clk => clk, reset => '1', mar_data => mar_out, mdr_data => mdr_out,
			r0_data => reg0_out, r1_data => reg1_out, lcd_rs => lcd_rs, lcd_en => lcd_en,
			lcd_on => lcd_on, lcd_rw => lcd_rw, lcd_data => lcd_data);
end structural;
