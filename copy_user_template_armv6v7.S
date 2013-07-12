/*
 *  linux/arch/arm/lib/copy_template.s
 *
 *  Code template for optimized memory copy functions
 *
 *  Author:	Nicolas Pitre
 *  Created:	Sep 28, 2005
 *  Copyright:	MontaVista Software, Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License version 2 as
 *  published by the Free Software Foundation.
 *
 *  Optimization for modern ARM platforms
 *  Copyright 2013 Harm Hanemaaijer
 */

/*
 * Theory of operation
 * -------------------
 *
 * This file provides the core code for a forward memory copy used in
 * the implementation of copy_to_user() and copy_from_user() for armv6/v7
 * platforms.
 *
 * The including file must define the following accessor macros
 * according to the need of the given function:
 *
 * ldr1w ptr reg abort
 *
 *	This loads one word from 'ptr', stores it in 'reg' and increments
 *	'ptr' to the next word. The 'abort' argument is used for fixup tables.
 *
 * ldr1wcond ptr reg cond abort
 *
 *	Similar to ldr1w, but also applies the condition code if provided,
 *	otherwise the "al" condition is assumed by default.
 *
 * ldr4w ptr reg1 reg2 reg3 reg4 abort
 * ldr8w ptr, reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
 *
 *	This loads four or eight words starting from 'ptr', stores them
 *	in provided registers and increments 'ptr' past those words.
 *	The'abort' argument is used for fixup tables.
 *
 * ldr1b ptr reg cond abort
 *
 *	Similar to ldr1w, but it loads a byte and increments 'ptr' one byte.
 *	It also must apply the condition code if provided, otherwise the
 *	"al" condition is assumed by default.
 *
 * str1w ptr reg abort
 * str1wcond ptr reg abort
 * str4w ptr reg1 reg2 reg3 reg4 abort
 * str8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
 * str1b ptr reg cond abort
 *
 *	Same as their ldr* counterparts, but data is stored to 'ptr' location
 *	rather than being loaded.
 *
 * enter_no_regs
 *
 *	Preserve data on the stack as needed by the implementation including
 *      this code. Called upon code entry.
 *
 * exit_no_regs
 *
 *	Exit, processing data on the stack saved with the 'enter' macro.
 *      Called upon code termination. The lr register holds the return
 *      address.
 *
 * LDR1W_SHIFT
 * STR1W_SHIFT
 *
 *	Correction to be applied to the "ip" register when branching into
 *	the ldr1w or str1w instructions (some of these macros may expand to
 *	than one 32bit instruction in Thumb-2)
 *
 * L1_CACHE_BYTES
 *
 *      The cache line size used for prefetches. Preloads are performed at
 *      L1_CACHE_BYTES aligned addresses. However, if L1_CACHE_BYTES == 64,
 *      in the case of unaligned copies preload instructions are performed
 *      at 32 bytes aligned addresses. The code could be modified to strictly
 *      preload at 64 bytes aligned addresses, at the cost of increasing code
 *      size and complexity. However, the armv7 architecture doesn't seem
 *      to incur a big penalty for the unnecessary preload instructions.
 *      Additionally unaligned copies are rare.
 *
 * PREFETCH_DISTANCE
 *
 *      The prefetch distance in units of L1_CACHE_BYTES used for prefetches.
 *
 * WRITE_ALIGN_BYTES
 *
 *      Write aligning is enabled if the CALGN macro expands to instructions
 *      instead of nothing. When enabled, WRITE_ALIGN_BYTES defines the number
 *      of bytes to align to (it must be 16 or 32).
 *
 * COPY_FUNCTION_FROM_USER
 *
 *      This is defined when compiling the copy_from_user function. The write
 *      alignment code is disabled because it is slower (the main loop will
 *      load single words any way, and the write alignment code only
 *      constitutes overhead).
 *
 * COPY_FUNCTION_TO_USER
 *
 *      This is defined when compiling the copy_to_user and copy_to_user_std
 *      functions. The write alignment code is disabled because it is slower
 *      (the main loop will write single words any way, and the write alignment
 *      code only constitutes overhead).
 *
 */

