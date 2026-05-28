library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity pct_parser_fsm is
	generic(
		MAX_PCT_LEN : integer := 256
	);
	Port(
		clk : in std_logic;
		rst : in std_logic;
		
		byte_in : in std_logic_vector(7 downto 0);
		byte_valid : in std_logic;
		
		pct_cmd : out std_logic_vector(7 downto 0);
		pct_len : out integer range 0 to MAX_PCT_LEN;
		pct_payload : out std_logic_vector(2047 downto 0);
		pct_payload_len : out integer range 0 to 256;
		pct_crc_expected : out std_logic_vector(15 downto 0);
		pct_complete : out std_logic;
		pct_error : out std_logic
	);
end pct_parser_fsm;

architecture rtl of pct_parser_fsm is
	type parser_state_type is (IDLE, HEADER, LENGTH, PAYLOAD, CRC_H, CRC_L, DONE);
	signal parser_state : parser_state_type := IDLE;
	
	signal byte_cnt : ineteger range 0 to 256;
	signal len_reg : integer range 0 to 256 := 0;
	signal cmd_reg : std_logic_vector(7 downto 0) := (others=>'0');
	signal payload_reg : std_logic_vector(2047 downto 0) := others=>'0');
	signal crc_h_reg : std_logic_vector(7 downto 0) := (others=>'0');
	signal crc_l_reg : std_logic_vector(7 downto 0) := (others=>'0');
	
	signal pct_complete_int : std_logic:= '0';
	signal pct_error_int : std_logic := '0';
	
begin
	process(clk, rst)
	begin
		if rst = '1' then
			parser_state <= IDLE;
			byte_cnt <= 0;
			len_reg <= 0;
			cmd_reg <= (others=>'0');
			payload_reg <= (others=>'0');
			crc_h_reg <= (others=>'0');
			crc_l_reg <= (others=>'0');
			pct_complete_int <= '0';
			pct_error_int <= '0';
		
		elsif rising_edge(clk) then
			pct_complete_int <= '0';
			pct_error_int <= '0';
			
			if byte_valid = '1' then
				case parser_state is
					when IDLE =>
						if byte_in = x"AA" then
							parser_state <= HEADER;
							byte_cnt <= 0;
						end if;
					
					when HEADER=>
						cmd_reg <= byte_in;
						parser_state <= LENGTH;
						
					when LENGTH => 
						len_reg <= to_integer(unsigned(byte_in));
						byte_cnt <= 0;
						if to_integer(unsigned(byte_in)) = 0 then
							parser_state <= CRC_H;
						else
							parser_state <= PAYLOAD;
						end if;
					
					when PAYLOAD =>
						if byte_cnt < 256 then
							payload_reg(byte_cnt*8+7 downto byte*8) <= byte_in;
							byte_cnt <= byte_cnt + 1;
							if byte_cnt + 1 >= len_reg then
								parser_state <= CRC_H;
							end if;
						else
							pct_error_int <= '1';
							parser_state <= IDLE;
						end if;
					
					when CRC_H =>
						crc_h_reg <= byte_in;
						parser_state <= CRC_L;
						
					when CRC_L =>
						crc_l_reg <= byte_in;
						parser_state <= DONE;
					
					when DONE =>
						pct_complete_int <= '1';
						parser_state <= IDLE;
				end case;
			end if;
		end if;
	end process;
	
	pct_cmd <= cmd_reg;
	pct_len <= len_reg;
	pct_payload <= payload_reg;
	pct_payload_len <= len_reg when len_reg <= 256 else 256;
	pct_crc_expected <= crc_h_reg & crc_l_reg;
	pct_complete <= pct_complete_int;
	pct_error <= pct_error_int;
	
end rtl;