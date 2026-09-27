library ieee;
use ieee.std_logic_1164.all;

entity hexss is
    port ( 
        din : in  std_logic_vector(3 downto 0);
        ss  : out std_logic_vector(6 downto 0) 
    );
end hexss;

architecture arc_hexss of hexss is
begin
    -- Active-Low logic: '0' is ON, '1' is OFF\
    -- Mapping: a=6, b=5, c=4, d=3, e=2, f=1, g=0
    ss <= "0000001" when din = "0000" else  -- 0
          "1001111" when din = "0001" else  -- 1
          "0010010" when din = "0010" else  -- 2
          "0000110" when din = "0011" else  -- 3
          "1001100" when din = "0100" else  -- 4
          "0100100" when din = "0101" else  -- 5
          "0100000" when din = "0110" else  -- 6
          "0001111" when din = "0111" else  -- 7
          "0000000" when din = "1000" else  -- 8
          "0000100" when din = "1001" else  -- 9
          "1111010" when din = "1010" else  -- A: lowercase 'r' (segments e, g)
          "1100000" when din = "1011" else  -- B: lowercase 'b'
          "1111111" when din = "1101" else  -- D: Blank (all segments OFF)
          "0110000" when din = "1110" else  -- E
          "1111110" when din = "1111" else  -- F: Middle bar (segment g)
          "1111111";                        -- Default: OFF
end arc_hexss;