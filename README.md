# Lab4_ES_S21
In this lab, we will construct a brightness adjustable LED light source. 

# TODO
- Create and document circuit on the breadboard (make the schematic)
- Implement code to change the display on the LCD with the RPG
- Implement code to change the display on the LCD with the pushbutton switch
- Implement Timers Properly
- Update code to work with the LEDs

### DEVELOPER DOCUMENTATION
##### Display Code:
There are three display functions. They work by looking at dedicated registers and printing contents based on that information.

printDCStatus: prints the duty cycle line of the LCD looking at registers 20 and 21 (duty_cycle_first, duty_cycle_sec - named referring to the digit which they represent). 

printLedStatus: prints the LED status based on register 22 (LED_on_off). If LED_on_off = 0, then the LED is off.  Else the LED is on.

printScreen: this function is used at the start to initialize the screen - all it does is call the other two functions.

