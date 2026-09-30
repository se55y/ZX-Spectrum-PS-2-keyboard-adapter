; AT-keyboard clock connected to RB6
; AT-keyboard data connected to RB5
; A8~A15 connected to RC0~RC7
; D0~D4 connected to RA0~RA2,RA4,RA5 (RA3 is input only)
; datasheet used DS40001795E
; FSR0 - pointer to RA0PPS (E90h)
; FSR1 - pointer to array where used CLC recorded

// <editor-fold defaultstate="collapsed" desc="CONFIG">
; Assembly source line config statements
; CONFIG1
  CONFIG  FEXTOSC = OFF         ; FEXTOSC External Oscillator mode Selection bits (Oscillator not enabled)
  CONFIG  RSTOSC = HFINT32      ; Power-up default value for COSC bits (HFINTOSC with 2x PLL (32MHz))
  CONFIG  CLKOUTEN = OFF
  CONFIG  CSWEN = ON            ; Clock Switch Enable bit (Writing to NOSC and NDIV is allowed)
  CONFIG  FCMEN = OFF		; Fail-Safe Clock Monitor Enable (Fail-Safe Clock Monitor is disabled)

; CONFIG2
  CONFIG  MCLRE = ON            ; Master Clear Enable bit (MCLR/VPP pin function is MCLR; Weak pull-up enabled)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bits (WDT disabled; SWDTEN is ignored)
  CONFIG  LPBOREN = OFF         ; Low-power BOR enable bit (ULPBOR disabled)
;  CONFIG  BOREN = ON            ; Brown-out Reset Enable bits (Brown-out Reset enabled, SBOREN bit ignored)
  CONFIG  BOREN = OFF           ; Brown-out Reset Enable bits (Brown-out Reset disabled)
  CONFIG  BORV = LOW            ; Brown-out Reset Voltage selection bit (Brown-out voltage (Vbor) set to 2.45V)
  CONFIG  PPS1WAY = OFF         ; PPSLOCK bit One-Way Set Enable bit (The PPSLOCK bit can be set and cleared repeatedly (subject to the unlock sequence))
  CONFIG  STVREN = ON           ; Stack Overflow/Underflow Reset Enable bit (Stack Overflow or Underflow will cause a Reset)
  CONFIG  DEBUG = OFF           ; Debugger enable bit (Background debugger disabled)

; CONFIG3
  CONFIG  WRT = OFF             ; User NVM self-write protection bits (Write protection off)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (Low Voltage programming enabled. MCLR/VPP pin function is MCLR. MCLRE configuration bit is ignored.)

; CONFIG4
  CONFIG  CP = OFF              ; User NVM Program Memory Code Protection bit (User NVM code protection disabled)
  CONFIG  CPD = OFF             ; Data NVM Memory Code Protection bit (Data NVM code protection disabled)
// config statements should precede project file includes.
// </editor-fold>
#include <xc.inc>
    PSECT   PorVec,class=CODE,reloc=2
PorVec:
    goto    main
    
;   Interrupt vector and handler
    PSECT   IsrVec,class=CODE,delta=2
IsrVec:
    banksel IOCBF
    btfss   IOCBF6
    goto    _tmr0
_ioc:
    banksel IOCBF
    clrf    IOCBF
    
    banksel TMR0L
    clrf    TMR0L		; Clear T0
    banksel T0CON0
    bsf	    T0EN		; start T0 if needed
    
    bsf	    CARRY
    banksel PORTB
    btfss   PORTB,5		; bit of data from keyboard
    bcf	    CARRY
    rrf	    scancode
    rrf	    scancode+1
    retfie
_tmr0:
    banksel T0CON0
    BCF	    T0EN
    banksel TMR0L
    clrf    TMR0L
    banksel PIR0
    bcf	    TMR0IF		; right place to clear flag!

    rlf	    scancode+1		; get rid of parity and stop bit
    rlf	    scancode
    rlf	    scancode+1
    rlf	    scancode
    
