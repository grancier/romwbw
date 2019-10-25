;
;==================================================================================================
; DALLAS SEMICONDUCTOR DS1302 RTC DRIVER
;==================================================================================================
;
; PROGRAMMING NOTES:
;  - ALL SIGNALS ARE ACTIVE HIGH
;  - DATA OUTPUT (HOST -> RTC) ON RISING EDGE
;  - DATA INPUT (RTC -> HOST) ON FALLING EDGE
;  - SIMPLIFIED TIMING CONSTRAINTS:
;    @ 50MHZ, 1 TSTATE IS WORTH 20NS, 1 NOP IS WORTH 80NS, 1 EX (SP), IX IS WORTH 23 460NS
;    1) AFTER CHANGING CE, WAIT 1US (2 X EX (SP), IX)
;    2) AFTER CHANGING CLOCK, WAIT 250NS (3 X NOP)
;    3) AFTER SETTING A DATA BIT, WAIT 50NS (1 X NOP)
;    4) PRIOR TO READING A DATA BIT, WAIT 200NS (3 X NOP)
;
;  COMMAND BYTE:
;
;     7     6     5     4     3     2     1     0
;  +-----+-----+-----+-----+-----+-----+-----+-----+
;  |  1  | RAM |  A4 |  A3 |  A2 |  A1 |  A0 |  RD |
;  |     | ~CK |     |     |     |     |     | ~WR |
;  +-----+-----+-----+-----+-----+-----+-----+-----+
;
;  REGISTER ADDRESSES (HEX / BCD):
;
;    RD   WR   D7   D6   D5   D4   D3   D2   D1   D0     RANGE
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 81 | 80 | CH | 10 SECS      | SEC               | 00-59     |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 83 | 82 |    | 10 MINS      | MIN               | 00-59     |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 85 | 84 | TF | 00 | PM | 10 | HOURS             | 1-12/0-23 |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 87 | 86 | 00 | 00 | 10 DATE | DATE              | 1-31      |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 89 | 88 | 00 | 10 MONTHS    | MONTH             | 1-12      |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 8B | 8A | 00 | 00 | 00 | 00 | DAY               | 1-7       |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 8D | 8C | 10 YEARS          | YEAR              | 0-99      |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 8F | 8E | WP | 00 | 00 | 00 | 00 | 00 | 00 | 00 |           |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 91 | 90 | TCS               | DS      | RS      |           |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | BF | BE | *CLOCK BURST*                                     |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | C1 | C0 |                                       |           |
;  | .. | .. | *RAM*                                 |           |
;  | FD | FC |                                       |           |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | FF | FE | *RAM BURST*                           |           |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;
;  CH=CLOCK HALT (1=CLOCK HALTED & OSC STOPPED)
;  TF=12 HOUR (1) OR 24 HOUR (0)
;  PM=IF 24 HOURS, 0=AM, 1=PM, ELSE 10 HOURS
;  WP=WRITE PROTECT (1=PROTECTED)
;  TCS=TRICKLE CHARGE ENABLE (1010 TO ENABLE)
;  DS=TRICKLE CHARGE DIODE SELECT
;  RS=TRICKLE CHARGE RESISTOR SELECT
;
; CONSTANTS
;
; RTC	SBC	SBC-004	MFPIC	N8	N8-CSIO	SC	
; -----	-------	-------	-------	-------	-------	-------	
; D7 WR	RTC_OUT RTC_OUT --	RTC_OUT RTC_OUT RTC_OUT, I2C_SDA
; D6 WR	RTC_CLK RTC_CLK --	RTC_CLK RTC_CLK RTC_CLK 
; D5 WR	/RTC_WE /RTC_WE --	/RTC_WE /RTC_WE /RTC_WE  
; D4 WR	RTC_CE  RTC_CE  --	RTC_CE  RTC_CE  RTC_CE  
; D3 WR	NC      SPK     /RTC_CE	NC      NC      /SPI_CS2      
; D2 WR	NC      CLKHI   RTC_CLK	SPI_CS	SPI_CS	/SPI_CS1 
; D1 WR	--      --	RTC_WE	SPI_CLK	NC	FS
; D0 WR	--	--	RTC_OUT	SPI_DI	NC	I2C_SCL    
;                       
; D7 RD	--	--	--	--	--	I2C_SDA	 
; D6 RD	CFG	CFG	--	SPI_DO	CFG	--	 
; D5 RD	--	--	--	--	--	--	
; D4 RD	--	--	--	--	--	--	
; D3 RD	--	--	--	--	--	--	     
; D2 RD	--	--	--	--	--	--	
; D1 RD	--      --      --      --      --      --      
; D0 RD	RTC_IN  RTC_IN  RTC_IN	RTC_IN	RTC_IN  RTC_IN     
;
#IF (DSRTCMODE == DSRTCMODE_STD)
;
DSRTC_BASE	.EQU	RTCIO		; RTC PORT
;
DSRTC_DATA	.EQU	%10000000	; BIT 7 IS RTC DATA OUT
DSRTC_CLK	.EQU	%01000000	; BIT 6 IS RTC CLOCK (CLK)
DSRTC_RD	.EQU	%00100000	; BIT 5 IS DATA  DIRECTION (/WE)
DSRTC_CE	.EQU	%00010000	; BIT 4 IS CHIP ENABLE (CE)
;
DSRTC_MASK	.EQU	%11110000	; MASK FOR BITS WE OWN IN RTC LATCH PORT
DSRTC_IDLE	.EQU	%00100000	; QUIESCENT STATE
;
; VALUES FOR DIFFERENT BATTERY OR SUPERCAPACITOR CHARGE RATES
;
DS1d2k		.EQU	%10100101	; 1 DIODE 2K RESISTOR (DEFAULT)
DS1d4k		.EQU	%10100110	; 1 DIODE 4K RESISTOR
DS1d8k		.EQU	%10100111	; 1 DOIDE 8K RESISTOR
DS2d2k		.EQU	%10101001	; 2 DIODES 2K RESISTOR
DS2d4k		.EQU	%10101010	; 2 DIODES 4K RESISTOR
DS2d8k		.EQU	%10101011	; 2 DIODES 8K RESISTOR
;
#ENDIF
;
#IF (DSRTCMODE == DSRTCMODE_MFPIC)
;
DSRTC_BASE	.EQU	$43		; RTC PORT ON MF/PIC
;
DSRTC_DATA	.EQU	%00000001	; BIT 0 IS RTC DATA OUT
DSRTC_CLK	.EQU	%00000100	; BIT 2 IS RTC CLOCK (CLK)
DSRTC_WR	.EQU	%00000010	; BIT 1 IS DATA DIRECTION (WE)
DSRTC_CE	.EQU	%00001000	; BIT 3 CHIP ENABLE (/CE)
;
DSRTC_MASK	.EQU	%00001111	; MASK FOR BITS WE OWN IN RTC LATCH PORT
DSRTC_IDLE	.EQU	%00101000	; QUIESCENT STATE
;
#ENDIF
;
DSRTC_BUFSIZ	.EQU	7		; 7 BYTE BUFFER (YYMMDDHHMMSSWW)
;
; RTC DEVICE PRE-INITIALIZATION ENTRY
;
DSRTC_PREINIT:
;
	; SET RELEVANT BITS IN RTC LATCH SHADOW REGISTER
	; TO THEIR QUIESENT STATE
	LD	A,(RTCVAL)		; GET CURRENT SHADOW REG VAL
	AND	DSRTC_MASK		; CLEAR OUR BITS
	OR	DSRTC_IDLE		; SET OUR IDLE BITS
	LD	(RTCVAL),A		; SAVE IT
