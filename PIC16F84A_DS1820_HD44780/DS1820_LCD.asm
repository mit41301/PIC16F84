;=================================================================================
;	NAME			: DS1820_LCD
;	DATE			: 14-03-2005
;	AUTHOR			: Heino Peters
;	DESCRIPTION		: Assmbly software for PIC16F84 to display temperature,
;					  measured with DS1820 on a 2x16 character HD44780-based
;					  LCD display, with 4-bits datatransfer via CMOS 4094, HG-2006
;=================================================================================
;	SETTINGS
 	ErrorLevel -302 						;suppress message 302 (proper bank)
	list    p=16f84a
	include <p16f84a.inc>
	__config _CP_OFF & _PWRTE_ON & _WDT_OFF & _XT_OSC

;	DEFINITION PORTA (A0-A4)
	#define	IN_OUT_PORTA
	#define	CLOCK_LCD		PORTA,0			;pin 17
	#define	DATA_LCD		PORTA,1			;pin 18
	#define	STROBE_LCD		PORTA,2			;pin 1
	#define	DATA_DS1820		PORTA,4			;pin 3, open collector

;	DEFINITION PORTB (B0-B7)
	#define	IN_OUT_PORTB
	#define	LDR				PORTB,4			;pin 10

;	BASIC PARAMETERS
	org		H'00'							;reset vector
	goto	MAIN_PROGRAM					;main
RAM			equ	H'0C' 						;start of RAM

;	RAM
	cblock	RAM
			COUNTER_1
			COUNTER_2
			COUNTER_3
			BIT
			BITS
			BYTE
			CRC_CHECK
			DECADES
			LCD_BYTE
			MEM_1
			DS1820_SIGN
			DS1820_TEMP
			DS1820_ERROR
	endc

;	LCD_BYTE
	#define	RS					LCD_BYTE,0
	#define	LCD_1				LCD_BYTE,1	;for free use
	#define LCD_2				LCD_BYTE,2	;for free use
	#define	BACKLIGHT			LCD_BYTE,3

;	BITS
	#define DS1820_INPUT_BIT	BITS,0
	#define DS1820_TEMP_HALF	BITS,1
	#define	DS1820_TEMP_100		BITS,2

;	DS1820_ERROR
	#define DS1820_SHORTED		DS1820_ERROR,0	;shorted to ground
	#define	DS1820_NO_DEVICE	DS1820_ERROR,1	;no device or shorted to +5V
	#define	DS1820_CRC_ERROR	DS1820_ERROR,2	;read-error or more than 1 DS1820

;=================================================================================
MAIN_PROGRAM
	call	INIT
main_0
	call	READ_DS1820
	movf	DS1820_ERROR,1
	btfss	STATUS,Z
	goto	main_1
	call	DISPLAY_TEMPERATURE
	goto	main_0
main_1
	call	DISPLAY_ERROR
	goto	main_0

;=================================================================================
INIT
	bsf		STATUS,RP0
	movlw   B'00000000'			;define all I/O ports RA0-RA4
	movwf	TRISA
	movlw   B'00010000'			;define all I/O ports RB0-RB7
	movwf	TRISB
	bcf		STATUS,RP0
	clrf	PORTA				;clear all output ports RA0-RA4
	clrf	PORTB				;clear all output ports RB0-RB7
	bcf		CLOCK_LCD			;reset CLOCK
	bsf		DATA_DS1820			;release dataline DS1820
	call	LCD_INIT			;initialize LCD-module
	return

;=================================================================================
LCD_INIT
	movlw	D'40'				;LCD-module needs 40 ms after power rise
	call	WAIT_1ms
	bcf		STROBE_LCD			;STROBE low
	bcf		CLOCK_LCD			;CLOCK low
	clrf	LCD_BYTE			;RS='0', BACKLIGHT is off
	movlw	B'00100000'			;set interface to 4 bits
	call	LCD_WRITE_BYTE
	movlw	D'5'				;LCD-module needs 5 ms for processing
	call	WAIT_1ms
	movlw	B'00101000'			;4-bits interface, 2 lines, 5x7 matrix
	call	LCD_WRITE_BYTE
	movlw	D'5'				;LCD-module needs 5 ms for processing
	call	WAIT_1ms
	movlw	B'00001100'			;display on, cursor off
	call	LCD_WRITE_BYTE
	movlw	B'00000110'			;cursor moves automatically to next position
	call	LCD_WRITE_BYTE
								;define degree-symbol "º" as ASCII 0
	movlw	B'01000000'
	call	LCD_WRITE_BYTE
	bsf		RS
	movlw	B'00000110'			;upper line of 7x5 matrix
	call	LCD_WRITE_CHARACTER
	movlw	B'00001001'			;2nd line of 7x5 matrix
	call	LCD_WRITE_CHARACTER
	movlw	B'00001001'			;and so on
	call	LCD_WRITE_CHARACTER
	movlw	B'00000110'
	call	LCD_WRITE_CHARACTER
	movlw	B'00000000'
	call	LCD_WRITE_CHARACTER
	movlw	B'00000000'
	call	LCD_WRITE_CHARACTER
	movlw	B'00000000'
	call	LCD_WRITE_CHARACTER
	movlw	B'00000000'
	call	LCD_WRITE_CHARACTER

	call	LCD_CLEAR_SCREEN
	return

