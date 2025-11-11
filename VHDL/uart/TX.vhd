-------------------------------------------------------------------------------
-- TRANSMITTER MODULE
-------------------------------------------------------------------------------
-- This module is the transmitter module of the UART implementation (TX).
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tx IS
	GENERIC (
		CLOCK_FREQ : INTEGER;-- := 50_000_000; -- System clock frequency
		BAUD_RATE  : INTEGER-- := 9600 -- UART baud rate
	);
	PORT (
		clock         : IN  STD_LOGIC; -- System clock
		reset         : IN  STD_LOGIC; -- Active high reset
		TX_byte_in    : IN  STD_LOGIC_VECTOR(7 DOWNTO 0); -- Data to transmit
		TX_send_enable: IN  STD_LOGIC; -- Send enable (high for one clock cycle)
		tx            : OUT STD_LOGIC; -- Serial TX line
		tx_busy       : OUT STD_LOGIC -- High when transmitter is busy
	);
END tx;

ARCHITECTURE RTL OF tx IS
	-- Calculate counter value for baud rate generator
	CONSTANT BAUD_COUNT : INTEGER := (CLOCK_FREQ / BAUD_RATE) - 1;

	-- State machine states
	TYPE state_type IS (IDLE, START_BIT, DATA_BITS, STOP_BIT);
	SIGNAL state : state_type;

	-- Counters
	SIGNAL baud_counter : INTEGER RANGE 0 TO BAUD_COUNT;
	SIGNAL bit_counter : INTEGER RANGE 0 TO 7;

	-- Internal signals
	SIGNAL shift_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN
	-- Baud rate counter and state machine process
	PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			IF reset = '1' THEN
				state <= IDLE;
				baud_counter <= 0;
				bit_counter <= 0;
				shift_reg <= (OTHERS => '0');
				tx <= '1'; -- TX line idle high
				tx_busy <= '0';
			ELSE
				tx_busy <= '0'; -- Default: not busy

				-- Increment baud counter
				IF baud_counter < BAUD_COUNT THEN
					baud_counter <= baud_counter + 1;
				ELSE
					baud_counter <= 0;

					CASE state IS
						WHEN IDLE =>
							tx <= '1'; -- TX line idle high
							IF TX_send_enable = '1' THEN
								state <= START_BIT;
								shift_reg <= TX_byte_in;
								tx_busy <= '1';
							END IF;

						WHEN START_BIT =>
							tx <= '0'; -- Start bit is low
							state <= DATA_BITS;
							bit_counter <= 0;

						WHEN DATA_BITS =>
							tx <= shift_reg(0); -- Shift out LSB first
							shift_reg <= '0' & shift_reg(7 DOWNTO 1);

							IF bit_counter = 7 THEN
								state <= STOP_BIT;
							ELSE
								bit_counter <= bit_counter + 1;
							END IF;

						WHEN STOP_BIT =>
							tx <= '1'; -- Stop bit is high
							state <= IDLE;
					END CASE;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END RTL;
