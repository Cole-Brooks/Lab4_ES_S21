;
; Lab4
;
; Created: 3/25/2021 11:11:15 AM
; Authors : Cole Brooks,
;			Thomas Butler
;
; ****************************** MACROS / REGISTER DEFINES *****************************
; register usage
.def temp						= R16
.def temp2						= R17
; R18 and 19 are used in timers
.def duty_cycle_first			= R20
.def duty_cycle_sec				= R21
.def duty_cycle_third			= R22 // only used when duty cycle = 100
// NOTE: if LED_on_off != 0, then LED is on
.def LED_on_off					= R23 

; INTERRUPT VECTOR TABLE
.org 0
rjmp RESET
.org INT0addr
rjmp toggleLed
.org 0x000A
rjmp rpgChangeDetected
.org 0x34

RESET:
	; Set interrupt to trigger when input is low
	ldi temp, (1<<ISC01)|(1<<ISC00)
	sts EICRA, temp

	ldi temp, (1<<INT0)
	out EIMSK, temp

	ldi temp, (1<<INTF0)
	out EIFR, temp

	clr temp
	out DDRD, temp

	// 
	ldi temp, 0b00000100
	sts PCICR, temp

	// Enable pins 3 and 4 for internal interrupt
	ldi temp, 0b10010000
	sts PCMSK2, temp

	; Global interrupt enable
	sei



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macro: COMMAND MODE: 
; Purpose: switches LCD to command mode
; NOTE: ANY SUBROUTINE THAT CALLS COMMAND MODE IS RESPONSIBLE
;		FOR SWITCHING BACK TO CHAR MODE WHEN IT'S FINISHED
.macro COMMAND_MODE
	cbi PORTB,5
	ldi temp, 40
	rcall delayTx1ms
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macro: CHAR_MODE: 
; Purpose: switches LCD to data mode
.macro CHAR_MODE
	sbi PORTB, 5
	ldi temp, 40
	rcall delayTx1ms
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macro: CLEAR_E
; Purpose: Clears the enable pin
.macro CLEAR_E
	cbi PORTB,3
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macro: SET_E: 
; Purpose: sets the enable pin
.macro SET_E
	sbi PORTB, 3
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macro: DATA_SEND: 
; Purpose: sends the contents of temp2 nibble by nibble to data pins
; NOTE: Make sure that you're in the mode you expect to be in when
;		making DATA_SEND calls
.macro DATA_SEND
	swap temp2			; get upper nibble ready
	OUT PORTC, temp2	; send upper nibble
	rcall LCDStrobe		; flash enable 
	rcall delay1ms
	swap temp2			; get lower nibble ready
	OUT PORTC, temp2	; send lower nibble
	rcall LCDStrobe		
	ldi temp, 50
	rcall delayTx1ms
.endmacro

; LCD Connections
.equ LCD_port = PORTD
.equ LCD_ddr = DDRD

.equ LCD_4 = PORTC0
.equ LCD_5 = PORTC1
.equ LCD_6 = PORTC2
.equ LCD_7 = PORTC3 

.equ LCD_rs = PORTB5
.equ LCD_e = PORTB3

; LCD hardware info
.equ line_one = 0x00	; start of line 1 on the LCD
.equ line_two = 0x40	; start of line 2 on the LCD

; LCD instructions
.equ LCD_clear  = 0x01					; replaces all characters with spaces
.equ LCD_off = 0b00001000				; turn the display off
.equ LCD_on = 0b00001100				; turn the display

.equ LCD_4_bit_mode_init_1 = 0x33		; setting the screen to 4 bit mode requires
.equ LCD_4_bit_mode_init_2 = 0x32		; 3 different commands. 1 initializes in 8 bit mode
.equ LCD_4_bit_mode_set = 0x28			; 2 moves it to 

; ****************************** MAIN PROGRAM *******************************
start:
; init stack pointer to highest RAM address;
	cli
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	ldi temp, 0xff
	out DDRC, temp
	out DDRC, temp

; configure pins for data lines
	sbi LCD_ddr, LCD_4
	sbi LCD_ddr, LCD_5
	sbi LCD_ddr, LCD_6 
	sbi LCD_ddr, LCD_7

	ldi R17, 0x01

	sbi DDRB, 3 ; enable
	sbi DDRB, 5 ; RS
	sbi DDRC, 0 ; D4
	sbi DDRC, 1 ; D5
	sbi DDRC, 2 ; D6
	sbi DDRC, 3 ; D7

; configure input
	cbi DDRD, 2

; init LCD
	rcall init_LCD 
	ldi temp, 255
	rcall delayTx1ms