;=================================================================================
LCD_CLEAR_SCREEN				;clears screen, cursor on upper left position
	bcf		RS
	movlw	B'00000001'
	call	LCD_WRITE_BYTE
	movlw	D'2'				;LCD-module needs 2 ms for processing
	call	WAIT_1ms
	return

LCD_START_LINE_1				;put cursor on 1st position of 1st line
	bcf		RS
	movlw	B'10000000'
	call	LCD_WRITE_BYTE
	return

LCD_START_LINE_2				;put cursor on 1st position of 2nd line
	bcf		RS
	movlw	B'11000000'
	call	LCD_WRITE_BYTE
	return

LCD_START_LINE_3				;put cursor on 1st position of 3rd line
	bcf		RS
	movlw	B'10010000'
	call	LCD_WRITE_BYTE
	return

LCD_START_LINE_4				;put cursor on 1st position of 4th line
	bcf		RS
	movlw	B'11010000'
	call	LCD_WRITE_BYTE
	return

LCD_WRITE_CHARACTER				;display character from workspace
	bsf		RS
	call	LCD_WRITE_BYTE
	return

;=================================================================================
LCD_WRITE_BYTE					;writes 8 bits from workspace with given RS/BL
	movwf	MEM_1				;keep 2nd half of databyte stored
	call	LCD_WRITE_HALF		;send 1st half of databyte (bit 7-4)
	swapf	MEM_1,0				;get back 2nd half of databyte
	call	LCD_WRITE_HALF		;send 2nd half of databyte (bit 3-0)
	return

LCD_WRITE_HALF
	andlw	B'11110000'			;select only the first 4 bits
	movwf	BYTE				;store them in BYTE
	movf	LCD_BYTE,0			;get LCD_BYTE for the right 4 bits
	iorwf	BYTE,1				;merge and restore in BYTE
	movlw	D'8'				;write D7-D0 to 4094 ...
	movwf	BIT					;... and keep bit-counter in BIT
lcd_write_half_1
	bcf		DATA_LCD			;make DATA-line '0' ...
	btfsc	BYTE,7				;... but if leftmost bit='1' ...
	bsf		DATA_LCD			;... then make DATA-line '1'
	bsf		CLOCK_LCD			;give a clock-puls ...
	bcf		CLOCK_LCD			;... and make CLOCK '0' again
	rlf		BYTE,1				;move bits in BYTE 1 position to the left
	decfsz	BIT,1				;repeat until BIT=0
	goto	lcd_write_half_1
	bsf		STROBE_LCD			;make STROBE '1' to strobe data into 4094 ...
	bcf		STROBE_LCD			;... and make STROBE '0' again
	movlw	D'2'				;LCD-module needs 8x5=40 us processing time
	call	WAIT_5us
	return

;=================================================================================
READ_DS1820
	clrf	DS1820_ERROR		;clear ERROR-code
	call	ONE_WIRE_RESET_AND_PRESENCE
	movlw	H'CC'				;SKIP ROM
	call	ONE_WIRE_WRITE_BYTE
	movlw	H'44'				;CONVERT T
	call	ONE_WIRE_WRITE_BYTE
