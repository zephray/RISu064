.section .text

#define UART_TX 0x20000000

start:
    li t0, UART_TX
    la t1, hello
loadchar:
    lb t2, 0(t1)
    beq t2, zero, done
    addi t1, t1, 1
    sd t2, 0(t0)
    j loadchar
done:
    nop
    nop
    ebreak

hello:
.string "Hello, world!\n"
