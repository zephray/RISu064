.section .text

start:
li t0, 0x80000000
li t1, 8
sd t1, 8(t0)
add t2, t0, t1
ld t3, 0(t2)
li a0, 1
li a1, 2
li a2, 3
li a3, 4
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
nop
nop