read_DS1820_1
	movf	DS1820_ERROR,1		;check DS1820_ERROR and ...
	btfss	STATUS,Z			;... if DS1820_ERROR is not 0 ...
	goto	read_DS1820_2		;... then stop reading here
	call	ONE_WIRE_READ_BIT	;check dataline to find out when ...
	btfss	DS1820_INPUT_BIT	;... conversion is ready 
	goto	read_DS1820_1
	call	ONE_WIRE_RESET_AND_PRESENCE
	movf	DS1820_ERROR,1		;check DS1820_ERROR and ...
	btfss	STATUS,Z			;... if DS1820_ERROR is not 0 ...
	goto	read_DS1820_2		;... then stop reading here
	movlw	H'CC'				;SKIP ROM
	call	ONE_WIRE_WRITE_BYTE
	movlw	H'BE'				;READ DATA
	call	ONE_WIRE_WRITE_BYTE
	clrf	CRC_CHECK			;check CRC from here
	call	ONE_WIRE_READ_BYTE	;read TEMP
	movwf	DS1820_TEMP
	call	ONE_WIRE_READ_BYTE	;read SIGN
	movwf	DS1820_SIGN
	call	ONE_WIRE_READ_BYTE	;TH
	call	ONE_WIRE_READ_BYTE	;TL
	call	ONE_WIRE_READ_BYTE	;FFh
	call	ONE_WIRE_READ_BYTE	;FFh
	call	ONE_WIRE_READ_BYTE	;REMAIN
	call	ONE_WIRE_READ_BYTE	;10h
	call	ONE_WIRE_READ_BYTE	;CRC
	movf	CRC_CHECK,1			;check CRC_CHECK and ...
	btfss	STATUS,Z			;... if CRC_CHECK not 0 ...
	bsf		DS1820_CRC_ERROR	;... then set error-code
read_DS1820_2
	return

;=================================================================================
ONE_WIRE_RESET_AND_PRESENCE
;	part one: dataline low for 480 us (RESET)
	bcf		DATA_DS1820			;dataline low
	movlw	D'96'				;wait for 96 x 5 us = 480 us
	call	WAIT_5us
;	part two: release dataline for 70 us and read dataline (PRESENCE)
	bsf		DATA_DS1820			;release dataline
	bsf		STATUS,RP0			;select BANK 1
	bsf		TRISA,4				;define DATA_DS1820 for input ('1')
	bcf		STATUS,RP0			;go back to BANK 0
	movlw	D'13'				;wait for 13 x 5 us = 65 us
	call	WAIT_5us
	btfsc	DATA_DS1820			;if dataline is low ...
	bsf		DS1820_NO_DEVICE	;... then no device found
;	part three: releae dataline for 400 us more
	movlw	D'80'				;wait for 80 x 5 us = 400 us
	call	WAIT_5us
	btfss	DATA_DS1820			;if dataline is low ...
	bsf		DS1820_SHORTED		;... then it is shorted to ground
	bsf		STATUS,RP0			;select BANK 1
	bcf		TRISA,4				;redefine DATA_DS1820 for output ('0')
	bcf		STATUS,RP0			;go back to BANK 0
	return

;=================================================================================
ONE_WIRE_READ_BYTE
	movwf	BYTE				;store workspace in BYTE
	movlw	D'8'				;read D0-D7 ...
	movwf	BIT					;... and follow bit-counter in BIT
one_wire_read_byte_1
	call	ONE_WIRE_READ_BIT	;read next bit in workspace
	rrf		BYTE,1				;move bits in BYTE 1 position to the right
	bcf		BYTE,7				;clear leftmost bit in BYTE ...
	btfsc	DS1820_INPUT_BIT	;... if INPUT_BIT = '1' ...
	bsf		BYTE,7				;... then set leftmost bit in BYTE
;	repeat for next bit
	decfsz	BIT,1				;countdown until BIT=0
	goto	one_wire_read_byte_1
	movf	BYTE,0				;put BYTE in workspace
	return

;=================================================================================
ONE_WIRE_WRITE_BYTE
	movwf	BYTE
	movlw	D'8'				;write D7-D0 ...
	movwf	BIT					;... en follow bit-counter in BIT
one_wire_write_byte_1
;	part one: dataline low for 10 us
	bcf		DATA_DS1820			;dataline low
	movlw	D'2'	
	call	WAIT_5us			;wait for 2 x 5 = 10 us
;	part two: if you send a '1', then release dataline
	btfsc	BYTE,0
	bsf		DATA_DS1820
;	part three: wait 50 us and finally always release the dataline
	movlw	D'10'
	call	WAIT_5us			;wait for 10 x 5 = 50 us
	bsf		DATA_DS1820
	rrf		BYTE,1				;move bits in BYTE 1 position to the right
	decfsz	BIT,1				;countdown until BIT=0
	goto	one_wire_write_byte_1
	return

;=================================================================================
ONE_WIRE_READ_BIT
;	part one: dataline low for 5 us
	bcf		DATA_DS1820			;dataline low
	call	WAIT_4us			;wait 4 us more
