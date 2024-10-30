;========================================================================================
; EdMon52 is an educational monitor program written for the AT89S52 for educational
; purposes. It is written using Keil uVision IDE.
; EdMon52 is inspired by MINMON - The Minimal 8051 Monitor Program by Steven B. Leeb
; This version has following commands:
; C:- changeCommand - change contents of specified external memory location
; G:- go command - executes a program
; M:- display Memory command - examine contents of specified memory location
; R:- display Registers command - display contents of registers R0 - R7
; ** Restored bin2Ascii subroutine in printHex subroutine - Hex2Ascii did not work out
; *Acknowledgement* - Subroutines with an asterisk '*' is adapted from 
; MINMON - The Minimal 8051 Monitor Program by Steven B. Leeb
; Massachusetts Institute of Technology. See link: 
; http://ee6115.mit.edu/page/8051-r31jp-info.html
; vvy - 29/10/2024 @10:50 (BST)
;========================================================================================
Stack  		EQU 	2Fh      	 ; bottom of stack - stack starts at 30h
errorFlag 	EQU 	0         	; bit 0 is error status

		Org 00h          	; power up and reset vector
		Ljmp Start

;========================================================================================
; Main program starts here
;========================================================================================
		Org     1000h		; Start address less than 0400h, program
Start:					; stalls at 2nd row of data displayed. 
		Mov     SP,#Stack      	; Initialize stack pointer
		Clr     EA             	; disable interrupts
		Acall   initSerial     	; initialize hardware
			
		Acall   printString    ; print welcome message
		db "EdMon52", 0h
			
monitorLoop:
		Clr     EA               ; disable all interrupts
		Clr     errorFlag        ; clear the error flag
		Acall   printString      ; print prompt
		db 0Dh, 0Ah,">", 0h
		Clr     RI               ; flush the serial input buffer
		Acall   getCommand       ; read the single-letter command
		Mov     R2, A            ; put the command number in R2
		Ljmp    commandSelector  ; branch to a monitor routine
endLoop:                 	         ; come here after command has finished
		Ajmp 	monitorLoop      ; loop forever in monitor loop

;========================================================================================
; Monitor jump table
;========================================================================================
jumpTable:
		dw changeMemory		; command 'c' -> index 0
		dw goCommand         	; command 'g' -> index 1
		dw DisplayMemory     	; command 'm' -> index 2
		dw rCommand          	; command 'r' -> index 3
	
;****************************************************************************************
; Monitor command routines                                                              *
;****************************************************************************************
;========================================================================================
; 'C' command  
; This routine allows user to modify external memory location
;========================================================================================
changeMemory:
		Mov A,#" "
		Lcall sendCharacter
		
		Lcall getByte        ; get address high byte
		Mov   R7, A         ; save in R7
		Mov 40h, A			; save in Acc for display purposes

		Lcall getByte        ; get address low byte
		Push  Acc           ; push LSB of address
		Mov 41h, A			; save in Acc for display purposes

		Lcall CRLF
		Mov   A, R7         ; recall address high byte
		Push  Acc          	; push MSB of jump address
		Mov DPH,40h			; Restore DPTR high nibble
		Lcall printHex
		Mov DPL,41h			; Restore DPTR low nibble
		Mov A, 41h
		Lcall printHex

		Mov A,#" "
		Lcall sendCharacter			
		
		Lcall getByte       ; get byte 
		Mov DPH,40h			; Restore DPTR high nibble
		Mov DPL,41h			; Restore DPTR low nibble
		Movx @DPTR, A       ; Store the value at the specified address
		Push  Acc          	; push MSB of jump address
		Lcall printHex		
getAnotherInput:
		Inc DPTR
		Lcall NewLine
		Mov A, DPH
		Lcall printHex
		Mov A, DPL
		Lcall printHex
		
		Mov A,#" "
		Lcall sendCharacter	
		
		Lcall getByte       ; get byte 	
		Movx @DPTR, A       ; Store the value at the specified address
		Push  Acc          	; push MSB of jump address
		Lcall printHex		
		
		Jnz getAnotherInput
		Ljmp endloop	
;========================================================================================

;========================================================================================
; 'G' command*                                                                    
; This routine branches to the 4 hex digit address following 'G'   
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
goCommand:	
			Mov A,#" "
			Acall sendCharacter
			Acall getByte          ; get address high byte
			Mov   R7, A            ; save high byte of address in R7
			Acall printHex         ; display the high byte for debugging
			Acall getByte          ; get address low byte
			Push  Acc              ; push LSB of jump address
			Acall printHex         ; display the low byte for debugging
			Acall CRLF
			Mov   A, R7            ; recall high byte of address
			Push  Acc              ; push MSB of jump address

			Ret                    ; use RET to jump to the address pushed on the stack