#ifdef COPY_FUNCTION_FROM_USER
#define SMALL_SIZE_THRESHOLD 7
/*
 * For copy_from_user, the fast path is unoptimal for sizes greater or
 * equal to about 96 bytes.
 */
#define FAST_PATH_SIZE_THRESHOLD 95
/* #define DISABLE_WRITE_ALIGNMENT */
#endif

#ifdef COPY_FUNCTION_TO_USER
#define SMALL_SIZE_THRESHOLD 7
/*
 * When copy_to_user_memcpy is enabled in the kernel configuration
 * (CONFIG_UACCESS_WITH_MEMCPY), the assembler copy_to_user function
 * will only be called for sizes less than 64 bytes. Ideally, the
 * fast path threshold for copy_to_user should be 63 or higher to
 * avoid the non-fast path code completely.
 *
 * Otherwise, it seems the fast path is faster or almost as fast even
 * for larger sizes. However, because preload instructions are omitted
 * from the fast path, transfers from kernel memory that is not in the CPU
 * cache may be slower when the threshold is set too high.
 */
#define FAST_PATH_SIZE_THRESHOLD 128
/* #define DISABLE_WRITE_ALIGNMENT */
#endif

#define OPTIMIZE_WITH_FAST_PATH
/* #define DISABLE_WRITE_ALIGNMENT_FOR_UNALIGNED_CASE */

