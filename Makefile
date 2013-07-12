# Change PLATFORM_CFLAGS to -DARMV7 to test armv7 (L1_CACHE_BYTES = 64),
# otherwise armv6 is selected (L1_CACHE_BYTES = 32).
# For ARMV7, uncomment the two lines defining THUMB2_CFLAGS to enable
# Thumb2 mode.

PLATFORM_CFLAGS = -DARMV6
#THUMB2_CFLAGS = -march=armv7-a -Wa,-march=armv7-a -mthumb -Wa,-mthumb -Wa,-mimplicit-it=always \
#-mthumb-interwork -DCONFIG_THUMB2_KERNEL -DCONFIG_THUMB
CFLAGS = -std=gnu99 -Ofast -Wall $(PLATFORM_CFLAGS) $(THUMB2_CFLAGS)

all : benchmark

benchmark : benchmark.o copy_page.o copy_page_orig.o memcpy_armv6v7.o copy_from_user_armv6v7.o \
copy_to_user_armv6v7.o memcpy_orig.o memset.o memzero.o \
memset_orig.o memzero_orig.o new_arm.o
	$(CC) $(CFLAGS) benchmark.o copy_page.o copy_page_orig.o \
memcpy_armv6v7.o memcpy_orig.o copy_from_user_armv6v7.o copy_to_user_armv6v7.o \
memset.o memset_orig.o memzero.o memzero_orig.o new_arm.o \
 -o benchmark -lm -lrt

clean :
	rm -f benchmark
	rm -f benchmark.o
	rm -f copy_page.o
	rm -f copy_page_orig.o
	rm -f memcpy_orig.o
	rm -f memcpy_armv6v7.o
	rm -f copy_from_user_armv6v7.o
	rm -f copy_to_user_armv6v7.o
	rm -f memset.o
	rm -f memset_orig.o
	rm -f memzero.o
	rm -f memzero_orig.o

benchmark.o : benchmark.c asm.h

copy_page_orig.o : copy_page_orig.S kernel_defines_orig.h

copy_page.o : copy_page.S kernel_defines.h

memcpy_orig.o : memcpy_orig.S copy_template_orig.S kernel_defines_orig.h

memcpy_armv6v7.o : memcpy_armv6v7.S copy_template.S kernel_defines.h

copy_from_user_armv6v7.o : copy_from_user_armv6v7.S copy_user_template_armv6v7.S kernel_defines.h

copy_to_user_armv6v7.o : copy_to_user_armv6v7.S copy_user_template_armv6v7.S kernel_defines.h

memset.o : memset.S kernel_defines.h

memzero.o : memzero.S kernel_defines.h

memset_orig.o : memset_orig.S kernel_defines.h

memzero_orig.o : memzero_orig.S kernel_defines.h

new_arm.o : new_arm.S new_arm.h

.c.o : 
	$(CC) -c $(CFLAGS) $< -o $@

.S.o :
	$(CC) -c -s $(CFLAGS) $< -o $@

.c.s :
	$(CC) -S $(CFLAGS) $< -o $@