;================================ End of Go command =====================================

;========================================================================================
; 'M' command 
; This routine display the hex and ASCII values of memory locations.
;========================================================================================
displayMemory:      
			Acall printString
			db 0Dh, 0Ah,"Address: ", 0Dh, 0Ah, 0h
Begin:      Acall printAddress
			Acall convertData2Hex

;--------------- The following will display one row of 16 hex values -----------------
displayOneRow:     
			Mov R3,#10h		  ; R3 is used as a counter to check number of data

			Mov R0,DPH		  ; Save DPTR high nibble
			Mov R1,DPL		  ; Save DPTR low nibble
			
Back:		Clr A      
			Movc A,@A+DPTR    ; get data into Acc

            Acall Hex2Ascii
            Acall DispChar
			
            Inc DPTR		  ; point to next data
            Djnz R3,Back 	  ; Do it again if it is not equal 10h
; At this point address and one row of hex values are displayed	
;------------------- End of displaying one row of hex values ------------------------

;--------------- The following will display one row of ASCII values -----------------
displayAscii:	
			Mov R3,#10h			; Counter to check no. of data (16 data)
			Mov DPH,R0			; Restore DPTR high nibble
			Mov DPL,R1			; Restore DPTR low nibble
;*Note* - DPH and DPL is a pointer to the address location - high and low byte
Again:		Clr A  	
			Movc A,@A+DPTR  	; Get data into Acc
			Acall HandleControlChar  ; Handle control characters
			Acall Transmit      ; Send the character to serial

			Inc DPTR
            Djnz R3,Again		;Finished displaying one row of ascii values
; At this point, all ascii values are displayed		
			Mov R0,DPH			; save DPTR high nibble
			Mov R1,DPL			; save DPTR low nibble
			Acall NewLine
			Jz EndHere 		  ; If equal goto EndHere
;--------------------- End of displaying ASCII Values  ---------------------------					
;--------------- End of displaying one row of hex and ASCII values --------------

;-------- Check for the no. of rows being displayed - stop at 10 rows ------------
			Dec 40h
			Mov A, 40h
			Jz EndHere
;------------------------------ End row checking ---------------------------------
			Acall displayNextAddress
; At this point, the next address is displayed - no hex values yet

;---------------------- Display next row hex and ASCII values --------------------
PointNext:  Inc R4
            Cjne R4,#0Ah,displayOneRow		; goto Reload to display next row of data - 0Bh for 10 rows of data
            Sjmp EndHere
;--------------------- End of displaying hex and ASCII values --------------------           
EndHere:    
			Ljmp endLoop
;=========================== Display Memory command ends here ===========================

;========================================================================================
; 'R' command 
; This routine display contents of the registers
;========================================================================================
rCommand:				
			Acall printString
			db 0Dh, 0Ah, 0h
			Clr RS0
			SetB RS1                 ; Select bank 2 to access R0-R7
StartLoc:   
			Mov R0,#00h              ; Get R0 address
Renew:      
			Mov R3,#08h              ; Loop through R0-R7
Return:		
			Clr A      
			Mov A,@R0                ; Get register value into Acc
			Acall Hex2Ascii
			Acall DispChar
			
			Inc R0
			Djnz R3,Return
			Acall CRLF
			
			Clr RS0
			Clr RS1
			Ljmp endLoop
			
;**********************************************************************************
; Monitor support subroutines
;**********************************************************************************
;==================================================================================
; checkDPL subroutine
;==================================================================================
checkDPL:	Mov 45h,A				; Temporarily store `DPL` value in a working register
			Subb A,#10h				; Subtract `10h` from `DPL`
			Jz endCheck				; If result is zero, `DPL` was `10h`, so jump to `endCheck`
			Mov A,45h				; Restore `DPL` value
			Subb A,#10h				; Restore the result of `DPL - 10h` (no carry or overflow)
endCheck: 	
			Ret
;==================================================================================

