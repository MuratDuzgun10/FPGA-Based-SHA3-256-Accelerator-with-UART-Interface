library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity rx_fifo_bram is
	generic(
		DEPTH : integer := 256;
		WIDTH : integer := 8
	);
	Port(
		clk : in std_logic;
		rst : in std_logic;
		
		wr_en : in std_logic;
		wr_data : in std_logic_vector(WIDTH-1 downto 0);
		wr_addr : in std_logic_vector(7 downto 0);
		fifo_full : out std_logic;
		
		rd_en : in std_logic;
		rd_data : out std_logic_vector(WIDTH-1 downto 0);
		rd_addr : in std_logic_vector(7 downto 0);
		fifo_empty : out std_logic
		
		wr_ptr : out std_logic_vector(7 downto 0);
		rd_ptr : out std_logic_vector(7 downto 0)
	);
end rx_fifo_bram;

architecture rtl of rx_fifo_bram is
	type ram_type is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
	signal ram : ram_type := (others=>(others=>'0'));
	
	signal wr_ptr_reg : std_logic_vector(7 downto 0) := (others=>'0');
	signal rd_ptr_reg : std_logic_vector(7 downto 0) := (others=>'0');
	signal wr_ptr_next : std_logic_vector(7 downto 0);
	signal rd_ptr_next : std_logic_vector(7 downto 0);
	
	signal fifo_full_int : std_logic := '0';
	signal fifo_empty_int : std_logic := '1';

begin
	wr_ptr_next <= std_logic_vector(unsigned(wr_ptr_reg) + 1);
	rd_ptr_next <= std_logic_vector(unsigned(rd_ptr_reg) + 1);
	
	process(clk, rst)
	begin
		if rst = '1' then
			wr_ptr_reg <= (others=>'0');
			rd_ptr_reg <= (others=>'0');
		
		elsif rising_edge(clk) then
			--Writing
			if wr_en = '1' and fifo_full_int = '0' then
				ram(to_integer(unsigned(wr_addr))) <= wr_data;
				wr_ptr_reg <= wr_ptr_next;
			end if;
			
			--Reading
			if rd_en = '1' and fifo_empty_int = '0' then
				rd_ptr_reg <= rd_ptr_next;
			end if;
		end if;
	end process;
	
	fifo_empty_int <= '1' when wr_ptr_reg = rd_ptr_reg else '0';
	fifo_full_int <= '1' when wr_ptr_next = rd_ptr_reg else '0';
	
	rd_data <= ram(to_integer(unsigned(rd_addr)));
	fifo_full <= fifo_full_int;
	fifo_empty <= fifo_empty_int;
	wr_ptr <= wr_ptr_reg;
	rd_ptr <= rd_ptr_reg;
end rtl;