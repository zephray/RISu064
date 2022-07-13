.section .text

start:
li x1, 1
li x2, 2
li x3, 3
bne x2, x3, branch_taken
li x4, 4
li x5, 5
li x6, 6
branch_taken:
li x7, 7
li x8, 8
li x9, 9
beq x8, x9, branch_not_taken
li x10, 10
li x11, 11
li x12, 12
branch_not_taken:
nop
nop
ebreak