;
	CALL	DSRTC_DETECT		; HARDWARE DETECTION
	LD	(DSRTC_STAT),A		; SAVE RESULT
	RET	NZ			; ABORT IF ERROR
;
	; CHECK FOR CLOCK HALTED
	CALL	DSRTC_TSTCLK
	JR	Z,DSRTC_PREINIT1
	;PRTS(" INIT CLOCK $")
	LD	HL,DSRTC_TIMDEF
	CALL	DSRTC_TIM2CLK
	LD	HL,DSRTC_BUF
	CALL	DSRTC_WRCLK
;
DSRTC_PREINIT1:
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
; RTC DEVICE INITIALIZATION ENTRY
;
DSRTC_INIT:
	CALL	NEWLINE			; FORMATTING
	PRTS("DSRTC: MODE=$")
;
#IF (DSRTCMODE == DSRTCMODE_STD)
	PRTS("STD$")
#ENDIF
#IF (DSRTCMODE == DSRTCMODE_MFPIC)
	PRTS("MFPIC$")
#ENDIF
;
	; PRINT RTC LATCH PORT ADDRESS
	PRTS(" IO=0x$")			; LABEL FOR IO ADDRESS
	LD	A,DSRTC_BASE		; GET IO ADDRESS
	CALL	PRTHEXBYTE		; PRINT IT
;
	; CHECK PRESENCE STATUS
	LD	A,(DSRTC_STAT)		; GET DEVICE STATUS
	OR	A			; SET FLAGS
	JR	Z,DSRTC_INIT1		; IF ZERO, ALL GOOD
	PRTS(" NOT PRESENT$")		; NOT ZERO, H/W NOT PRESENT
	OR	$FF			; SIGNAL FAILURE
	RET				; BAIL OUT
;
DSRTC_INIT1:
	; DISPLAY CURRENT TIME
	CALL	PC_SPACE
	LD	HL,DSRTC_BUF
	CALL	DSRTC_RDCLK
	LD	HL,DSRTC_TIMBUF
	CALL	DSRTC_CLK2TIM
	LD	HL,DSRTC_TIMBUF
	CALL	PRTDT
;	
#IF	DSRTCCHG			; FORCE_RTC_CHARGE_ENABLE
	LD	C,$90			; ACCESS CHARGE REGISTER
	LD	E,DS1d2k		; STD CHARGE VALUES
	CALL	DSRTC_WRBYTWP
#ENDIF
;
	PRTS(" CHARGE=$")		; DISPLAY
	CALL DSRTC_TSTCHG		; CHARGING
	JR	NZ,NOCHG1		; STATUS
	PRTS("ON$")
	JR	NOCHG2
NOCHG1:
	PRTS("OFF$")
NOCHG2:
	XOR	A			; SIGNAL SUCCESS
	RET
;
; RTC DEVICE FUNCTION DISPATCH ENTRY
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERR
;   B: FUNCTION (IN)
;
DSRTC_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION
	JP	Z,DSRTC_GETTIM	; GET TIME
	DEC	A
	JP	Z,DSRTC_SETTIM	; SET TIME
	DEC	A
	JP	Z,DSRTC_GETBYT	; GET NVRAM BYTE VALUE
	DEC	A
	JP	Z,DSRTC_SETBYT	; SET NVRAM BYTE VALUE
	DEC	A
	JP	Z,DSRTC_GETBLK	; GET NVRAM DATA BLOCK VALUES
	DEC	A
	JP	Z,DSRTC_SETBLK	; SET NVRAM DATA BLOCK VALUES 
	CALL	PANIC
;
; NVRAM FUNCTIONS ARE NOT AVAILABLE IN SIMULATOR
;
DSRTC_GETBLK:
DSRTC_SETBLK:
	CALL	PANIC
;
; RTC GET TIME
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERR
;   HL: DATE/TIME BUFFER (OUT)
; BUFFER FORMAT IS BCD: YYMMDDHHMMSS
; 24 HOUR TIME FORMAT IS ASSUMED
;
DSRTC_GETTIM:
;
	PUSH	HL			; SAVE ADR OF OUTPUT BUF
;
	; READ THE CLOCK
	LD	HL,DSRTC_BUF		; POINT TO CLOCK BUFFER
	CALL	DSRTC_RDCLK		; READ THE CLOCK
	LD	HL,DSRTC_TIMBUF		; POINT TO TIME BUFFER
	CALL	DSRTC_CLK2TIM		; CONVERT CLOCK TO TIME
;
	; NOW COPY TO REAL DESTINATION (INTERBANK SAFE)
	LD	A,BID_BIOS		; COPY FROM BIOS BANK
	LD	(HB_SRCBNK),A           ; SET IT
	LD	A,(HB_INVBNK)		; COPY TO CURRENT USER BANK
	LD	(HB_DSTBNK),A           ; SET IT
	LD	HL,DSRTC_TIMBUF		; SOURCE ADR
	POP	DE			; DEST ADR
	LD	BC,6			; LENGTH IS 6 BYTES
#IF (INTMODE == 1)
	DI
#ENDIF
	CALL	HB_BNKCPY		; COPY THE CLOCK DATA
