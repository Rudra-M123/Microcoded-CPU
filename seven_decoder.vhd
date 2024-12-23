library ieee;
use ieee.std_logic_1164.all;

entity seven_decoder is
	port(data : in std_logic_vector(3 downto 0);
		segments: out std_logic_vector(0 to 6));
end seven_decoder;

architecture behavior of seven_decoder is
begin
	with data select
		segments <=
			"0000001" when x"0",
			"1001111" when x"1",
			"0010010" when x"2",
			"0000110" when x"3",
			"1001100" when x"4",
			"0100100" when x"5",
			"0100000" when x"6",
			"0001111" when x"7",
			"0000000" when x"8",
			"0001100" when x"9",
			"0001000" when x"A",
			"1100000" when x"B",
			"0110001" when x"C",
			"1000010" when x"D",
			"0110000" when x"E",
			"0111000" when x"F",
			"1111111" when others;
end behavior;
