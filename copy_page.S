/*
 *  linux/arch/arm/lib/copypage.S
 *
 *  Copyright (C) 1995-1999 Russell King
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 *  ASM optimised string functions
 *
 *  Optimization for modern ARM platforms
 *  Copyright 2013 Harm Hanemaaijer
 */
#include "kernel_defines.h"

/*
 * This function depends on the following constants:
 *
 * PRELOAD_CACHE_LINE_SIZE
 *     The size of the cache line assumed to be prefetched when issuing
 *     an aligned PLD instruction. Generally 32 or 64. Because of the
 *     need to support diverse platforms with the same kernel, it may be
 *     equal to 32 on a system that would also support the more optimal
 *     value of 64.
 *
 * PREFETCH_DISTANCE
 *     The offset, in units of PRELOAD_CACHE_LINE_SIZE, from the source
 *     address used for prefetching source data.
 *
 * NEON_MEMORY_FUNCTIONS
 *     When defined, which is only compatible with a PRELOAD_CACHE_LINE_SIZE
 *     setting of 64, use NEON instructions. Because of several technical
 *     issues, use of NEON is currently disabled in the ARM kernel memory
 *     functions.
 *
 * This function translates to 16-bit Thumb2 instructions whenever possible.
 *
 * This version should work on older platforms as well and is unlikely
 * to degrade performance significantly.
 */


#define COPY_COUNT (PAGE_SZ / PRELOAD_CACHE_LINE_SIZE)
/* Set the number of preload loops to perform. */
#if PRELOAD_CACHE_LINE_SIZE == 32
/* For line size 32, we perform two preloads per loop. */
#define PRELOAD_LOOP_COUNT ((COPY_COUNT - PREFETCH_DISTANCE) / 2)
#else
#define PRELOAD_LOOP_COUNT (COPY_COUNT - PREFETCH_DISTANCE)
#endif

		.text
	ARM(	.p2align 5	)
	THUMB(	.p2align 2	)
#ifdef NEON_MEMORY_FUNCTIONS
		.fpu neon
#endif

ENTRY(kernel_copy_page)
#ifdef NEON_MEMORY_FUNCTIONS
		vpush	{d0-d3}
#else
		stmfd	sp!, {r4-r8, lr}
#endif
	PLD(	pld	[r1, #0]		)
	PLD(	pld	[r1, #PRELOAD_CACHE_LINE_SIZE]		)
#if PREFETCH_DISTANCE > 2
	PLD(	pld	[r1, #2 * PRELOAD_CACHE_LINE_SIZE]	)
#if PREFETCH_DISTANCE > 3
	PLD(	pld	[r1, #3 * PRELOAD_CACHE_LINE_SIZE]	)
#if PREFETCH_DISTANCE > 4
	PLD(	pld	[r1, #4 * PRELOAD_CACHE_LINE_SIZE]	)
#if PREFETCH_DISTANCE > 5
	PLD(	pld	[r1, #5 * PRELOAD_CACHE_LINE_SIZE]	)
#if PREFETCH_DISTANCE > 6
	PLD(	pld	[r1, #6 * PRELOAD_CACHE_LINE_SIZE]	)
#if PREFETCH_DISTANCE > 7
	PLD(	pld	[r1, #7 * PRELOAD_CACHE_LINE_SIZE]	)
#endif
#endif
#endif
#endif
#endif
#endif
NO_PLD(		mov	r2, #COPY_COUNT		)
PLD(	THUMB(	movs	r2, #PRELOAD_LOOP_COUNT	)	)
PLD(	ARM(	mov	r2, #PRELOAD_LOOP_COUNT	)	)
#if PRELOAD_CACHE_LINE_SIZE == 32
		/*
		 * When PRELOAD_CACHE_LINE_SIZE is 32, process 64 bytes at
		 * at time, performing two preloads per loop.
		 */
1:	PLD(	pld	[r1, #PREFETCH_DISTANCE * PRELOAD_CACHE_LINE_SIZE])
		ldmia   r1!, {r3-r8, ip, lr}
		stmia	r0!, {r3-r8, ip, lr}
	PLD(	pld	[r1, #PREFETCH_DISTANCE * PRELOAD_CACHE_LINE_SIZE])
		ldmia   r1!, {r3-r8, ip, lr}
		subs	r2, r2, #1
		stmia	r0!, {r3-r8, ip, lr}
		bgt	1b
		/*
		 * Because PREFETCH_DISTANCE may be uneven, we have to 
		 * be careful to perform the right number of preloads and
		 * block copies.
		 */
#if (PREFETCH_DISTANCE & 1) == 1
	PLD(	pld	[r1, #PREFETCH_DISTANCE * PRELOAD_CACHE_LINE_SIZE])
#endif
2:	PLD(	ldmia   r1!, {r3-r8, ip, lr}	)
	PLD(	subs	r2, r2, #1		)
	PLD(	stmia	r0!, {r3-r8, ip, lr}	)
	PLD(	cmn	r2, #(PREFETCH_DISTANCE + (PREFETCH_DISTANCE & 1)))
	PLD(	bgt	2b			)
#else /* PRELOAD_CACHE_LINE_SIZE == 64 */
		/*
		 * When PRELOAD_CACHE_LINE_SIZE is 64, process 64 bytes at
		 * at time, performing one preload per loop.
		 */
1:	PLD(	pld	[r1, #PREFETCH_DISTANCE * PRELOAD_CACHE_LINE_SIZE])
2:
#ifdef NEON_MEMORY_FUNCTIONS
		vld1.64 {d0-d3}, [r1 :256]!
		vst1.64 {d0-d3}, [r0 :256]!
		vld1.64 {d0-d3}, [r1 :256]!
		subs	r2, r2, #1
		vst1.64 {d0-d3}, [r0 :256]!
#else
		ldmia   r1!, {r3-r8, ip, lr}
		stmia	r0!, {r3-r8, ip, lr}
		ldmia   r1!, {r3-r8, ip, lr}
		subs	r2, r2, #1
		stmia	r0!, {r3-r8, ip, lr}
#endif
		bgt	1b
	PLD(	cmn	r2, #PREFETCH_DISTANCE	)
	PLD(	bgt	2b			)
#endif
#ifdef NEON_MEMORY_FUNCTIONS
		vpop	{d0-d3}
		bx	lr
#else
		ldmfd	sp!, {r4-r8, pc}
#endif
ENDPROC(kernel_copy_page)