; init LED (default: ON) and Duty Cycle (50)
	ldi duty_cycle_first, 0b00110101
	ldi duty_cycle_sec, 0b00110000
	ldi duty_cycle_third, 0b00100000
	ldi LED_on_off, 0x01

	sei

main:
; print screen
	rcall printScreen

; create static string in program memory
;.cseg
;	msg1: .db "DC = ", 0x00
;	ldi r30,LOW(2*msg1) ; load Z register low
;	ldi r31,HIGH(2*msg1) ; load Z register high

;	CHAR_MODE ; make sure in character mode
;	CLEAR_E ; make sure E is cleared
;	rcall displayCString

	bruh:
	nop
	nop
	nop
	nop
rjmp bruh

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: toggleLED
; purpose: Handles the push button input. Toggles the 
;		   Current status of the LED (on/off)
 toggleLED:
	cpi LED_on_off, 0x00
	brne toggle_off

	// The led is off, turn it on
	ldi LED_on_off, 0x01
	rcall printLedStatus
	reti

	// The led is on, turn it off
	toggle_off:
	ldi LED_on_off, 0x00
	rcall printLedStatus
	reti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: rpgChangeDetected
; purpose: Handles RPG changes. Should change duty cycle of LED
;		   Called via interrupt.
 rpgChangeDetected:
	sbic PIND, 4
	rcall incrementDC

	sbic PIND, 7
	rcall decrementDC

	ldi temp, 100
	rcall delayTx1ms

	rcall printDCStatus
	reti

	;************* Helper Functions *****************;
	incrementDC:
		; first, check if duty cycle = 100, if it is, just return
		cpi duty_cycle_third, 0b00110000
		brne not_max

		ret
		not_max:

		; Now, check if duty cycle = 95. If it is, then need to add third digit
		cpi duty_cycle_first, 0b00111001
		brne third_set
		cpi duty_cycle_sec, 0b00110101
		brne third_set

		ldi duty_cycle_first, 0b00110001
		ldi duty_cycle_sec, 0b00110000
		ldi duty_cycle_third, 0b00110000
		ret

		third_set:
		; If second digit is zero, then add five to this register
		; If second digit is five, set this register to 0 and increment first digit
		cpi duty_cycle_sec, 0b00110101
		breq incrementFirst
		ldi temp, 0b00000101
		ADD duty_cycle_sec, temp
		ret

		incrementFirst:
		ldi temp, 0b00000001
		ADD duty_cycle_first, temp
		ret

	decrementDC:
		; first, check if dc = 0, if it is, just return
		cpi duty_cycle_first, 0b00110000
		brne not_min
		cpi duty_cycle_sec, 0b00110000
		brne not_min

		ret
		not_min:

		; next, check if dc = 100. If it is, we need to set it to 95
		cpi duty_cycle_third, 0b00110000
		brne not_max_dec

		ldi duty_cycle_first, 0b00111001
		ldi duty_cycle_sec, 0b00110101
		ldi duty_cycle_third, 0b00100000
		ret

		not_max_dec:
		cpi duty_cycle_sec, 0b00110101
		breq decrement_sec

		ldi temp, 0b00000001
		SUB duty_cycle_first, temp
		ret

		decrement_sec:
		ldi temp, 0b00000101
		SUB duty_cycle_sec, temp

		ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: init_LCD