;==================================================================================
; initSerial subroutine* 
; This routine initializes the hardware
; set up serial port with a 11.0592 MHz crystal,
; use timer 1 for 9600 baud serial communications
; Steven B. Leeb, Massachusetts Institute of Technology
;==================================================================================
initSerial:
			Mov   TMOD, #20h       	; set timer 1 for auto reload - mode 2
			Mov   TCON, #41h       	; run counter 1 and set edge trig ints
			Mov   TH1,  #0FDh      	; set 9600 baud with xtal=11.059mhz
			Mov   SCON, #50h       	; set serial control reg for 8-bit data and mode 1
			Ret
;========================== End initSerial subroutine =============================
		
;==================================================================================
; Display next address subroutine
; This subroutine gets the memory address from user. It echoes what it is being 
; keyed onto terminal. 
;==================================================================================
displayNextAddress:
			Mov DPH,R0			; Restore DPTR high nibble
			Mov DPL,R1			; Restore DPTR low nibble
			
			Mov A,DPH        	; get High Byte of start address
            Acall Hex2Ascii
            Acall DisplayAddress
              
            Mov A,DPL
			Acall checkDPL		; Check if DPL is 10h
            Add A,#10h			; Increment DPL by 10h
					
            Acall Hex2Ascii
            Acall DisplayAddress
            Acall AddColon
			Ret
;====================== End of displaying next address ============================  
;==================================================================================
; Convert data to hex address suroutine - used by the M command
; The following routine converts byte data into hex address and display it. 
; This routine also stores the bytes of addresses into RAM memory location 20h. 
; It uses R7 as a counter.
;==================================================================================
convertData2Hex:
			Mov R1,#20h         	;Restore address array in data memory
			Mov R7,#00h				;Counter for rows   
            Mov 40h, #0Ah			;Counter for row checking - 0Ah (10) rows
			
            Mov A,@R1
            Acall CheckHighNibble   ;Check high nibble
            Inc R1
            Mov A,@R1
            Acall CheckLowNibble	;Check low nibble
            Inc R1
            Mov DPH, A
            Acall Hex2Ascii
            Acall DisplayAddress
            
            Mov A,@R1
            Acall CheckHighNibble    
            Inc R1
            Mov A,@R1
            Acall CheckLowNibble
            Mov DPL, A
            Acall Hex2Ascii
            Acall DisplayAddress
            Acall AddColon
			Ret
;========================================================================================

;========================================================================================
; Print address subroutine
; This routine print address in hex - used by the M command
;======================================================================================== 
printAddress:
			Mov R1,#20h             ;Address of array in data memory - store user input address
            Mov R7,#00h             ;Initialize counter - use to check no. of user inputs
            
hereAgain:  Acall getCharacter		;Get character
            Acall Echo				;Display user input
            Mov @R1,A               ;store input into data memory (20h)          
  
            Inc R7                  ;Inc counter
            Inc R1                  ;Points to next location in data memory
            Cjne R7,#04h,hereAgain  ;Limit to 4 inputs  
            Acall Erase
            Acall Erase
            Acall Erase
            Acall Erase             ;Four erase operations required
			Ret
;========================================================================================

;========================================================================================
; badCommand subroutine* 
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
badCommand:
			Lcall printString
			db 0Dh, 0Ah," bad command ", 0h
			Ljmp endloop
;========================================================================================
; badParameter subroutine* 
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
badParameter:
			Lcall printString
			db 0Dh, 0Ah," bad parameter ", 0h
			Ljmp endloop
;========================================================================================

;========================================================================================
; getCommand subroutine 
;========================================================================================
getCommand:
			Lcall getCharacter           ; Get the single-letter command from user input
			Clr   Acc.5                  ; Convert lowercase to uppercase by clearing bit 5
			Lcall sendCharacter          ; Echo the command
			
			Cjne A, #'C', checkG         ; Check if command is 'C'
			Sjmp processCCommand         ; If 'C', jump to process C command
checkG:
			Cjne A, #'G', checkM         ; Check if command is 'G'
			Sjmp processGCommand         ; If 'G', jump to process G command
checkM:
			Cjne A, #'M', checkR         ; Check if command is 'M'
			Sjmp processMCommand         ; If 'M', jump to process M command
checkR:
			Cjne A, #'R', badParameter   ; Check if command is 'R'
			Sjmp processRCommand         ; If 'R', jump to process R command
			
processCCommand:
			Mov A, #00h                  ; Map 'C' to index 0 in the jump table
			Sjmp storeR2
		
processGCommand:
			Mov A, #01h                  ; Map 'G' to index 1 in the jump table
			Sjmp storeR2

processMCommand:
			Mov A, #02h                  ; Map 'M' to index 2 in the jump table
			Sjmp storeR2