next:
    movf    scancode,W
    sublw   0xF0		; break prefix received?
    btfsc   ZERO
    goto    update_lastcode
    sublw   0xF0
    movf    scancode,W   
    call    scancode2key_num	; get key number (0~39)
    
    sublw   0xFF		; check for non-mapped key pressed    
    btfsc   ZERO
    goto    update_lastcode
    sublw   0xFF		; restore WREG value
    movwf   key_num    
    movwf   FSR1L		; offset (0~39) array pointer
   
    movlw   high(key_num2ports)
    movwf   PCLATH
    movf    key_num,W
    call    key_num2ports	; fetch RCx-RAx connection info
    movwf   ports
    
    movf    ports,W		; DS40001795E-page 51
    movlw   high(RA0PPS)	; 0Eh
    movwf   FSR0H
    movlw   low(RA0PPS)		; 90h
    movwf   FSR0L

    movf    lastcode,W
    sublw   0xF0		; break prefix
    btfsc   ZERO		; https://wiki.osdev.org/PS/2_Keyboard
    goto    _release_button
    
_press_button:
    btfss   clc_usage,0		; if ONE - CLC1 in use
    goto    _use_clc1
    btfss   clc_usage,1		; if ONE - CLC2 in use
    goto    _use_clc2
    btfss   clc_usage,2		; if ONE - CLC3 in use
    goto    _use_clc3
    btfss   clc_usage,3		; if ONE - CLC4 in use
    goto    _use_clc4
    retfie			; no free CLC found
_use_clc1:
    banksel CLCIN0PPS
    swapf   ports,W		; RAxRCx
    andlw   0x0F		; RCx
    addlw   0x10		; 1xxxxB = RCx (p.162)
    movwf   CLCIN0PPS
    ;
    movlw   CLC1OUT_CODE
    movwf   INDF0		; write to one of RAxPPS
    ;
    movlw   1
    movwf   INDF1		; record in array (offset=key_num)
    bsf	    clc_usage,0           
    goto    make_RAx_output    
_use_clc2:
    banksel CLCIN1PPS
    swapf   ports,W
    andlw   0x0F
    addlw   0x10
    movwf   CLCIN1PPS
    ;
    movlw   CLC2OUT_CODE
    movwf   INDF0
    ;
    movlw   2
    movwf   INDF1
    bsf	    clc_usage,1    
    goto    make_RAx_output    
_use_clc3:
    banksel CLCIN2PPS
    swapf   ports,W
    andlw   0x0F
    addlw   0x10
    movwf   CLCIN2PPS
    ;
    movlw   CLC3OUT_CODE
    movwf   INDF0
    ;
    movlw   3
    movwf   INDF1
    bsf	    clc_usage,2
    goto    make_RAx_output
_use_clc4:    
    banksel CLCIN3PPS
    swapf   ports,W
    andlw   0x0F
    addlw   0x10
    movwf   CLCIN3PPS
    ;
    movlw   CLC4OUT_CODE
    movwf   INDF0
    ;
    movlw   4
    movwf   INDF1
    bsf	    clc_usage,3
    goto    make_RAx_output
_release_button:
    movf    key_num,W
    movwf   FSR1L		; add array offset (0~39)
    movf    ports,W		; fetch RCxRAx info
    andlw   0x0F		; RAx
    call    value2one
    banksel TRISA
    iorwf   TRISA		; set TRISA bit (make pin input)
    ;
    movf    INDF1,W		; 1~4
    decf    WREG		; 0~3
    call    value2zero		; 11111110~11110111
    andlw   0x0F		; 00001110~00000111
    andwf   clc_usage		; clear CLCx bit    
    clrf    INDF1		; delete record in array
    goto    update_lastcode
    
make_RAx_output:
    movf    ports,W		; RCxRAx info
    andlw   0x0F		; RAx
    call    value2zero		; 1xxxxB = RCx (p.162)
    banksel TRISA
    andwf   TRISA
    
update_lastcode:
    movf    scancode,W
    movwf   lastcode
    clrf    scancode
    clrf    scancode+1    
    retfie
    
    PSECT   MainData,global,class=COMMON,space=1,delta=1,noexec
    ; receive buffer for 11-bit word (start,scancode,parity,stop)    
    scancode:	DS  2
    lastcode:	DS  1
    ;
    key_num:	DS  1	    ; 0~39 key number
    ports:	DS  1	    ; RCxRAx connection info
    ;
    clc_usage:	DS  1
    cntr:	DS  1
    
    PSECT   MainCode,global,class=CODE,delta=2 
    
CLC1OUT_CODE	EQU 00100B	;   (DS40001795E-page 163)
CLC2OUT_CODE    EQU 00101B
CLC3OUT_CODE    EQU 00110B
CLC4OUT_CODE    EQU 00111B

