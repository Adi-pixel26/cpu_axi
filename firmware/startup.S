.section .init
.global _start
.type _start, @function

_start:
    la      gp, __global_pointer$
    la      sp, __stack_top

    # Clear all uninitialized global variables (.bss).
    la      t0, __bss_start
    la      t1, __bss_end

clear_bss:
    bgeu    t0, t1, call_main
    sw      zero, 0(t0)
    addi    t0, t0, 4
    jal     zero, clear_bss

call_main:
    call    main

hang:
    jal     zero, hang