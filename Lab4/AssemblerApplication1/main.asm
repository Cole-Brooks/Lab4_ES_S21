;
; Lab4
;
; Created: 3/25/2021 11:11:15 AM
; Authors : Cole Brooks,
;			Thomas Butler
;
; ****************************** INITIALIZATION *****************************

; register usage
.def temp = R16

; LCD Connections
.equ LCD_port = PORTD
.equ LCD_ddr = DDRD

.equ LCD_4 = PORTC0
.equ LCD_5 = PORTC1
.equ LCD_6 = PORTC2
.equ LCD_7 = PORTC3

; LCD hardware info
.equ line_one = 0x00	; start of line 1 on the LCD
.equ line_two = 0x40	; start of line 2 on the LCD

; LCD instructions
.equ LCD_clear  = 0b00000001			; replaces all characters with spaces
.equ LCD_off = 0b00001000				; turn the display off
.equ LCD_on = 0b00001100				; turn the display

.equ LCD_4_bit_mode_init_1 = 0x33		; setting the screen to 4 bit mode requires
.equ LCD_4_bit_mode_init_2 = 0x32		; 3 different commands. 1 initializes in 8 bit mode
.equ LCD_4_bit_mode_set = 0x28			; 2 moves it to 

; ****************************** MAIN PROGRAM *******************************
start:
; init stack pointer to highest RAM address
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

; configure pins for data lines
	sbi LCD_ddr, LCD_4
	sbi LCD_ddr, LCD_5
	sbi LCD_ddr, LCD_6
	sbi LCD_ddr, LCD_7

	ldi R17, 0x01
rjmp start