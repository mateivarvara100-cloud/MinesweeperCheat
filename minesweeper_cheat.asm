.386
.model flat, stdcall
option casemap: none

include /masm32/include/windows.inc
includelib /masm32/lib/kernel32.lib
includelib /masm32/lib/user32.lib

.const
cheat_title BYTE "MLnesweeper", 0
origin_title BYTE "Minesweeper", 0
debug_msg BYTE "Failed to find the game window.", 0

MINE_WIDTH_PTR equ 01005334h
MINE_HEIGHT_PTR equ 01005338h
MINE_AREA equ 01005340h
MINE equ 8Fh
TOP_LEFT_X equ 12
TOP_LEFT_Y equ 55

; Function prototypes
Hook            proto
Unhook          proto
GetMineAreaPos  proto   pixel_x: DWORD, pixel_y: DWORD, x: ptr DWORD, y: ptr DWORD
HasMine         proto   x: DWORD, y: DWORD
SetWindowText   proto   :HWND, :DWORD
FindWindow      proto   :DWORD, :DWORD
OutputDebugStringW proto :DWORD
SetWindowLongW  proto   :HWND, :DWORD, :DWORD


.data
wnd_proc LPVOID NULL ;adresa functiei originale
main_wnd HWND NULL ;salvez handle-ul ferestrei Minesweeper


.code
;functia se apeleaza automat din Windows cand DLL-ul 
;este injectat in Minesweeper si DLL-ul este descarcat din memorie
DllMain proc inst: HINSTANCE, reason: DWORD, reserved: DWORD

	.if reason==DLL_PROCESS_ATTACH
		invoke Hook
	.elseif reason==DLL_PROCESS_DETACH
		invoke Unhook
	.endif

	mov eax, TRUE
	ret
DllMain endp

;functia se apeleaza de fiecare data cand: mouse-ul se misa, se apasa o tasta,
;se redeseneaza fereastra, se intampla orice cu fereastra Minesweeper
WndProc proc wnd: HWND, msg: DWORD, wparam: WPARAM, lparam: LPARAM
	local @pixel_x: DWORD
	local @pixel_y: DWORD
	local @mine_x: DWORD
	local @mine_y: DWORD
	
	;salvare registre
	pushad
    
    .if msg == WM_MOUSEMOVE
		;lparam contine : bitii X in 0-15 si bitii Y in 16-31
        mov eax, lparam
        movzx ecx, ax
        mov @pixel_x, ecx
        shr eax, 16
        mov @pixel_y, eax

		;converteste pixeli in coordonate grila
        invoke GetMineAreaPos, @pixel_x, @pixel_y, addr @mine_x, addr @mine_y
        ;daca mouse-ul e in afara grilei, coordonatele vor fi -1
        .if @mine_x < 0 || @mine_y < 0
			;schimba titlul la normal
            invoke SetWindowText, main_wnd, addr origin_title
            jmp _end
        .endif
		
		;verifica daca e mina la aceasta pozitie
        invoke HasMine, @mine_x, @mine_y
        
        .if eax == TRUE
			;e mina - schimba titlu
            invoke SetWindowText, main_wnd, addr cheat_title
        .else
			;nu e mina - titlu normal
            invoke SetWindowText, main_wnd, addr origin_title
        .endif
    .endif

_end:
	;restaurare registre
    popad

	;apel functie originala pentru a procesa mesajul normal
    push lparam
    push wparam
    push msg
    push wnd
	
	;apel functie originala salvata in wnd_proc
    mov edx, wnd_proc
    call edx

    ret
WndProc endp

