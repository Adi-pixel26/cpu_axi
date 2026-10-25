#Full rv32i test: exercises every remaining RV32I instruction not already
#covered by rv32i_test_1b.s -- slli/srli/srai/xori/sltiu, sll/srl/sra/xor/sltu,
#lb/lh/lbu/lhu, sb/sh, bne/blt/bge/bltu/bgeu, jal -- plus the three
#instructions 1b flagged as unimplemented (lui, auipc, jalr), which are run
#here as well since main_decoder.v is expected to support them by this stage.
#
#This is the source that rv32i_test_1c.hex was hand-assembled from, annotated
#line-by-line with the PC of each instruction and the check number/name used
#by t1_risc_cpu/.test/tb_1c.v (38 checks total, see localparams at the top of
#that file). The testbench keys each check to a PC value and looks at Result
#(and DataAdr/WriteData for stores), exactly like the numbered $display
#messages it prints during simulation -- e.g. if the console prints
#"5. sltiu implementation is incorrect", search this file for "#5 " to jump
#straight to the failing instruction and PC.
#
#Like 1b, this runs straight-line in program order with NO pass counter and
#NO recovery: if an earlier instruction's control signals go X, every PC
#after it is unreliable, so checks later in the file will not be reached
#until everything before them is fixed. Fix top-to-bottom.
#
#Calculation columns show canonical RV32I-correct values (verified by
#simulating this program in software), not necessarily what the current
#incomplete data_mem.v would produce -- data_mem.v (see MEM_SIZE array,
#word-indexed by wr_addr[31:2]) only implements word-granular storage, so the
#byte/halfword store-load pairs below (SB/LB, SH/LH) are exactly the kind of
#sub-word access the memory needs to be extended to support; do not be
#surprised if DataAdr for those doesn't yet match the "addr=" note.
#
#Instructions                                    #Calculation                          #PC    #Note

# ---- I type instructions (register file) ----
main:       addi    x1, x0, 1                    # x1 = 1                              000
            addi    x2, x0, 16                   # x2 = 16                             004
            addi    x3, x0, -3                   # x3 = -3                             008   #1 ADDI_x0 check
            addi    x4, x0, 0                    # x4 = 0 (scratch, reused by loops)    00C
            addi    x5, x3, 12                   # x5 = (-3+12) = 9                     010   #2 ADDI check
            slli    x6, x2, 2                    # x6 = (16<<2) = 64                    014   #3 SLLI check
            slti    x7, x2, -16                  # x7 = (16 < -16) = 0                  018   #4 SLTI check
            sltiu   x8, x2, -16                  # x8 = (16 <u 0xFFFFFFF0) = 1          01C   #5 SLTIU check
            xori    x9, x2, 18                   # x9 = (16 ^ 18) = 2                   020   #6 XORI check
            srli    x10, x3, 3                   # x10 = (-3 >>u 3) = 536870911         024   #7 SRLI check
            srai    x11, x3, 3                   # x11 = (-3 >>s 3) = -1                028   #8 SRAI check
            ori     x12, x3, 3                   # x12 = (-3 | 3) = -1                  02C   #9 ORI check
            andi    x13, x3, 3                   # x13 = (-3 & 3) = 1                   030   #10 ANDI check

# ---- R type instructions ----
            add     x14, x2, x1                  # x14 = (16+1) = 17                    034   #11 ADD check
            sub     x15, x2, x1                  # x15 = (16-1) = 15                    038   #12 SUB check
            sll     x16, x2, x1                  # x16 = (16<<1) = 32                   03C   #13 SLL check
            slt     x17, x2, x3                  # x17 = (16 < -3) = 0                  040   #14 SLT check
            sltu    x18, x2, x3                  # x18 = (16 <u 0xFFFFFFFD) = 1         044   #15 SLTU check
            xor     x19, x2, x1                  # x19 = (16^1) = 17                    048   #16 XOR check
            srl     x20, x2, x1                  # x20 = (16 >>u 1) = 8                 04C   #17 SRL check
            sra     x21, x2, x1                  # x21 = (16 >>s 1) = 8                 050   #18 SRA check
            or      x22, x2, x1                  # x22 = (16|1) = 17                    054   #19 OR check
            and     x23, x2, x1                  # x23 = (16&1) = 0                     058   #20 AND check

# ---- U type instructions (unimplemented in 1b) ----
            lui     x24, 0x2000                  # x24 = 0x02000000                     05C   #21 LUI check
            auipc   x25, 0x2000                  # x25 = PC+0x02000000 = 0x02000060     060   #22 AUIPC check

# ---- S type instructions (store) ----
            sb      x1, 16(x2)                   # mem_byte[16+16=32] = 1               064   #23 SB check
            sh      x3, 20(x2)                   # mem_half[16+20=36] = -3              068   #24 SH check
            sw      x2, 24(x2)                   # mem[16+24=40] = 16                   06C   #25 SW check

# ---- I type instructions (load) ----
            lb      x26, 35(x3)                  # x26 = mem_byte[-3+35=32] = 1         070   #26 LB check
            lh      x27, 39(x3)                  # x27 = mem_half[-3+39=36] = -3        074   #27 LH check
            lw      x28, 43(x3)                  # x28 = mem[-3+43=40] = 16             078   #28 LW check
            lbu     x29, 35(x3)                  # x29 = mem_byte[32] (unsigned) = 1    07C   #29 LBU check
            lhu     x30, 39(x3)                  # x30 = mem_half[36] (unsigned)        080   #30 LHU check
                                                  #     = 0x0000FFFD = 65533

