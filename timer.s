		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Timer Definition
STCTRL		EQU		0xE000E010		; SysTick Control and Status Register
STRELOAD	EQU		0xE000E014		; SysTick Reload Value Register
STCURRENT	EQU		0xE000E018		; SysTick Current Value Register
	
STCTRL_STOP	EQU		0x00000004		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 0, Bit 0 (ENABLE) = 0
STCTRL_GO	EQU		0x00000007		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 1, Bit 0 (ENABLE) = 1
STRELOAD_MX	EQU		0x00FFFFFF		; MAX Value = 1/16MHz * 16M = 1 second
STCURR_CLR	EQU		0x00000000		; Clear STCURRENT and STCTRL.COUNT	
SIGALRM		EQU		14			; sig alarm

; System Variables
SECOND_LEFT	EQU		0x20007B80		; Secounds left for alarm( )
USR_HANDLER     EQU		0x20007B84		; Address of a user-given signal handler function	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer initialization
; void timer_init( )
		EXPORT		_timer_init
_timer_init
		; stop SysTick
		LDR		R1, =0xe000e010			; write memory address of the SYST_CSR into R1
		MOV		R2, #0x4				; write 0x4 to R2 (100 -> lowest 2 bits zeroed, 3rd bit set)
		STR		R2, [R1]				; write R2 (currently 0x4) into the SYST_CSR
		
		; load max. value to SYST_RVR
		LDR		R1, =0xe000e014			; write the memory address of the SYST_RVR into R1
		MOV		R2, #0x00ffffff
		STR		R2, [R1]				; write the value `0x00ffffff` into the SYST_RVR
	
		MOV		pc, lr		; return to Reset_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer start
; int timer_start( int seconds )
		EXPORT		_timer_start
_timer_start
		; save current `seconds` value for return
		; and write the new `seconds` argument
		LDR		R1, =0x20007b80			; write *current* `seconds` value location into R1
		LDR		R2, [R1]				; write R1's value (*current* `seconds` value) into R2 (to return later in R0)
		STR		R0, [R1]				; write *new* `seconds` value from R0 into the memory location pointed to by R1
        MOV		R0, R2					; write R2's value into R0 as the return value

		; enable SysTick
		LDR		R1, =0xe000e010			; write memory address of the SYST_CSR into R1
		MOV		R2, #0x7				; write 0x7 to R2 (111 -> lowest 3 bits set)
		STR		R2, [R1]				; write R2 (currently 0x7) into the SYST_CSR
		
		; clear SYST_CVR
		LDR		R1, =0xe000e018			; write memory address of the SYST_CVR into R1
		MOV		R2, #0x0				; write zero into R2
		STR		R2, [R1]				; write R2 (currently zero) into the SYST_CVR addr
		
		MOV		pc, lr					; return to SVC_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void timer_update( )
		EXPORT		_timer_update
_timer_update
		; decrement `seconds`
		LDR		R1, =0x20007b80			; read remaining `seconds` value
		LDR		R2, [R1]
		SUBS	R2, R2, #1				; decrement it by 1 second (updating flags to check if zero)
		STR		R2, [R1]				; save the decremented value back into `seconds`

		BNE		_timer_update_done		; branch to exit if `seconds` is **not** zero
		
		; continue here if `seconds` **is** zero (it is done)
		; stop SysTick
		LDR		R1, =0xe000e010			; write memory address of the SYST_CSR into R1
		MOV		R2, #0x4				; write 0x4 to R2 (100 -> lowest 2 bits zeroed, 3rd bit set)
		STR		R2, [R1]				; write R2 (currently 0x4) into the SYST_CSR

		; invoke a function
		LDR		R1, =0x20007b84			; write memory address of the function into R1
		LDR		R2, [R1]				; load its value
		CMP		R2, #0
		BLXNE	R2						; branch to it if its not zero
_timer_update_done
		MOV		pc, lr		; return to SysTick_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void* signal_handler( int signum, void* handler )
	    EXPORT	_signal_handler
_signal_handler
	;; Implement by yourself
	
		MOV		pc, lr		; return to Reset_Handler
		
		END		
