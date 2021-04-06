;
; Lab4
;
; Created: 3/25/2021 11:11:15 AM
; Authors : Cole Brooks,
;			Thomas Butler
;

.include "m328Pdef.inc"
.cseg


; ****************************** MACROS / REGISTER DEFINES *****************************
; register usage
.def temp						= R16
.def temp2						= R17
.def temp3						= R18
; R18 and 19 are used in timers
.def duty_cycle_first			= R20
.def duty_cycle_sec				= R21
.def duty_cycle_third			= R22 // only used when duty cycle = 100
// NOTE: if LED_on_off != 0, then LED is on
.def LED_on_off					= R23 
;;;;; if works replace with r20 and delete r21
.def ledDC						= R24

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
	ldi temp, (1<<ISC11)|(0<<ISC10)
	sts EICRA, temp

	ldi temp, (1<<INT0)
	out EIMSK, temp

	ldi temp, (1<<INTF0)
	out EIFR, temp

	ldi temp, 0b00000100
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

; PD5 - OC0B -> to transistor (external output for the Timer/Counter0 
;Compare Match B - must be set as output )
	sbi DDRD,5 ; set pin as output

; configure input
	cbi DDRD, 2

; init LCD
	rcall init_LCD 
	ldi temp, 255
	rcall delayTx1ms

; init LED (default: OFF) and Duty Cycle (50)
	ldi duty_cycle_first, 0b00110101
	ldi duty_cycle_sec, 0b00110000
	ldi duty_cycle_third, 0b00100000
	ldi LED_on_off, 0x00

; configure TIMER0 as PWM 
	ldi temp,0b00110011 ; fast PWM mode,inverting mode 
	out TCCR0A, temp 
	ldi temp,0b00001011 ; 64 prescale
	out TCCR0B,temp 
	ldi temp,100  ; TOP = 100
	out OCR0A,temp
	ldi temp,0 ; start counter at zero
	out TCNT0,temp
; brightness starts at 50%, LED off
	ldi ledDC,49 ;increments 
	ldi temp,101 
	out OCR0B,temp

; interrupt global enable
	sei

main:
; print screen
	rcall printScreen

	loop:
	; All interactions with the circuit from here on out
	; are interrupt driven.  Main loop does nothing.
rjmp loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: toggleLED
; purpose: Handles the push button input. Toggles the 
;		   Current status of the LED (on/off)
 toggleLED:

	cpi LED_on_off, 0x00
	brne toggle_off

	// The led is off, turn it on
	ldi LED_on_off, 0x01
	out OCR0B,ledDC
	rcall printLedStatus
	reti

	// The led is on, turn it off
	toggle_off:
	ldi LED_on_off, 0x00
	ldi temp,101
	out OCR0B,temp
	rcall printLedStatus
	reti

	filter_press:
	reti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: pbsDebounce
; purpose: debounces the pushbutton switch
pbsDebounce:
	ldi temp, 5  
	ldi temp2, 0
	
	pbs_pressed:
		rcall delay1ms
		sbic PIND, 2
		inc temp2
		dec temp
		brne pbs_pressed

	cpi temp2, 4
	brlt filter_press
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function: rpgChangeDetected
; purpose: Handles RPG changes. Should change duty cycle of LED
;		   Called via interrupt.
rpgChangeDetected:
	cpi LED_on_off, 0x00
	breq force_ret

	sbic PIND, 4
	rcall incrementDC

	sbic PIND, 7
	rcall decrementDC

	ldi temp, 100
	rcall delayTx1ms

	rcall printDCStatus
	force_ret:
	reti

	;************* Helper Functions *****************;
	incrementDC:
		; if led is at 100 currently, just skip this whole thing
		cpi duty_cycle_third, 0b00110000
		breq force_ret

		; check if led off
		cpi ledDC,101
		brne led_ONinc
		
		led_ONinc:
		; check if ledDC at TOP
		cpi ledDC,99
		brne not_max

		ret

		not_max:
		; increase by 5%
		ldi temp,5
		sub ledDC,temp
		out OCR0B, ledDC ; update led duty cycle

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
		; check if dc = 5. If it is, just force return
		cpi duty_cycle_first, 0b00110000
		brne not_dc_min
		cpi duty_cycle_sec, 0b00110101
		brne not_dc_min
		rjmp force_ret

		not_dc_min:
		; check if led off
		cpi ledDC,101
		brne led_ONdec
		
		led_ONdec:
		; check if ledDC = 4
		cpi ledDC,4
		brne not_min

		ret

		not_min:
		; decrease by 5%
		ldi temp,5
		add ledDC,temp
		out OCR0B, ledDC ; update led duty cycle
		
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

	;cpi LED_on_off, 0x00
	cpi led_on_off,0x00
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
