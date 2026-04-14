# Minesweeper Cheat (DLL Injector) 💣

An educational reverse engineering project that injects a custom DLL into the classic **Minesweeper (Windows XP version - 32-bit)**. When hovering the cursor over a cell containing a mine, the window title subtly changes from "Minesweeper" to "Mlnesweeper".

## ⚙️ How it works

The project is split into two main components:

### 1. The Injector (written in C#)

The injector's role is to force the game process to load our custom code (the DLL). The steps are:

- Finds the game window using `FindWindow` and retrieves its Process ID (PID).
- Opens the game process with full access rights (`OpenProcess`).
- Allocates memory inside the game process (`VirtualAllocEx`) large enough to store the absolute path to our `.dll` file.
- Writes the DLL path into that allocated space (`WriteProcessMemory`).
- Finds the address of the `LoadLibraryA` function from the `kernel32.dll` module.
- Creates a remote thread in the game (`CreateRemoteThread`) that calls `LoadLibraryA` with our DLL path as the argument. This forces the game to execute our injected code.

### 2. The Assembly Code Explained (Direct Memory Lookup vs. Algorithms)

_You might think that a Minesweeper cheat uses a pathfinding or board-solving algorithm (like Lee's algorithm, BFS, or Flood Fill)._ **It does not.**

While the original game uses a recursive flood-fill algorithm to open empty cells when you click on a "0", our cheat doesn't need to "solve" the board or simulate clicks. Because we are injected directly into the game's memory, we can just **look at the answers** in real-time.

Here is exactly what the Assembly code (`minesweeper_cheat.asm`) does:

#### Step A: The Hook (Message Interception)

When the DLL is loaded, it calls `SetWindowLongA` to replace the game's official `WndProc` (Window Procedure) with our own custom `WndProc`. This is called "Hooking". Now, every time you move the mouse or click, Windows sends that event to _our_ code first.

#### Step B: Tracking the Mouse (`WM_MOUSEMOVE`)

We ignore all messages except `WM_MOUSEMOVE`. When the mouse moves, Windows provides the X and Y pixel coordinates inside the `lparam` variable (X in the lower 16 bits, Y in the upper 16 bits).

#### Step C: Pixel to Grid Conversion (The Math)

The game grid doesn't start at the very top-left of the window; there are borders and a smiley face button.

1. We subtract the visual offsets (`TOP_LEFT_X = 12`, `TOP_LEFT_Y = 55`) from the mouse pixels.
2. Since every Minesweeper square is exactly 16x16 pixels, we divide the remaining pixels by 16. In Assembly, shifting right by 4 bits (`shr 4`) is a very fast way to divide by 16. This gives us the visual Grid X and Grid Y.
3. **The Invisible Border:** The game stores the board in memory with an invisible 1-cell thick border around it (to make calculating adjacent mines easier without array out-of-bounds errors). So, we add 1 to our X and Y coordinates (`inc eax`, `inc ecx`) to match the memory layout.

#### Step D: The 1D Array Index

In memory, the 2D grid is flattened into a 1D array. Even if you play on "Beginner" (9x9), Minesweeper's internal memory array always allocates a fixed width of **32 columns** per row.
To find exactly where our mouse is pointing in memory, the Assembly calculates:
`Memory Index = (Y * 32) + X`
_(In Assembly: `shl 5` multiplies Y by 32, then we `add` X)._

#### Step E: Direct Memory Reading

We take the base memory address of the board (`0x01005340`) and add our calculated `Memory Index`. We read the exact byte located there.

- If the byte is exactly `0x8F` (the hardcoded hexadecimal value for a hidden mine), we call `SetWindowTextA` to change the title to **"Mlnesweeper"**.
- If it's anything else, we change it back to **"Minesweeper"**.

Finally, we use `CallWindowProcA` to pass the mouse movement back to the original game code, so the game continues running completely normally and the player notices no lag.

## ⚠️ Important: Memory Addresses and Versions

This code uses **static (hardcoded) memory addresses** that work **EXCLUSIVELY** on the old version of Minesweeper from Windows XP (the 32-bit `winmine.exe`).

**If you want to use this cheat on another version of Minesweeper (e.g., Windows 7, Windows 10/11, or other clones):**
This code will _not_ work out of the box. Newer games use completely different memory layouts and modern security mitigations like ASLR (Address Space Layout Randomization). You will need to use **Reverse Engineering** tools (like _Cheat Engine_, _x64dbg_, or _IDA Pro_) to dissect the specific version, find the correct base pointers, and update the logic in the `.asm` file.

## 🚀 How to compile and run

You need the MSVC (Microsoft Visual C++) toolchain and the C# compiler (`csc.exe`). The easiest way to get these is to open the **Developer Command Prompt for Visual Studio** and navigate to your project folder.

### Step 1: Compiling

Run the following commands in the terminal (make sure you update the hardcoded DLL path inside `Program.cs` to match your actual path before compiling):

```cmd
:: 1. Delete old files (if they exist)
del /Q minesweeper_cheat.obj cheat.dll cheat.exp cheat.lib Program.exe 2>nul

:: 2. Assemble the .asm file into an .obj file using MASM
ml /c /coff minesweeper_cheat.asm

:: 3. Link the .obj into a .dll file (without using a .def file)
link /DLL /SUBSYSTEM:WINDOWS /OUT:cheat.dll minesweeper_cheat.obj user32.lib kernel32.lib

:: 4. Compile the C# injector (VERY IMPORTANT: It must be compiled for 32-bit /x86)
csc /platform:x86 Program.cs
```

_(Note: If you run this from the Developer Command Prompt, you don't need the full paths to `ml.exe`, `link.exe`, or `csc.exe` as they are already in your PATH)._

### Step 2: Running

1. Open the **Minesweeper (`winmine.exe`)** game.
2. Run **`Program.exe`** (your compiled injector).
3. You should see a `DLL Loaded!` message box pop up inside the game.
4. Move your mouse over the game board. When hovering over a cell with a mine, the window title will change to "Mlnesweeper".

### Troubleshooting (Common Errors)

- **Compilation Error (`LNK1104 cannot open file 'cheat.dll'`)**: The DLL is currently injected into a running Minesweeper process and locked by Windows. Close the game completely and try compiling again.
- **The game crashes**: Did you make sure `Program.exe` was compiled with the `/platform:x86` flag? A 64-bit process cannot properly inject code into a 32-bit process.
- **The injector cannot find the process**: Ensure the game's window title exactly matches the one specified in `Program.cs` ("Minesweeper").

---

_This project was created strictly for educational purposes to demonstrate Windows API usage, Memory Management, DLL Injection, and x86 Assembly._
