.386                   
.model flat, stdcall    
option casemap: none    

;Minesweeper (Windows XP) Hardcoded Memory Addresses & Constants
MINE_WIDTH_PTR  equ     01005334h   ;Memory pointer to the board's width
MINE_HEIGHT_PTR equ     01005338h   ;Memory pointer to the board's height
MINE_AREA       equ     01005340h   ;Base address where the mine grid starts in memory
MINE            equ     8Fh         ;The byte value that represents a hidden mine
TOP_LEFT_X      equ     12          ;X pixel offset of the first mine cell in the window
TOP_LEFT_Y      equ     55          ;Y pixel offset of the first mine cell in the window

;Windows API Constants
WM_MOUSEMOVE       equ 200h         ;Hex code for mouse movement message
GWL_WNDPROC        equ -4           ;Offset to get/set the Window Procedure
DLL_PROCESS_ATTACH equ 1
DLL_PROCESS_DETACH equ 0
TRUE               equ 1
FALSE              equ 0
NULL               equ 0
MB_OK              equ 0

;Windows API Function Imports
extern FindWindowA@8 : proc
extern SetWindowLongA@12 : proc
extern SetWindowTextA@8 : proc
extern MessageBoxA@16 : proc
extern CallWindowProcA@20 : proc

.const
cheat_title  BYTE "Mlnesweeper", 0  
origin_title BYTE "Minesweeper", 0  
debug_msg    BYTE "DLL Loaded!", 0  

.data
wnd_proc DWORD NULL ;Pointer to the original Window Procedure
main_wnd DWORD NULL ;Handle to the main game window

.code
DllMain proc inst: DWORD, reason: DWORD, reserved: DWORD
    cmp reason, DLL_PROCESS_ATTACH
    jne check_detach
    
    ;Display a debug message box to confirm successful injection
    push MB_OK
    push 0
    lea eax, debug_msg
    push eax
    push 0
    call MessageBoxA@16
    
    ;Apply the window procedure hook
    call Hook
    jmp dll_ret

check_detach:
    cmp reason, DLL_PROCESS_DETACH
    jne dll_ret
    ;Remove the hook before the DLL is unloaded
    call Unhook

dll_ret:
    mov eax, TRUE
    ret 
DllMain endp


;WndProc - Our Custom Window Procedure
;Intercepts messages sent to the game window
WndProc proc wnd: DWORD, msg: DWORD, wparam: DWORD, lparam: DWORD
    ;We only care about mouse movement, if it's another message, pass it to the original proc
    cmp msg, WM_MOUSEMOVE
    jne call_old_proc
    
    ;lparam contains the mouse coordinates: Y in the high word, X in the low word.
    mov eax, lparam
    movzx ecx, ax   
    shr eax, 16     
    
    ;Check if the mouse is outside the left or top border of the mine grid
    cmp eax, TOP_LEFT_Y
    jl call_old_proc
    cmp ecx, TOP_LEFT_X
    jl call_old_proc
    
    ;Subtract the border offsets to make (0,0) the top-left pixel of the first block
    sub eax, TOP_LEFT_Y
    sub ecx, TOP_LEFT_X
    
    cmp eax, 256
    jge call_old_proc
    cmp ecx, 256
    jge call_old_proc
    
    ;Convert pixel coordinates to grid coordinates (each block is 16x16 pixels)
    shr eax, 4 ;Grid Y
    shr ecx, 4 ;Grid X
	
    ;In memory, the game adds an invisible 1-cell border around the entire board
    ;Add 1 to our X and Y grid coordinates to match the memory layout
    inc eax   
	inc ecx
    
    ;Calculate the 1D memory array index: Index = (Y * 32) + X
    mov edx, eax
    shl edx, 5      
    add edx, ecx     
    
    cmp edx, 256
    jge call_old_proc
    
	;Save original ebx of the game
    push ebx                          
    mov ebx, MINE_AREA
    movzx eax, byte ptr [ebx + edx]
	;Restore ebx to the original value of the game
    pop ebx                           
    
    cmp al, MINE
    je is_mine
    
    ;Not a mine: Restore the original title
    push offset origin_title
    push wnd
    call SetWindowTextA@8
    jmp call_old_proc
    
is_mine:
    ;It's a mine: Change the title to the cheat title
    push offset cheat_title
    push wnd
    call SetWindowTextA@8

call_old_proc:
    ;If the hook failed or isn't set, just exit
    cmp wnd_proc, NULL
    je proc_end
    
    ;Pass the message back to the original game's window procedure
    ;so the game continues to function normally 
    push lparam
    push wparam
    push msg
    push wnd
    push wnd_proc
    call CallWindowProcA@20
    ret 

proc_end:
    xor eax, eax
    ret 
WndProc endp


;Hook - Replaces the game's window procedure with ours
Hook proc
    ;Find the game window by its title
    push offset origin_title
    push 0
    call FindWindowA@8
    
    cmp eax, NULL
    je hook_ret
    mov main_wnd, eax
    
    ;SetWindowLongA returns the pointer to the old WndProc, save it
    push offset WndProc
    push GWL_WNDPROC
    push eax
    call SetWindowLongA@12
    mov wnd_proc, eax

hook_ret:
    ret
Hook endp


;Unhook - Restores the original game's window procedure
Unhook proc
    cmp wnd_proc, NULL
    je unhook_ret
    cmp main_wnd, NULL
    je unhook_ret
    
    ;Restore the original WndProc saved earlier
    push wnd_proc
    push GWL_WNDPROC
    push main_wnd
    call SetWindowLongA@12

unhook_ret:
    ret
Unhook endp


;Helper Function (Unused in main logic but available for bounds checking)
;Converts pixel coords to grid coords using pointers
GetMineAreaPos proc pixel_x: DWORD, pixel_y: DWORD, ppx: DWORD, ppy: DWORD
    mov eax, ppx
    mov dword ptr [eax], -1
    mov eax, ppy
    mov dword ptr [eax], -1
    
    ;Check if mouse is above or to the left of the board
    mov eax, pixel_x
    cmp eax, TOP_LEFT_X
    jl gmp_ret
    mov eax, pixel_y
    cmp eax, TOP_LEFT_Y
    jl gmp_ret
    
    ;Check width bounds and calculate X
    mov eax, dword ptr [MINE_WIDTH_PTR]
    mov ecx, pixel_x
    sub ecx, TOP_LEFT_X
    shr ecx, 4
    cmp ecx, eax
    jge gmp_ret
    mov eax, ppx
    mov dword ptr [eax], ecx
    
    ;Check height bounds and calculate Y
    mov eax, dword ptr [MINE_HEIGHT_PTR]
    mov ecx, pixel_y
    sub ecx, TOP_LEFT_Y
    shr ecx, 4
    cmp ecx, eax
    jge gmp_ret
    mov eax, ppy
    mov dword ptr [eax], ecx
    
gmp_ret:
    ret
GetMineAreaPos endp


;Helper Function (Unused in main logic as WndProc does this inline)
;Checks if a specific grid coordinate has a mine
HasMine proc x: DWORD, y: DWORD
    mov eax, y
    shl eax, 5                      
    add eax, x                      
    mov ebx, MINE_AREA              
    movzx eax, byte ptr [ebx + eax] 
    cmp al, MINE                     
    jne hm_ret
    mov eax, TRUE                 
    ret                              
hm_ret:
    xor eax, eax                    
    ret
HasMine endp

end DllMain