processRCommand:
			Mov A, #03h                  ; Map 'R' to index 3 in the jump table
			Sjmp storeR2

storeR2:
			Mov R2, A                    ; Store the jump table index
			Ret
;========================================================================================

;========================================================================================
; commandSelector subroutine* 
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
commandSelector:
			Mov   DPTR, #jumpTable ; point DPTR at beginning of jump table
			Mov   A, R2            ; load Acc with monitor routine number
			Rl    A                ; multiply by two (for 16-bit address)
			Inc   A                ; Increment A to get the first byte of the vector
			Movc  A, @A+DPTR       ; Load first byte of vector into Acc
			Push  Acc              ; Push the first byte onto the stack
			Mov   A, R2            ; Reload Acc with monitor routine number
			Rl    A                ; Multiply by two again
			Movc  A, @A+DPTR       ; Load second byte of vector into Acc
			Push  Acc              ; Push second byte onto the stack
			Ret                    ; Use Ret to jump to the address on the stack
;========================================================================================

;========================================================================================
; sendCharacter subroutine*
; This routine takes the character in Acc and sends it out to the serial port
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
sendCharacter:
			Clr  TI            		; clear the tx buffer full flag
			Mov  SBUF,A            	; put chr in SBUF
transmitLoop:
			Jnb  TI, transmitLoop  	; wait until chr is sent
			Ret
;========================================================================================

;========================================================================================
; getCharacter subroutine* 
; This routine reads in a chr from the serial port and saves it
; in the accumulator
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
getCharacter:
			Jnb  RI, getCharacter  ; wait until character received
			Mov  A,  SBUF          ; get character
			Anl  A,  #7Fh          ; mask off 8th bit
			Clr  RI                ; clear serial status bit
			Ret
;========================================================================================

;========================================================================================
; getByte subroutine* 
; This routine reads in an 2 digit ascii hex number from the
; serial port. The result is stored in the acc.
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
getByte:
			Acall getCharacter      ; get msb ascii chr
			Acall ascii2Bin         ; conv it to binary
			Swap  A                 ; move to most sig half of acc
			Mov   B,  A             ; save in b
			Acall getCharacter      ; get lsb ascii chr
			Acall ascii2Bin         ; conv it to binary
			Orl   A,  B             ; combine two halves
			Ret
;========================================================================================

;========================================================================================
; CRLF subroutine* 
; This routine sends a carriage return line feed (CRLF) out the serial port
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
CRLF:
			Mov   A,  #0Ah         ; print line feed
			Acall sendCharacter

			Mov   A,  #0Dh         ; print carriage return
			Acall sendCharacter
			Ret
;========================================================================================

;========================================================================================
; printHex subroutine*
; This subroutine takes the contents of the acc and prints it out as a 2 digit ascii hex number.
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
printHex:
		Push Acc
		Lcall bin2Ascii           ; convert acc to ascii
		Lcall sendCharacter           ; print first ascii hex digit
		Mov   A,  R2           ; get second ascii hex digit
		Lcall sendCharacter           ; print it
		Pop Acc
		Ret
;========================================================================================

;========================================================================================
; bin2Ascii subroutine*
; This subroutine takes the contents of the accumulator and converts it
; into two ascii hex numbers.  the result is returned in the accumulator and R2.
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
bin2Ascii:
		Mov   R2, A            ; save in r2
		Anl   A,  #0Fh         ; convert least sig digit.
		Add   A,  #0F6h        ; adjust it
		Jnc   adjustOne        ; if a-f then readjust
		Add   A,  #07h
adjustOne:
		Add   A,  #3Ah         ; make ascii
		Xch   A,  r2           ; put result in reg 2
		Swap  A                ; convert most sig digit
		Anl   A,  #0Fh         ; look at least sig half of acc
		Add   A,  #0F6h        ; adjust it
		Jnc   adjustTwo        ; if a-f then re-adjust
		Add   A,  #07h
adjustTwo:
		Add   A,  #3Ah         ; make ascii
		Ret
;========================================================================================

;========================================================================================
; ascii2Bin subroutine* 
; This subroutine takes the ascii character passed to it in the acc and converts it 
; to a 4 bit binary number which is returned in the acc.
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
ascii2Bin:
			Clr   errorFlag
			Add   A,  #0D0h        ; if chr < 30 then error
			Jnc   notValid
			Clr   C                ; check if chr is 0-9
			Add   A,  #0F6h        ; adjust it
			Jc    not0to9          ; jmp if chr not 0-9
			Add   A,  #0Ah         ; if it is then adjust it
			Ret
