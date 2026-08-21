		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table
HEAP_TOP	EQU		0x20001000
HEAP_BOT	EQU		0x20004FE0
MAX_SIZE	EQU		0x00004000		; 16KB = 2^14
MIN_SIZE	EQU		0x00000020		; 32B  = 2^5
	
MCB_TOP		EQU		0x20006800      	; 2^10B = 1K Space
MCB_BOT		EQU		0x20006BFE
MCB_ENT_SZ	EQU		0x00000002		; 2B per entry
MCB_TOTAL	EQU		512			; 2^9 = 512 entries
	
INVALID		EQU		-1			; an invalid id

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Memory Control Block Initialisation
	; void _kinit(void)
	;
	; mcb[0] = 0x4000 (the complete 16KB heap is free)
	; mcb[1...511] = 0 (rest of heap initialised as 0)
		EXPORT	_kinit
_kinit
		LDR		R0, =MCB_TOP
		LDR		R1, =MCB_TOTAL
		MOVS	R2, #0

_kinit_zero_loop
		STRH	R2, [R0]
		ADDS	R0, R0, #MCB_ENT_SZ ; Move to next entry.
		SUBS	R1, R1, #1 ; Update count of uninitialised entries.
		BNE		_kinit_zero_loop

		LDR		R0, =MCB_TOP
		LDR		R1, =MAX_SIZE
		STRH	R1, [R0]
		BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Kernel Memory Allocation
	; void* _kalloc(int size)
	;
	; R0 = requested number of bytes
	; Returns R0 = allocated heap address or 0 on failure.
		EXPORT	_kalloc
_kalloc
		; malloc fails under NULL size entry.
		CMP		R0, #0
		BEQ		_kalloc_fail

		; Ensure size entries are within heap size.
		LDR		R1, =MAX_SIZE
		CMP		R0, R1
		BHI		_kalloc_fail

		; The smallest buddy is 32 bytes.
		CMP		R0, #MIN_SIZE
		BHS		_kalloc_size_ready
		MOVS	R0, #MIN_SIZE

_kalloc_size_ready
		; _ralloc is recursive, so preserve this routine's return address.
		PUSH	{R4, LR}
		LDR		R1, =MCB_TOP
		LDR		R2, =MCB_BOT
		BL		_ralloc
		POP		{R4, PC}

_kalloc_fail
		MOVS	R0, #0
		BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Recursive buddy allocation helper
	; void* _ralloc(int size, short* left_mcb, short* right_mcb)
	;
	; R0 = requested size
	; R1 = address of first MCB entry in the current range
	; R2 = address of last  MCB entry in the current range (inclusive)
	; Returns R0 = heap pointer or 0 if this range cannot satisfy the request.
		EXPORT	_ralloc
_ralloc
		; 6 registers = 24 bytes, preserving 8-byte stack alignment for recursion.
		PUSH	{R3-R7, LR}
		MOV		R4, R0			; requested size
		MOV		R5, R1			; left MCB address
		MOV		R6, R2			; right MCB address

		; Current Size calculated from (right - left + 2) * 16
		SUBS	R7, R6, R5
		ADDS	R7, R7, #MCB_ENT_SZ
		LSLS	R7, R7, #4

		; ralloc fails if request does not fit in this range.
		CMP		R4, R7
		BHI		_ralloc_fail

		; If the request can fit in a half-sized buddy, descend recursively.
		; A 32-byte block cannot be split any further.
		CMP		R7, #MIN_SIZE
		BEQ		_ralloc_take_current
		LSRS	R3, R7, #1		; R3 = half of current heap size
		CMP		R4, R3
		BHI		_ralloc_take_current

		; Determine whether this current range is still one whole block or
		; has already been split into smaller buddies.  Mask off the in-use bit.
		LDRH	R0, [R5]
		MOV		R1, R0
		LSRS	R1, R1, #1
		LSLS	R1, R1, #1		; R1 = MCB entry with bit 0 cleared
		CMP		R1, R7
		BHI		_ralloc_fail		; inconsistent/corrupt metadata
		BLO		_ralloc_already_split

		; Entry size equals the whole current range.  If bit 0 is set, the
		; whole range is allocated and therefore cannot be split.
		MOVS	R2, #1
		TST		R0, R2
		BNE		_ralloc_fail

		; Split the free current range into two equal buddies.
		; right_start = left + current_size / 32 (in MCB address bytes)
		LSRS	R2, R7, #5
		ADD		R7, R5, R2		; R7 now holds right-half MCB start
		STRH	R3, [R5]
		STRH	R3, [R7]
		B		_ralloc_try_left

_ralloc_already_split
		; Reconstruct the midpoint for an already-split range.
		LSRS	R2, R7, #5
		ADD		R7, R5, R2		; R7 = right-half MCB start

_ralloc_try_left
		; First-fit policy: recursively try the left buddy.
		MOV		R0, R4
		MOV		R1, R5
		SUBS	R2, R7, #MCB_ENT_SZ
		BL		_ralloc
		CMP		R0, #0
		BNE		_ralloc_done

		; If the left half cannot satisfy the request, try the right buddy.
		MOV		R0, R4
		MOV		R1, R7
		MOV		R2, R6
		BL		_ralloc
		B		_ralloc_done