;gasim fereastra Minesweeper, salvam functia originala, o inlocuim cu a noastra
Hook proc
	;daca hook-ul e deja instalat, nu mai instalam din nou
	.if wnd_proc != NULL
		jmp _end
	.endif

	;cautam fereastra cu titlul "Minesweeper"
	invoke FindWindow, NULL, addr origin_title
	
	.if eax == NULL
		;fereastra nu gasita - jocul nu e pornit
		invoke OutputDebugStringW, addr debug_msg
		jmp _end
	.endif	
	
	;salvam handle-ul ferestrei
	mov main_wnd, eax
	
	;instalam hook-ul nostru
	;SetWindowLongW inlocuiteste functia originala cu a noastra (WndProc)
	invoke SetWindowLongW, main_wnd, GWL_WNDPROC, offset WndProc
	;salvam adresa functiei originale pentru apel mai tarziu
	mov wnd_proc, eax
	
_end:
	ret
Hook endp

;restaurare functie originala de procesare a mesajelor
Unhook proc
	;SetWindowLongW restaureaza functia originala
	invoke SetWindowLongW, main_wnd, GWL_WNDPROC, wnd_proc
	ret
Unhook endp

;convertire pixeli in coordonate grila
;formula: x_grila=(pixel_x-12)/16, y_grila=(pixel_y-55)/16
GetMineAreaPos proc pixel_x: DWORD, pixel_y: DWORD, x: ptr DWORD, y: ptr DWORD
	local @mine_width: DWORD
	local @mine_height: DWORD
	
	;initializeaza cu -1(coordonate invalide)
	mov eax, x
	mov dword ptr [eax], -1
	mov eax, y
	mov dword ptr [eax], -1
	
	;citim latimea grilei din memorie(adresa 01005334h)
	mov eax, MINE_WIDTH_PTR
	mov ecx, dword ptr [eax]
	mov @mine_width, ecx
	
	;citim inaltimea grilei din memorie(adresa 01005338h)
	mov eax, MINE_HEIGHT_PTR
	mov ecx, dword ptr [eax]
	mov @mine_height, ecx
	
	;coordonata X in grila: (pixel_x-TOP_LEFT_X)/16
	mov eax, pixel_x
	sub eax, TOP_LEFT_X

	;daca e negativ(inseamna ca e in afara, la stanga)
	.if eax < 0
		jmp _return_invalid
	.endif
	
	;impart la 16(latimea unui patrat)
	mov ecx, 16
	cdq
	idiv ecx
	
	;daca e mai mare decat latimea (inseamna ca e in afara, la dreapta)
	mov ecx, eax
	mov eax, x
	
	.if ecx >= @mine_width
		jmp _return_invalid
	.endif
	
	;salvez rezultatul X
	mov dword ptr [eax], ecx
	
	;coordonata Y in grila: (pixel_y-TOP_LEFT_Y)/16
	mov eax, pixel_y
	sub eax, TOP_LEFT_Y ;scad offsetul(55)
	
	.if eax < 0
		jmp _return_invalid
	.endif
	
	;impart la 16
	mov ecx, 16
	cdq
	idiv ecx
	
	mov ecx, eax
	mov eax, y
	
	.if ecx >= @mine_height
		jmp _return_invalid
	.endif
	
	;salvez rezultatul Y
	mov dword ptr [eax], ecx
	jmp _return
	
_return_invalid:
	mov eax, x
	mov dword ptr [eax], -1
	mov eax, y
	mov dword ptr [eax], -1
	
_return:
	ret
GetMineAreaPos endp	

HasMine proc x: DWORD, y: DWORD
	local @mine_width: DWORD
	local @offset: DWORD
	
	;citim latimea grilei din memorie
	mov eax, MINE_WIDTH_PTR
	mov ecx, dword ptr [eax]
	mov @mine_width, ecx
	
	;offset=y*latimea+x 
	;grila e stocata liniar: byte 0-8=rand 0, byte 9-17=rand 1, etc
	mov eax, y
	imul eax, @mine_width
	add eax, x
	mov @offset, eax
	
	;adresa byte-ului: MINE_AREA(01005340h)+offset
	mov eax, MINE_AREA
	add eax, @offset
	mov al, byte ptr [eax]
	
	;byte-ul ales din adresa este comparat cu MINE(0x8F)
	.if al == MINE
		mov eax, TRUE
	.else
		mov eax, FALSE
	.endif
	
	ret
HasMine endp

end DllMain