not0to9:
			Clr   Acc.5            ; convert to upper
			Clr   C                ; check if chr is a-f
			Add   A,  #0F9h        ; adjust it
			Jnc   notValid         ; if not a-f then error
			Clr   C                ; see if char is 46 or less.
			Add   A,  #0FAh        ; adjust acc
			Jc    notValid         ; if carry then not hex
			Anl   A,  #0Fh         ; clear unused bits
			Ret
notValid:
			Setb  errorFlag        ; if not a valid digit
			Ljmp  endLoop
;========================================================================================

;========================================================================================
; printString subroutine*
; This subroutine takes the string immediately following the call and sends it out the 
; serial port. The string must be terminated with a null.
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
printString:
			Pop   DPH              ; put return address in DPTR
			Pop   DPL
getString:
			Clr  A                 ; set offset = 0
			Movc A,  @A+DPTR       ; get chr from code memory
			Cjne A,  #0h, print    ; if termination chr, then return
			Sjmp printDone
print:
			Acall sendCharacter    ; send character
			Inc   DPTR             ; point at next character
			Sjmp  getString        ; loop till end of string
printDone:
			Mov   A,  #1h          ; point to instruction after string
			Jmp   @A+DPTR          ; return
;========================================================================================

;========================================================================================
; Hex to Ascii subroutine
;========================================================================================
Hex2Ascii:  
			Mov B,A
            Anl A,#0Fh        		; mask upper nibble - work out lower nibble first				
            Acall Hex2AsciiLow    	; Convert lower nibble hex to ASCII
			Mov A,B           		; get data into Acc
            Anl A,#0F0h       		; mask lower nibble 			
            Acall Hex2AsciiHigh	  	; Convert upper nibble hex to ASCII	
            Ret
;============================== End of Hex to Ascii =====================================

;========================================================================================
; Converting High and Low Byte subroutine
;========================================================================================
Hex2AsciiLow:		
			Cjne A,#0Ah,NotEqual			
; ------------ Data equal or greater goes here ------------
NotEqual:	Jc LessThan
            Add A,#37h		  ; Add 37h if range Ah->Fh
            Mov R6,A          ; send it to R6
            Sjmp StopCon
; --------------- Data less than goes here ----------------
LessThan:	Add A,#30h		  ; Add 30h if range 0h->9h
            Mov R6,A          ; send it to R6			
StopCon:	Ret

Hex2AsciiHigh:		
			Cjne A,#0A0h,NotSame	
; ------------ Data equal or greater goes here ------------
NotSame:	Jc Smaller
            RR A
            RR A
            RR A
            RR A
            Add A,#37h
            Mov R5,A          ; send it to R5
            Sjmp Stop
; ---------------- Data less than goes here -----------------
Smaller:	RR A
            RR A
            RR A
            RR A
            Add A,#30h
            Mov R5,A          ; send it to R5
Stop:		Ret
;======================== End of Converting High and Low Byte ===========================

;========================================================================================
;Handle control characters subroutine
;========================================================================================
HandleControlChar:
			Cjne A, #21h, CheckIfNonPrintable ; Check if <= 21h

CheckIfNonPrintable:	
			Jc ReplaceControl		; Replace with '.'

			Mov 30h, A				; Preserve Acc
			Subb A, #7Fh			; Check if Acc > 7Fh
			Mov A,30h				; Restore Acc
			Jc ReturnNormal			; If < 7Fh then return and display 
			Sjmp ReplaceControl		; Replace if > 7Fh

ReplaceControl:	
			Mov A, #'.'             ; Replace with '.'
			Sjmp ReturnNormal		; Return to main
			
ReturnNormal: 
			Ret
;============================ End of handle control characters ==========================

;========================================================================================
; Display Address subroutine
;========================================================================================
DisplayAddress:   
			Setb TR1			   ;Start timer
            Mov A,R5
            Call Transmit
            Mov A,R6
            Call Transmit
            Ret
;========================================================================================

;========================================================================================
; Send character subroutine
;========================================================================================
DispChar:   
			Setb TR1			   ;Start timer
            Mov A,R5
            ACall Transmit
            Mov A,R6
            ACall Transmit
            Mov A,#" "
		    ACall Transmit
            Ret
;========================================================================================

