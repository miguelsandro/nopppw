processor 16f84
include	  <p16f84.inc>
__config  _XT_OSC & _WDT_OFF & _PWRTE_ON

PC      equ 02
Port_A  equ 05
Port_B  equ 06
LEIDO   equ 08

INICIO  movlw 0F
        tris Port_A
        movlw 0
        tris Port_B

        movlw 0F
        movwf LEIDO

HOL     movf LEIDO,w
        movwf Port_B

        movf Port_A,w
        andlw 3
        addwf PC
        goto HOL
        nop
        nop
        movwf LEIDO
        goto HOL

        end
