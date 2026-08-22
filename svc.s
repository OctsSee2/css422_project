		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table
SYSTEMCALLTBL	EQU		0x20007B00 ; originally 0x20007500
SYS_EXIT		EQU		0x0		; address 20007B00
SYS_ALARM		EQU		0x1		; address 20007B04
SYS_SIGNAL		EQU		0x2		; address 20007B08
SYS_MALLOC		EQU		0x3		; address 20007B0C
SYS_FREE		EQU		0x4		; address 20007B10

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		IMPORT _timer_start
		IMPORT _signal_handler

; System Call Table Initialisation
		EXPORT	_syscall_table_init
_syscall_table_init
		; alarm
		LDR		R0, =0x20007b04			; write intended system call memory address for `alarm()` into R0
		LDR		R1, =_timer_start		; write memory address to `_timer_start` into R1
		STR		R1, [R0]				; write `_timer_start`'s memory address to 0x2007b04

		; signal
		LDR		R0, =0x2007b08			; write intended system call memory address for `signal()` into R0
		LDR		R1, =_signal_handler	; write memory address to `_signal_handler` into R1
		STR		R1, [R0]

		; malloc
		LDR		R0, =0x2007b0c			; write intended system call memory address for `malloc()` into R0
		LDR		R1, =_signal_handler	; write memory address to `_signal_handler` into R1
		STR		R1, [R0]

		; free
		LDR		R0, =0x2007b10			; write intended system call memory address for `free()` into R0
		LDR		R1, =_signal_handler	; write memory address to `_signal_handler` into R1
		STR		R1, [R0]

		MOV		pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table Jump Routine
        EXPORT	_syscall_table_jump
_syscall_table_jump
		; each address is separated by 4 bytes + syscall number is stored in R7 
		; 	-> use `LSL <some-register>, R7, #0x2` to translate it into the 
		;      proper jump offset from the jump table start memory address (at 0x20007b00)
		LSL		R2, R7, #0x2			; calculate the jump offset using R7 * 4 and store it into R2
		LDR		R3, =0x20007b00			; write start memory address for the jump table into R3
		ADD		R3, R3, R2				; increment R3's value by the jump offset amt
		
		LDR		R2, [R3]				; write the value stored at the offsetted memory address (should be `alarm()`) into R2
		CMP		R2, #0x0
		BXNE	R2						; branch to the function at that memory address if its not zero (don't save return address)

		MOV		pc, lr		
		END


		
