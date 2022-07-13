.section .text

start:
li x1, 1
li x2, 2
j jump_target_taken
li x5, 5
li x6, 6
li x5, 7
li x6, 8
jump_target_taken:
li x3, 3
li x4, 4
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop