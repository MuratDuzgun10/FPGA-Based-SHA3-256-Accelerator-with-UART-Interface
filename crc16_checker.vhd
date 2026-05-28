library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity crc16_checker is
	Port(
		clk : in std_logic;
		rst : in std_logic;
		
		data_in : in std_logic_vector(7 downto 0);
		data_valid : in std_logic;
		crc_expected : in std_logic_vector(15 downto 0);
		check_en : in std_logic;
		
		crc_match : out std_logic;
		crc_error : out std_logic
	);
end crc16_checker;

architecture rtl of crc16_checker is
	signal crc_reg : std_logic_vector(15 downto 0) := (others=>'0');
	signal crc_next : std_logic_vector(15 downto 0);
	signal crc_match_int : std_logic := '0';
	
begin
	process(crc_reg, data_in)
		variable temp : std_logic_vector(15 downto 0);
		variable i : integer;
	begin
		temp := crc_reg;
		for i in 0 to 7 loop
			if (temp(15) xor data_in(i)) = '1' then
				temp := temp(14 downto 0) & '0';
				temp := temp xor x"1021";
			else
				temp := temp(14 downto 0) & '0';
			end if;
		end loop;
		crc_next <= temp;
	end process;
	
	process(clk, rst)
	begin
		if rst = '1' then
			crc_reg <= (others=>'0');
			crc_match_int <= '0';
		elsif rising_edge(clk) then
			if data_valid = '1' then
				crc_reg <= crc_next;
			end if;
			
			if check_en = '1' then
				if crc_reg = crc_expected then
					crc_match_int <= '1';
				else
					crc_match_int <= '0';
				end if;
			end if;
		end if;
	end process;
	
	crc_match <= crc_match_int;
	crc_error <= not crc_match_int;
end rtl;