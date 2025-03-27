;========================================================================================
; EdMon52 is an educational monitor program written for the AT89S52 microcontroller for 
; educational purposes. It is developed using the Keil uVision IDE.
; EdMon52 is inspired by MINMON - The Minimal 8051 Monitor Program by Steven B. Leeb.
;
; This is version 4.0. It includes the following commands:
; C: - Change command - changes the contents of a specified external memory location.
; G: - Go command - executes a program.
; M: - Display Memory command - examines the contents of a specified memory location.
; R: - Display Registers command - displays the contents of registers R0 - R7.
; Q: - Quit command - exits the program.
;
; Latest update: With C command - the address that is being keyed is echo to the terminal. 
;
; ** Several subroutines written previously have been removed and replaced with MINMON 
;    subroutines. The code is now shorter.
;
; *Acknowledgment* - Subroutines marked with an asterisk '*' are adapted from
; MINMON - The Minimal 8051 Monitor Program by Steven B. Leeb,
; Massachusetts Institute of Technology. See link:
; http://ee6115.mit.edu/page/8051-r31jp-info.html
;
; vvy - 13/03/2024 @11:40 (BST) - latest update
;========================================================================================

Stack  		EQU 	2Fh       	  ; bottom of stack - stack starts at 30h
errorFlag 	EQU 	0         	  ; bit 0 is error status

			Org 00h               ; power up and reset vector
			Ljmp Start

;========================================================================================
; Main program starts here
;========================================================================================
			Org     1000h		   ; Start address less than 0400h, program
Start:						   	   ; stalls at 2nd row of data displayed. 
			Mov     SP,#Stack      ; Initialize stack pointer
			Clr     EA             ; disable interrupts
			Acall   initSerial     ; initialize hardware
			
			Acall   CommandMenu		; print command menu			
			
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
			dw changeMemory		 ; command 'C' -> index 0
			dw goCommand         ; command 'G' -> index 1
			dw displayMemory     ; command 'M' -> index 2
			dw rCommand          ; command 'R' -> index 3
			dw quitCommand       ; command 'Q' -> index 4
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
			
			Lcall getByte       ; get high byte address 
			Mov   R7, A         ; save in R7
			Mov 40h, A			; save [Acc] - high byte address
			Lcall printHex
			
			Lcall getByte       ; get low byte address 
			Push  Acc           ; push LSB of address
			Mov 41h, A			; save [Acc] - low byte address
			Lcall printHex
			
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
			Lcall newLine
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
			DB 0Dh, 0Ah,"Address: ", 0Dh, 0Ah, 0h
			
			Lcall getByte       ; get address high byte
			Mov   R7, A         ; save [Acc] in R7
			Mov 40h, A			; save [Acc] - high byte address
			Lcall printHex
			
			Lcall getByte       ; get address low byte
			Push  Acc           ; push LSB of address
			Mov 41h, A			; save [Acc] - low byte address
			Lcall printHex
			
			Mov   A, R7         ; recall address high byte
			Push  Acc          	; push MSB of jump address
			Mov DPH,40h			; Restore DPTR high nibble
			Mov DPL,41h			; Restore DPTR low nibble
			Mov A, 41h

			Acall addColon
			
			Mov 42h,#0Ah 			; Hex and Ascii values row counter
;--------------- The following will display one row of 16 hex values -----------------
displayOneRow:     
			Mov R3,#10h		  		; R3 is used as a counter to check number of data
			
			Mov R0,DPH		  		; Save DPTR high nibble
			Mov R1,DPL		  		; Save DPTR low nibble
			
Back:		Clr A      
			Movc A,@A+DPTR    		; get data into Acc

			Push Acc
			Lcall bin2Ascii           ; convert acc to ascii
			Lcall sendCharacter           ; print first ascii hex digit
			Mov   A,  R2           ; get second ascii hex digit
			Lcall sendCharacter           ; print it
			Pop Acc		
			Mov A,#" "
			Lcall sendCharacter
			
            Inc DPTR		  		; point to next data
            Djnz R3,Back 	  		; Do it again if it is not equal 10h
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
			Acall sendCharacter

			Inc DPTR
            Djnz R3,Again		;Finished displaying one row of ascii values
; At this point, all ascii values are displayed		
			Mov R0,DPH			; save DPTR high nibble
			Mov R1,DPL			; save DPTR low nibble
			Acall newLine
;--------------------- End of displaying ASCII Values  ---------------------------	
;-------- Check for the no. of rows being displayed - stop at 10 rows ------------
			Dec 42h
			Mov A, 42h
			Jz EndHere
;------------------------------ End row checking ---------------------------------
			Acall displayNextAddress	
			
; At this point, the next address is displayed - no hex values yet

;---------------------- Display next row hex and ASCII values --------------------
PointNext:  Inc R4
            Cjne R4,#0Ah,displayOneRow		; goto Reload to display next row of data

;--------------------- End of displaying hex and ASCII values --------------------           
EndHere:    
			Lcall getCharacter         ; Call subroutine read key
			Mov R7, A                  ; Save byte in R7
			Cjne R7, #0Dh, EndHere     ; If not Carriage Return, check if it’s Line Feed
			Ljmp Start                 ; If Carriage Return, jump to Start

;=========================== Display Memory command ends here ===========================

;========================================================================================
; 'R' command 
; This routine display contents of the registers
;========================================================================================
rCommand:				
			Acall printString
			db 0Dh, 0Ah, 0h
               	
			Mov PSW,#00h				; Select bank 2 to access R0-R7
StartLoc:   
			Mov R0,#00h              	; Get R0 address
