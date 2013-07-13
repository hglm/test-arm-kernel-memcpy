#ifdef ARMV7
#define __LINUX_ARM_ARCH__ 7
#endif
#ifdef ARMV6
#define __LINUX_ARM_ARCH__ 6
#endif
#ifdef ARMV5
#define __LINUX_ARM_ARCH__ 5
#endif
#ifndef __LINUX_ARM_ARCH__
#define __LINUX_ARM_ARCH__ 4
#endif

#if __LINUX_ARM_ARCH__ == 7
#define L1_CACHE_BYTES 64
#else
#define L1_CACHE_BYTES 32
#endif

#ifndef PREFETCH_DISTANCE
#if __LINUX_ARM_ARCH__ == 7
#define PREFETCH_DISTANCE 3
#else
#define PREFETCH_DISTANCE 3
#endif
#endif

#define PAGE_SZ 4096

#if __LINUX_ARM_ARCH__ >= 5
#define PLD(code...) code
#define NO_PLD(code...)
#else
#define PLD(code...)
#define NO_PLD(code...) code
#endif

#define ENTRY(proc) asm_function proc

#define ENDPROC(proc) .endfunc

/* Write alignment for memcpy family. */

#if __LINUX_ARM_ARCH__ == 6
#define CALGN(code...) code
#define WRITE_ALIGN_BYTES 8
#else
#define CALGN(code...)
#define WRITE_ALIGN_BYTES 0
#endif

/* Write alignment for memset family. */

#if __LINUX_ARM_ARCH__ >= 6
#define CALGN_MEMSET(code...) code
#if __LINUX_ARM_ARCH__ == 6
#define MEMSET_WRITE_ALIGN_BYTES 32
#else
#define MEMSET_WRITE_ALIGN_BYTES 8
#endif
#else
#define CALGN_MEMSET(code...)
#define MEMSET_WRITE_ALIGN_BYTES 0
#endif

#define pullbits        lsr
#define pushbits        lsl
#ifdef CONFIG_THUMB2_KERNEL
#define W(instr)        instr.w
#define ARM(instr...)
#define THUMB(instr...)	instr
#else
#define W(instr)        instr
#define ARM(instr...)	instr
#define THUMB(instr...)
#endif

#if __LINUX_ARM_ARCH__ >= 6
#define BXLR bx lr
#define BXEQLR bxeq lr
#else
#define BXLR mov pc, lr
#define BXEQLR moveq pc, lr
#endif

.macro asm_function function_name
    .global \function_name
.func \function_name
.type \function_name, function
\function_name:
.endm

#ifdef CONFIG_THUMB2_KERNEL
.syntax unified
#endif