; purpose: initializes the LCD
init_LCD:
	rcall delay100ms
	
	COMMAND_MODE

	ldi temp,255
	rcall delayTx1ms

	ldi temp2, 0x33 ; set 8-bit mode
	DATA_SEND
	ldi temp,255
	rcall delayTx1ms

	ldi temp2, 0x32 ; set 8-bit mode (3) then 4 bit mode (2)
	DATA_SEND
	ldi temp,255
	rcall delayTx1ms

	ldi temp2, 0x28 ; set 4-bit mode, two rows, 5x7 chars
	DATA_SEND
	ldi temp,255
	rcall delayTx1ms

	ldi temp2, LCD_clear ; clear display
	DATA_SEND
	ldi temp,255
	rcall delayTx1ms

	ldi temp2, 0b00001100 ; display on, underline off, blink off
	DATA_SEND
	ldi temp,255
	rcall delayTx1ms

	ldi temp2, 0x06 ; display shift off, address auto increment
	DATA_SEND
	ldi temp,255
	rcall delayTx1ms

	CHAR_MODE					
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: printScreen
; purpose: prints data to the string
; NOTE: ASSUMES THAT WE'RE IN CHAR MODE
printScreen:
	rcall printDCStatus
	rcall printLedStatus
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: printDCStatus
; purpose: prints duty cycle in proper location
; NOTE: ASSUMES THAT WE'RE IN CHAR MODE
printDCStatus:
	// Move cursor to the right position
	rcall moveCursorToDC
	
	// Duty Cycle digits
	mov temp2, duty_cycle_first
	DATA_SEND
	rcall display_delay
	mov temp2, duty_cycle_sec
	DATA_SEND
	rcall display_delay
	mov temp2, duty_cycle_third
	DATA_SEND
	rcall display_delay 

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: printLedStatus
; purpose: prints Led status in the proper location
; NOTE: ASSUMES THAT WE'RE IN CHAR MODE
printLedStatus:
	// Move cursor to the right position
	rcall moveCursorToLED

	cpi LED_on_off, 0x00
	breq off

	// on
	ldi temp2, 0b01001111
	DATA_SEND
	rcall display_delay

	ldi temp2, 0b01001110
	DATA_SEND
	rcall display_delay

	ldi temp2, 0b00010000
	DATA_SEND
	rcall display_delay
	ret

	// off
	off:
	ldi temp2, 0b01001111
	DATA_SEND
	rcall display_delay

	ldi temp2, 0b01000110
	DATA_SEND
	rcall display_delay

	ldi temp2, 0b01000110
	DATA_SEND
	rcall display_delay

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: LCDStrobe
; purpose: flashes the rs port
LCDStrobe:
	SET_E
	nop
	nop
	nop
	nop
	CLEAR_E
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: delayTx1ms
; purpose: dealys for 1ms x temp
delayTx1ms:
	rcall delay1ms
	dec temp
	brne delayTx1ms
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: delay1ms
; purpose: delays for ~1ms (1004 us)
delay1ms:
    ldi  r18, 21
    ldi  r19, 199
	L1: dec  r19
    brne L1
    dec  r18
    brne L1
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: delay100ms
; purpose: delays for ~1ms (1004 us)
delay100ms:
	ldi temp, 100
	rcall delayTx1ms
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: display_delay
; purpose: delays for ~40 ms. Enough elapsed time for 
;		  display to prep for next DATA_SEND
display_delay:
	ldi temp, 40
	rcall delayTx1ms
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: displayCString
; purpose: writes a string to the LCD
displayCString:
	lpm		r0,Z+		; r0 <--first byte
	tst		r0			; Reached end of message ?
	breq	done		; Yes => quit
	swap	r0			; Upper nibble in place
	out		PORTC,r0	; Send upper nibble out
	rcall	LCDStrobe	; Latch nibble
	swap	r0          ; Lower nibble in place
	out		PORTC,r0	; Send lower nibble out
	rcall	LCDStrobe	; Latch nibble
	rjmp	displayCstring
done:
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: moveCursorToDC
; purpose: moves LCD cursor to the proper position
;		   to rewrite the Duty Cycle
moveCursorToDC:
	COMMAND_MODE

	// Move to line 1
	rcall display_delay
	ldi temp, 0x00
	out PORTC,temp
	rcall LCDStrobe
	rcall display_delay
	ldi temp, 0x02
	out PORTC,temp
	rcall LCDStrobe

	CHAR_MODE

	// Move cursor to proper position by rewriting top of screen
	// TODO - move cursor without rewriting characters -- takes too long
	// and makes the screen feel sluggish.
	ldi temp2, 0b01000100 
	DATA_SEND
	rcall display_delay
	ldi temp2, 0b01000011
	DATA_SEND
	rcall display_delay
	ldi temp2, 0b00111010
	DATA_SEND
	rcall display_delay
	ldi temp2, 0b00010000
	DATA_SEND
	rcall display_delay

	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: moveCursorToLED
; purpose: moves LCD cursor to the proper position to 
;		   rewrite the LED status
moveCursorToLED:
	COMMAND_MODE

	ldi temp, 0x0C
	out PORTC,temp
	rcall LCDStrobe
	// Cursor offset
	ldi temp,0x00
	out PORTC, temp
	rcall LCDStrobe

	CHAR_MODE


	// Move to LED position by rewriting LED: 
	ldi temp2, 0b01001100
	DATA_SEND
	rcall display_delay
	ldi temp2, 0b01000101
	DATA_SEND
	rcall display_delay
	ldi temp2, 0b01000100
	DATA_SEND
	rcall display_delay
	ldi temp2, 0b00111010
	DATA_SEND
	rcall display_delay
	ldi temp2, 0b00010000
	DATA_SEND
	rcall display_delay

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: moveToLine2
; purpose: moves LCD cursor to line 2
moveToLine2:
	COMMAND_MODE

	ldi temp, 0x0C
	out PORTC,temp
	rcall LCDStrobe
	// Cursor offset
	ldi temp,0x00
	out PORTC, temp
	rcall LCDStrobe

	CHAR_MODE

	ret