library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity uart_tx_ctrl is
	generic(
		CLK_FREQ : integer := 100_000_000; --100MHz
		BAUD_RATE : integer := 115_200
	);
	Port(
		clk : in std_logic;
		rst : in std_logic;
		
		data_in : in std_logic_vector(7 downto 0);
		data_valid : in std_logic;
		
		txd : out std_logic;
		tx_ready : out std_logic;
		tx_done : out std_logic;
		
		tx_irq : out std_logic
	);
end uart_tx_ctrl;

architecture rtl of uart_tx_crtl is
	constant BAUD_DIVISOR : integer := CLK_FREQ / BAUD_RATE;
	type tx_state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
	signal tx_state : tx_state_type := IDLE;
	
	signal baud_cnt : integer range 0 to BAUD_DIVISOR - 1 := 0;
	signal bit_cnt : integer range 0 to 7 := 0;
	signal shift_reg : std_logic_vector(7 downto 0) := (others=>'0');
	signal txd_int : std_logic := '1';
	
	signal tx_done_int : std_logic := '0';
	signal tx_ready_int : std_logic := '1';
	
begin
	process(clk, rst)
	begin
		if rst = '1' then
			tx_state <= IDLE;
			baud_cnt <= 0;
			bit_cnt <= 0;
			shift_reg <= (others=>'0');
			txd_int <= '1';
			tx_done_int <= '0';
			tx_ready_int <= '1';
		
		elsif rising_edge(clk) then
			tx_done_int <= '0';
			baud_cnt <= baud_cnt + 1;
			
			if baud_cnt = BAUD_DIVISOR - 1 then
				baud_cnt <= 0;
				
				case tx_state is
					when IDLE =>
						txd_int <= '1';
						tx_ready_int <= '1';
						if data_valid = '1' then
							shift_reg <= data_in;
							tx_state <= START_BIT;
							tx_ready_int <= '0';
						end if;
					
					when START_BIT =>
						txd_int <= '0';
						tx_state <= DATA_BITS;
						bit_cnt <= 0;
					
					when DATA_BITS =>
						txd_int <= shift_reg(0);
						shift_reg <= '0' & shift_reg(7 downto 1);
						if bit_cnt = 7 then
							tx_state <= STOP_BIT;
						end if;
					
					when STOP_BIT =>
						txd_int <= '1';
						tx_done_int <= '1';
						tx_state <= IDLE;
				end case;
			end if;
		end if;
	end process;
	
	txd <= txd_int;
	tx_ready <= tx_ready_int;
	tx_done <= tx_done_int;
	tx_irq <= tx_done_int;
	
end rtl;