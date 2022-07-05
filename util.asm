; A simple yet useful macro library written in 16-bit nasm for DOS

; Copyright (c) 2022 Andrey Sikorin

; .com programs
            bits        16
            org         0x100

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PRINT FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%macro PRINT_STR 1 ; %1 is string to print
            mov         ah, 0x09
            mov         dx, %1
            int         0x21
%endmacro

%macro PRINT_INT 1 ; %1 is word buffer
            INT_TO_STR  %1, int_buf
            PRINT_STR   int_buf
%endmacro

%macro PRINT_BIN 1 ; %1 is word
            WORD_TO_BIN %1, bin_buf
            PRINT_STR   bin_buf
%endmacro

%macro PRINT_NEW_LINE 0
            mov         ah, 0x02

            mov         dx, 0x0d                ; '\r'
            int         0x21

            mov         dx, 0x0a                ; '\n'
            int         0x21
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INPUT FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%macro INPUT_STR 2 ; %1 is input buffer, %2 is buffer size
            push        bx

            mov         ah, 0x01
            mov         cx, %2-1

%%input:    mov         bx, cx                  ; bx is -cx
            neg         bx

            int         0x21                    ; read byte from stdin

            cmp         al, 0x0d                ; '\r'
            jz          %%end
            cmp         al, '$'
            jz          %%end

            ; [%1-cx+%2-1] is forbidden
            mov         [%1+bx+%2-1], al
            loop        %%input
            inc         bx                      ; not overwrite last byte by '$'

%%end:      mov         [%1+bx+%2-1], byte '$'

            pop         bx
%endmacro

%macro INPUT_INT 1 ; %1 is word buffer, dx is 0 if error
            INPUT_STR   int_buf, int_size
            STR_TO_INT  int_buf, %1
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; STRING UTILITY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%macro STR_LEN 1 ; %1 is string, len in cx
            push        di

            mov         di, %1
            xor         cx, cx

            mov         al, '$'
%%loop:     scasb
            jz          %%end
            inc         cx
            jmp         %%loop

%%end:      pop         di
%endmacro

%macro CMP_WRD 2 ; %1 is word (e.g. keyboard), %2 is the string, result is zf
            push        di
            push        si

            ; handle case when params are di and si
            push        %2
            push        %1
            pop         di
            pop         si

%%loop:     cmp         [di], byte '$'
            jz          %%word_end
            cmp         [di], byte ' '
            jz          %%word_end

            cmpsb
            jz          %%loop
            jmp         %%end                   ; zf is unset

%%word_end: cmp         [si], byte '$'

%%end:      pop         si
            pop         di
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONVERSION FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%macro STR_TO_INT 2 ; %1 is string, %2 is int, dx is 0 if error
            push        si
            push        bx

            xor         ax, ax                  ; result is in ax
            mov         bx, 10
            mov         si, %1

            ; push number sign into stack
            push        word '+'
            cmp         [si], byte '-'
            jnz         %%atoi
%%negative: push        word '-'
            inc         si

%%atoi:     movzx       cx, byte [si]           ; store digit in cl, ch is 0
            cmp         cl, '0'
            jb          %%error
            cmp         cl, '9'
            ja          %%error

            sub         cl, '0'
            mul         bx                      ; ax * 10
            cmp         dx, 0
            jnz         %%error
            add         ax, cx

            ; check overflow
            cmp         ax, 32768
            ja          %%error
            pop         dx
            cmp         dx, '-'
            jz          %%check_end
            cmp         ax, 32767
            ja          %%error
%%check_end:
            push        dx

            inc         si
            cmp         [si], byte '$'
            jnz         %%atoi

            ; pop number sign from stack
            pop         dx
            cmp         dx, '-'
            jnz         %%end
            ; handle '-'
            neg         ax
            jmp         %%end

%%error:    mov         dx, 0

%%end:      mov         [%2], ax

            pop         bx
            pop         si
%endmacro

%macro INT_TO_STR 2 ; %1 is int, %2 is string
            push        di
            push        bx

            cld

            ; init
            mov         di, %2
            mov         ax, [%1]
            mov         bx, 10
            xor         cx, cx

            ; check for '-'
            cmp         ax, 0
            jge         %%itoa

            ; add '-' in string
            push        ax
            mov         al, '-'
            stosb
            pop         ax
            ; ax * (-1)
            neg         ax

%%itoa:     xor         dx, dx
            div         bx                      ; dx:ax / 10, digit in dx, rest in ax
            
            add         dx, '0'
            push        dx                      ; save digits in stack

            inc         cx

            cmp         ax, 0
            jnz         %%itoa

%%loop:     pop         ax                      ; load digits from stack
            stosb
            loop        %%loop

            mov         al, '$'
            stosb

            pop         bx
            pop         di
%endmacro

%macro WORD_TO_BIN 2 ; %1 is word, %2 is string
            push        di
            push        bx

            cld
            mov         di, %2
            mov         bx, [%1]
            mov         cx, 16
            xor         dx, dx

%%loop:     cmp         dx, 4
            jnz         %%shift
            add         di, 1
            xor         dx, dx

%%shift:    shl         bx, 1
            jc          %%one
            mov         al, '0'
            jmp         %%load
%%one:      mov         al, '1'
%%load:     stosb

            inc         dx
            loop        %%loop

            pop         bx
            pop         di
%endmacro

%macro BYTE_TO_HEX 2 ; %1 is byte, %2 is word for storing hex
            mov         al, [%1]
            shr         al, 4
            cmp         al, 10
            jb          %%digit1
            jmp         %%letter1

%%digit1:   add         al, '0'
            mov         [%2], al
            jmp         %%next
%%letter1:  add         al, 'a'
            sub         al, 10
            mov         [%2], al

%%next:     mov         al, [%1]
            shl         al, 4
            shr         al, 4
            cmp         al, 10
            jb          %%digit2
            jmp         %%letter2

%%digit2:   add         al, '0'
            mov         [%2 + 1], al
            jmp         %%end
%%letter2:  add         al, 'a'
            sub         al, 10
            mov         [%2 + 1], al
%%end:
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LIBRARY BUFFERS FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            section     .data
int_buf     db          "-32768$"
int_size    equ         $ - int_buf
bin_buf     db          "0000_0000_0000_0000$"