#IF (INTMODE == 1)
	EI
#ENDIF
;
	; CLEAN UP AND RETURN
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
; RTC SET TIME
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERR
;   HL: DATE/TIME BUFFER (IN)
; BUFFER FORMAT IS BCD: YYMMDDHHMMSS
; 24 HOUR TIME FORMAT IS ASSUMED
;
DSRTC_SETTIM:
;
	; COPY INCOMING TIME DATA TO OUR TIME BUFFER
	LD	A,(HB_INVBNK)		; COPY FROM CURRENT USER BANK
	LD	(HB_SRCBNK),A		; SET IT
	LD	A,BID_BIOS		; COPY TO BIOS BANK
	LD	(HB_DSTBNK),A		; SET IT
	LD	DE,DSRTC_TIMBUF		; DEST ADR
	LD	BC,6			; LENGTH IS 6 BYTES
#IF (INTMODE == 1)
	DI
#ENDIF
	CALL	HB_BNKCPY		; COPY THE CLOCK DATA
#IF (INTMODE == 1)
	EI
#ENDIF
;
	; WRITE TO CLOCK
	LD	HL,DSRTC_TIMBUF		; POINT TO TIME BUFFER
	CALL	DSRTC_TIM2CLK		; CONVERT TO CLOCK FORMAT
	LD	HL,DSRTC_BUF		; POINT TO CLOCK BUFFER
	CALL	DSRTC_WRCLK		; WRITE TO THE CLOCK
;
	; CLEAN UP AND RETURN
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
; RTC GET NVRAM BYTE
;   C: INDEX
;   E: VALUE (OUTPUT)
;
DSRTC_GETBYT:
	LD	A,C			; INDEX
	SLA	A			; SHIFT TO INDEX BITS
	ADD	A,$C1			; CMD OFFSET
	LD	C,A			; SAVE READ CMD BYTE
	CALL	DSRTC_RDBYT		; DO IT
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
; RTC SET NVRAM BYTE
;   C: INDEX
;   E: VALUE
;
DSRTC_SETBYT:
	LD	A,C			; INDEX
	SLA	A			; SHIFT TO INDEX BITS
	ADD	A,$C0			; CMD OFFSET
	LD	C,A			; SAVE WRITE CMD BYTE
	CALL	DSRTC_WRBYTWP		; DO IT
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
; CONVERT DATA IN CLOCK BUFFER TO TIME BUFFER AT HL
;
DSRTC_CLK2TIM:
	LD	A,(DSRTC_YR)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_MON)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_DT)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_HR)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_MIN)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_SEC)
	LD	(HL),A	
	RET
;
; CONVERT DATA IN TIME BUFFER AT HL TO CLOCK BUFFER
;
DSRTC_TIM2CLK:
	PUSH	HL
	LD	A,(HL)
	LD	(DSRTC_YR),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_MON),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_DT),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_HR),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_MIN),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_SEC),A
	POP	HL
	CALL	TIMDOW
	INC	A			; CONVERT FROM 0-6 TO 1-7
	LD	(DSRTC_DAY),A
	RET
;
; TEST CLOCK FOR CHARGE DATA
;
DSRTC_TSTCHG:
	LD	C,$91			; CHARGE RESISTOR & DIODE VALUES
	CALL	DSRTC_RDBYT		; GET VALUE
	LD	A,E			; VALUE TO A
	AND	%11110000		; CHECK FOR
	CP	%10100000		; ... ENABLED FLAG
	RET	
;
; DETECT RTC HARDWARE PRESENCE
;
DSRTC_DETECT:
	LD	C,31			; NVRAM INDEX 31
	CALL	DSRTC_GETBYT		; GET VALUE
	LD	A,E			; TO ACCUM
	LD	(DSRTC_TEMP),A		; SAVE IT
	XOR	$FF			; FLIP ALL BITS
	LD	E,A			; TO E
	LD	C,31			; NVRAM INDEX 31
	CALL	DSRTC_SETBYT		; WRITE IT
	LD	C,31			; NVRAM INDEX 31
	CALL	DSRTC_GETBYT		; GET VALUE
	LD	A,(DSRTC_TEMP)		; GET SAVED VALUE
	XOR	$FF			; FLIP ALL BITS
	CP	E			; COMPARE WITH VALUE READ
	LD	A,0			; ASSUME OK
	JR	Z,DSRTC_DETECT1		; IF MATCH, GO AHEAD
	LD	A,$FF			; ELSE STATUS IS ERROR