main:
// <editor-fold defaultstate="collapsed" desc="PORTA">
    BANKSEL LATA		; Data Latch
    movlw   0x00
    movwf   LATA		;
    BANKSEL ANSELA		;
    CLRF    ANSELA		; digital I/O
    BANKSEL TRISA		;
    MOVLW   11111111B		;
    MOVWF   TRISA		;
// </editor-fold>
// <editor-fold defaultstate="collapsed" desc="PORTB">
    BANKSEL LATB		; Data Latch
    CLRF    LATB		;
    BANKSEL ANSELB		;
    CLRF    ANSELB		; digital I/O
    BANKSEL TRISB		;
    MOVLW   01101111B		;
    MOVWF   TRISB		;
// </editor-fold>   
// <editor-fold defaultstate="collapsed" desc="PORTC">
    BANKSEL LATC		; Data Latch
    CLRF    LATC		;
    BANKSEL ANSELC		;
    CLRF    ANSELC		; digital I/O
    BANKSEL TRISC		;
    MOVLW   11111111B		; RC1 and RC0 are clock and data
    MOVWF   TRISC		;    
// </editor-fold>
// <editor-fold defaultstate="collapsed" desc="T0">
    BANKSEL T0CON0
    CLRF    T0CON0		; Postscaler = 1:1, TMR0 is an 8-bit timer, TMR0 is DISABLED

    BANKSEL T0CON1
    CLRF    T0CON1
    BCF	    T0CS0
    BSF	    T0CS1
    BCF	    T0CS2		; Clock source = Fosc/4
    
    BSF	    T0CKPS0
    BSF	    T0CKPS1
    BCF	    T0CKPS2
    BCF	    T0CKPS3		; Prescaler = 1:8
    
    BANKSEL TMR0H		; in 8-bit mode TMR0H is period register   
    MOVLW   160			; 160uS period    
    MOVWF   TMR0H
    
    BANKSEL TMR0L
    CLRF    TMR0L		; Clear Timer0
    
    BCF	    T0EN
// </editor-fold>
// <editor-fold defaultstate="collapsed" desc="INTERRUPTS">
    BANKSEL IOCBN		; NEGATIVE EDGE ON RB6 (clock from keyboard)
    BSF	    IOCBN,6

    BANKSEL PIE0
    BSF	    IOCIE
    BSF	    TMR0IE    
    BSF	    PEIE
    BSF	    GIE    
    
// </editor-fold>
// <editor-fold defaultstate="collapsed" desc="CLCs">
    banksel CLC1CON
    clrf    CLC1CON
    clrf    CLC2CON
    clrf    CLC3CON
    clrf    CLC4CON		; before configuring
    
    banksel CLC1SEL0
    movlw   00000B		; CLCIN0PPS (DS40001795E.pdf p.222)
    movwf   CLC1SEL0
    movlw   00001B		; CLCIN1PPS
    movwf   CLC2SEL0
    movlw   00010B		; CLCIN2PPS
    movwf   CLC3SEL0
    movlw   00011B		; CLCIN3PPS
    movwf   CLC4SEL0
    
    banksel CLC1GLS0
    movlw   0x02		; Gate 0 = LCx_in[0]
    movwf   CLC1GLS0
    clrf    CLC1GLS1
    clrf    CLC1GLS2
    clrf    CLC1GLS3
    
    movwf   CLC2GLS0
    clrf    CLC2GLS1
    clrf    CLC2GLS2
    clrf    CLC2GLS3

    movwf   CLC3GLS0
    clrf    CLC3GLS1
    clrf    CLC3GLS2
    clrf    CLC3GLS3

    movwf   CLC4GLS0
    clrf    CLC4GLS1
    clrf    CLC4GLS2
    clrf    CLC4GLS3
		
    clrf    CLC1POL		; LCxPOL,-,-,-,LCxG4POL,LCxG3POL,LCxG2POL,LCxG1POL
    clrf    CLC2POL
    clrf    CLC3POL
    clrf    CLC4POL
    
    movlw   0x81		
    movwf   CLC1CON		; LCxEN — LCxOUT LCxINTP LCxINTN LCxMODE<2:0>
    movwf   CLC2CON		; Enable CLC, LCxMODE = 001 (OR-XOR)
    movwf   CLC3CON
    movwf   CLC4CON				
