library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_crypto_top is
  generic (
    CLK_FREQ : integer := 100_000_000;
    BAUD_RATE : integer := 115_200
  );
  port (
    clk : in std_logic;
    rst : in std_logic;
    rxd : in std_logic;
    txd : out std_logic;
    status_led : out std_logic_vector(3 downto 0);
    crypto_done_irq : out std_logic;
    tx_done_irq : out std_logic
  );
end entity uart_crypto_top;

architecture rtl of uart_crypto_top is

  component uart_rx_phy is
    generic (CLK_FREQ : integer; BAUD_RATE : integer);
    port (clk, rst : in std_logic; rxd : in std_logic;
          data_out : out std_logic_vector(7 downto 0);
          data_valid : out std_logic);
  end component;

  component rx_deserializer is
    port (clk, rst : in std_logic;
          phy_data : in std_logic_vector(7 downto 0);
          phy_valid : in std_logic;
          byte_data : out std_logic_vector(7 downto 0);
          byte_valid : out std_logic);
  end component;

  component pct_parser_fsm is
    generic (MAX_pct_LEN : integer);
    port (clk, rst : in std_logic;
          byte_in : in std_logic_vector(7 downto 0);
          byte_valid : in std_logic;
          pct_cmd : out std_logic_vector(7 downto 0);
          pct_len : out integer;
          pct_payload : out std_logic_vector(2047 downto 0);
          pct_payload_len : out integer;
          pct_crc_expected : out std_logic_vector(15 downto 0);
          pct_complete : out std_logic;
          pct_error : out std_logic);
  end component;

  component crc16_checker is
    port (clk, rst : in std_logic;
          data_in : in std_logic_vector(7 downto 0);
          data_valid : in std_logic;
          crc_expected : in std_logic_vector(15 downto 0);
          check_en : in std_logic;
          crc_match : out std_logic;
          crc_error : out std_logic);
  end component;

  component rx_fifo_bram is
    generic (DEPTH : integer; WIDTH : integer);
    port (clk, rst : in std_logic;
          wr_en : in std_logic;
          wr_data : in std_logic_vector;
          wr_addr : in std_logic_vector(7 downto 0);
          fifo_full : out std_logic;
          rd_en : in std_logic;
          rd_data : out std_logic_vector;
          rd_addr : in std_logic_vector(7 downto 0);
          fifo_empty : out std_logic;
          wr_ptr : out std_logic_vector(7 downto 0);
          rd_ptr : out std_logic_vector(7 downto 0));
  end component;

  component crypto_core is
    generic (BLOCK_SIZE : integer);
    port (clk, rst : in std_logic;
          cmd : in std_logic_vector(7 downto 0);
          data_in : in std_logic_vector(255 downto 0);
          data_in_valid : in std_logic;
          data_len : in integer;
          result : out std_logic_vector(511 downto 0);
          result_valid : out std_logic;
          busy : out std_logic);
  end component;

  component tx_pct_builder is
    port (clk, rst : in std_logic;
          result_in : in std_logic_vector(511 downto 0);
          result_valid : in std_logic;
          result_len : in integer;
          crc_from_gen : in std_logic_vector(15 downto 0);
          frame_out : out std_logic_vector(7 downto 0);
          frame_valid : out std_logic;
          frame_last : out std_logic;
          crc_data_out : out std_logic_vector(7 downto 0);
          crc_data_valid : out std_logic;
          crc_reset : out std_logic;
          busy : out std_logic);
  end component;

  component crc16_gen is
    port (clk, rst : in std_logic;
          data_in : in std_logic_vector(7 downto 0);
          data_valid : in std_logic;
          crc_reset : in std_logic;
          crc_out : out std_logic_vector(15 downto 0);
          crc_ready : out std_logic);
  end component;

  component uart_tx_ctrl is
    generic (CLK_FREQ : integer; BAUD_RATE : integer);
    port (clk, rst : in std_logic;
          data_in : in std_logic_vector(7 downto 0);
          data_valid : in std_logic;
          txd : out std_logic;
          tx_ready : out std_logic;
          tx_done : out std_logic;
          tx_irq : out std_logic);
  end component;

  signal phy_data : std_logic_vector(7 downto 0);
  signal phy_valid : std_logic;
  signal deser_data : std_logic_vector(7 downto 0);
  signal deser_valid : std_logic;

  signal pct_cmd : std_logic_vector(7 downto 0);
  signal pct_len : integer;
  signal pct_payload : std_logic_vector(2047 downto 0);
  signal pct_complete : std_logic;
  signal crc_expected : std_logic_vector(15 downto 0);

  signal fifo_full : std_logic;
  signal fifo_wr_en : std_logic;
  signal fifo_wr_data : std_logic_vector(7 downto 0);

  signal crypto_busy : std_logic;
  signal crypto_result : std_logic_vector(511 downto 0);
  signal crypto_result_valid : std_logic;

  signal tx_frame : std_logic_vector(7 downto 0);
  signal tx_frame_valid : std_logic;
  signal tx_ready : std_logic;
  signal tx_done_sig : std_logic;

  signal crc_data_out_sig : std_logic_vector(7 downto 0);
  signal crc_data_valid_sig : std_logic;
  signal crc_reset_sig : std_logic;
  signal crc_result : std_logic_vector(15 downto 0);
  signal crc_ready_sig : std_logic;
  
  signal check_en : std_logic;
  signal crc_match : std_logic;
  signal crc_error : std_logic; 

