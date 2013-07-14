/*
 *  linux/arch/arm/lib/memzero.S
 *
 *  Copyright (C) 1995-2000 Russell King
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */
#include "kernel_defines.h"

	.text
	.syntax unified
#ifdef NEON_MEMORY_FUNCTIONS
	.fpu neon
#endif
ARM(	.p2align 5	)
THUMB(	.p2align 2	)

ENTRY(__kernel_memzero)
	ands	r3, r0, #3
	mov	r2, #0
	bne	7f

/*
 * we know that the pointer in r0 is aligned to a word boundary.
 */
1:	cmp	r1, #8
	blt	5f
	mov	r3, r2

	cmp	r1, #64
	push 	{r4}
	blt	4f
#if MEMSET_WRITE_ALIGN_BYTES > 0
	ands	r4, r0, #(MEMSET_WRITE_ALIGN_BYTES - 1)
	/* Let r4 be equal to the number of bytes align.  */
	rsb	r4, r4, #MEMSET_WRITE_ALIGN_BYTES
	/*
	 * At this point r4 contains the number of bytes to align
	 * if eq is not set. The eq flag is set if there are no bytes
	 * to align.
	 */
#if MEMSET_WRITE_ALIGN_BYTES == 8
	subne	r1, r1, r4
	strne	r2, [r0], #4
#elif MEMSET_WRITE_ALIGN_BYTES == 32
	beq	2f
	tst     r4, #4
	sub	r1, r1, r4
	strne	r2, [r0], #4
	tst     r4, #8
	stmiane r0!, {r2, r3}
	cmp	r4, #16
	stmiage r0!, {r2, r3}
        stmiage r0!, {r2, r3}
#endif
	cmp	r1, #64
	blt	4f
#endif

2:
#ifdef NEON_MEMORY_FUNCTIONS
	/*
	 * When NEON is enabled, MEMSET_WRITE_ALIGN_BYTES is
	 * equal to 32 so specify 256-bit alignment in the
	 * NEON store instructions.
	 */
	vmov.u64 d0, #0
	vmov.u64 d1, #0
	vmov	q1, q0
3:	subs	r1, r1, #64
	vst1.64 {d0-d3}, [r0 :256]!
	cmp	r1, #64
	vst1.64 {d0-d3}, [r0 :256]!
	bge	3b
#else
	mov	r4, r2
	push	{r5}
	mov	r5, r2

3:	stmia	r0!, {r2, r3, r4, r5}
	subs	r1, r1, #64		/* Thumb16 */
	stmia	r0!, {r2, r3, r4, r5}
	cmp	r1, #64
	stmia	r0!, {r2, r3, r4, r5}
	stmia	r0!, {r2, r3, r4, r5}
	bge	3b

	pop	{r5}
#endif
	/* Early exit if there are 0 bytes left. */
THUMB(	cbz	r1, 9f	)
ARM(	teq	r1, #0	)
ARM(	beq	9f	)

	/* Handle 8-64 bytes. */
4:	bic	r4, r1, #7
	subs	r1, r1, r4
	rsb	r4, r4, #64
	/* The stmia instruction is 32-bit for ARM, 16-bit for Thumb2. */
THUMB(	lsrs	r4, r4, #2	)
ARM(	lsrs	r4, r4, #1	)
	add	pc, pc, r4
	nop
	stmia	r0!, {r2, r3}
	stmia	r0!, {r2, r3}
	stmia	r0!, {r2, r3}
	stmia	r0!, {r2, r3}
	stmia	r0!, {r2, r3}
	stmia	r0!, {r2, r3}
	stmia	r0!, {r2, r3}
	stmia	r0!, {r2, r3}
	pop	{r4}

5:	cmp	r1, #4
	strge	r2, [r0], #4
	/* Early exit for multiple of 4 size. */
	ands	r1, r1, #3
	BXEQLR

	/*
	 * At this point there are 1, 2 or 3 bytes,
	 * and the destination is word aligned.
	 */
6:	cmp	r1, #2
	strhge	r2, [r0], #2
	strbne	r2, [r0]
	BXLR

7:	cmp	r1, #4
	blt	8f
	cmp	r3, #2
	sub	r1, r1, #4
	strble	r2, [r0]
	strble	r2, [r0, #1]
	addle	r0, r0, #2
	add	r1, r1, r3
	strbne	r2, [r0], #1
	b	1b

	/* 0 to 3 bytes left. */
8:	cmp	r1, #2
	strbge	r2, [r0]
	strbge	r2, [r0, #1]
	addge	r0, r0, #2
	tst	r1, #1
	strbne	r2, [r0]
	BXLR

9:	pop	{r4}
	BXLR

ENDPROC(__kernel_memzero)
