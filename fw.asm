processor 16f84
include	  <p16f84.inc>
__config  _XT_OSC & _WDT_OFF & _PWRTE_ON

;envio de datos del PC al PIC
;pin 17 (ra0) -> entrada RS232
;pin 18 (ra1) -> 1200 bps
;pin  1 (ra2) -> 2400 bps
;pin  2 (ra3) -> 4800 bps
;pin  3 (ra4) -> 9600 bps

status	equ	3h		;registro de estados del micro
ptoa	equ	5h		;puerto a
ptob	equ	6h		;puerto b
cfga	equ	85h		;registro de config. puerto a
cfgb	equ	86h		;registro de config. puerto b
r0d	equ	0dh		;registros de proposito general
r0e	equ	0eh
bits	equ	10h
recep	equ	11h		;buffer de entrada
retsb	equ	12h		;retardo del bit de arranque
reteb	equ	13h		;retardo entre bits
z	equ	2h		;bandera de zero
c	equ	0h		;bandera de carry
p	equ	5h		;bit de seleccion de pagina
w	equ	0h		;para almacenar en w
r	equ	1h		;para almacenar en el mismo registro
rx	equ	0h		;bit de recepcion de datos en serie

	org	00h		;vector de reset
	goto	inicio		;salta al comienzo del programa
	org	05h		;saltea el vector de interrupcion

start	movf	retsb,w		;retardo para generar bit de arranque
	goto	startup
delay	movf	reteb,w		;retardo para generar bit de datos
startup	movwF	r0e
redo	nop			;pierde 12 microsegundos
	nop
	decfsz	r0e		;resta 1 al retardo
	goto	redo		;si falta tiempo itera
	retlw	0		;si termino retorna limpiando w

recibir	nop			;recibe un byte por RS232
	clrf	recep		;limpia el buffer de recepcion
	btfss	ptoa,rx		;mira el estado de la linea serie
	goto	recibir		;si esta inactiva queda a la espera
	call	start		;retardo para bit de arranque
rec	movlw	8		;carga cantidad de bits a recibir
	movwf	bits
rnext	bcf	status,c	;limpia el carry
	btfss	ptoa,rx		;mira la linea de recepcion
	bsf	status,c	;si esta en alto sube el carry
	rrf	recep		;rota el buffer de recepcion
	call	delay		;retardo entre bits
	decfsz	bits		;resta uno a la cant. de bits a recibir
	goto	rnext		;si faltan bits por recibir itera
	retlw	0		;si termino sale y limpia w

inicio	bsf	status,p	;selecciona la pagina 1 de memoria
	movlw	0ffh		;programa el puerto a como entradas
	movwf	cfga
	movlw	00h		;programa el puerto b como salidas
	movwf	cfgb
	bcf	status,p	;selecciona la pagina 0 de memoria
	clrf	recep		;limpia el buffer de recepcion
	clrf	ptob		;apaga todas las salidas

sel	btfss	ptoa,1		;mira si el pin 18 esta a masa
	goto	sel12		;selecciona valores para comunicacion a 1200 bps
	btfss	ptoa,2		;mira si el pin 1 esta a masa
	goto	sel24		;selecciona valores para comunicacion a 2400 bps
	btfss	ptoa,3		;mira si el pin 2 esta a masa
	goto	sel48		;selecciona valores para comunicacion a 4800 bps
	btfss	ptoa,4		;mira si el pin 3 esta a masa
	goto	sel96		;selecciona valores para comunicacion a 9600 bps
	goto	sel		;queda a la espera que se seleccione la velocidad

ciclo	call	recibir		;queda a la espera de recibir datos
	movf	recep,w		;carga en w el dato recibido
	movwf	ptob		;manda el dato a las salidas
	goto	ciclo		;itera indefinidamente

sel12	movlw	.249		;tiempo de bit de arranque para 1200 bps
	movwf	retsb
	movlw	.166		;tiempo entre bit y bit para 1200 bps
	movwf	reteb
	goto	ciclo

sel24	movlw	.124		;tiempo de bit de arranque para 2400 bps
	movwf	retsb
	movlw	.83		;tiempo entre bit y bit para 2400 bps
	movwf	reteb
	goto	ciclo

sel48	movlw	.62		;tiempo de bit de arranque para 4800 bps
	movwf	retsb
	movlw	.41		;tiempo entre bit y bit para 4800 bps
	movwf	reteb
	goto	ciclo

sel96	movlw	.31		;tiempo de bit de arranque para 9600 bps
	movwf	retsb
	movlw	.19		;tiempo entre bit y bit para 9600 bps (probar con 20)
	movwf	reteb
	goto	ciclo

	end