// </editor-fold>
    clrf    clc_usage    
    clrf    lastcode
    clrf    scancode
    clrf    scancode+1

    movlw   0x20	; Linear Data Memory (0x2000~0x29AF)
    movwf   FSR1H
    clrf    FSR1L
    
    movlw   40		; array for ZX keys
    movwf   cntr

    movlw   0		; array cleanup
    movwi   FSR1++
    decfsz  cntr
    goto    $-2
    
    goto    $		; endless loop    

    /*
PSECT   lut256,class=CODE,reloc=100h,delta=2
    DS      0xFF-55	; to put BRW at xxFF address
			; 55 - length of three other LUTs
    */
;ZX key to RCxRAx mapping
key_num2ports:
    BRW
    RETLW   0x00	;0x00	caps shift  (RC0-RA0)
    RETLW   0x01	;0x01	z	    (RC0-RA1)
    RETLW   0x02	;0x02	x	    ...
    RETLW   0x04	;0x03	c
    RETLW   0x05	;0x04	v
    RETLW   0x10	;0x05	a
    RETLW   0x11	;0x06	s
    RETLW   0x12	;0x07	d
    RETLW   0x14	;0x08	f
    RETLW   0x15	;0x09	g
    RETLW   0x20	;0x0a	q
    RETLW   0x21	;0x0b	w
    RETLW   0x22	;0x0c	e
    RETLW   0x24	;0x0d	r
    RETLW   0x25	;0x0e	t
    RETLW   0x30	;0x0f	1
    RETLW   0x31	;0x10	2
    RETLW   0x32	;0x11	3
    RETLW   0x34	;0x12	4
    RETLW   0x35	;0x13	5
    RETLW   0x40	;0x14	0
    RETLW   0x41	;0x15	9
    RETLW   0x42	;0x16	8
    RETLW   0x44	;0x17	7
    RETLW   0x45	;0x18	6
    RETLW   0x50	;0x19	p
    RETLW   0x51	;0x1a	o
    RETLW   0x52	;0x1b	i
    RETLW   0x54	;0x1c	u
    RETLW   0x55	;0x1d	y
    RETLW   0x60	;0x1e	enter
    RETLW   0x61	;0x1f	l
    RETLW   0x62	;0x20	k
    RETLW   0x64	;0x21	j
    RETLW   0x65	;0x22	h
    RETLW   0x70	;0x23	space
    RETLW   0x71	;0x24	symbol shift
    RETLW   0x72	;0x25	m
    RETLW   0x74	;0x26	n
    RETLW   0x75	;0x27	b
	
value2one:
    BRW
    RETLW   00000001B	; to use in iorwf TRISA
    RETLW   00000010B    
    RETLW   00000100B    
    RETLW   00001000B
    RETLW   00010000B    
    RETLW   00100000B
    
value2zero:
    BRW
    RETLW   11111110B	; to use in andwf TRISA
    RETLW   11111101B
    RETLW   11111011B
    RETLW   11110111B
    RETLW   11101111B    
    RETLW   11011111B
    
