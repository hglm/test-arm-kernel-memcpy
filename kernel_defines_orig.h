
#define PLD(code...) code
#ifdef ARMV7
#define __LINUX_ARM_ARCH__ 7
#define L1_CACHE_BYTES 64
#else
#define __LINUX_ARM_ARCH__ 6
#define L1_CACHE_BYTES 32
#endif
#define PAGE_SZ 4096

#define ENTRY(proc) asm_function proc

#define ENDPROC(proc) .endfunc

#define CALGN(code...)

#define pull            lsr
#define push            lsl
#ifdef CONFIG_THUMB2_KERNEL
#define W(instr)	instr.w
#else
#define W(instr)        instr
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
