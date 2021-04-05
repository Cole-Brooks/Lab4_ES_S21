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


; configure TIMER0 as PWM 
ldi tmp1,0b00110011 ; fast PWM mode, inverting mode (sets OC0b on compare match)
out TCCR0A, tmp1 
ldi tmp1,0b00001001 ; no prescale, WGM02 = 1 
out TCCR0B,tmp1 
ldi tmp1,0xff ; (change for PWM?)
out TCNT0,tmp1
;ldi tmp1, 0x01  ; 00-ff adjusts brightness level
;out OCR0A,tmp1


main:
	ldi tmp1,0x01 ; low brightness
	out OCR0A,tmp1

	rcall delay_long

	ldi tmp1,0xff ; high brightness
	out OCR0A,tmp1

	rcall delay_long
	

	rjmp main

 delay_long:
      ldi   r23,255      ; r23 <-- Counter for outer loop
  d1: ldi   r24,253     ; r24 <-- Counter for level 2 loop 
  d2: ldi   r25,253     ; r25 <-- Counter for inner loop
  d3: dec   r25
      nop               ; no operation 
      brne  d3 
      dec   r24
      brne  d2
      dec   r23
      brne  d1
      ret
.exit