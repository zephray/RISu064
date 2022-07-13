.section .text

start:
li t0, 1
li t1, 100
li t2, 0
_loop:
add t2, t2, t0
addi t0, t0, 1
ble t0, t1, _loop
nop
nop
ebreak