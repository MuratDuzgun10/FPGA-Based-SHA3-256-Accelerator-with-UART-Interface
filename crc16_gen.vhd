library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity crc16_gen is
	Port(
		clk : in std_logic;
		rst : in std_logic;
		
		data_in : in std_logic_vector(7 downto 0);
		data_valid : in std_logic;
		
		crc_reset : in std_logic;
		
		crc_out : out std_logic_vector(15 downto 0);
		crc_ready : out std_logic
	);
end crc16_gen;

architecture rtl of crc16_gen is
	signal crc_reg : std_logic_vector(15 downto 0) := (others=>'0');
	signal crc_next : std_logic_vector(15 downto 0);
	signal crc_ready_int : std_logic;
	
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
			crc_ready_int <= '0';
		
		elsif rising_edge(clk) then
			if crc_reset = '1' then
				crc_reg <= (others=>'0');
				crc_ready_int <= '0';
			elsif data_valid = '1' then
				crc_reg <= crc_next;
				crc_ready_int <= '1';
			end if;
		end if;
	end process;
	
	crc_out <= crc_reg;
	crc_ready <= crc_ready_int;
	
end rtl;