DSRTC_DETECT1:
	PUSH	AF			; SAVE STATUS
	LD	A,(DSRTC_TEMP)		; GET SAVED VALUE
	LD	C,31			; NVRAM INDEX 31
	CALL	DSRTC_SETBYT		; SAVE IT
	POP	AF			; RECOVER STATUS
	OR	A			; SET FLAGS
	RET				; DONE
;
; TEST CLOCK FOR VALID DATA
;   READ CLOCK HALT BIT AND RETURN ZF BASED ON BIT VALUE
;   0 = RUNNING
;   1 = HALTED
;
DSRTC_TSTCLK:
	LD	C,$81			; SECONDS REGISTER HAS CLOCK HALT FLAG
	CALL	DSRTC_RDBYT		; GET REGISTER VALUE
	LD	A,E			; VALUE TO A
	AND	%10000000		; HIGH ORDER BIT IS CLOCK HALT
	RET
;
; READ RAW BYTE
;   C=READ CMD BYTE
;   E=VALUE (OUTPUT)
;
DSRTC_RDBYT:
	LD	E,C
	CALL	DSRTC_CMD
	CALL	DSRTC_GET
	CALL	DSRTC_END
	RET
;
; WRITE RAW BYTE
;   C=WRITE CMD BYTE
;   E=VALUE
;
DSRTC_WRBYT:
	PUSH	DE			; SAVE VALUE TO WRITE
	LD	E,C			; CMD TO E
	CALL	DSRTC_CMD
	POP	DE			; RESTORE VALUE
	CALL	DSRTC_PUT
	CALL	DSRTC_END
	RET
;
; WRITE RAW BYTE W/ WRITE PROTECT BRACKETING
;   C=WRITE CMD BYTE
;   E=VALUE
;
DSRTC_WRBYTWP:
	LD	D,C			; WRITE CMD TO D
	PUSH	DE			; SAVE PARMS
;	
	; TURN OFF WRITE PROTECT
	LD	C,$8E			; CMD
	LD	E,0			; WRITE PROTECT OFF
	CALL	DSRTC_WRBYT		; DO IT
;
	; WRITE THE VALUE
	POP	DE			; RESTORE INPUTS
	LD	C,D			; WRITE CMD BACK TO C
	CALL	DSRTC_WRBYT		; DO IT
;
	; TURN WRITE PROTECT BACK ON 
	LD	C,$8E			; WRITE CMD TO D
	LD	E,$80			; WRITE PROTECT ON
	CALL	DSRTC_WRBYT		; DO IT
;
	RET
;
; BURST READ CLOCK DATA INTO BUFFER AT HL
;
DSRTC_RDCLK:
	LD	E,$BF			; COMMAND = $BF TO BURST READ CLOCK
	CALL	DSRTC_CMD		; SEND COMMAND TO RTC
	LD	B,DSRTC_BUFSIZ		; B IS LOOP COUNTER
DSRTC_RDCLK1:
	PUSH	BC			; PRESERVE BC
	CALL	DSRTC_GET		; GET NEXT BYTE
	LD	(HL),E			; SAVE IN BUFFER
	INC	HL			; INC BUF POINTER
	POP	BC			; RESTORE BC
	DJNZ	DSRTC_RDCLK1		; LOOP IF NOT DONE
	JP	DSRTC_END		; FINISH IT
;
; BURST WRITE CLOCK DATA FROM BUFFER AT HL
;
DSRTC_WRCLK:
	LD	E,$8E			; COMMAND = $8E TO WRITE CONTROL REGISTER
	CALL	DSRTC_CMD		; SEND COMMAND
	LD	E,$00			; $00 = UNPROTECT
	CALL	DSRTC_PUT		; SEND VALUE TO CONTROL REGISTER
	CALL	DSRTC_END		; FINISH IT
;
	LD	E,$BE			; COMMAND = $BE TO BURST WRITE CLOCK
	CALL	DSRTC_CMD		; SEND COMMAND TO RTC
	LD	B,DSRTC_BUFSIZ		; B IS LOOP COUNTER
