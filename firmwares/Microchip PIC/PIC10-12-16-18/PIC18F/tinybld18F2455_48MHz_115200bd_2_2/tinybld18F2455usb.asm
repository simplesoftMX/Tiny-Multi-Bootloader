	radix DEC
	
	; change these lines in accordance to your application	
#include "p18f2455.inc"
IdTypePIC = 0x56			; must exists in "piccodes.ini"
#define max_flash 0x6000	; in BYTES!!! (= 'max flash memory' from "piccodes.ini")
; 20MHzQuartz / 5 * 24 / 2 => 48MHz	; check _CONFIG1
xtal EQU 48000000		; 'xtal' here is resulted frequency (is no longer quartz frequency)
baud EQU 115200			; the desired baud rate
	; The above 5 lines can be changed and buid a bootloader for the desired frequency and PIC type
	
	;********************************************************************
	;	Tiny Bootloader		18F*55 series		Size=100words
	;	claudiu.chiculita@ugal.ro
	;	http://www.etc.ugal.ro/cchiculita/software/picbootloader.htm
	; 
	; modified by Edorul:
	; EEPROM write is only compatible with "Tiny PIC Bootloader+"
	; http://sourceforge.net/projects/tinypicbootload/
	;********************************************************************
	;	     |	12kW	16kW
	;	-----+----------------
	;	28pin|	2455	2550
	;	40pin|	4455	4550
	#include "../../spbrgselect.inc"	; RoundResult and baud_rate

		#define first_address max_flash-200		;=100 words
	__CONFIG _CONFIG1L, _PLLDIV_5_1L & _CPUDIV_OSC1_PLL2_1L & _USBDIV_2_1L
	__CONFIG _CONFIG1H, _FOSC_HSPLL_HS_1H & _IESO_OFF_1H ; & _FCMEM_OFF_1H
	__CONFIG _CONFIG2L, _PWRT_ON_2L & _BOR_OFF_2L ; _VREGEN_OFF_2L
	__CONFIG _CONFIG2H, _WDT_OFF_2H & _WDTPS_32768_2H 
	__CONFIG _CONFIG3H, _MCLRE_ON_3H & _PBADEN_OFF_3H & _CCP2MX_ON_3H
	__CONFIG _CONFIG4L, _DEBUG_OFF_4L & _LVP_OFF_4L & _STVREN_ON_4L & _XINST_OFF_4L
	__CONFIG _CONFIG5L, _CP0_OFF_5L & _CP1_OFF_5L & _CP2_OFF_5L
	__CONFIG _CONFIG5H, _CPB_OFF_5H & _CPD_OFF_5H
	__CONFIG _CONFIG6L, _WRT0_OFF_6L & _WRT1_OFF_6L & _WRT2_OFF_6L
	__CONFIG _CONFIG6H, _WRTB_OFF_6H & _WRTC_OFF_6H & _WRTD_OFF_6H
	__CONFIG _CONFIG7L, _EBTR0_OFF_7L & _EBTR1_OFF_7L & _EBTR2_OFF_7L
	__CONFIG _CONFIG7H, _EBTRB_OFF_7H


;----------------------------- PROGRAM ---------------------------------
	cblock 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//$1-1
	buffer:64
	crc
	i
	cnt1
	cnt2
	cnt3
	counter_hi
	counter_lo
	flag
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//$2-5
	count
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	endc
;	cblock 10
;	buffer:64
;	endc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@1-1
;SendL macro car
;	movlw car
;	movwf TXREG
;	endm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
;0000000000000000000000000 RESET 00000000000000000000000000

		ORG     0x0000
		GOTO    IntrareBootloader

;view with TabSize=4
;&&&&&&&&&&&&&&&&&&&&&&&   START     &&&&&&&&&&&&&&&&&&&&&&
;----------------------  Bootloader  ----------------------
;PC_flash:		C1h				U		H		L		x  ...  <64 bytes>   ...  crc	
;PC_eeprom:		C1h			   	40h   EEADRH  EEADR     1       EEDATA	crc					
;PC_cfg			C1h			U OR 80h	H		L		1		byte	crc
;PIC_response:	   type `K`
	
	ORG first_address			;space to deposit first 4 instr. of user prog.
	nop
	nop
	nop
	nop
	org first_address+8
IntrareBootloader
	;skip TRIS to 0 C6			;init serial port
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@4-1
;	movlw b'00100100'
	movlw 	((1<<TXEN) | (1<<BRGH))		;init serial port
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	movwf TXSTA
	;use only SPBRG (8 bit mode default) not using BAUDCON
	movlw spbrg_value
	movwf SPBRG
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@4-2
;	movlw b'10010000'
	movlw	((1<<SPEN) | (1<<CREN))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	movwf RCSTA
						;wait for computer
	rcall Receive			
	sublw 0xC1				;Expect C1h
	bnz way_to_exit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@1-2