;========================================================================================
;Add Colon subroutine
;========================================================================================
AddColon:   
			Mov A,#":"
		    ACall Transmit
            Mov A,#" "
		    ACall Transmit
            Ret
;========================================================================================

;================================ Serial Transmission ===================================
Transmit:   
			Clr TI            	; clear the tx  buffer full flag.
			Mov SBUF,A		    ;Send contents of A
Here:   	Jnb TI, Here		;wait for last bit
            Clr TI				;clear T1 for next char	
            Ret
;========================================================================================

;========================================================================================
; Erase a character subroutine
;========================================================================================
; To erase a character you need to do Backspace-Space-Backspace
Erase:      
			Push Acc
            Mov	A,#08h      ;backspace
            Acall Transmit
            Mov	A,#20h      ;space
            Acall Transmit
            Mov	A,#08h      ;backspace
            Acall Transmit
            Pop	Acc         
            Ret   
;========================================================================================

;========================================================================================
; Echo typed characrter subroutine
;========================================================================================
Echo:       
			Setb TR1          ;Timer1 start or stop bit.
            Mov SBUF,A        ;Display recieved data (echo)
Wait:      	Jnb TI,Wait       ;Stay here till data is transmitted - Transmit Interrupt (TI) flag set
            Clr TI            ;Clear TI flag and wait for next data
            Ret
;========================================================================================

;========================================================================================
;Generate newline subroutine
;========================================================================================
Newline:    
			Push	Acc
            Mov	A,#0Dh      ;carriage return
            Acall Transmit
            Mov	A,#0Ah      ;line feed
            Acall Transmit
            Pop	Acc         ;Need both carriage return and line feed to get to new line
            Ret   
;========================================================================================

;=============================== Convert High and Low Nibble =============================
;=========================================================================================
; Convert high nibble subroutine ChkHiNib
;=========================================================================================
CheckHighNibble:   
			Cjne A,#40h,Less		
; Data equal then code goes here
Less:       Jc Greater
            Acall A2FhConvertHigh
            Sjmp HaltHi
; Less than code goes here 
Greater:	Acall zero29ConvertHigh
HaltHi:		Ret 
;=========================================================================================

;=========================================================================================
; Convert low nibble subroutine
;=========================================================================================
CheckLowNibble:   
			Cjne A,#40h,NotMore		
; Data equal, then code goes here
NotMore:    Jc Bigger
            Acall A2FhConvertLow
            Sjmp HaltLo 
; less than, code goes here 
Bigger:	    Acall zero29ConvertLow
HaltLo:		Ret 
;=========================================================================================

;=========================================================================================
; Convert 0 to 9 to hex - high nibble subroutine
;=========================================================================================
zero29ConvertHigh: 
			Anl A,#0Fh        ;0-9 - mask upper nibble 
            RL A
            RL A
            RL A
            RL A
            Mov R2,A
            Ret
;=========================================================================================

;=========================================================================================
;Convert 0 to 9 to hex subroutine
;=========================================================================================
zero29ConvertLow: 
			Mov A,@R1         ;0-9 - mask lower nibble
            Anl A,#0Fh        ;mask upper nibble - work out lower nibble 
            Add A,R2
            Ret
;Convert A to F to hex - high nibble        
A2FhConvertHigh:   
			Clr C			  ;A-F - convert upper nibble
            Subb A,#41h
            Mov A,@R1
            Jc Skip
            Clr C
            Subb A,#07h
Skip:       Clr C
            Subb A,#30h
            RL A
            RL A
            RL A
            RL A
            Mov R2,A
            Ret
;=========================================================================================

;=========================================================================================
;Convert A to F to hex - low nibble subroutine
;=========================================================================================
A2FhConvertLow:   
			Clr C			  ;A-F - convert lower nibble
            Subb A,#41h
            Mov A,@R1
            Jc Skip2
            Clr C
            Subb A,#07h
Skip2:      Clr C
            Subb A,#30h
            Anl A,#0Fh
            Add A,R2
            Ret
;=========================================================================================

;=========================================================================================
; Welcome message
;=========================================================================================
			Org 0300h
LUT:        DB 0x0A, 0x0D, "Address: ", 0x0A, 0x0D, 0x00 ;0x0A - Line Feed 0x0D - Carriage Return
;=========================================================================================

;=========================================================================================
; The following is a test program. 	
;=========================================================================================
			Org 3000h
myProg:		Lcall printString
			DB "My program starts here", 0x0A, 0x0D, 0x00
			Ljmp endLoop
;=========================================================================================
		    End
