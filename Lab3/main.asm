;
; Lab3.asm
;
; Created: 2/28/2023 9:49:10 PM
; Author : stlondon, mpass
;

.include "m328Pdef.inc"
.cseg
.org 0

; 7-segement bit-patterns
;0 = 3F
.equ d0=0x3F

;1 = 06
.equ d1=0x06

;2 = 5B
.equ d2=0x5B

;3 = 4F
.equ d3=0x4F

;4 = 66
.equ d4=0x66

;5 = 6D
.equ d5=0x6D

;6 = 7D
.equ d6=0x7D

;7 = 07
.equ d7=0x07

;8 = 7F
.equ d8=0x7F

;9 = 6F
.equ d9=0x6F

;A = 77
.equ dA=0x77

;B = 7C
.equ dB=0x7C

;C = 39
.equ dC=0x39

;D = 5E
.equ dD=0x5E

;E = 79
.equ dE=0x79

;F = 71
.equ dF=0x71

;. = 80
.equ d_dot=0x80

;- = 40
.equ d_dash=0x40

;_ = 08
.equ d_underscore=0x08


.equ SERIAL=0		; SERIAL is PB0 (Pin 8)
.equ RCLK=1			; RCLK is PB1 (Pin 9)
.equ SRCLK=2		; SRCLK is PB2 (Pin 10)
.equ BUTTON0=3		; BUTTON0 is PB3 (Pin 11)
.equ LED=5			; Display LED is PB5 (Pin 13)

.equ RPG0=2			; RPG0 is PD2 (Pin 2)
.equ RPG1=3			; RPG1 is PD3 (Pin 3)

; Data-direction register setup
sbi DDRB, SERIAL	; Set SERIAL (PB0/Pin 8) as output
sbi DDRB, RCLK		; Set RCLK (PB1/Pin 9) as output
sbi DDRB, SRCLK		; Set SRCLK (PB2/Pin 10) as output
cbi DDRB, BUTTON0	; Set BUTTON0 (PB3/Pin 11) as input
sbi DDRB, LED		; Set LED (Pin 13) as output

cbi DDRD, RPG0		; Set RPG0 (PD2/Pin 2) as input
cbi DDRD, RPG1		; Set RPG1 (PD3/Pin 3) as input

; Initialize registers to 0
ldi R16, 0	; Current digit entered
ldi R20, 0	; Previous reading of RPG
ldi R21, 0	; Current reading of RPG, timer counter
ldi R22, 0	; Comparison register for RPG read
ldi R23, 0	; Current digit being entered
ldi R24, 0	; Digit 1
ldi R25, 0  ; Digit 2
ldi R26, 0	; Digit 3
ldi R27, 0	; Digit 4
ldi R28, 0	; Digit 5

; Replace with your application code
start:
    sbis PINB, BUTTON0
	rcall wait_for_release_button0

	rcall read_rpg

	rcall resolve_digits
	rcall display

    rjmp start


read_rpg:
	in R21, PIND	; Read all pins on Port D simultaneously
	lsr R21			; Shift contents to the right
	lsr R21	
	andi R21, 0x03	; Ignore all but two least-significant bits
	mov R22, R21
	lsl R22			; Make room for previous reading into R22
	lsl R22
	or R22, R20		; Load previous reading (R20) into current comparison (R22)
	cpi R22, 0x0D	;  (Reading now in detent after clockwise rotation)
	breq do_clockwise
	cpi R22, 0x0E	; (Reading now in detent after counter-clockwise rotation)
	breq do_counterclockwise
	rjmp end_read_rpg

do_clockwise:
	rcall increment_counter
	cpi R23, 0			; Motion from RPG should change the dash display to a digit. If R23 is 0, the dash is being displayed. Motion should cancel this.
	brne end_do_clockwise
	inc R23
	clr R16
end_do_clockwise: 
	rjmp end_read_rpg

do_counterclockwise:
	rcall decrement_counter
	cpi R23, 0
	brne end_do_counterclockwise
	inc R23
	clr R16
end_do_counterclockwise:
	rjmp end_read_rpg

end_read_rpg:
	mov R20, R21	; Save current reading as previous reading
	ret


enter_digit:
try_1:
	cpi R23, 1
	breq enter_1
	rjmp try_2
enter_1:
	mov R24, R16
	inc R23
	rcall flash_digit
	rjmp end_enter_digit
try_2:
	cpi R23, 2
	breq enter_2
	rjmp try_3
enter_2:
	mov R25, R16
	inc R23
	rcall flash_digit
	rjmp end_enter_digit
try_3:
	cpi R23, 3
	breq enter_3
	rjmp try_4
enter_3:
	mov R26, R16
	inc R23
	rcall flash_digit
	rjmp end_enter_digit