# ---- BLT loop (self-contained: taken while x6 < x7, falls thru at x6==x7+1... ----
# ---- actually exits as soon as x6 is no longer < 5) ----
            addi    x4, x0, 0                    # loop counter reset                   084
            addi    x6, x0, -5                   # loop var, starts at -5               088
            addi    x7, x0, 5                    # loop bound                           08C
blt_loop:   addi    x4, x4, 1                    # x4 increments each iter              090   #31 BLT_IN check
            addi    x6, x6, 1                    # x6 increments each iter              094
            blt     x6, x7, blt_loop             # loops while x6 < 5 (10 iterations)   098   #31 BLT check
            add     x6, x0, x6                   # x6 = 5 confirms loop behaved         09C   #31 BLT_OUT check

# ---- BGE loop (counts down; taken while x9 >= x8) ----
            addi    x4, x0, 0                    # loop counter reset                   0A0
            addi    x8, x0, -5                   # loop bound                           0A4
            addi    x9, x0, 5                    # loop var, starts at 5                0A8
bge_loop:   addi    x4, x4, 1                    # x4 increments each iter              0AC   #32 BGE_IN check
            addi    x9, x9, -1                   # x9 decrements each iter              0B0
            bge     x9, x8, bge_loop             # loops while x9 >= -5 (11 iterations) 0B4   #32 BGE check
            add     x9, x0, x9                   # x9 = -6 confirms loop behaved        0B8   #32 BGE_OUT check

# ---- BLTU loop (unsigned compare; taken while x10 <u x11) ----
            addi    x4, x0, 0                    # loop counter reset                   0BC
            addi    x10, x0, 1                   # loop var, starts at 1                0C0
            addi    x11, x0, 5                   # loop bound                           0C4
bltu_loop:  addi    x4, x4, 1                    # x4 increments each iter              0C8   #33 BLTU_IN check
            addi    x10, x10, 1                  # x10 increments each iter             0CC
            bltu    x10, x11, bltu_loop          # loops while x10 <u 5 (4 iterations)  0D0   #33 BLTU check
            add     x10, x0, x10                 # x10 = 5 confirms loop behaved        0D4   #33 BLTU_OUT check

# ---- BGEU loop (unsigned compare; taken while x13 >=u x12) ----
            addi    x4, x0, 0                    # loop counter reset                   0D8
            addi    x12, x0, 1                   # loop bound                           0DC
            addi    x13, x0, 5                   # loop var, starts at 5                0E0
bgeu_loop:  addi    x4, x4, 1                    # x4 increments each iter              0E4   #34 BGEU_IN check
            addi    x13, x13, -1                 # x13 decrements each iter             0E8
            bgeu    x13, x12, bgeu_loop          # loops while x13 >=u 1 (5 iterations) 0EC   #34 BGEU check
            add     x13, x0, x13                 # x13 = 0 confirms loop behaved        0F0   #34 BGEU_OUT check

# ---- BNE loop (taken while x15 != x14) ----
            addi    x4, x0, 0                    # loop counter reset                   0F4
            addi    x14, x0, 5                   # loop bound                           0F8
            addi    x15, x0, 0                   # loop var, starts at 0                0FC
bne_loop:   addi    x4, x4, 1                    # x4 increments each iter              100   #35 BNE_IN check
            addi    x15, x15, 1                  # x15 increments each iter             104
            bne     x15, x14, bne_loop           # loops while x15 != 5 (5 iterations)  108   #35 BNE check
            add     x15, x0, x15                 # x15 = 5 confirms loop behaved        10C   #35 BNE_OUT check

# ---- BEQ loop (same as 1b: taken while x16 != x17, i.e. falls thru on equal) ----
            addi    x4, x0, 0                    # loop counter reset                   110
            addi    x16, x0, 2                   # loop var, starts at 2                114
            addi    x17, x0, 3                   # loop bound                           118
beq_loop:   addi    x4, x4, 1                    # x4 increments each iter              11C   #36 BEQ_IN check
            addi    x16, x16, 1                  # x16 increments each iter             120
                                                  # iter1: x16=3==x17(3) taken, loops
            beq     x16, x17, beq_loop           # iter2: x16=4!=3 not taken, falls thru 124   #36 BEQ check
            add     x16, x0, x16                 # x16 = 4 confirms loop behaved        128   #36 BEQ_OUT check

# ---- unimplemented instructions in 1b: jalr, jal ----
            jalr    x31, 0x134(x0)               # x31 = PC+4 = 0x130 (return addr)      12C   #37 JALR check (target=0x134,
                                                  # x0+0x134, so the padding below is
                                                  # skipped and 0x130 is only ever
                                                  # confirmed via the readback at 0x134)
            addi    x4, x0, -1                   # padding (skipped by the jalr above;   130
                                                  # only reached if jalr is broken and
                                                  # falls through instead of jumping)
            add     x31, x0, x31                 # readback: x31 = 0x130 confirms jalr   134   #37 JALR_OUT check
self:       jal     x4, self                     # x4 = PC+4 = 0x13C; jumps to itself:   138   #38 JAL check
                                                  # infinite loop, end of program