begin

  uart_rx_phy_inst : uart_rx_phy
    generic map (CLK_FREQ => CLK_FREQ, BAUD_RATE => BAUD_RATE)
    port map (clk => clk, rst => rst, rxd => rxd,
              data_out => phy_data, data_valid => phy_valid);

  rx_deser_inst : rx_deserializer
    port map (clk => clk, rst => rst,
              phy_data => phy_data, phy_valid => phy_valid,
              byte_data => deser_data, byte_valid => deser_valid);

  pct_parser_inst : pct_parser_fsm
    generic map (MAX_pct_LEN => 256)
    port map (clk => clk, rst => rst,
              byte_in => deser_data, byte_valid => deser_valid,
              pct_cmd => pct_cmd, pct_len => pct_len,
              pct_payload => pct_payload,
              pct_crc_expected => crc_expected,
              pct_complete => pct_complete);
			  
	crc16_checker_inst: crc16_checker 
    port map (clk => clk, rst => rst,
          data_in => deser_data,
          data_valid => deser_valid,
          crc_expected => crc_expected,
          check_en => pct_complete,
          crc_match => crc_match,
          crc_error => crc_error);
  end component;
	

  rx_fifo_inst : rx_fifo_bram
    generic map (DEPTH => 256, WIDTH => 8)
    port map (clk => clk, rst => rst,
              wr_en => fifo_wr_en, wr_data => fifo_wr_data, wr_addr => (others => '0'),
              fifo_full => fifo_full);

  crypto_inst : crypto_core
    generic map (BLOCK_SIZE => 1024)
    port map (clk => clk, rst => rst,
              cmd => pct_cmd, data_in => pct_payload(255 downto 0),
              data_in_valid => pct_complete,
              data_len => pct_len,
              result => crypto_result, result_valid => crypto_result_valid,
              busy => crypto_busy);

  crc16_gen_inst : crc16_gen
    port map (clk => clk, rst => rst,
              data_in => crc_data_out_sig,
              data_valid => crc_data_valid_sig,
              crc_reset => crc_reset_sig,
              crc_out => crc_result,
              crc_ready => crc_ready_sig);

  tx_builder_inst : tx_pct_builder
    port map (clk => clk, rst => rst,
              result_in => crypto_result, result_valid => crypto_result_valid,
              result_len => 32,
              crc_from_gen => crc_result,
              frame_out => tx_frame, frame_valid => tx_frame_valid,
              crc_data_out => crc_data_out_sig,
              crc_data_valid => crc_data_valid_sig,
              crc_reset => crc_reset_sig);

  uart_tx_inst : uart_tx_ctrl
    generic map (CLK_FREQ => CLK_FREQ, BAUD_RATE => BAUD_RATE)
    port map (clk => clk, rst => rst,
              data_in => tx_frame, data_valid => tx_frame_valid,
              txd => txd, tx_ready => tx_ready, tx_done => tx_done_sig,
              tx_irq => tx_done_irq);

  fifo_wr_en <= pct_complete and not fifo_full;
  fifo_wr_data <= pct_payload(7 downto 0);
  crypto_done_irq <= crypto_result_valid;

  status_led <= crypto_busy & pct_complete & fifo_full & tx_ready;

end architecture rtl;