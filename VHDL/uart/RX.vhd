-------------------------------------------------------------------------------
-- RECIEVER MODULE
-------------------------------------------------------------------------------
-- This module is the receiver module of the UART implementation (RX).
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY rx IS
	GENERIC (
		CLOCK_FREQ      : INTEGER;-- := 50_000_000; -- System clock frequency
		BAUD_RATE       : INTEGER;-- := 9600; -- UART baud rate
		OVERSAMPLE_RATE : INTEGER-- := 8 -- Oversampling factor
	);
	PORT (
		clock      	 : IN  STD_LOGIC; -- System clock
		reset      	 : IN  STD_LOGIC; -- Active high reset
		RX         	 : IN  STD_LOGIC; -- Serial RX line
		RX_byte_out  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Received data byte
		RX_data_ready: OUT STD_LOGIC; -- High for one clock cycle when data is ready
		RX_busy		 : OUT STD_LOGIC
	);
END rx;

ARCHITECTURE RTL OF rx IS
	-- Calculate counter value for baud rate generator
	CONSTANT BAUD_COUNT : INTEGER := (CLOCK_FREQ / (BAUD_RATE * OVERSAMPLE_RATE)) - 1;

	-- State machine states
	TYPE state_type IS (IDLE, START, DATA, STOP);
	SIGNAL state : state_type;

	-- Counters
	SIGNAL baud_counter : INTEGER RANGE 0 TO BAUD_COUNT;
	SIGNAL bit_counter : INTEGER RANGE 0 TO 7;
	SIGNAL sample_count : INTEGER RANGE 0 TO (OVERSAMPLE_RATE - 1);

	-- Internal signals
	SIGNAL shift_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
	--SIGNAL RX_byte_out : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Received data byte

BEGIN
	-- Baud rate counter and state machine process
	PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			IF reset = '1' THEN
				state <= IDLE;
				baud_counter <= 0;
				bit_counter <= 0;
				sample_count <= 0;
				shift_reg <= (OTHERS => '0');
				RX_byte_out <= (OTHERS => '0');
				RX_data_ready <= '0';
			ELSE
				-- Default assignments
				RX_data_ready <= '0';

				-- Increment baud counter
				IF baud_counter < BAUD_COUNT THEN
					baud_counter <= baud_counter + 1;
				ELSE
					baud_counter <= 0;

					CASE state IS
						WHEN IDLE =>
							RX_busy <= '0';
							-- Look for start bit (falling edge)
							IF rx = '0' THEN
								state <= START;
								sample_count <= 0;
							END IF;

						WHEN START =>
							RX_busy <= '1';
							sample_count <= sample_count + 1;

							-- Wait until middle of start bit to sample
							IF sample_count = (OVERSAMPLE_RATE/2 - 1) THEN
								-- Verify start bit is still low
								IF rx = '0' THEN
									state <= DATA;
									bit_counter <= 0;
								ELSE
									state <= IDLE; -- Start bit gone, likely glitch
								END IF;
							END IF;

						WHEN DATA =>
							RX_busy <= '1';
							sample_count <= sample_count + 1;

							-- Sample at middle of bit period (4th sample for 8x oversampling)
							IF sample_count = (OVERSAMPLE_RATE/2 - 1) THEN
								shift_reg <= rx & shift_reg(7 DOWNTO 1);
							END IF;

							-- Move to next state after full bit period
							IF sample_count = (OVERSAMPLE_RATE - 1) THEN
								IF bit_counter = 7 THEN
									state <= STOP;
								ELSE
									bit_counter <= bit_counter + 1;
								END IF;
								sample_count <= 0;
							END IF;

						WHEN STOP =>
							RX_busy <= '1';
							sample_count <= sample_count + 1;

							-- Check stop bit at middle of bit period
							IF sample_count = (OVERSAMPLE_RATE/2 - 1) THEN
								-- Verify stop bit is high
								IF rx = '1' THEN
									-- Valid frame received
									RX_byte_out <= shift_reg;
									RX_data_ready <= '1';
								END IF;
							END IF;

							-- Move back to IDLE after full bit period
							IF sample_count = (OVERSAMPLE_RATE - 1) THEN
								state <= IDLE;
								sample_count <= 0;
							END IF;
					END CASE;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END RTL;