try_4:
	cpi R23, 4
	breq enter_4
	rjmp try_5
enter_4:
	mov R27, R16
	inc R23
	rcall flash_digit
	rjmp end_enter_digit
try_5:
	cpi R23, 5
	breq enter_5
	rjmp end_enter_digit
enter_5:
	mov R28, R16
	rcall test_lock_sequence
	clr R23 ; Reset digit counter to 0. Begin displaying dash and allowing input.
	rjmp end_enter_digit

end_enter_digit:
	ret

test_lock_sequence:
; Valid sequence - DA181
; Test each digit one by one
	cpi R24, 0x0D		; Digit 1
	brne fail_sequence
	cpi R25, 0x0A		; Digit 2
	brne fail_sequence
	cpi R26, 0x01		; Digit 3
	brne fail_sequence
	cpi R27, 0x08		; Digit 4
	brne fail_sequence
	cpi R28, 0x01		; Digit 5
	brne fail_sequence
	; All digits are correct. Initiate success sequence.
success_sequence: ; If success occurs, display Arduino LED and display "." on 7-segment for 5 seconds
	ldi R17, d_dot
	rcall display
	sbi PORTB, LED	; Turn on Arduino LED
	ldi R29, 5		; Delay 5 seconds

loop_delay_5s:
	rcall delay_1s
	dec R29
	brne loop_delay_5s

	cbi PORTB, LED ; Turn off Arduino LED
	rjmp end_test_lock_sequence


fail_sequence: ; If failure occurs, display an underscore while delaying for 9 seconds
	ldi R17, d_underscore
	rcall display
	ldi R29, 9 ; Delay 9 seconds
loop_delay_9s:
	rcall delay_1s
	dec R29
	brne loop_delay_9s


end_test_lock_sequence:
	ret


flash_digit:
	ldi R17, 0
	rcall display
	rcall delay_500ms

	rcall resolve_digits
	rcall display
	rcall delay_500ms

	ldi R17, 0
	rcall display
	rcall delay_500ms

	rcall resolve_digits
	rcall display
	rcall delay_500ms

	ret



increment_counter:
; Don't allow incrementing past F.
	cpi R16, 15
	breq end_increment_counter
	inc R16
end_increment_counter:
	ret

decrement_counter:
; Don't allow decrementing below 0.
	cpi R16, 0
	breq end_decrement_counter
	dec R16
end_decrement_counter:
	ret

wait_for_release_button0:
; Note: Button is Active-Low. So I/O bit will be set when released.
; Behavior: If button is held for >= 1s, counter is reset.
; Otherwise, if released before 1s, counter is incremented.
	push R21
	clr R21 ; Initialize button timer to 0

button0_held:
	rcall delay_10ms
	rcall increment_button_timer
	sbis PINB, BUTTON0
	rjmp button0_held

	cpi R21, 100
	breq reset_counter

	rcall enter_digit
	rjmp end_wait_for_release_button0

reset_counter:
	clr R23	; Reset to display dash
	clr R16	; Clear main counter

end_wait_for_release_button0:
	pop R21
	ret

increment_button_timer:
	cpi R21, 100
	breq end_increment_button_timer
	inc R21
end_increment_button_timer:
	ret

resolve_digits:
; R17 - digit0

try_dash:
	cpi R23, 0
	breq set_dash
	rjmp try_00
set_dash:
	ldi R17, d_dash
	rjmp end_resolve

try_00:
	cpi R16, 0
	breq set_00
	rjmp try_01
set_00:
	ldi R17, d0; 0
	rjmp end_resolve

try_01:
	cpi R16, 1
	breq set_01
	rjmp try_02
set_01:
	ldi R17, d1; 1
	rjmp end_resolve

try_02:
	cpi R16, 2
	breq set_02
	rjmp try_03
set_02:
	ldi R17, d2; 2
	rjmp end_resolve

try_03:
	cpi R16, 3
	breq set_03
	rjmp try_04
set_03:
	ldi R17, d3; 3
	rjmp end_resolve

try_04:
	cpi R16, 4
	breq set_04
	rjmp try_05
set_04:
	ldi R17, d4; 4
	rjmp end_resolve

try_05:
	cpi R16, 5
	breq set_05
	rjmp try_06
set_05:
	ldi R17, d5; 5
	rjmp end_resolve

try_06:
	cpi R16, 6
	breq set_06
	rjmp try_07
set_06:
	ldi R17, d6; 6
	rjmp end_resolve

try_07:
	cpi R16, 7
	breq set_07
	rjmp try_08
set_07:
	ldi R17, d7; 7
	rjmp end_resolve

try_08:
	cpi R16, 8
	breq set_08
	rjmp try_09
set_08:
	ldi R17, d8; 8
	rjmp end_resolve

try_09:
	cpi R16, 9
	breq set_09
	rjmp try_10
