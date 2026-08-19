		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _bzero( void *s, int n )
; Parameters
;	s 		- pointer to the memory location to zero-initialize
;	n		- a number of bytes to zero-initialize
; Return value
;   none
		EXPORT	_bzero
_bzero
		; return early if n == 0
		CMP		R1, #0
		BEQ		bzero_done
		; if n != 0, prep the 0 byte to write
		MOV		R2, #0
bzero_loop
		; store zero, advance pointer by 1
		STRB	R2, [R0], #1
		; n--
		SUBS	R1, R1, #1
		BNE		bzero_loop
bzero_done
		; redirect program counter to caller
		MOV		pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; char* _strncpy( char* dest, char* src, int size )
; Parameters
;   dest 	- pointer to the buffer to copy to
;	src		- pointer to the zero-terminated string to copy from
;	size	- a total of n bytes
; Return value
;   dest
		EXPORT	_strncpy
_strncpy
		; save original dest pointer on stack
		PUSH	{R0}
strncpy_loop
		; return early if size == 0
		CMP		R2, #0
		BEQ		strncpy_done
		; load byte from pointed src location, iterate src pointer
		LDRB	R3, [R1], #1
		; store byte to pointed dest location, iterate dest pointer
		STRB	R3, [R0], #1
		; size--
		SUBS	R2, R2, #1
		; return early if that was the final byte to copy
		CMP		R3, #0
		BEQ		strncpy_done
		; if not, loop
		B 		strncpy_loop
strncpy_done
		; restore original dest pointer that was saved on the stack
		POP		{R0}
		; redirect program counter to caller
		MOV		pc, lr
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _malloc( int size )
; Parameters
;	size	- #bytes to allocate
; Return value
;   void*	- a pointer to the allocated space
		EXPORT	_malloc
_malloc
		; save registers
		PUSH	{R7, LR}
		; set the system call # to R7
		MOV		R7, #0x3
		SVC     #0x0
		; resume registers	
		POP		{R7, LR}
		MOV		pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _free( void* addr )
; Parameters
;	size	- the address of a space to deallocate
; Return value
;   none
		EXPORT	_free
_free
		; save registers
		PUSH	{R7, LR}
		; set the system call # to R7
		MOV		R7, #0x4
		SVC     #0x0
		; resume registers	
		POP		{R7, LR}
		MOV		pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; unsigned int _alarm( unsigned int seconds )
; Parameters
;   seconds - seconds when a SIGALRM signal should be delivered to the calling program	
; Return value
;   unsigned int - the number of seconds remaining until any previously scheduled alarm
;                  was due to be delivered, or zero if there was no previously schedul-
;                  ed alarm. 
		EXPORT	_alarm
_alarm
		; save registers
		PUSH	{R7, LR}
		; set the system call # to R7
		MOV		R7, #0x1
		SVC     #0x0
		; resume registers	
		POP		{R7, LR}
		MOV		pc, lr	
			
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _signal( int signum, void *handler )
; Parameters
;   signum - a signal number (assumed to be 14 = SIGALRM)
;   handler - a pointer to a user-level signal handling function
; Return value
;   void*   - a pointer to the user-level signal handling function previously handled
;             (the same as the 2nd parameter in this project)
		EXPORT	_signal
_signal
		; save registers
		PUSH	{R7, LR}
		; set the system call # to R7
		MOV		R7, #0x2
		SVC     #0x0
		; resume registers
		POP		{R7, LR}
		MOV		pc, lr	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		END			
