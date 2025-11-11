-------------------------------------------------------------------------------
-- CONTROL MODULE
-------------------------------------------------------------------------------
-- This module is the control module for the UART protocol implementation. It 
-- functions as a way to interact with the 7-segment display, intiate loopback, 
-- give spesific inputs to the TX module and display if the RX module is 
-- receiving data.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY CTRL IS
	GENERIC (
		NUM_SEGMENTS : INTEGER-- := 7 -- number of individual segments on the 7-segment display
	);
	PORT (
		-- GENERAL 
		clock 					  : IN STD_LOGIC;
		reset 					  : IN STD_LOGIC;

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
		RX_byte_in             : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
		TX_byte_out			     : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		loopback_mode          : IN  STD_LOGIC;
		RX_busy					  : IN  STD_LOGIC;
		LED_out                : OUT STD_LOGIC;
		--baud_rate_out          : OUT INTEGER;
		baud_code              : IN  STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
END ENTITY CTRL;

ARCHITECTURE RTL OF CTRL IS

	---------------------------------------------------------------------------
	-- 7-SEGMENT VARIABLES
	---------------------------------------------------------------------------

	---------------------------------------------------------------------------
	-- Signals for converting the number to the correct form for the 7-segment display.
	---------------------------------------------------------------------------

	SIGNAL number_to_display : INTEGER;
	SIGNAL ASCII_code_to_display : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000000";

	---------------------------------------------------------------------------
	-- Binary numbers of each digit, e.g "12" -> "1" and "2", represented as 0001 and 0010.
	---------------------------------------------------------------------------

	SIGNAL ascii_digit_0 : STD_LOGIC_VECTOR (3 DOWNTO 0);
	SIGNAL ascii_digit_1 : STD_LOGIC_VECTOR (3 DOWNTO 0);
	SIGNAL ascii_digit_2 : STD_LOGIC_VECTOR (3 DOWNTO 0);
	SIGNAL ascii_digit_3 : STD_LOGIC_VECTOR (3 DOWNTO 0);
	SIGNAL ascii_digit_4 : STD_LOGIC_VECTOR (3 DOWNTO 0);
	SIGNAL ascii_digit_5 : STD_LOGIC_VECTOR (3 DOWNTO 0);

	---------------------------------------------------------------------------
	-- Binary representations of the digit will show the correct digit on the display.
	-- This drives the indivual segments on each 7-segment display, e.g "1" is "0001" is 
	-- "1111001" on the given segment.
	---------------------------------------------------------------------------

	SIGNAL bin_segment_d0 : STD_LOGIC_VECTOR(NUM_SEGMENTS - 1 DOWNTO 0);
	SIGNAL bin_segment_d1 : STD_LOGIC_VECTOR(NUM_SEGMENTS - 1 DOWNTO 0);
	SIGNAL bin_segment_d2 : STD_LOGIC_VECTOR(NUM_SEGMENTS - 1 DOWNTO 0);
	SIGNAL bin_segment_d3 : STD_LOGIC_VECTOR(NUM_SEGMENTS - 1 DOWNTO 0);
	SIGNAL bin_segment_d4 : STD_LOGIC_VECTOR(NUM_SEGMENTS - 1 DOWNTO 0);
	SIGNAL bin_segment_d5 : STD_LOGIC_VECTOR(NUM_SEGMENTS - 1 DOWNTO 0);

	---------------------------------------------------------------------------
	-- Button debounce and press logic. one_shot_button_x signals one press while 
	-- pulse_button_x is used to drive an external LED for user feedback.
	---------------------------------------------------------------------------

	CONSTANT COUNT_MAX : INTEGER := 20; --the higher this is, 
	--the more longer time the user has to press the button.
	CONSTANT BTN_ACTIVE : STD_LOGIC := '0'; --set it '1' if 
	--the button creates a high pulse when its pressed, otherwise '0'.
	SIGNAL count_button_0 : INTEGER := 0; -- For counting debounce time
	SIGNAL count_button_1 : INTEGER := 0; -- For counting debounce time
	--type state_type is (idle,wait_time); 
	TYPE state_type_press IS (idle, wait_time, pressed);--state machine for the button press
	SIGNAL one_shot_button_0 : STD_LOGIC := '0'; -- one-clock pulse on new press
	SIGNAL one_shot_button_1 : STD_LOGIC := '0'; -- one-clock pulse on new press
	SIGNAL state_button_0_press : state_type_press := idle;
	SIGNAL state_button_1_press : state_type_press := idle;

	---------------------------------------------------------------------------
	-- Signal for changing the baud rate during runtime.
	---------------------------------------------------------------------------
	SIGNAL baud_rate : INTEGER := 0;
	
	
	SIGNAL TX_button_byte_out : STD_LOGIC_VECTOR (7 DOWNTO 0);
	SIGNAL TX_loopback_data : STD_LOGIC_VECTOR (7 DOWNTO 0);

BEGIN

	----------------------------------------------------------------
	--REQ CTRL 01 Show the received bytes on the 7-segment dispplay.
	----------------------------------------------------------------
	-- The modue converts the received byte to an integer, and then 
	-- divides the number received into its respective digits that
	-- will be displayed on each individual 7-segment display.

	--------------------------------------------------------
	-------- CONVERT SECONDS TO DIGITS --------
	--------------------------------------------------------
	-- this section converts the received byte to an integer, and 
	-- divides up the resulting integer to its respective digits.
	
	ascii_code_to_display <= RX_byte_in;

	convert : PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			number_to_display <= to_integer(unsigned(ASCII_code_to_display));
			-- Digit 1 (100,000s place): (number_to_display / 100000) mod 10 = 1
			ascii_digit_5 <= STD_LOGIC_VECTOR(to_unsigned((number_to_display / 100000) MOD 10, ascii_digit_0'LENGTH));
			-- Digit 2 (10,000s place): (number_to_display / 10000) mod 10 = 2
			ascii_digit_4 <= STD_LOGIC_VECTOR(to_unsigned((number_to_display / 10000) MOD 10, ascii_digit_1'LENGTH));
			-- Digit 3 (1,000s place): (number_to_display / 1000) mod 10 = 3
			ascii_digit_3 <= STD_LOGIC_VECTOR(to_unsigned((number_to_display / 1000) MOD 10, ascii_digit_2'LENGTH));
			-- Digit 4 (100s place): (number_to_display / 100) mod 10 = 4
			ascii_digit_2 <= STD_LOGIC_VECTOR(to_unsigned((number_to_display / 100) MOD 10, ascii_digit_3'LENGTH));
			-- Digit 5 (10s place): (number_to_display / 10) mod 10 = 5
			ascii_digit_1 <= STD_LOGIC_VECTOR(to_unsigned((number_to_display / 10) MOD 10, ascii_digit_4'LENGTH));
			-- Digit 6 (1s place): (number_to_display / 1) mod 10 = 6
			ascii_digit_0 <= STD_LOGIC_VECTOR(to_unsigned(number_to_display MOD 10, ascii_digit_5'LENGTH));
		END IF;
	END PROCESS;

	----------------------------------------------
	-------- 7 SEGMENT OUTPUT FOR DIGIT 0 --------
	----------------------------------------------

	segment0 : PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			CASE ascii_digit_0 IS
				WHEN "0000" => -- Digit 0
					bin_segment_d0 <= "1000000"; -- a,b,c,d,e,f are on, g is off
				WHEN "0001" => -- Digit 1
					bin_segment_d0 <= "1111001"; -- b,c are on
				WHEN "0010" => -- Digit 2
					bin_segment_d0 <= "0100100"; -- a,b,d,e,g are on
				WHEN "0011" => -- Digit 3
					bin_segment_d0 <= "0110000"; -- a,b,c,d,g are on
				WHEN "0100" => -- Digit 4
					bin_segment_d0 <= "0011001"; -- b,c,f,g are on
				WHEN "0101" => -- Digit 5
					bin_segment_d0 <= "0010010"; -- a,c,d,f,g are on
				WHEN "0110" => -- Digit 6
					bin_segment_d0 <= "0000010"; -- a,c,d,e,f,g are on
				WHEN "0111" => -- Digit 7
					bin_segment_d0 <= "1111000"; -- a,b,c are on
				WHEN "1000" => -- Digit 8
					bin_segment_d0 <= "0000000"; -- All segments are on
				WHEN "1001" => -- Digit 9
					bin_segment_d0 <= "0010000"; -- a,b,c,d,f,g are on
				WHEN OTHERS =>
					bin_segment_d0 <= "1111111"; -- All segments off (blank)
			END CASE;
		END IF;
	END PROCESS;

	----------------------------------------------
	-------- 7 SEGMENT OUTPUT FOR DIGIT 1 --------
	----------------------------------------------

	segment1 : PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			CASE ascii_digit_1 IS
				WHEN "0000" => -- Digit 0
					bin_segment_d1 <= "1000000"; -- a,b,c,d,e,f are on, g is off
				WHEN "0001" => -- Digit 1
					bin_segment_d1 <= "1111001"; -- b,c are on
				WHEN "0010" => -- Digit 2
					bin_segment_d1 <= "0100100"; -- a,b,d,e,g are on
				WHEN "0011" => -- Digit 3
					bin_segment_d1 <= "0110000"; -- a,b,c,d,g are on
				WHEN "0100" => -- Digit 4
					bin_segment_d1 <= "0011001"; -- b,c,f,g are on
				WHEN "0101" => -- Digit 5
					bin_segment_d1 <= "0010010"; -- a,c,d,f,g are on
				WHEN "0110" => -- Digit 6
					bin_segment_d1 <= "0000010"; -- a,c,d,e,f,g are on
				WHEN "0111" => -- Digit 7
					bin_segment_d1 <= "1111000"; -- a,b,c are on
				WHEN "1000" => -- Digit 8
					bin_segment_d1 <= "0000000"; -- All segments are on
				WHEN "1001" => -- Digit 9
					bin_segment_d1 <= "0010000"; -- a,b,c,d,f,g are on
				WHEN OTHERS =>
					bin_segment_d1 <= "1111111"; -- All segments off (blank)
			END CASE;
		END IF;
	END PROCESS;
	----------------------------------------------
	-------- 7 SEGMENT OUTPUT FOR DIGIT 2 --------
	----------------------------------------------

	segment2 : PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			CASE ascii_digit_2 IS
				WHEN "0000" => -- Digit 0
					bin_segment_d2 <= "1000000"; -- a,b,c,d,e,f are on, g is off
				WHEN "0001" => -- Digit 1
					bin_segment_d2 <= "1111001"; -- b,c are on
				WHEN "0010" => -- Digit 2
					bin_segment_d2 <= "0100100"; -- a,b,d,e,g are on
				WHEN "0011" => -- Digit 3
					bin_segment_d2 <= "0110000"; -- a,b,c,d,g are on
				WHEN "0100" => -- Digit 4
					bin_segment_d2 <= "0011001"; -- b,c,f,g are on
				WHEN "0101" => -- Digit 5
					bin_segment_d2 <= "0010010"; -- a,c,d,f,g are on
				WHEN "0110" => -- Digit 6
					bin_segment_d2 <= "0000010"; -- a,c,d,e,f,g are on
				WHEN "0111" => -- Digit 7
					bin_segment_d2 <= "1111000"; -- a,b,c are on
				WHEN "1000" => -- Digit 8
					bin_segment_d2 <= "0000000"; -- All segments are on
				WHEN "1001" => -- Digit 9
					bin_segment_d2 <= "0010000"; -- a,b,c,d,f,g are on
				WHEN OTHERS =>
					bin_segment_d2 <= "1111111"; -- All segments off (blank)
			END CASE;
		END IF;
	END PROCESS;

	----------------------------------------------
	-------- 7 SEGMENT OUTPUT FOR DIGIT 3 --------
	----------------------------------------------

	segment3 : PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			CASE ascii_digit_3 IS
				WHEN "0000" => -- Digit 0
					bin_segment_d3 <= "1000000"; -- a,b,c,d,e,f are on, g is off
				WHEN "0001" => -- Digit 1
					bin_segment_d3 <= "1111001"; -- b,c are on
				WHEN "0010" => -- Digit 2
					bin_segment_d3 <= "0100100"; -- a,b,d,e,g are on
				WHEN "0011" => -- Digit 3
					bin_segment_d3 <= "0110000"; -- a,b,c,d,g are on
				WHEN "0100" => -- Digit 4
					bin_segment_d3 <= "0011001"; -- b,c,f,g are on
				WHEN "0101" => -- Digit 5
					bin_segment_d3 <= "0010010"; -- a,c,d,f,g are on
				WHEN "0110" => -- Digit 6
					bin_segment_d3 <= "0000010"; -- a,c,d,e,f,g are on
				WHEN "0111" => -- Digit 7
					bin_segment_d3 <= "1111000"; -- a,b,c are on
				WHEN "1000" => -- Digit 8
					bin_segment_d3 <= "0000000"; -- All segments are on
				WHEN "1001" => -- Digit 9
					bin_segment_d3 <= "0010000"; -- a,b,c,d,f,g are on
				WHEN OTHERS =>
					bin_segment_d3 <= "1111111"; -- All segments off (blank)
			END CASE;
		END IF;
	END PROCESS;

	----------------------------------------------
	-------- 7 SEGMENT OUTPUT FOR DIGIT 4 --------
	----------------------------------------------

	segment4 : PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			CASE ascii_digit_4 IS
				WHEN "0000" => -- Digit 0
					bin_segment_d4 <= "1000000"; -- a,b,c,d,e,f are on, g is off
				WHEN "0001" => -- Digit 1
					bin_segment_d4 <= "1111001"; -- b,c are on
				WHEN "0010" => -- Digit 2
					bin_segment_d4 <= "0100100"; -- a,b,d,e,g are on
				WHEN "0011" => -- Digit 3
					bin_segment_d4 <= "0110000"; -- a,b,c,d,g are on
				WHEN "0100" => -- Digit 4
					bin_segment_d4 <= "0011001"; -- b,c,f,g are on
				WHEN "0101" => -- Digit 5
					bin_segment_d4 <= "0010010"; -- a,c,d,f,g are on
				WHEN "0110" => -- Digit 6
					bin_segment_d4 <= "0000010"; -- a,c,d,e,f,g are on
				WHEN "0111" => -- Digit 7
					bin_segment_d4 <= "1111000"; -- a,b,c are on
				WHEN "1000" => -- Digit 8
					bin_segment_d4 <= "0000000"; -- All segments are on
				WHEN "1001" => -- Digit 9
					bin_segment_d4 <= "0010000"; -- a,b,c,d,f,g are on
				WHEN OTHERS =>
					bin_segment_d4 <= "1111111"; -- All segments off (blank)
			END CASE;
		END IF;
	END PROCESS;

	----------------------------------------------
	-------- 7 SEGMENT OUTPUT FOR DIGIT 5 --------
	----------------------------------------------

	PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			CASE ascii_digit_5 IS
				WHEN "0000" => -- Digit 0
					bin_segment_d5 <= "1000000"; -- a,b,c,d,e,f are on, g is off
				WHEN "0001" => -- Digit 1
					bin_segment_d5 <= "1111001"; -- b,c are on
				WHEN "0010" => -- Digit 2
					bin_segment_d5 <= "0100100"; -- a,b,d,e,g are on
				WHEN "0011" => -- Digit 3
					bin_segment_d5 <= "0110000"; -- a,b,c,d,g are on
				WHEN "0100" => -- Digit 4
					bin_segment_d5 <= "0011001"; -- b,c,f,g are on
				WHEN "0101" => -- Digit 5
					bin_segment_d5 <= "0010010"; -- a,c,d,f,g are on
				WHEN "0110" => -- Digit 6
					bin_segment_d5 <= "0000010"; -- a,c,d,e,f,g are on
				WHEN "0111" => -- Digit 7
					bin_segment_d5 <= "1111000"; -- a,b,c are on
				WHEN "1000" => -- Digit 8
					bin_segment_d5 <= "0000000"; -- All segments are on
				WHEN "1001" => -- Digit 9
					bin_segment_d5 <= "0010000"; -- a,b,c,d,f,g are on
				WHEN OTHERS =>
					bin_segment_d5 <= "1111111"; -- All segments off (blank)
			END CASE;
		END IF;
	END PROCESS;

	-- Combinational logic to drive the segments
	out_segments_digit_0 <= bin_segment_d0;
	out_segments_digit_1 <= bin_segment_d1;
	out_segments_digit_2 <= bin_segment_d2;
	out_segments_digit_3 <= bin_segment_d3;
	out_segments_digit_4 <= bin_segment_d4;
	out_segments_digit_5 <= bin_segment_d5;

	----------------------------------------------------------------
	--REQ CTRL 02 Indicate that a byte has been received by lighting a LED.
	----------------------------------------------------------------

	indicator : PROCESS (reset, clock, RX_busy)
	BEGIN
		IF reset = '0' THEN
			LED_out <= '0';
		ELSIF rising_edge(clock) THEN
			LED_out <= RX_busy;
		END IF;
	END PROCESS;

	----------------------------------------------------------------
	--REQ CTRL 03 Send the received byte immediately in return (loopback).
	----------------------------------------------------------------

	loopback : PROCESS (reset, clock, loopback_mode, RX_byte_in)
	BEGIN
		IF loopback_mode = '0' THEN
			TX_loopback_data <= (OTHERS => '0');
		ELSIF rising_edge(clock) THEN
			TX_loopback_data <= RX_byte_in;
		END IF;
	END PROCESS;

	----------------------------------------------------------------
	--REQ CTRL 04 Send a pre-defined byte with button presses. 
	----------------------------------------------------------------

	-- The process sends the byte for "-" when button 0 is pressed.
	-- The process sends the byte for "+" when button 0 is pressed. 
	-- Extra: the buttons have LED-output feedback for user friendliness.

	-- state_button_x_press is a state machine for implementing debounce.
	-- count_button_x is for debounce time counting. 
	-- pulse_button_x_out is for the LED feedback when a button is presssed. 
	-- one_shot_button_x sends a byte when a button has been pressed (once per press).

	------------------------------------------------
	-------- BUTTON0/KEY0 DEBOUNCE LOGIC --------
	------------------------------------------------
	button0 : PROCESS (reset, clock)
	BEGIN
		IF reset = '0' THEN
			state_button_0_press <= idle;
			count_button_0 <= 0;
			pulse_button_0_out <= '0';
			one_shot_button_0 <= '0';
		ELSIF rising_edge(clock) THEN
			one_shot_button_0 <= '0';

			CASE state_button_0_press IS
				WHEN idle =>
					pulse_button_0_out <= '0';
					count_button_0 <= 0;
					IF button_0_in = BTN_ACTIVE THEN
						state_button_0_press <= wait_time;
					END IF;

				WHEN wait_time =>
					-- debounce counting
					IF count_button_0 = COUNT_MAX THEN
						count_button_0 <= 0;
						IF button_0_in = BTN_ACTIVE THEN
							-- button confirmed pressed
							one_shot_button_0 <= '1'; -- create one-clock pulse for action
							pulse_button_0_out <= '1'; -- keep LED on while pressed (debounced)
							state_button_0_press <= pressed; -- wait for release before next action
						ELSE
							state_button_0_press <= idle;
						END IF;
					ELSE
						count_button_0 <= count_button_0 + 1;
					END IF;

				WHEN pressed =>
					-- keep LED on while button still active
					IF button_0_in = BTN_ACTIVE THEN
						pulse_button_0_out <= '1';
					ELSE
						pulse_button_0_out <= '0';
						state_button_0_press <= idle; -- allow new press after release
					END IF;

			END CASE;
		END IF;
	END PROCESS;

	------------------------------------------------
	-------- BUTTON1/KEY1 DEBOUNCE LOGIC --------
	------------------------------------------------

	button1 : PROCESS (reset, clock)
	BEGIN
		IF reset = '0' THEN
			state_button_1_press <= idle;
			count_button_1 <= 0;
			pulse_button_1_out <= '0';
			one_shot_button_1 <= '0';
		ELSIF rising_edge(clock) THEN
			one_shot_button_1 <= '0'; -- default: one-shot is single clock pulse

			CASE state_button_1_press IS
				WHEN idle =>
					pulse_button_1_out <= '0';
					count_button_1 <= 0;
					IF button_1_in = BTN_ACTIVE THEN
						state_button_1_press <= wait_time;
					END IF;

				WHEN wait_time =>
					-- debounce counting
					IF count_button_1 = COUNT_MAX THEN
						count_button_1 <= 0;
						IF button_1_in = BTN_ACTIVE THEN
							-- button confirmed pressed
							one_shot_button_1 <= '1'; -- create one-clock pulse for action
							pulse_button_1_out <= '1'; -- keep LED on while pressed (debounced)
							state_button_1_press <= pressed; -- wait for release before next action
						ELSE
							state_button_1_press <= idle;
						END IF;
					ELSE
						count_button_1 <= count_button_1 + 1;
					END IF;

				WHEN pressed =>
					-- keep LED on while button still active
					IF button_1_in = BTN_ACTIVE THEN
						pulse_button_1_out <= '1';
					ELSE
						pulse_button_1_out <= '0';
						state_button_1_press <= idle; -- allow new press after release
					END IF;

			END CASE;
		END IF;
	END PROCESS;

	------------------------------------------------
	-------- ARE ANY OF THE BUTTONS PRESSED? --------
	------------------------------------------------

	buttonpress : PROCESS (reset, clock)
	BEGIN
		IF reset = '0' THEN
			TX_button_byte_out <= (OTHERS => '0');
		ELSIF rising_edge(clock) THEN
			IF one_shot_button_0 = '1' THEN
				TX_button_byte_out <= "00101101"; -- send "-"
			ELSE
				TX_button_byte_out <= (OTHERS => '0');
			END IF;
			IF one_shot_button_1 = '1' THEN
				TX_button_byte_out <= "00101011"; -- send "+"
			ELSE
				TX_button_byte_out <= (OTHERS => '0');
			END IF;
		END IF;
	END PROCESS;
	
	WITH loopback_mode select
		TX_byte_out <= TX_loopback_data when '1',
		TX_button_byte_out when others;
	----------------------------------------------------------------
	--REQ CTRL 05 Send a pre-defined string of 8 bytes with button presses. (optional)
	----------------------------------------------------------------
	----------------------------------------------------------------
	--REQ CTRL 06 Adjust baud rate while the FPGA is running. (optional) 
	----------------------------------------------------------------

	-- Baud code for corresponding baud rates: 

	--0000 	600
	--0001 	1200
	--0010 	2400
	--0011 	4800
	--0100 	9600
	--0101 	19200
	--0110 	38400
	--0111 	57600
	--1000 	115200

	baud : PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN
			CASE baud_code IS
				WHEN "0000" =>
					baud_rate <= 600;
				WHEN "0001" =>
					baud_rate <= 1200;
				WHEN "0010" =>
					baud_rate <= 2400;
				WHEN "0011" =>
					baud_rate <= 4800;
				WHEN "0100" =>
					baud_rate <= 9600;
				WHEN "0101" =>
					baud_rate <= 19200;
				WHEN "0110" =>
					baud_rate <= 38400;
				WHEN "0111" =>
					baud_rate <= 57600;
				WHEN "1000" =>
					baud_rate <= 115200;
				WHEN OTHERS =>
					baud_rate <= 0;
			END CASE;
		END IF;
	END PROCESS;

	--baud_rate_out <= baud_rate;

END ARCHITECTURE RTL;