set_09:
	ldi R17, d9; 9
	rjmp end_resolve

try_10:
	cpi R16, 10
	breq set_10
	rjmp try_11
set_10:
	ldi R17, dA; A
	rjmp end_resolve

try_11:
	cpi R16, 11
	breq set_11
	rjmp try_12
set_11:
	ldi R17, dB; B
	rjmp end_resolve

try_12:
	cpi R16, 12
	breq set_12
	rjmp try_13
set_12:
	ldi R17, dC; C
	rjmp end_resolve

try_13:
	cpi R16, 13
	breq set_13
	rjmp try_14
set_13:
	ldi R17, dD; D
	rjmp end_resolve

try_14:
	cpi R16, 14
	breq set_14
	rjmp try_15
set_14:
	ldi R17, dE; E
	rjmp end_resolve

try_15:
	cpi R16, 15
	breq set_15
	rjmp end_resolve
set_15:
	ldi R17, dF; F
	rjmp end_resolve

end_resolve:
	ret

display:
; Input - R17:digit0 

	; backup used registers on stack
	push R17
	push R18
	in R18, SREG
	push R18
	ldi R18, 8 ; loop --> test all 8 bits


loop_digit0:
	rol R17 ; rotate left trough Carry
	brcs set_ser_in_1_digit0 ; branch if Carry is set
	; put code here to set SER to 0
	cbi PORTB,SERIAL
	rjmp end_digit0
set_ser_in_1_digit0:
	; put code here to set SER to 1
	sbi PORTB,SERIAL
end_digit0:
	; put code here to generate SRCLK pulse
	cbi PORTB,SRCLK
	nop
	sbi PORTB,SRCLK
	nop
	cbi PORTB, SRCLK
	dec R18
	brne loop_digit0


	; put code here to generate RCLK pulse
	cbi PORTB,RCLK
	nop
	sbi PORTB,RCLK
	nop
	cbi PORTB,RCLK

	; restore registers from stack
	pop R18
	out SREG, R18
	pop R18
	pop R17

	ret


; ------------ Delay times ------------


delay_1s:
	rcall delay_500ms
	rcall delay_500ms
	ret


delay_500ms:
	; Backup registers used onto the stack
	push r16
	push r17
	push r18
	push r19
	push r20

	ldi r17, 0
	ldi r18, 0
	ldi r19, 0
	ldi r20, 0

	; Initialize timer
	ldi r16, (1 << CS02)	; Set prescaler to 256
	out TCCR0B, r16			; Set TImer0 control register B
	clr r16
	out TCCR0A, r16			; Set Timer0 to normal mode
	out TCNT0, r16			; Set Timer0 to 0

loop_delay_500ms:
	in r17, TCNT0	; Reader Timer0 value
	mov r18, r17	; Copy current reading so that arithmetic can be performed on r17
	sub r17, r16	; Get time difference between current reading (r17) and previous reading (r16)
	mov r16, r18	; Save current reading as previous reading
	add r19, r17	; Add time difference to running total
	brvs add_to_counter_500ms
	rjmp loop_delay_500ms

add_to_counter_500ms:
	inc r20	; Amount of time has surpassed 256 counter ticks (256 * (1/(16000000Hz/256)) = 0.004096s)
	cpi r20, 123 ; (Check to see if 123 overflows have occurred. 123 * 0.004096s = 0.503808s)
	breq end_delay_500ms
	rjmp loop_delay_500ms

end_delay_500ms:
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	ret



delay_10ms:
	; Backup registered used onto the stack
	push r16
	push r17
	push r18
	push r19
	push r20

	ldi r17, 0
	ldi r18, 0
	ldi r19, 0
	ldi r20, 0

	; Initialize timer
	ldi r16, 0b00000010		; Set prescaler value to 8
	out TCCR0B, r16			; Write prescaler value to control register
	clr r16
	out TCCR0A, r16			; Set Timer0 to normal mode
	out TCNT0, r16			; Set Timer0 to 0

loop_delay_10ms:
	in r17, TCNT0	; Reader Timer0 value
	mov r18, r17	; Copy current reading so that arithmetic can be performed on r17
	sub r17, r16	; Get time difference between current reading (r17) and previous reading (r16)
	mov r16, r18	; Save current reading as previous reading
	add r19, r17	; Add time difference to running total
	brvs add_to_counter_10ms
	rjmp loop_delay_10ms

add_to_counter_10ms:
	inc r20	; Amount of time has surpassed 256 counter ticks (256 * (1/(16000000Hz/8)) = 0.000128s)
	cpi r20, 78 ; (Check to see if 78 overflows have occurred. 78 * 0.000128s = 0.009984s)
	breq end_delay_10ms
	rjmp loop_delay_10ms

end_delay_10ms:
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	ret

.exit