-------------------------------------------------------------------------------
-- Universal asynchronous receiver transmitter (UART)
-------------------------------------------------------------------------------
-- This module is the top module of the UART and consists of three smaller modules
-- RX: Receiver module
-- TX: Transmitter module
-- CTRL: Control module
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY UART IS

	GENERIC (
		CLOCK_FREQ      : INTEGER := 50_000_000; --frequency of system clock in Hertz
		BAUD_RATE       : INTEGER := 9600; --data link baud rate in bits/second
		OVERSAMPLE_RATE : INTEGER := 8; --oversampling rate to find center of receive bits (in samples per baud period)
		NUM_SEGMENTS    : INTEGER := 7 -- number of individual segments on the 7-segment display
	);
	PORT (
		clock         : IN  STD_LOGIC; --system clock
		reset         : IN  STD_LOGIC; --reset input
		RX            : IN  STD_LOGIC; -- Serial RX line
		RX_byte_out   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Received data byte
		RX_data_ready : OUT STD_LOGIC; -- High for one clock cycle when data is ready
		TX            : OUT STD_LOGIC; -- Serial TX line
		TX_byte_in    : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Data to transmit
		TX_send_enable: IN STD_LOGIC; -- Send enable (high for one clock cycle)
		TX_busy 		  : OUT STD_LOGIC; -- High when transmitter is busy
		
		-- LED SEGMENT OUTPUT VECTORS (ONE FOR EACH SEGMENT; NUMBERED ACCORDINGLY TO DE10-LITE)
		out_segments_digit_0,
		out_segments_digit_1,
		out_segments_digit_2,
		out_segments_digit_3,
		out_segments_digit_4,
		out_segments_digit_5   : OUT STD_LOGIC_VECTOR(NUM_SEGMENTS - 1 DOWNTO 0);

		--BUTTON INPUT AND OUTPUT
		button_0_in            : IN  STD_LOGIC; -- register button input on KEY0
		button_1_in            : IN  STD_LOGIC; --register button input on KEY1
		pulse_button_0_out     : OUT STD_LOGIC; --give a light pulse output (LED) to confirm button press 
		pulse_button_1_out     : OUT STD_LOGIC; --give a light pulse output (LED) to confirm button press 

		--UART LOGIC
		loopback_mode          : IN  STD_LOGIC;
		RX_busy 					  : IN  STD_LOGIC;
		RX_byte_in				  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		LED_out                : OUT STD_LOGIC;
		--baud_rate_out          : OUT INTEGER;
		baud_code              : IN  STD_LOGIC_VECTOR (3 DOWNTO 0)
		);
END UART;

ARCHITECTURE RTL OF UART IS

	SIGNAL RX_out_to_RX_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL TX_out_to_TX_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
	--
BEGIN
	---------------------------------------------------------------------------
	-- RECIEVER MODULE (RX) GENERIC AND PORT MAPPING
	---------------------------------------------------------------------------

	INSTANCE_RX : ENTITY work.rx(RTL)
		GENERIC MAP(
			CLOCK_FREQ      => CLOCK_FREQ,
			BAUD_RATE       => BAUD_RATE,
			OVERSAMPLE_RATE => OVERSAMPLE_RATE
		)
		PORT MAP(--IN:
			clock         => clock,
			reset         => reset,
			RX            => RX,
			--OUT:
			RX_byte_out   => RX_out_to_RX_in,
			RX_data_ready => RX_data_ready
		);
	---------------------------------------------------------------------------
	-- TRANSMITTER MODULE (TX) GENERIC AND PORT MAPPING
	---------------------------------------------------------------------------
	INSTANCE_TX : ENTITY work.tx(RTL)
		GENERIC MAP(
			CLOCK_FREQ => CLOCK_FREQ,
			BAUD_RATE  => BAUD_RATE
		)
		PORT MAP(--IN:
			clock          => clock,
			reset          => reset,
			TX_byte_in     => TX_out_to_TX_in,
			TX_send_enable => TX_send_enable,
			--OUT:
			TX             => TX,
			TX_busy        => TX_busy
		);
	---------------------------------------------------------------------------
	-- CONTROL MODULE (CTRL) GENERIC AND PORT MAPPING
	---------------------------------------------------------------------------
	INSTANCE_CTRL : ENTITY work.ctrl(RTL)
		GENERIC MAP(
			NUM_SEGMENTS => NUM_SEGMENTS
		)
		PORT MAP(--IN:
			clock                => clock,
			reset                => reset,
			button_0_in          => button_0_in,
			button_1_in          => button_1_in,
			RX_byte_in           => RX_out_to_RX_in,
			loopback_mode        => loopback_mode,
			RX_busy				   => RX_busy,
			baud_code            => baud_code,
			--OUT:
			out_segments_digit_0 => out_segments_digit_0,
			out_segments_digit_1 => out_segments_digit_1,
			out_segments_digit_2 => out_segments_digit_2,
			out_segments_digit_3 => out_segments_digit_3,
			out_segments_digit_4 => out_segments_digit_4,
			out_segments_digit_5 => out_segments_digit_5,
			pulse_button_0_out   => pulse_button_0_out,
			pulse_button_1_out   => pulse_button_1_out,
			TX_byte_out 		   => TX_out_to_TX_in
		);
		
		
END RTL;
