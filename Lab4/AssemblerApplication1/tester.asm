;
; lab4-misc.asm
;
; Created: 4/4/2021 9:22:55 PM
; Author : tombu
;


; PD5 - PWM pin for LEDS

; PD2 - External Interupt 0 for PBS

; sei/cli  -> gloabally enable/disable interrupts

;;;;;;;;;;;;;;;;;
; from lecture example
; TCTN0 -> 256 - n = 28
; CS02: c00 = 100
; normal mode -> WGM02: WGM00 = 000
; TCCR0A = 0x00
; TCCR0B = 0x04


;;;;;;;;;;;;;;;;
; Example ISR
; extint: push r0 ; save r0 on stack
	;     ...
	;	  pop r0 ; restore r0
	;	  reti   ; return and enable interrupts

.include "m328Pdef.inc"
.def tmp1 = r23 ; Use r23 for temporary variables
.def tmp2 = r24 ; use r24 for temporary values
.cseg
.org 0


; PD5 - OC0B -> to transistor (external output for the Timer/Counter0 
		;Compare Match B - must be set as output )
sbi DDRD,5 ; set pin as output


; PD2 - External Interupt 0 for PBS

; sei/cli  -> gloabally enable/disable interrupts


; configure TIMER0 as PWM ( not correct )
ldi tmp1,0b00110011 ; fast PWM mode, inverting mode (sets OC0b on compare match)
out TCCR0A, tmp1 
ldi tmp1,0x01 ; no prescale (change for PWM?)
out TCCR0B,tmp1 
ldi tmp1,0x00 ; (change for PWM?)
out TCNT0,tmp1

main:
	;rcall delay -- LEDS on without calling delay (change to non-inverting to turn off?)

	rjmp main



delay_long:
    rcall delay
    sbiw Z,1
    brne delay_long
    ret

delay:
    in tmp2,TCNT0 ; Get counter value 
    cpi tmp2,0x00 ; is it zero?
    brne delay ; no --> wait more