LUT256:
scancode2key_num:
    BRW	;   key_num	    scancode	key
    RETLW   0xFF        ;   0 (0x00)
    RETLW   0xFF        ;   1 (0x01)
    RETLW   0xFF        ;   2 (0x02)
    RETLW   0xFF        ;   3 (0x03)
    RETLW   0xFF        ;   4 (0x04)
    RETLW   0xFF        ;   5 (0x05)
    RETLW   0xFF        ;   6 (0x06)
    RETLW   0xFF        ;   7 (0x07)
    RETLW   0xFF        ;   8 (0x08)
    RETLW   0xFF        ;   9 (0x09)
    RETLW   0xFF        ;  10 (0x0A)
    RETLW   0xFF        ;  11 (0x0B)
    RETLW   0xFF        ;  12 (0x0C)
    RETLW   0xFF        ;  13 (0x0D)
    RETLW   0xFF        ;  14 (0x0E)
    RETLW   0xFF        ;  15 (0x0F)
    RETLW   0xFF        ;  16 (0x10)
    RETLW   0xFF        ;  17 (0x11)
    RETLW   0x00        ;  18 (0x12)	caps shift
    RETLW   0xFF        ;  19 (0x13)
    RETLW   0xFF        ;  20 (0x14)
    RETLW   0x0a        ;  21 (0x15)	q
    RETLW   0x0f        ;  22 (0x16)	1 (one)
    RETLW   0xFF        ;  23 (0x17)
    RETLW   0xFF        ;  24 (0x18)
    RETLW   0xFF        ;  25 (0x19)
    RETLW   0x01        ;  26 (0x1A)	z
    RETLW   0x06        ;  27 (0x1B)	s
    RETLW   0x05        ;  28 (0x1C)	a
    RETLW   0x0b        ;  29 (0x1D)	w
    RETLW   0x10        ;  30 (0x1E)	2
    RETLW   0xFF        ;  31 (0x1F)
    RETLW   0xFF        ;  32 (0x20)
    RETLW   0x03        ;  33 (0x21)	c
    RETLW   0x02        ;  34 (0x22)	x
    RETLW   0x07        ;  35 (0x23)	d
    RETLW   0x0c        ;  36 (0x24)	e
    RETLW   0x12        ;  37 (0x25)	4
    RETLW   0x11        ;  38 (0x26)	3
    RETLW   0xFF        ;  39 (0x27)
    RETLW   0xFF        ;  40 (0x28)
    RETLW   0x23        ;  41 (0x29)	space
    RETLW   0x04        ;  42 (0x2A)	v
    RETLW   0x08        ;  43 (0x2B)	f
    RETLW   0x0e        ;  44 (0x2C)	t
    RETLW   0x0d        ;  45 (0x2D)	r
    RETLW   0x13        ;  46 (0x2E)	5
    RETLW   0xFF        ;  47 (0x2F)
    RETLW   0xFF        ;  48 (0x30)
    RETLW   0x26        ;  49 (0x31)	n
    RETLW   0x27        ;  50 (0x32)	b
    RETLW   0x22        ;  51 (0x33)	h
    RETLW   0x09        ;  52 (0x34)	g
    RETLW   0x1d        ;  53 (0x35)	y
    RETLW   0x18        ;  54 (0x36)	6
    RETLW   0xFF        ;  55 (0x37)
    RETLW   0xFF        ;  56 (0x38)
    RETLW   0xFF        ;  57 (0x39)
    RETLW   0x25        ;  58 (0x3A)	m
    RETLW   0x21        ;  59 (0x3B)	j
    RETLW   0x1c        ;  60 (0x3C)	u
    RETLW   0x17        ;  61 (0x3D)	7
    RETLW   0x16        ;  62 (0x3E)	8
    RETLW   0xFF        ;  63 (0x3F)
    RETLW   0xFF        ;  64 (0x40)
    RETLW   0xFF        ;  65 (0x41)
    RETLW   0x20        ;  66 (0x42)	k
    RETLW   0x1b        ;  67 (0x43)	i
    RETLW   0x1a        ;  68 (0x44)	o
    RETLW   0x14        ;  69 (0x45)	0
    RETLW   0x15        ;  70 (0x46)	9
    RETLW   0xFF        ;  71 (0x47)
    RETLW   0xFF        ;  72 (0x48)
    RETLW   0xFF        ;  73 (0x49)
    RETLW   0xFF        ;  74 (0x4A)
    RETLW   0x1f        ;  75 (0x4B)	l
    RETLW   0xFF        ;  76 (0x4C)
    RETLW   0x19        ;  77 (0x4D)	p
    RETLW   0xFF        ;  78 (0x4E)
    RETLW   0xFF        ;  79 (0x4F)
    RETLW   0xFF        ;  80 (0x50)
    RETLW   0xFF        ;  81 (0x51)
    RETLW   0xFF        ;  82 (0x52)
    RETLW   0xFF        ;  83 (0x53)
    RETLW   0xFF        ;  84 (0x54)
    RETLW   0xFF        ;  85 (0x55)
    RETLW   0xFF        ;  86 (0x56)
    RETLW   0xFF        ;  87 (0x57)
    RETLW   0xFF        ;  88 (0x58)
    RETLW   0x24        ;  89 (0x59)	symbol shift
    RETLW   0x1e        ;  90 (0x5A)	enter
    RETLW   0xFF        ;  91 (0x5B)
    RETLW   0xFF        ;  92 (0x5C)
    RETLW   0xFF        ;  93 (0x5D)
    RETLW   0xFF        ;  94 (0x5E)
    RETLW   0xFF        ;  95 (0x5F)
    RETLW   0xFF        ;  96 (0x60)
    RETLW   0xFF        ;  97 (0x61)
    RETLW   0xFF        ;  98 (0x62)
    RETLW   0xFF        ;  99 (0x63)
    RETLW   0xFF        ; 100 (0x64)
    RETLW   0xFF        ; 101 (0x65)
    RETLW   0xFF        ; 102 (0x66)
    RETLW   0xFF        ; 103 (0x67)
    RETLW   0xFF        ; 104 (0x68)
    RETLW   0xFF        ; 105 (0x69)
    RETLW   0xFF        ; 106 (0x6A)
    RETLW   0xFF        ; 107 (0x6B)
    RETLW   0xFF        ; 108 (0x6C)
    RETLW   0xFF        ; 109 (0x6D)
    RETLW   0xFF        ; 110 (0x6E)
    RETLW   0xFF        ; 111 (0x6F)
    RETLW   0xFF        ; 112 (0x70)
    RETLW   0xFF        ; 113 (0x71)
    RETLW   0xFF        ; 114 (0x72)
    RETLW   0xFF        ; 115 (0x73)
    RETLW   0xFF        ; 116 (0x74)
    RETLW   0xFF        ; 117 (0x75)
    RETLW   0xFF        ; 118 (0x76)
    RETLW   0xFF        ; 119 (0x77)
    RETLW   0xFF        ; 120 (0x78)
    RETLW   0xFF        ; 121 (0x79)
    RETLW   0xFF        ; 122 (0x7A)
    RETLW   0xFF        ; 123 (0x7B)
    RETLW   0xFF        ; 124 (0x7C)
    RETLW   0xFF        ; 125 (0x7D)
    RETLW   0xFF        ; 126 (0x7E)
    RETLW   0xFF        ; 127 (0x7F)
    RETLW   0xFF        ; 128 (0x80)
    RETLW   0xFF        ; 129 (0x81)
    RETLW   0xFF        ; 130 (0x82)
    RETLW   0xFF        ; 131 (0x83)
    RETLW   0xFF        ; 132 (0x84)
    RETLW   0xFF        ; 133 (0x85)
    RETLW   0xFF        ; 134 (0x86)
    RETLW   0xFF        ; 135 (0x87)
    RETLW   0xFF        ; 136 (0x88)
    RETLW   0xFF        ; 137 (0x89)
    RETLW   0xFF        ; 138 (0x8A)
    RETLW   0xFF        ; 139 (0x8B)
    RETLW   0xFF        ; 140 (0x8C)
    RETLW   0xFF        ; 141 (0x8D)
    RETLW   0xFF        ; 142 (0x8E)
    RETLW   0xFF        ; 143 (0x8F)
    RETLW   0xFF        ; 144 (0x90)
    RETLW   0xFF        ; 145 (0x91)
    RETLW   0xFF        ; 146 (0x92)
    RETLW   0xFF        ; 147 (0x93)
    RETLW   0xFF        ; 148 (0x94)
    RETLW   0xFF        ; 149 (0x95)
    RETLW   0xFF        ; 150 (0x96)
    RETLW   0xFF        ; 151 (0x97)
    RETLW   0xFF        ; 152 (0x98)
    RETLW   0xFF        ; 153 (0x99)
    RETLW   0xFF        ; 154 (0x9A)
    RETLW   0xFF        ; 155 (0x9B)
    RETLW   0xFF        ; 156 (0x9C)
    RETLW   0xFF        ; 157 (0x9D)
    RETLW   0xFF        ; 158 (0x9E)
    RETLW   0xFF        ; 159 (0x9F)
    RETLW   0xFF        ; 160 (0xA0)
    RETLW   0xFF        ; 161 (0xA1)
    RETLW   0xFF        ; 162 (0xA2)
    RETLW   0xFF        ; 163 (0xA3)
    RETLW   0xFF        ; 164 (0xA4)
    RETLW   0xFF        ; 165 (0xA5)
    RETLW   0xFF        ; 166 (0xA6)
    RETLW   0xFF        ; 167 (0xA7)
    RETLW   0xFF        ; 168 (0xA8)
    RETLW   0xFF        ; 169 (0xA9)
    RETLW   0xFF        ; 170 (0xAA)
    RETLW   0xFF        ; 171 (0xAB)
    RETLW   0xFF        ; 172 (0xAC)
    RETLW   0xFF        ; 173 (0xAD)
    RETLW   0xFF        ; 174 (0xAE)
    RETLW   0xFF        ; 175 (0xAF)
    RETLW   0xFF        ; 176 (0xB0)
    RETLW   0xFF        ; 177 (0xB1)
    RETLW   0xFF        ; 178 (0xB2)
    RETLW   0xFF        ; 179 (0xB3)
    RETLW   0xFF        ; 180 (0xB4)
    RETLW   0xFF        ; 181 (0xB5)
    RETLW   0xFF        ; 182 (0xB6)
    RETLW   0xFF        ; 183 (0xB7)
    RETLW   0xFF        ; 184 (0xB8)
    RETLW   0xFF        ; 185 (0xB9)
    RETLW   0xFF        ; 186 (0xBA)
    RETLW   0xFF        ; 187 (0xBB)
    RETLW   0xFF        ; 188 (0xBC)
    RETLW   0xFF        ; 189 (0xBD)
    RETLW   0xFF        ; 190 (0xBE)
    RETLW   0xFF        ; 191 (0xBF)
    RETLW   0xFF        ; 192 (0xC0)
    RETLW   0xFF        ; 193 (0xC1)
    RETLW   0xFF        ; 194 (0xC2)
    RETLW   0xFF        ; 195 (0xC3)
    RETLW   0xFF        ; 196 (0xC4)
    RETLW   0xFF        ; 197 (0xC5)
    RETLW   0xFF        ; 198 (0xC6)
    RETLW   0xFF        ; 199 (0xC7)
    RETLW   0xFF        ; 200 (0xC8)
    RETLW   0xFF        ; 201 (0xC9)
    RETLW   0xFF        ; 202 (0xCA)
    RETLW   0xFF        ; 203 (0xCB)
    RETLW   0xFF        ; 204 (0xCC)
    RETLW   0xFF        ; 205 (0xCD)
    RETLW   0xFF        ; 206 (0xCE)
    RETLW   0xFF        ; 207 (0xCF)
    RETLW   0xFF        ; 208 (0xD0)
    RETLW   0xFF        ; 209 (0xD1)
    RETLW   0xFF        ; 210 (0xD2)
    RETLW   0xFF        ; 211 (0xD3)
    RETLW   0xFF        ; 212 (0xD4)
    RETLW   0xFF        ; 213 (0xD5)
    RETLW   0xFF        ; 214 (0xD6)
    RETLW   0xFF        ; 215 (0xD7)
    RETLW   0xFF        ; 216 (0xD8)
    RETLW   0xFF        ; 217 (0xD9)
    RETLW   0xFF        ; 218 (0xDA)
    RETLW   0xFF        ; 219 (0xDB)
    RETLW   0xFF        ; 220 (0xDC)
    RETLW   0xFF        ; 221 (0xDD)
    RETLW   0xFF        ; 222 (0xDE)
    RETLW   0xFF        ; 223 (0xDF)
    RETLW   0xFF        ; 224 (0xE0)
    RETLW   0xFF        ; 225 (0xE1)
    RETLW   0xFF        ; 226 (0xE2)
    RETLW   0xFF        ; 227 (0xE3)
    RETLW   0xFF        ; 228 (0xE4)
    RETLW   0xFF        ; 229 (0xE5)
    RETLW   0xFF        ; 230 (0xE6)
    RETLW   0xFF        ; 231 (0xE7)
    RETLW   0xFF        ; 232 (0xE8)
    RETLW   0xFF        ; 233 (0xE9)
    RETLW   0xFF        ; 234 (0xEA)
    RETLW   0xFF        ; 235 (0xEB)
    RETLW   0xFF        ; 236 (0xEC)
    RETLW   0xFF        ; 237 (0xED)
    RETLW   0xFF        ; 238 (0xEE)
    RETLW   0xFF        ; 239 (0xEF)
    RETLW   0xFF        ; 240 (0xF0)
    RETLW   0xFF        ; 241 (0xF1)
    RETLW   0xFF        ; 242 (0xF2)
    RETLW   0xFF        ; 243 (0xF3)
    RETLW   0xFF        ; 244 (0xF4)
    RETLW   0xFF        ; 245 (0xF5)
    RETLW   0xFF        ; 246 (0xF6)
    RETLW   0xFF        ; 247 (0xF7)
    RETLW   0xFF        ; 248 (0xF8)
    RETLW   0xFF        ; 249 (0xF9)
    RETLW   0xFF        ; 250 (0xFA)
    RETLW   0xFF        ; 251 (0xFB)
    RETLW   0xFF        ; 252 (0xFC)
    RETLW   0xFF        ; 253 (0xFD)
    RETLW   0xFF        ; 254 (0xFE)
    RETLW   0xFF        ; 255 (0xFF)
   
    END	PorVec



