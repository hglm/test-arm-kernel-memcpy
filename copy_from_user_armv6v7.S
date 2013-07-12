/*
 *  linux/arch/arm/lib/memcpy.S
 *
 *  Author:	Nicolas Pitre
 *  Created:	Sep 28, 2005
 *  Copyright:	MontaVista Software, Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License version 2 as
 *  published by the Free Software Foundation.
 */

#include "kernel_defines.h"

#define LDR1W_SHIFT	0
#define STR1W_SHIFT	0
#define COPY_FUNCTION_FROM_USER

	.macro ldr1w ptr reg abort
	W(ldr) \reg, [\ptr], #4
	.endm

	.macro ldr1wcond ptr reg cond abort
	ldr\cond \reg, [\ptr], #4
	.endm

	/*
	 * Using offset addressing instead of post-increment for a block
	 * of load instructions has several advantages: the instructions
	 * can be dual-issued, and the Thumb2 instructions are half the
	 * size for registers in the range r0-r7.
	 */
	.macro ldr1woffset ptr reg offset abort
	ldr \reg, [\ptr, #\offset]
	.endm

        .macro ldr2w ptr reg1 reg2 abort
	ldr1woffset \ptr, \reg1, 0, \abort
	ldr1woffset \ptr, \reg2, 4, \abort
	add	r1, r1, #8
	.endm

        .macro ldr4w ptr reg1 reg2 reg3 reg4 abort
	ldr1woffset \ptr, \reg1, 0, \abort
	ldr1woffset \ptr, \reg2, 4, \abort
	ldr1woffset \ptr, \reg3, 8, \abort
	ldr1woffset \ptr, \reg4, 12, \abort
	add	r1, r1, #16
        .endm

        .macro ldr8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
	ldr1woffset \ptr, \reg1, 0, \abort
	ldr1woffset \ptr, \reg2, 4, \abort
	ldr1woffset \ptr, \reg3, 8, \abort
	ldr1woffset \ptr, \reg4, 12, \abort
	ldr1woffset \ptr, \reg5, 16, \abort
	ldr1woffset \ptr, \reg6, 20, \abort
	ldr1woffset \ptr, \reg7, 24, \abort
	ldr1woffset \ptr, \reg8, 28, \abort
	add	r1, r1, #32
        .endm

	.macro ldr1b ptr reg cond=al abort
	ldr\cond\()b \reg, [\ptr], #1
	.endm

	.macro str1w ptr reg abort
	W(str) \reg, [\ptr], #4
	.endm

	.macro str1wcond ptr reg cond abort
	str\cond \reg, [\ptr], #4
	.endm

	.macro str2w ptr reg1 reg2 abort
	stmia \ptr!, {\reg1, \reg2}
	.endm

	.macro str4w ptr reg1 reg2 reg3 reg4 abort
	stmia \ptr!, {\reg1, \reg2, \reg3, \reg4}
	.endm

	.macro str8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
	stmia \ptr!, {\reg1, \reg2, \reg3, \reg4, \reg5, \reg6, \reg7, \reg8}
	.endm

	.macro str1b ptr reg cond=al abort
	str\cond\()b \reg, [\ptr], #1
	.endm

	.macro enter_no_regs
	/* Push the destination onto the stack. */
	stmdb sp!, {r0}
	.endm

	.macro exit_no_regs
	/* Return the original destination in r0. */
	ldr r0, [sp], #4
	bx lr
	.endm

	.text
	.syntax unified

/* Prototype: void *copy_from_user(void *dest, const void *src, size_t n); */

ENTRY(kernel_copy_from_user_armv6v7)

#include "copy_user_template_armv6v7.S"

ENDPROC(kernel_copy_from_user_armv6v7)