;	SendL IdTypePIC				;send PIC type
	movlw IdTypePIC				;send PIC type
	movwf TXREG
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MainLoop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@1-3
;	SendL 'K'				; "-Everything OK, ready and waiting."
	movlw 'K'				; "-Everything OK, ready and waiting."
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
mainl
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@1-4
	movwf TXREG
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	clrf crc
	rcall Receive			;Upper
	movwf TBLPTRU
	movwf flag			;(for EEPROM and CFG cases)
	rcall Receive			;Hi
	movwf TBLPTRH
	rcall Receive			;Lo
	movwf TBLPTRL
	movwf EEADR			;(for EEPROM case)

	rcall Receive			;count
	movwf i
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//$2-6
	movwf count
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//$1-2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@2-1
;;	incf i
;;	lfsr FSR0, (buffer-1)
;	lfsr FSR0,buffer
	clrf FSR0L
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
rcvoct						;read 64+1 bytes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@2-2
;	movwf TABLAT		;prepare for cfg; => store byte before crc
	rcall Receive
;	movwf PREINC0
	movwf POSTINC0
	movwf TABLAT		;prepare for cfg; => store byte before crc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@3
;	btfss i,0		;don't know for the moment but in case of EEPROM data presence...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	movwf EEDATA		;...then store the data byte (and not the CRC!)
	decfsz i
	bra rcvoct
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@2-3
;	tstfsz crc				;check crc
;	bra ziieroare
	rcall Receive			;check crc
	bnz ziieroare
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		btfss flag,6		;is EEPROM data?
		bra noeeprom
		movlw b'00000100'	;Setup eeprom
		rcall Write
		bra waitwre
noeeprom
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;$2-1
		clrf FSR0L
		btfss flag,7		;is CFG data?
		bra noconfig
		TBLRD*-			; point to adr-1
lp_noeeprom
		rcall put1byte
		rcall Write
		decfsz	count,f
		bra lp_noeeprom
;		tblwt*			;write TABLAT(byte before crc) to TBLPTR***
;		movlw b'11000100'	;Setup cfg
;		rcall Write
		bra waitwre
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
noconfig
							;write
eraseloop
	movlw	b'10010100'		; Setup erase
	rcall Write
	TBLRD*-					; point to adr-1
	
writebigloop	
	movlw 2					; 2groups
	movwf counter_hi
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;$2-2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;$1-3
;;	lfsr FSR0,buffer
;	clrf FSR0L
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
writesloop
	movlw 32				; 32bytes = 4instr
	movwf counter_lo
writebyte
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//$2-3
	rcall put1byte
;	movf POSTINC0,w			; put 1 byte
;	movwf TABLAT
;	tblwt+*
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	decfsz counter_lo
	bra writebyte
	
	movlw	b'10000100'		; Setup writes
	rcall Write
	decfsz counter_hi
	bra writesloop
waitwre	
	;btfsc EECON1,WR		;for eeprom writes (wait to finish write)
	;bra waitwre			;no need: round trip time with PC bigger than 4ms
	
	bcf EECON1,WREN			;disable writes
	bra MainLoop
	
ziieroare					;CRC failed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//@1-5
;	SendL 'N'
	movlw 'N'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	bra mainl
	  
;******** procedures ******************

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;//$2-4
put1byte
	movf POSTINC0,w			; put 1 byte
	movwf TABLAT
	tblwt+*
	retlw b'11000100'		;Setup cfg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Write
	movwf EECON1
	movlw 0x55
	movwf EECON2
	movlw 0xAA
	movwf EECON2
	bsf EECON1,WR			;WRITE
	nop
	;nop
	return


Receive
	movlw xtal/2000000+1	; for 20MHz => 11 => 1second delay
	movwf cnt1
rpt2						
	clrf cnt2
rpt3
	clrf cnt3
rptc
		btfss PIR1,RCIF			;test RX
		bra notrcv
	    movf RCREG,w			;return read data in W
	    addwf crc,f				;compute crc
		return
notrcv
	decfsz cnt3
	bra rptc
	decfsz cnt2
	bra rpt3
	decfsz cnt1
	bra rpt2
	;timeout:
way_to_exit
	bcf	RCSTA,	SPEN			; deactivate UART
	bra first_address
;*************************************************************
; After reset
; Do not expect the memory to be zero,
; Do not expect registers to be initialised like in catalog.

            END
