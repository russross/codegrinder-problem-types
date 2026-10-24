                .global print_string, print_int, print_hex, print_set, print_int_array
                .equ    stdout, 1
                .equ    sys_write, 64
                .equ    sys_exit, 93
                .equ    print_string_args, 1
                .equ    print_int_args, 1
                .equ    print_hex_args, 1
                .equ    print_set_args, 1
                .equ    print_int_array_args, 2

                .text

# print_string(s)
print_string:
                # a1: ptr
                # a2: len
                mv      a1, a0
                li      a2, 0
1:              add     t0, a1, a2
                lb      t1, (t0)
                beqz    t1, 2f
                addi    a2, a2, 1
                j       1b
2:              li      a0, stdout
                li      a7, sys_write
                ecall
                bgez    a0, 3f
                neg     a0, a0
                li      a7, sys_exit
                ecall
3:              ret


# print_int(n)
print_int:
                addi    sp, sp, -16
                sw      ra, 12(sp)

                # a0: n
                # a1: ptr
                # a2: 10
                # a3: is_negative
                sltz    a3, a0
                bgez    a0, 1f
                neg     a0, a0
1:              mv      a1, sp
                li      a2, 10
2:              remu    t0, a0, a2
                addi    t0, t0, '0'
                sb      t0, (a1)
                addi    a1, a1, 1
                divu    a0, a0, a2
                bnez    a0, 2b
                beqz    a3, 3f
                li      t0, '-'
                sb      t0, (a1)
                addi    a1, a1, 1

                # a0: ptr_a
                # a1: ptr_b
                # a2: len
3:              sub     a2, a1, sp
                mv      a0, sp
                addi    a1, a1, -1
4:              lb      t0, (a0)
                lb      t1, (a1)
                sb      t0, (a1)
                sb      t1, (a0)
                addi    a0, a0, 1
                addi    a1, a1, -1
                blt     a0, a1, 4b

                add     t0, sp, a2
                sb      zero, (t0)

                mv      a0, sp
                jal     print_string
5:              lw      ra, 12(sp)
                addi    sp, sp, 16
                ret

# print_int_array(start, end) prints aligned int words in [start, end), without a newline.
                .data
int_array_open: .asciz  "["
int_array_sep:  .asciz  ", "
int_array_close:.asciz  "]"
                .text
print_int_array:
                # prelude
                addi    sp, sp, -16
                sw      ra, 12(sp)
                sw      s0, 8(sp)
                sw      s1, 4(sp)
                mv      s0, a0
                mv      s1, a1

                # empty ranges still print both brackets.
                la      a0, int_array_open
                jal     print_string
                bgeu    s0, s1, 2f

                # print each value, separating only adjacent elements.
1:              lw      a0, (s0)
                jal     print_int
                addi    s0, s0, 4
                bgeu    s0, s1, 2f
                la      a0, int_array_sep
                jal     print_string
                j       1b

                # close the array
2:              la      a0, int_array_close
                jal     print_string

                # postlude
                lw      ra, 12(sp)
                lw      s0, 8(sp)
                lw      s1, 4(sp)
                addi    sp, sp, 16
                ret

# print_hex(n)
print_hex:
                addi    sp, sp, -16
                sw      ra, 12(sp)

                # a0: n
                # a1: ptr
                # a2: 10
                # a3: is_negative
                sltz    a3, a0
                bgez    a0, 1f
                neg     a0, a0
1:              mv      a1, sp
                li      a2, 10
2:              andi    t0, a0, 0xf
                blt     t0, a2, 3f
                addi    t0, t0, 'a' - ('0' + 10)
3:              addi    t0, t0, '0'
                sb      t0, (a1)
                addi    a1, a1, 1
                srli    a0, a0, 4
                bnez    a0, 2b
                beqz    a3, 4f
                li      t0, '-'
                sb      t0, (a1)
                addi    a1, a1, 1

                # a0: ptr_a
                # a1: ptr_b
                # a2: len
4:              sub     a2, a1, sp
                mv      a0, sp
                addi    a1, a1, -1
5:              lb      t0, (a0)
                lb      t1, (a1)
                sb      t0, (a1)
                sb      t1, (a0)
                addi    a0, a0, 1
                addi    a1, a1, -1
                blt     a0, a1, 5b

                add     t0, sp, a2
                sb      zero, (t0)

                mv      a0, sp
                jal     print_string
5:              lw      ra, 12(sp)
                addi    sp, sp, 16
                ret

# print_set(set)
print_set:
                # prelude
                addi    sp, sp, -16
                sw      ra, 12(sp)

                # a0: in
                # a1: out
                # a2: i
                # a3: 10
                li      a1, 0
                li      a3, 10

                # for i from [31,0]
                li      a2, 31
1:              li      t0, 1
                sll     t1, t0, a2
                and     t2, a0, t1
                beqz    t2, 2f
                mul     a1, a1, a3
                add     a1, a1, a2
2:              addi    a2, a2, -1
                bgez    a2, 1b

                mv      a0, a1
                jal     print_int

                lw      ra, 12(sp)
                addi    sp, sp, 16
                ret
