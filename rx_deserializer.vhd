library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity rx_deserializer is
	Port(
		clk : in std_logic;
		rst : in std_logic;
		
		phys_data : in std_logic_vector(7 downto 0);
		phys_valid : in std_logic;
		
		byte_data : out std_logic_vector(7 downto 0);
		byte_valid : out std_logic
	);
end rx_deserializer;

architecture rtl of rx_deserializer is
	signal phys_valid_r : std_logic := '0';
	signal phys_valid_r2 : std_logic := '0';
	signal phys_valid_edge : std_logic := '0';
	
begin
	process(clk, rst)
	begin
		if rst = '1' then
			phys_valid_r <= '0';
			phys_valid_r2 <= '0';
			
		elsif rising_edge(clk) then
			phys_valid_r <= phys_valid;
			phys_valid_r2 <= phys_valid_r;
		end if;
	end process;
	
	phys_valid_edge <= phys_valid_r and not phys_valid_r2;
	
	byte_data <= phys_data;
	byte_valid <= phys_valid_edge;
end rtl;