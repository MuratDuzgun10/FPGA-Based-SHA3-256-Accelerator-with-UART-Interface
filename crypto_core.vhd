library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity crypto_core is
	generic(
		BLOCK_SIZE : integer := 1024 
	);
	Port(
		clk : in std_logic;
		rst : in std_logic;
		
		cmd : in std_logic_vector(7 downto 0); --0x01=SHA3
		data_in : in std_logic_vector(255 downto 0);
		data_in_valid : in std_logic;
		data_len : in integer range 0 to 32;
		
		result : out std_logic_vector(511 downto 0);
		result_valid : out std_logic;
		busy : out std_logic
	);
end crypto_core;

architecture rtl of crypto_core is
	--Keccak state: 8x32 bit 
	type state_array is array(0 to 7) of std_logic_vector(31 downto 0);
	
	type sha3_fsm is (IDLE, PERMUTE, SQUEEZE, DONE);
	signal sha3_state : sha3_fsm := IDLE;
	
	signal keccak_state : state_array := (others=>(others=>'0'));
	signal keccak_state_next : state_array;
	
	signal round_cnt : integer rango 0 to 24 := 0;
	signal data_reg : std_logic_vector(255 downto 0) := (others=>'0');
	signal hash_reg : std_logic_vector(255 downto 0) := (others=>'0');
	signal result_reg : std_logic_vector(511 downto 0) := (others=>'0');
	
	signal hash_valid_int : std_logic := '0';
	signal busy_int : std_logic := '0';
	
begin
	--Keccak permütasyonu
	process(keccak_state)
		variable temp : std_logic_vector(31 downto 0);
		variable i : integer;
	begin
		for i in 0 t0 7 loop
			temp := keccak_state(i);
			
			keccak_state_next(i) <= keccak_state((i + 1) mod 8) xor (keccak_state(i)(30 downto 0) & keccak_state(i)(31)) xor keccak_state((i + 7) mod 8);
		end loop;
	end process;
	
	--SHA3-256 FSM
	
	process(clk, rst)
		variable i : integer;
	begin
		if rst = '1' then
			sha3_state <= IDLE;
			keccak_state <= (others => (others => '0'));
			round_cnt <= 0;
		    hash_reg <= (others => '0');
		    hash_valid_int <= '0';
			busy_int <= '0';
			data_reg <= (others => '0');
			result_reg <= (others => '0');
		
		elsif rising_edge(clk) then
			hash_valid_int <= '0';
			
			case sha3_state is
				when IDLE =>
					busy_int <= '0';
					if data_in_valid = '1' and cmd = x"01" then --SHA3-256 başlatma komutlu
						for i in 0 to 7 loop
							keccak_state(i) <= keccak_state(i) xor data_in(i*32+31 downto i*32);
						end loop;
						data_reg <= data_in;
						round_cnt <= 0;
						sha3_state <= PERMUTE;
						busy_int <= '1';
					end if;
				
				when PERMUTE=>
					if round_cnt < 24 then
						keccak_state <= keccak_state_next;
						round_cnt <= round_cnt + 1;
					
					else 
						sha3_state <= SQUEEZE;
					end if;
				
				when SQUEEZE=>
				  hash_reg(255 downto 224) <= keccak_state(0);
				  hash_reg(223 downto 192) <= keccak_state(1);
				  hash_reg(191 downto 160) <= keccak_state(2);
				  hash_reg(159 downto 128) <= keccak_state(3);
				  hash_reg(127 downto 96)  <= keccak_state(4);
				  hash_reg(95 downto 64)   <= keccak_state(5);
				  hash_reg(63 downto 32)   <= keccak_state(6);
				  hash_reg(31 downto 0)    <= keccak_state(7);
                  sha3_state <= DONE;
				  
				when DONE =>
					result_reg(255 downto 0) <= hash_reg;
					result_reg(511 downto 256) <= (others=>'0');
					hash_valid_int <= '1';
					busy_int <= '0';
					sha3_state <= IDLE;
			end case;
		end if;
	end process;
	
	result <= result_reg;
	result_valid <= hash_valid_int;
	busy <= busy_int;
end rtl;