;	part two: release dataline during 10 us and read dataline
	bsf		DATA_DS1820			;release dataline
	bsf		STATUS,RP0			;select BANK 1
	bsf		TRISA,4				;define DATA_DS1820 for input ('1')
	bcf		STATUS,RP0			;back to BANK 0
	call	WAIT_4us
	nop
	bcf		DS1820_INPUT_BIT	;clear input-bit ...
	btfsc	DATA_DS1820			;... and if DATA is not '0' ...
	bsf		DS1820_INPUT_BIT	;... then set input-bit
;	part three: release dataline 45 us more
	movlw	D'7'
	call	WAIT_5us			;wait 7 x 5 = 35 us
	btfss	DATA_DS1820			;if dataline is 0 ...
	bsf		DS1820_SHORTED		;... then line is shorted
	bsf		STATUS,RP0			;selectBANK 1
	bcf		TRISA,4				;define DATA_DS1820 back for output ('0')
	bcf		STATUS,RP0			;and back again to BANK 0
	call	CALCULATE_NEW_CRC	;update CRC
	return

;=================================================================================
DISPLAY_TEMPERATURE
	bcf		BACKLIGHT			;reset BACKLIGHT and ...
	btfss	LDR					;... if LDR = '0' (dark) ...
	bsf		BACKLIGHT			;... then set BACKLIGHT
;	display headerline
	call	LCD_START_LINE_1
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	"T"
	call	LCD_WRITE_CHARACTER
	movlw	"E"
	call	LCD_WRITE_CHARACTER
	movlw	"M"
	call	LCD_WRITE_CHARACTER
	movlw	"P"
	call	LCD_WRITE_CHARACTER
	movlw	"E"
	call	LCD_WRITE_CHARACTER
	movlw	"R"
	call	LCD_WRITE_CHARACTER
	movlw	"A"
	call	LCD_WRITE_CHARACTER
	movlw	"T"
	call	LCD_WRITE_CHARACTER
	movlw	"U"
	call	LCD_WRITE_CHARACTER
	movlw	"R"
	call	LCD_WRITE_CHARACTER
	movlw	"E"
	call	LCD_WRITE_CHARACTER
;	display temperature
	call	LCD_START_LINE_2
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	" "
	call	LCD_WRITE_CHARACTER

;	if negative, then show sign and calculate complement of TEMP
	movf	DS1820_SIGN,1		;set STATUS,Z based on contents of SIGN
	btfsc	STATUS,Z			;if SIGN = 0 then skip next code for ...
	goto	display_temp_1		;.. negative temperatures
	movlw	"-"					;display minus-sign on LCD
	call	LCD_WRITE_CHARACTER
	comf	DS1820_TEMP,1		;calculate TEMP's complement and ...
	incf	DS1820_TEMP,1		;... add one

display_temp_1
;	store decimal position in TEMP_HALF and do the integer-division of TEMP
	bcf		DS1820_TEMP_HALF	;HALF = '0' unless ...
	btfsc	DS1820_TEMP,0		;... the rightmost bit of TEMP is not '0' ...
	bsf		DS1820_TEMP_HALF	;... then let HALF = '1'
	rrf		DS1820_TEMP,1		;move bits in TEMP 1 position to the right ...
	bcf		DS1820_TEMP,7		;... and clear the leftmost bit (= TEMP\2)

display_temp_2
;	find whether TEMP>=100 by subtracting 100 from TEMP and display it if neccesary
	movlw	D'100'				;TEMP <- TEMP - 100
	subwf	DS1820_TEMP,1
	btfsc	STATUS,C			;if carry-bit clear, then no hundreds
	goto	display_temp_3
;	TEMP < 100
	movlw	D'100'				;TEMP <- TEMP + 100 because we subtracted ...
	addwf	DS1820_TEMP,1		;... 100 one time too often
	bcf		DS1820_TEMP_100
	goto	display_temp_4
display_temp_3
;	TEMP >= 100
	movlw	"1"
	call	LCD_WRITE_CHARACTER
	bsf		DS1820_TEMP_100

display_temp_4
;	find decades of temperature and display them
	clrf	DECADES				;reset DECADES
display_temp_5					;find DECADES by subtracting 10 as often as possible
	movlw	D'10'
	subwf	DS1820_TEMP,1		;TEMP <- TEMP - 10
	btfss	STATUS,C			;if carry-bit clear, then we went negative
	goto	display_temp_6
	incf	DECADES,1			;increase DECADES with 1
	goto	display_temp_5
