library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity tx_pct_builder is
	Port(
		clk : in std_logic;
		rst : in std_logic;
		
		---crypto_core dan gelen sonuçlar
		result_in : in std_logic_vector(511 downto 0);
		result_valid: in std_logic;
		result_len : in integer range 0 to 64;
		
		crc_from_gen : in std_logic_vector(15 downto 0);
		
		frame_out : out std_logic_vector(7 downto 0);
		frame_valid : out std_logic;
		frame_last : out std_logic;
		
		crc_data_out : out std_logic_vector(7 downto 0);
		crc_data_valid : out std_logic;
		crc_reset : out std_logic;
		
		busy : out std_logic
	);
end tx_pct_builder;

architecture rtl of tx_pct_builder is
	type builder_state_type is (IDLE, SYNC, STATUS, LENGTH, PAYLOAD, CRC_WAIT, CRC_H, CRC_L, DONE);
	signal builder_state : builder_state_type := IDLE;
	
	signal result_reg : std_logic_vector(511 downto 0) := (others=>'0');
	signal len_reg : integer rango 0 to 64 := 0;
	signal byte_cnt : integer range 0 to 64 := 0;
	signal crc_val : std_logic_vector(15 downto 0) := (others=>'0');
	
	signal frame_out_int : std_logic_vector(7 downto 0) := (others=>'0');
	signal frame_valid_int : std_logic := '0';
	signal crc_reset_int : std_logic := '0';
	signal crc_data_valid_int : std_logic := '0';
	
begin
	process(clk, rst)
	begin
		if rst = '1' then
			builder_state <= IDLE;
			result_reg <= (others=>'0');
			len_reg <= 0;
			byte_cnt <= 0;
			frame_valid_int <= '0';
			crc_reset_int <= '0';
			crc_data_valid_int <= '0'
			
		elsif rising_edge(clk) then
			frame_valid_int <= '0';
			case builder_state is
				when IDLE=>	
					if result_valid = '1' then
						result_reg <= result_in;
						len_reg <= result_len;
						builder_state <= SYNC;
						byte_cnt <= 0;
						crc_reset_int <= '1';
					end if;
				
				when SYNC=>	
					frame_out_int <= x"AA"
					frame_valid_int <= '1';
					crc_data_out <= x"AA";
					crc_data_valid_int <= '1';
					builder_state <= STATUS;
				
				when STATUS=>
					frame_out_int <= x"00";
					frame_valid_int <= '1';
					crc_data_out <= x"00";
					crc_data_valid_int <= '1';
					builder_state <= LENGTH;
				
				when LENGTH=>
					frame_out_int <= std_logic_vector(to_unsigned(len_reg, 8));
					frame_valid_int <= '1';
					crc_data_out <= std_logic_vector(to_unsigned(len_reg, 8));
					crc_data_valid_int <= '1';
					builder_state <= PAYLOAD;
					byte_cnt <= 0;
					
				when PAYLOAD=>
					if byte_cnt < len_reg then
						frame_out_int <= result_reg(byte_cnt*8+7 downto byte_cnt*8);
						frame_valid_int <= '1';
						crc_data_out <= result_reg(byte_cnt*8+7 downto byte_cnt*8);
						crc_data_valid_int <= '1';
						byte_cnt <= byte_cnt + 1;
					else
						builder_state <= CRC_WAIT;
						byte_cnt <= 0;
					end if;
				
				when CRC_WAIT=>
					builder_state <= CRC_H;
				
				when CRC_H =>
					frame_out_int <= crc_from_gen(15 downto 8);
					frame_valid_int <= '1';
					builder_state <= CRC_L;
				
				when CRC_L =>
					frame_out_int <= crc_from_gen(7 downto 0);
					frame_valid_int <= '1';
					builder_state <= DONE;

				when DONE=>	
					builder_state <= IDLE;
			end case;
		end if;
	end process;
	
	frame_out <= frame_out_int;
	frame_valid <= frame_valid_int;
	frame_last <= '1' when builder_state = DONE  else '0';
	busy <= '1' when builder_state /= IDLE else '0'; --IDLE dışında busy kısmana giriyor
	crc_rest <= crc_reset_int;
	crc_data_valid <= crc_data_valid_int;

end rtl;