Renew:      
			Mov R3,#08h              	; Loop through R0-R7
Return:		
			Clr A      
			Mov A,@R0                	; Get register value into Acc

			Push Acc
			Lcall bin2Ascii           	; convert [Acc] to ascii
			Lcall sendCharacter       	; print first ascii hex digit
			Mov   A,  R2           		; get second ascii hex digit
			Lcall sendCharacter        	; print it
			Pop Acc		
			Mov A,#" "
			Lcall sendCharacter
			
			Inc R0
			Djnz R3,Return

			Ljmp endLoop		
;========================================================================================

;========================================================================================
; 'Q' command 
; This routine will return to the command menu
;========================================================================================
quitCommand:
			Acall newLine
			Ljmp Start
;========================================================================================			
			
;****************************************************************************************
; Monitor support subroutines                                                           *
;****************************************************************************************

;========================================================================================	
; Command menu subroutine
;========================================================================================	
CommandMenu:
			Acall   printString    ; print message 
			DB "EdMon52 4.0", 0Dh, 0Ah, 00h
			Acall   printString    ; print message
			DB 0Dh, 0Ah, "Commands: ", 00h
			Acall   printString    ; print message
			DB 0Dh, 0Ah, "C <aaaa> <dd> - Change contents of external memory ", 00h
			Acall   printString    ; print message
			DB 0Dh, 0Ah, "G <aaaa>      - Go (execute program) ", 00h
			Acall   printString    ; print message
			DB 0Dh, 0Ah, "M <aaaa>      - Display contents of code memory ", 00h	
			Acall   printString    ; print message
			DB 0Dh, 0Ah, "R             - Dump registers ", 00h
			Acall   printString    ; print message
			DB 0Dh, 0Ah, "Q             - Quit ", 0Dh, 0Ah, 00h
			Ret
;========================================================================================

;========================================================================================
; checkDPL subroutine
;========================================================================================
checkDPL:	Mov 45h,A				; Temporarily store `DPL` value in a working register
			Subb A,#10h				; Subtract `10h` from `DPL`
			Jz endCheck				; If result is zero, `DPL` was `10h`, so jump to `endCheck`
			Mov A,45h				; Restore `DPL` value
			Subb A,#10h				; Restore the result of `DPL - 10h` (no carry or overflow)
endCheck: 	
			Ret
;========================================================================================

;========================================================================================
; initSerial subroutine* 
; This routine initializes the hardware
; set up serial port with a 11.0592 MHz crystal,
; use timer 1 for 9600 baud serial communications
; Steven B. Leeb, Massachusetts Institute of Technology
;========================================================================================
initSerial:
			Mov   TMOD, #20h       	; set timer 1 for auto reload - mode 2
			Mov   TCON, #41h       	; run counter 1 and set edge trig ints
			Mov   TH1,  #0FDh      	; set 9600 baud with xtal=11.059mhz
			Mov   SCON, #50h       	; set serial control reg for 8-bit data and mode 1
			Ret
;=============================== End initSerial subroutine ==============================
		
;========================================================================================
; Display next address subroutine
; This subroutine gets the memory address from user. It echoes what it is being 
; keyed onto the terminal. 
;========================================================================================
displayNextAddress:
			Mov A,DPH        		; get High Byte of start address

			Lcall bin2Ascii 		; convert binary to ascii
			Lcall sendCharacter 	; print first ascii hex digit
			Mov   A,  R2           	; get second ascii hex digit
			Lcall sendCharacter 	; print it
			
            Mov A,DPL
			Clr C					; Clear the carry flag - if not a one(1) is added to the result
			Acall checkDPL			; Check if DPL is 10h
            Add A,#10h				; Increment DPL by 10h
					
			Lcall bin2Ascii      	; convert acc to ascii
			Lcall sendCharacter 	; print first ascii hex digit
			Mov   A,  R2           	; get second ascii hex digit
			Lcall sendCharacter   	; print it
			
            Acall addColon
			Ret
;============================ End of displaying next address ============================  

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
			Cjne A, #'R', checkQ   		 ; Check if command is 'R'
			Sjmp processRCommand         ; If 'R', jump to process R command

checkQ:
			Cjne A, #'Q', badParameter   ; Check if command is 'Q'
			Sjmp processQCommand         ; If 'Q', jump to process Q command

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

processQCommand:
			Mov A, #04h                  ; Map 'Q' to index 4 in the jump table
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
			Lcall sendCharacter       ; print first ascii hex digit
			Mov   A,  R2           	  ; get second ascii hex digit
			Lcall sendCharacter       ; print it
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
			Mov   R2, A            ; save in R2
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
;Add Colon subroutine
;========================================================================================
addColon:   
			Mov A,#":"
		    ACall sendCharacter
            Mov A,#" "
		    ACall sendCharacter
            Ret
;========================================================================================

;========================================================================================
;Generate newline subroutine
;========================================================================================
newline:    
			Push	Acc
            Mov	A,#0Dh      ;carriage return
            Acall sendCharacter
            Mov	A,#0Ah      ;line feed
            Acall sendCharacter
            Pop	Acc         ;Need both carriage return and line feed to get to new line
            Ret   
;========================================================================================

;=========================================================================================
; The following is a test program. 	
;=========================================================================================
			Org 4000h
myProg:		Mov DPTR,#LUT
DoAgain:	Clr A
			Movc A,@A+DPTR
			Jz Finish
			Lcall sendCharacter
			Inc DPTR
			Jmp DoAgain
LUT:		DB 'Test Program', 00h
Finish:		Ljmp endLoop
;=========================================================================================
		    End