display_temp_6
	movlw	D'10'				;TEMP <- TEMP + 10 because we just added 1 ...
	addwf	DS1820_TEMP,1		;... one time to often and made TEMP "negative"
	movf	DECADES,1
	btfss	STATUS,Z
	goto	display_temp_7
	btfss	DS1820_TEMP_100
	goto	display_temp_8
display_temp_7
	movlw	"0"					;convert DECADES to an ASCII-figure
	addwf	DECADES,0			;display DECADES of temperature on LCD
	call	LCD_WRITE_CHARACTER

display_temp_8
;	display units of temperature
	movlw	"0"					;convert remaining units to an ASCII-figure
	addwf	DS1820_TEMP,0		;show units of temperature on LCD
	call	LCD_WRITE_CHARACTER

;	display .0 or .5
	movlw	"."					;display decimal point
	call	LCD_WRITE_CHARACTER
	btfsc	DS1820_TEMP_HALF	;if TEMP_HALF = "0" then ...
	goto	display_temp_9
	movlw	"0"					;... display "0" ...
	call	LCD_WRITE_CHARACTER
	goto	display_temp_10
display_temp_9
	movlw	"5"					;... else display "5"
	call	LCD_WRITE_CHARACTER

display_temp_10
;	add text "ºC"
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	D'0'				;display the symbol for degrees (º) we defined
	call	LCD_WRITE_CHARACTER
	movlw	"C"					;display C for Celcius
	call	LCD_WRITE_CHARACTER
	movlw	" "					;overwrite last position in case temp is shorter
	call	LCD_WRITE_CHARACTER
	return

;=================================================================================
DISPLAY_ERROR
;	display headerline
	call	LCD_START_LINE_2
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	"E"
	call	LCD_WRITE_CHARACTER
	movlw	"R"
	call	LCD_WRITE_CHARACTER
	movlw	"R"
	call	LCD_WRITE_CHARACTER
	movlw	"O"
	call	LCD_WRITE_CHARACTER
	movlw	"R"
	call	LCD_WRITE_CHARACTER
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	"0"					;convert ERROR-code to ASCII-character
	addwf	DS1820_ERROR,0
	call	LCD_WRITE_CHARACTER
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	" "
	call	LCD_WRITE_CHARACTER
	movlw	" "
	call	LCD_WRITE_CHARACTER
	return

;=================================================================================
CALCULATE_NEW_CRC				;based on contents of bit in DS1820_INPUT_BIT
	btfsc	DS1820_INPUT_BIT
	goto 	CRC_DIGIT_1
CRC_DIGIT_0
	btfsc	CRC_CHECK,0
	goto	CRC_DIGIT_NOT_EQUAL
	goto	CRC_DIGIT_EQUAL
CRC_DIGIT_1
	btfss	CRC_CHECK,0
	goto	CRC_DIGIT_NOT_EQUAL
CRC_DIGIT_EQUAL
	rrf		CRC_CHECK,1			;move bits in CRC 1 position to right
	movlw	B'01111111'			;clear MSB of CRC
	andwf	CRC_CHECK,1
	goto	calculate_new_CRC_end
CRC_DIGIT_NOT_EQUAL
	rrf		CRC_CHECK,1			;move bits in CRC 1 position to right
	movlw	B'01111111'			;clear MSB of CRC
	andwf	CRC_CHECK,1
	movlw	B'10001100'			;XOR bits 2,3 and 7 of CRC
	XORWF	CRC_CHECK,1
calculate_new_CRC_end
	return

;=================================================================================
WAIT_200ms
;	Wait as many times 200ms as the number in the workspace presents
	movwf	COUNTER_3
wait_200ms_1
	movlw	D'200'
	call	WAIT_1ms
	decfsz	COUNTER_3,1
	goto	wait_200ms_1
	return
;==================
WAIT_1ms
;	Wait as many times 1ms as the number in the workspace presents
	movwf	COUNTER_2
wait_1ms_1
	movlw	D'200'
	call	WAIT_5us
	decfsz	COUNTER_2,1
	goto	wait_1ms_1
	return
;==================
WAIT_5us
;	Wait as many times 5us as the number in the workspace presents
;	minimum 2x5us, call included
	addlw	D'255'
	movwf	COUNTER_1
wait_5us_1
	nop
	nop
	decfsz	COUNTER_1,1
	goto	wait_5us_1
	return
;==================
WAIT_4us
;	Wait 4 us (call included)
	return

;=================================================================================

THE_END;)
	End
