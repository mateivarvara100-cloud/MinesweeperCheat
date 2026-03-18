;fisierul pentru toate constantele si prototipurile de functii pe care le folosim 
;pt assembly
include /masm32/include/windows.inc

;latimea grid-ului cu mine 
MINE_WIDTH_PTR equ 01005334h

;inaltimea grid-ului cu mine 
MINE_HEIGHT_PTR equ 01005338h

;datele minelor - octet 8Fh = mina 
MINE_AREA equ 01005340h

; Valoarea unui octet din grila care indica prezenta unei mine
MINE equ 8Fh

;pozitiile x,y pentru coltul din stanga-sus al grilei (pixeli)
TOP_LEFT_X equ 12
TOP_LEFT_Y equ 55

;functia de intrare pt DLL
DllMain proto inst: HINSTANCE, reason: DWORD, reserved: DWORD

;functia ce proceseaza mesajele ferestrei
WndProc proto wnd: HWND, msg: DWORD, wparam: WPARAM, lparam:LPARAM

;convertorul pixelilor în coordonate de pe grila
GetMineAreaPos proto   pixel_x: DWORD, pixel_y: DWORD, x: ptr DWORD, y: ptr DWORD

;verificare daca e MINA la o pozitie
HasMine proto x:DWORD, y:DWORD

Hook proto
Unhook proto