DSRTC_WRCLK1:
	PUSH	BC			; PRESERVE BC
	LD	E,(HL)			; GET NEXT BYTE TO WRITE
	CALL	DSRTC_PUT		; PUT NEXT BYTE
	INC	HL			; INC BUF POINTER
	POP	BC			; RESTORE BC
	DJNZ	DSRTC_WRCLK1		; LOOP IF NOT DONE
	LD	E,$80			; ADD CONTROL REG BYTE, $80 = PROTECT ON
	CALL	DSRTC_PUT		; WRITE REQUIRED 8TH BYTE
	JP	DSRTC_END		; FINISH IT
;
; SEND COMMAND IN E TO RTC
;   ALL RTC SEQUENCES MUST CALL THIS FIRST TO SEND THE RTC COMMAND.
;   THE COMMAND IS SENT VIA A PUT.  CE AND CLK ARE LEFT ASSERTED!  THIS
;   IS INTENTIONAL BECAUSE WHEN THE CLOCK IS LOWERED, THE FIRST BIT
;   WILL BE PRESENTED TO READ (IN THE CASE OF A READ CMD).
;
;   N.B. REGISTER A CONTAINS WORKING VALUE OF LATCH PORT AND MUST NOT
;   BE MODIFIED BETWEEN CALLS TO DSRTC_CMD, DSRTC_PUT, AND DSRTC_GET.
;
;   0) ASSUME ALL LINES UNDEFINED AT ENTRY
;   1) DEASSERT ALL LINES (CE, RD, CLOCK, & DATA)
;   2) WAIT 1US
;   3) SET CE HI
;   4) WAIT 1US
;   5) PUT COMMAND
;
DSRTC_CMD:
	LD	A,(RTCVAL)		; INIT A WITH QUIESCENT STATE
	OUT	(DSRTC_BASE),A		; WRITE TO PORT
	CALL	DLY2			; DELAY 2 * 27 T-STATES
#IF (DSRTCMODE == DSRTCMODE_MFPIC)
	AND	~DSRTC_CE		; ASSERT CE (LOW)
#ELSE
	OR	DSRTC_CE		; ASSERT CE (HIGH)
#ENDIF
	OUT	(DSRTC_BASE),A		; WRITE TO RTC PORT
	CALL	DLY2			; DELAY 2 * 27 T-STATES
	CALL	DSRTC_PUT		; WRITE IT
	RET
;
; WRITE BYTE IN E TO THE RTC
;   WRITE BYTE IN E TO THE RTC.  CE IS IMPLICITY ASSERTED AT
;   THE START.  CE AND CLK ARE LEFT ASSERTED AT THE END IN CASE
;   NEXT ACTION IS A READ.
;
;   0) ASSUME ENTRY WITH CE HI, OTHERS UNDEFINED
;   1) SET CLK LO
;   2) WAIT 250NS
;   3) SET DATA ACCORDING TO BIT VALUE
;   4) SET CLOCK HI
;   5) WAIT 250NS (CLOCK READS DATA BIT FROM BUS)
;   6) LOOP FOR 8 DATA BITS
;   7) EXIT WITH CE,CLK HI
;
DSRTC_PUT:
	LD	B,8			; LOOP FOR 8 BITS
#IF (DSRTCMODE == DSRTCMODE_MFPIC)
	OR	DSRTC_WR		; SET WRITE MODE
#ELSE
	AND	~DSRTC_RD		; SET WRITE MODE
#ENDIF
DSRTC_PUT1:
	AND	~DSRTC_CLK		; SET CLOCK LOW
	OUT	(DSRTC_BASE),A		; DO IT
	CALL	DLY1			; DELAY 27 T-STATES
	
#IF (DSRTCMODE == DSRTCMODE_MFPIC)
	RRA				; PREP ACCUM TO GET DATA BIT IN CARRY
	RR	E			; ROTATE NEXT BIT TO SEND INTO CARRY
	RLA				; ROTATE BITS BACK TO CORRECT POSTIIONS
#ELSE
	RLA				; PREP ACCUM TO GET DATA BIT IN CARRY
	RR	E			; ROTATE NEXT BIT TO SEND INTO CARRY
	RRA				; ROTATE BITS BACK TO CORRECT POSTIIONS