#ifdef OPTIMIZE_WITH_FAST_PATH
		/*
                 * For small aligned memcpy/copy_to_user/copy_from_user
                 * operations, the previous implementation has some
                 * overhead. By creating a fast path for common small
                 * aligned requests, performance is increased.
                 */
		cmp	r2, #SMALL_SIZE_THRESHOLD
		/* Calculate the aligned base for preloads. */
	PLD(	bic	ip, r1, #(L1_CACHE_BYTES - 1)	)
		enter_no_regs
	PLD(	pld	[ip]				)
		orr	r3, r0, r1
		ble	36f
		cmp	r2, #FAST_PATH_SIZE_THRESHOLD
		tstle	r3, #3
		bne	37f

		/*
		 * At this point, we have a small-to-medium sized
		 * (<= FAST_PATH_SIZE_THRESHOLD bytes) word-aligned request
		 * of size greater than SMALL_SIZE_THRESHOLD.
		 */
		/*
                 * For copy_to_user and copy_from_user, the fast path
		 * uses single word loads and stores, but due to the
		 * decreased overhead this can be a big win for small
		 * sizes which are very common.
		 */
32:
#ifdef COPY_FUNCTION_FROM_USER
		ldr1w	r1, r3, abort=22f
		subs	r2, r2, #8		/* Thumb16 */
		ldr1w	r1, ip, abort=22f
		cmp	r2, #8
		str2w	r0, r3, ip, abort=22f
#else	/* COPY_FUNCTION_TO_USER */
		ldr2w	r1, r3, ip, abort=22f
		subs	r2, r2, #8		/* Thumb16 */
		str1w	r0, r3, abort=22f
		cmp	r2, #8
		str1w	r0, ip, abort=22f
#endif
		bge	32b
		tst	r2, #4
		ldr1wcond r1, r3, ne, abort=22f
		str1wcond r0, r3, ne, abort=22f
34:		tst	r2, #3
		bne	38f
		exit_no_regs

36:		/*
                 * At this point, we have <= SMALL_SIZE_THRESHOLD bytes that
		 * may not be aligned. This code is optimized for < 4 bytes
		 * or word aligned source and destination; otherwise, branch
		 * to the general case.
                 */
#if SMALL_SIZE_THRESHOLD <= 7
		tst	r3, #3		/* Sets the carry flag. */
		cmpne	r2, #3
		bhi	37f		/* Branch if cs and ne. */
		/*
		 * Word aligned source and destination, >= 4 bytes and <= 7,
		 * or unaligned, < 4 bytes.
		 */
		tst	r2, #4
		ldr1wcond r1, r3, ne, abort=22f
		str1wcond r0, r3, ne, abort=22f
		tst	r2, #3
		beq	39f
#else
		cmp	r2, #4
		blt	38f
		tst	r3, #3
		sub	r2, r2, #3
		bne	35f
		/* Word aligned source and destination, >= 4 bytes. */
44:		ldr1w	r1, r3, abort=22f
		subs	r2, r2, #4
		str1w	r0, r3, abort=22f
		bgt	44b
		adds	r2, r2, #3
		beq	39f
#endif
38:		movs	r2, r2, lsl #31
		ldr1b	r1, r3, ne, abort=22f
		str1b	r0, r3, ne, abort=22f
		ldr1b	r1, ip, cs, abort=22f
		ldr1b	r1, r3, cs, abort=22f
		str1b	r0, ip, cs, abort=22f
		str1b	r0, r3, cs, abort=22f
39:		exit_no_regs

33:		/* Unaligned case, >= 4 bytes. */
		ands	ip, r0, #3
		sub	r2, r2, #4
		bne	9f
		ands	ip, r1, #3
		b	10f

1:		/*
		 * Unaligned case that has been aligned to a word
		 * boundary (src & 3) == (dst & 3).
		 */
		/* Correct the count. */
		adds	r2, r2, #4
		push	{r5-r9}
		cmp	r2, #32
		mov	r8, r3
		/* Jump to the tail if there are too few bytes. */
		blt	5f
		subs	r2, r2, #32
		/* Jump to the regular alignment code. */
		b	45f

35:		adds	r2, r2, #3	/* Thumb16 */

		/*
		 * We get here when the fast path was not selected,
		 * which is for unaligned requests >= 4 bytes and aligned
		 * requests > FAST_PATH_THRESHOLD. r3 is equal to the
		 * logical OR of the source and destination addresses,
		 * ip holds the aligned source base address.
		 */
37:		tst	r3, #3
		push	{r4, lr}
	PLD(	mov	r3, ip			)
	PLD(	pld	[ip, #L1_CACHE_BYTES]	)
		bne	33b	/* Unaligned. */

		subs	r2, r2, #32
		push	{r5-r9}
		mov	r8, r3
45:
#else	/* defined(OPTIMIZE_WITH_FAST_PATH) */
		/*
		 * This is the entry point of the original function, used
		 * when the fast path is disabled.
		 * ip holds the aligned source base address.
		 */
37:		push	{r4, lr}

33:		subs	r2, r2, #4
	PLD(	mov	r3, ip			)
		blt	8f
		ands	ip, r0, #3
	PLD(	pld	[r3, #L1_CACHE_BYTES]	)
		bne	9f
		ands	ip, r1, #3
		bne	10f

1:		subs	r2, r2, #(28)
		push	{r5-r9}
	PLD(	mov	r8, r3			)
		/* Correct the count when jumping to the tail. */
		addlt	r2, r2, #32
		blt	5f
#endif

#ifndef DISABLE_WRITE_ALIGNMENT
	CALGN(	ands	ip, r0, #(WRITE_ALIGN_BYTES - 1)	)
	CALGN(	rsb	r3, ip, #WRITE_ALIGN_BYTES		)
	CALGN(	sbcsne	r4, r3, r2		)  @ C is always set here
#if WRITE_ALIGN_BYTES == 8
		/*
		 * For write alignment of 8, it is quickest to simply
		 * use a conditional load/store.
		 */
	CALGN(	ldr1wcond r1, r4, cc		)
	CALGN(	subcc	r2, r2, r3		)
	CALGN(	str1wcond r0, r4, cc		)
#else
	CALGN(	bcs	2f			)
ARM(	CALGN(	adr	r4, 6f			)	)
#if WRITE_ALIGN_BYTES == 16
	CALGN(  add	ip, ip, #16		)
#endif
	CALGN(	subs	r2, r2, r3		)  @ C gets set
ARM(	CALGN(	add	pc, r4, ip		)	)
		/* On Thumb2, we need to use relative addressing. */
THUMB(	CALGN(	add	r4, ip, #(6f - 2f)	)	)
THUMB(	CALGN(	add	pc, pc, r4		)	)
THUMB(	CALGN(	nop				)	)
#endif
#endif

2:
#if L1_CACHE_BYTES == 64
		cmp	r2, #32
		/* Correct the count when jumping to the tail, */
		addlt	r2, r2, #32
		blt     30f
		subs	r2, r2, #32
#endif
		/*
                 * Assume a preload at aligned base + 2 * L1_CACHE_BYTES will
		 * be useful.
		 */
	PLD(	pld	[r8, #(2 * L1_CACHE_BYTES)]	)

	PLD(	add	r9, r1, #(PREFETCH_DISTANCE * L1_CACHE_BYTES)	)
	PLD(	subs	r2, r2, #(PREFETCH_DISTANCE * L1_CACHE_BYTES)	)
	PLD(	bic     r3, r9, #(L1_CACHE_BYTES - 1)			)
	PLD(	add	r8, #(3 * L1_CACHE_BYTES)	)
	PLD(	blt	4f				)
	PLD(	cmp	r8, r3				)
	PLD(	sub	r9, r3, r1			)
		/*
		 * "Catch-up" the early preloads (which have been performed up
		 * to aligned base + 2 * L1_CACHE_BYTES) to the preload offset
		 * used in the main loop.
		 */
	PLD(	bge	41f				)
42:	PLD(	adds	r8, r8, #L1_CACHE_BYTES		)	/* Thumb16 */
	PLD(	cmp	r8, r3				)
	PLD(	pld	[r8, #(- L1_CACHE_BYTES)]	)
	PLD(	blt	42b				)
41:

#if L1_CACHE_BYTES == 32
3:	PLD(	pld	[r1, r9]		)
4:		ldr8w	r1, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		subs	r2, r2, #32
		str4w	r0, r3, r4, r5, r6, abort=20f
		str4w   r0, r7, r8, ip, lr, abort=20f
		bge	3b
	PLD(	cmn	r2, #(PREFETCH_DISTANCE * 32)	)
	PLD(	bge	4b			)
		/* Correct the count. */
	PLD(	adds	r2, r2, #(PREFETCH_DISTANCE * L1_CACHE_BYTES + 32)	)
	NO_PLD(	add	r2, r2, #32						)
#else /* L1_CACHE_BYTES == 64 */
3:	PLD(	pld	[r1, r9]		)
4:		ldr8w	r1, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		subs	r2, r2, #64
		str8w	r0, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		ldr8w	r1, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		str8w	r0, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		bge	3b
	PLD(	cmn	r2, #(PREFETCH_DISTANCE * 64)	)
	PLD(	bge	4b				)
		/* Correct the count. */
	PLD(	adds	r2, r2, #(PREFETCH_DISTANCE * L1_CACHE_BYTES + 64)	)
	NO_PLD( add	r2, r2, #64						)
#endif
30:
5:
#if L1_CACHE_BYTES == 64
		tst     r2, #32
		beq	31f
		ldr8w	r1, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		str8w	r0, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
31:
#endif
		ands	ip, r2, #28
		rsb	ip, ip, #32
		/*
		 * At this point carry is expected to be clear. However,
		 * because we corrected the count, the ands instruction
		 * resulted in carry set. Explicitly clear carry here.
		 */
		cmpne	r2, #128
#if LDR1W_SHIFT > 0
		lsl	ip, ip, #LDR1W_SHIFT
#endif
		addne	pc, pc, ip
		b	7f
6:
		.rept	(1 << LDR1W_SHIFT)
		W(nop)
		.endr
		ldr1w	r1, r3, abort=20f
		ldr1w	r1, r4, abort=20f
		ldr1w	r1, r5, abort=20f
		ldr1w	r1, r6, abort=20f
		ldr1w	r1, r7, abort=20f
		ldr1w	r1, r8, abort=20f
		ldr1w	r1, lr, abort=20f

#if LDR1W_SHIFT < STR1W_SHIFT
		lsl	ip, ip, #STR1W_SHIFT - LDR1W_SHIFT
#elif LDR1W_SHIFT > STR1W_SHIFT
		lsr	ip, ip, #LDR1W_SHIFT - STR1W_SHIFT
#endif
		add	pc, pc, ip
		nop
		.rept	(1 << STR1W_SHIFT)
		W(nop)
		.endr
		str1w	r0, r3, abort=20f
		str1w	r0, r4, abort=20f
		str1w	r0, r5, abort=20f
		str1w	r0, r6, abort=20f
		str1w	r0, r7, abort=20f
		str1w	r0, r8, abort=20f
		str1w	r0, lr, abort=20f

#ifndef DISABLE_WRITE_ALIGNMENT
	CALGN(	bcs	2b	)
#endif

7:		pop	{r5-r9}

8:		movs	r2, r2, lsl #31
		ldr1b	r1, r3, ne, abort=21f
		str1b	r0, r3, ne, abort=21f
		ldr1b	r1, r4, cs, abort=21f
		ldr1b	r1, ip, cs, abort=21f
		str1b	r0, r4, cs, abort=21f
		str1b	r0, ip, cs, abort=21f

		pop	{r4, lr}
		exit_no_regs

		/* Unaligned destination. r3 is preload base address. */
9:		rsb	ip, ip, #4
		cmp	ip, #2
		ldr1b	r1, r4, gt, abort=21f
		str1b	r0, r4, gt, abort=21f
		ldr1b	r1, r4, ge, abort=21f
		str1b	r0, r4, ge, abort=21f
		ldr1b	r1, lr, abort=21f
		subs	r2, r2, ip
		str1b	r0, lr, abort=21f
		blt	8b
		ands	ip, r1, #3
		beq	1b

10:		bic	r1, r1, #3
		cmp	ip, #2
		ldr1w	r1, lr, abort=21f
		beq	17f
		bgt	18f


		.macro	forward_copy_shift pullshift pushshift

		subs	r2, r2, #28
		blt	14f

#ifndef DISABLE_WRITE_ALIGNMENT_FOR_UNALIGNED_CASE
	CALGN(	ands	ip, r0, #(WRITE_ALIGN_BYTES - 1)	)
	CALGN(	rsb	ip, ip, #WRITE_ALIGN_BYTES		)
	CALGN(	sbcsne	r4, ip, r2		)  @ C is always set here
	CALGN(	subcc	r2, r2, ip		)
#if WRITE_ALIGN_BYTES == 8
		/*
		 * For write alignment of 8, it is quickest to simply
		 * use conditional instructions.
		 */
	CALGN(	movcc	r4, lr, pullbits #\pullshift		)
	CALGN(	ldr1wcond r1, lr, cc, abort=21f			)
	CALGN(	orrcc	r4, r4, lr, pushbits #\pushshift	)
	CALGN(	str1wcond r0, r4, cc, abort=21f			)
#else
	CALGN(	bcc	15f			)
#endif
#endif
		/*
		 * At this point the aligned base address used for early
		 * preloads is stored in r3.
		 */
11:		push {r5-r10}

	PLD(	add	r10, r1, #(PREFETCH_DISTANCE * L1_CACHE_BYTES)	)
	PLD(	subs	r2, r2, #(PREFETCH_DISTANCE * L1_CACHE_BYTES)	)
	PLD(	bic     r4, r10, #31					)
	PLD(	add	r3, #(2 * L1_CACHE_BYTES)	)
	PLD(	blt	13f				)
	PLD(	cmp	r3, r4				)
	PLD(	sub	r10, r4, r1			)
		/*
		 * "Catch-up" the early preloads (which have been performed up
		 * to aligned base + 2 * L1_CACHE_BYTES) to the preload offset
		 * used in the main loop.
		 */
	PLD(	bge	46f				)
47:	PLD(	adds	r3, r3, #L1_CACHE_BYTES		)	/* Thumb16 */
	PLD(	cmp	r3, r4				)
	PLD(	pld	[r3, #(- L1_CACHE_BYTES)]	)
	PLD(	blt	47b				)
46:

		/*
		 * Note that when L1_CACHE_BYTES is 64, we are
		 * prefetching every 32 bytes. Although not optimal
		 * there doesn't seem to be big penalty for the extra
		 * preload instructions and it prevents greater
		 * code size and complexity.
		 */
12:	PLD(	pld	[r1, r10]		)
13:		ldr4w	r1, r4, r5, r6, r7, abort=19f
		mov	r3, lr, pullbits #\pullshift
		ldr4w	r1, r8, r9, ip, lr, abort=19f
		orr	r3, r3, r4, pushbits #\pushshift
		movs	r4, r4, pullbits #\pullshift		/* Thumb16 */
		orr	r4, r4, r5, pushbits #\pushshift
		movs	r5, r5, pullbits #\pullshift		/* Thumb16 */
		orr	r5, r5, r6, pushbits #\pushshift
		movs	r6, r6, pullbits #\pullshift		/* Thumb16 */
		orr	r6, r6, r7, pushbits #\pushshift
		movs	r7, r7, pullbits #\pullshift		/* Thumb16 */
		orr	r7, r7, r8, pushbits #\pushshift
		mov	r8, r8, pullbits #\pullshift
		orr	r8, r8, r9, pushbits #\pushshift
		mov	r9, r9, pullbits #\pullshift
		orr	r9, r9, ip, pushbits #\pushshift
		mov	ip, ip, pullbits #\pullshift
		orr	ip, ip, lr, pushbits #\pushshift
		subs	r2, r2, #32
		str8w	r0, r3, r4, r5, r6, r7, r8, r9, ip, , abort=19f
		bge	12b
	PLD(	cmn	r2, #(PREFETCH_DISTANCE * L1_CACHE_BYTES)	)
	PLD(	bge	13b				)

		pop	{r5-r10}

14:		ands	ip, r2, #28
		beq	16f

15:		mov	r4, lr, pullbits #\pullshift
		ldr1w	r1, lr, abort=21f
		subs	ip, ip, #4
		orr	r4, r4, lr, pushbits #\pushshift
		str1w	r0, r4, abort=21f
		bgt	15b
#ifndef DISABLE_WRITE_ALIGNMENT_FOR_UNALIGNED_CASE
	CALGN(	cmp	r2, #0			)
	CALGN(	bge	11b			)
#endif

16:		subs	r1, r1, #(\pushshift / 8)	/* Thumb16 */
		b	8b

		.endm


		forward_copy_shift	pullshift=8	pushshift=24

17:		forward_copy_shift	pullshift=16	pushshift=16

18:		forward_copy_shift	pullshift=24	pushshift=8


/*
 * Abort preamble and completion macros.
 * If a fixup handler is required then those macros must surround it.
 * It is assumed that the fixup code will handle the private part of
 * the exit macro.
 */

		.macro	copy_abort_preamble
19:		pop {r5-r10}
		b	21f
20:		pop {r5-r9}
21:		pop {r4, lr}
22:
		.endm
