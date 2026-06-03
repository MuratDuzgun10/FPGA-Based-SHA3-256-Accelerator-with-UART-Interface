library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity uart_rx_phy is
	generic(
		CLK_FREQ : integer := 100_000_000; ---100MHz
		BAUD_RATE : integer := 115_200 --115200 baudrate
	);
	Port(
		clk : in std_logic;
		rst : in std_logic;
		rxd : in std_logic;
		
		data_out : out std_logic_vector(7 downto 0);
		data_valid : out std_logic
	);
end uart_rx_phy;

architecture rtl of uart_rx_phy is
	constant BAUD_DIVISOR : integer := CLK_FREQ / BAUD_RATE;
	constant SAMPLE_COUNT : integer := 16;
	
	type rx_state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
	signal rx_state : rx_state_type := IDLE;
	
	signal baud_cnt : integer range 0 to BAUD_DIVISOR - 1 := 0;
	signal sample_cnt : integer range 0 to SAMPLE_COUNT - 1 := 0;
	signal bit_cnt : integer range 0 to 7 := 0;
	signal shift_reg : std_logic_vector(7 downto 0) := (others=>'0');
	signal rxd_sync : std_logic_vector(1 downto 0) := "11"; --Metasatability safety
	
begin
	process(clk, rst)
	begin
		if rst = '1' then
			rx_state <= IDLE;
			baud_cnt <= 0;
			sample_cnt <= 0;
			bit_cnt <= 0;
			shift_reg <= (others=>'0');
			data_valid <= '0';
			data_out <= (others=>'0');
		
		elsif rising_edge(clk) then
			rxd_sync <= rxd_sync(0) & rxd;
			data_valid <= '0';
			baud_cnt <= baud_cnt + 1;
			
			if baud_cnt = BAUD_DIVISOR -1 then
				baud_cnt <= 0;
				sample_cnt <= sample_cnt + 1;
				
				if sample_cnt = SAMPLE_COUNT - 1 then
					sample_cnt <= 0;
					case rx_state is
					
						when IDLE =>
							if rxd_sync(1) = '0' then
								rx_state <= START_BIT;
								bit_cnt <= 0;
							end if;
						when START_BIT =>
							if rxd_sync(1) = '0' then
								rx_state <= DATA_BITS;
							else
								rx_state <= IDLE;
							end if;
							
						when DATA_BITS =>
							shift_reg <= rxd_sync(1) & shift_reg(7 downto 1);
							if bit_cnt  = 7 then
								rx_state <= STOP_BIT;
							else
								bit_cnt <= bit_cnt + 1;
							end if;
						
						when STOP_BIT =>
							if rxd_sync(1) = '1' then
								data_out <= shift_reg;
								data_valid <= '1';
							end if;
					end case;
				end if;
			end if;
		end if;
	end process;
end rtl;