#ENDIF	
	OUT	(DSRTC_BASE),A		; ASSERT DATA BIT ON BUS
	OR	DSRTC_CLK		; SET CLOCK HI
	OUT	(DSRTC_BASE),A		; DO IT
	CALL	DLY1			; DELAY 27 T-STATES
	DJNZ	DSRTC_PUT1		; LOOP IF NOT DONE
	RET
;
; READ BYTE FROM RTC, RETURN VALUE IN E
;   READ THE NEXT BYTE FROM THE RTC INTO E.  CE IS IMPLICITLY
;   ASSERTED AT THE START.  CE AND CLK ARE LEFT ASSERTED AT
;   THE END.  CLOCK *MUST* BE LEFT ASSERTED FROM DSRTC_CMD!
;
;   0) ASSUME ENTRY WITH CE HI, OTHERS UNDEFINED
;   1) SET RD HI AND CLOCK LOW
;   3) WAIT 250NS (CLOCK PUTS DATA BIT ON BUS)
;   4) READ DATA BIT
;   5) SET CLOCK HI
;   6) WAIT 250NS
;   7) LOOP FOR 8 DATA BITS
;   8) EXIT WITH CE,CLK,RD HI
;
DSRTC_GET:
	LD	E,0			; INITIALIZE WORKING VALUE TO 0
	LD	B,8			; LOOP FOR 8 BITS
#IF (DSRTCMODE == DSRTCMODE_MFPIC)
	AND	~DSRTC_WR		; SET READ MODE
#ELSE
	OR	DSRTC_RD		; SET READ MODE
#ENDIF
DSRTC_GET1:
	AND	~DSRTC_CLK		; SET CLK LO
	OUT	(DSRTC_BASE),A		; WRITE TO RTC PORT
	CALL	DLY1			; DELAY 2 * 27 T-STATES
	PUSH	AF			; SAVE PORT VALUE
	IN	A,(DSRTC_BASE)		; READ THE RTC PORT
	RRA				; DATA BIT TO CARRY
	RR	E			; SHIFT INTO WORKING VALUE
	POP	AF			; RESTORE PORT VALUE
	OR	DSRTC_CLK		; CLOCK BACK TO HI
	OUT	(DSRTC_BASE),A		; WRITE TO RTC PORT
	CALL	DLY1			; DELAY 27 T-STATES
	DJNZ	DSRTC_GET1		; LOOP IF NOT DONE (13)
	RET
;
; COMPLETE A COMMAND SEQUENCE
;   FINISHES UP A COMMAND SEQUENCE.
;   DOES NOT DESTROY ANY REGISTERS.
;
;   1) SET ALL LINES BACK TO QUIESCENT STATE
;
DSRTC_END:
	LD	A,(RTCVAL)		; INIT A WITH QUIESCENT STATE
	OUT	(DSRTC_BASE),A		; WRITE TO PORT
	RET				; RETURN
;
; WORKING VARIABLES
;
DSRTC_STAT	.DB	0		; DEVICE STATUS (0=OK)
DSRTC_TEMP	.DB	0		; TEMP VALUE STORAGE
;
; DSRTC_BUF IS USED FOR BURST READ/WRITE OF CLOCK DATA TO DS-1302
; FIELDS BELOW MATCH ORDER OF DS-1302 FIELDS (BCD)
;
DSRTC_BUF:
DSRTC_SEC:	.DB	0		; SECOND
DSRTC_MIN:	.DB	0		; MINUTE
DSRTC_HR:	.DB	0		; HOUR
DSRTC_DT:	.DB	0		; DATE
DSRTC_MON:	.DB	0		; MONTH
DSRTC_DAY:	.DB	0		; DAY OF WEEK
DSRTC_YR:	.DB	0		; YEAR
;
; DSRTC_TIMBUF IS TEMP BUF USED TO STORE TIME TEMPORARILY TO DISPLAY
; IT.
;
DSRTC_TIMBUF	.FILL	6,0		; 6 BYTES FOR GETTIM
;
; DSRTC_TIMDEF IS DEFAULT TIME VALUE TO INITIALIZE CLOCK IF IT IS
; NOT RUNNING.
;
DSRTC_TIMDEF:	; DEFAULT TIME VALUE TO INIT CLOCK
		.DB	$00,$01,$01	; 2000-01-01
		.DB	$00,$00,$00	; 00:00:00