_ralloc_take_current
		; A request larger than half the current range must take this entire
		; buddy.  It is usable only when its MCB entry exactly describes this
		; range and is currently free.
		LDRH	R0, [R5]
		MOV		R1, R0
		LSRS	R1, R1, #1
		LSLS	R1, R1, #1		; clear in-use bit
		CMP		R1, R7
		BNE		_ralloc_fail

		MOVS	R2, #1
		TST		R0, R2
		BNE		_ralloc_fail

		; Mark this block in use: size | 1.
		ADDS	R1, R7, #1
		STRH	R1, [R5]

		; Convert the MCB address to the corresponding heap address:
		; heap = HEAP_TOP + (mcb - MCB_TOP) * 16.
		LDR		R2, =MCB_TOP
		SUBS	R1, R5, R2
		LSLS	R1, R1, #4
		LDR		R2, =HEAP_TOP
		ADDS	R0, R2, R1
		B		_ralloc_done

_ralloc_fail
		MOVS	R0, #0

_ralloc_done
		POP		{R3-R7, PC}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Kernel Memory De-allocation
	; void* _kfree(void *ptr)
	;
	; R0 = heap address previously returned by _kalloc
	; Returns the original pointer on success or 0 for an invalid pointer.
		EXPORT	_kfree
_kfree
		; free(NULL) performs no operation.
		CMP		R0, #0
		BEQ		_kfree_fail

		; Pointer must be within the heap and on a 32-byte buddy boundary.
		LDR		R1, =HEAP_TOP
		CMP		R0, R1
		BLO		_kfree_fail
		LDR		R2, =HEAP_BOT
		CMP		R0, R2
		BHI		_kfree_fail

		SUBS	R3, R0, R1		; heap byte offset
		MOVS	R2, #0x1F
		TST		R3, R2
		BNE		_kfree_fail

		; mcb = MCB_TOP + (heap_offset / 16)
		; (heap_offset / 32 entries * 2 bytes/entry = /16).
		LSRS	R3, R3, #4
		LDR		R1, =MCB_TOP
		ADDS	R3, R3, R1

		; The exact MCB entry must currently be allocated.  This rejects
		; double-free and pointers into the middle of a larger allocation.
		LDRH	R1, [R3]
		MOVS	R2, #1
		TST		R1, R2
		BEQ		_kfree_fail

		PUSH	{R4, LR}
		MOV		R4, R0			; remember original heap pointer
		MOV		R0, R3
		BL		_rfree
		CMP		R0, #0
		BEQ		_kfree_recursive_fail
		MOV		R0, R4
		POP		{R4, PC}

_kfree_recursive_fail
		MOVS	R0, #0
		POP		{R4, PC}

_kfree_fail
		MOVS	R0, #0
		BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Recursive buddy de-allocation helper
	; short* _rfree(short* mcb)
	;
	; R0 = MCB entry corresponding to a block being freed/merged.
	; Returns a nonzero MCB address on success or 0 on invalid metadata.
		EXPORT	_rfree
_rfree
		; 6 registers = 24 bytes, preserving 8-byte stack alignment for recursion.
		PUSH	{R3-R7, LR}
		MOV		R4, R0			; current MCB address

		; Validate the MCB address.
		LDR		R5, =MCB_TOP
		CMP		R4, R5
		BLO		_rfree_fail
		LDR		R5, =MCB_BOT
		CMP		R4, R5
		BHI		_rfree_fail

		; Read size and clear the in-use bit, making the block available.
		LDRH	R5, [R4]
		CMP		R5, #0
		BEQ		_rfree_fail
		LSRS	R6, R5, #1
		LSLS	R6, R6, #1		; R6 = block size, bit 0 cleared
		CMP		R6, #MIN_SIZE
		BLO		_rfree_fail
		LDR		R7, =MAX_SIZE
		CMP		R6, R7
		BHI		_rfree_fail
		STRH	R6, [R4]

		; A 16KB block is already the root and has no buddy above it.
		CMP		R6, R7
		BEQ		_rfree_success

		; Number of MCB address bytes spanned by this heap block = size / 16.
		LSRS	R7, R6, #4
		LDR		R5, =MCB_TOP
		SUBS	R1, R4, R5		; current MCB offset from MCB_TOP

		; Since the span is a power of two, this span bit tells whether the
		; current block is the left (0) or right (1) buddy at this level.
		TST		R1, R7
		BNE		_rfree_is_right

_rfree_is_left
		ADD		R2, R4, R7		; R2 = right buddy
		LDR		R1, =MCB_BOT
		CMP		R2, R1
		BHI		_rfree_success

		; Buddy must be free and exactly the same size.  Because an in-use
		; buddy stores size|1, an exact compare with R6 also checks bit 0.
		LDRH	R3, [R2]
		CMP		R3, R6
		BNE		_rfree_success

		; Merge: left entry becomes the doubled parent; right entry disappears.
		MOVS	R3, #0
		STRH	R3, [R2]
		LSLS	R6, R6, #1
		STRH	R6, [R4]
		MOV		R0, R4
		BL		_rfree
		B		_rfree_done

_rfree_is_right
		SUBS	R2, R4, R7		; R2 = left buddy / future parent
		LDR		R1, =MCB_TOP
		CMP		R2, R1
		BLO		_rfree_success

		LDRH	R3, [R2]
		CMP		R3, R6
		BNE		_rfree_success

		; Merge: clear the right entry and double the left/parent entry.
		MOVS	R3, #0
		STRH	R3, [R4]
		LSLS	R6, R6, #1
		STRH	R6, [R2]
		MOV		R0, R2
		BL		_rfree
		B		_rfree_done

_rfree_success
		MOV		R0, R4
		B		_rfree_done

_rfree_fail
		MOVS	R0, #0

_rfree_done
		POP		{R3-R7, PC}

		END
