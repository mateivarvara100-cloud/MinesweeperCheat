# Minesweeper Cheat - DLL Injector

A low-level Windows DLL injector that hooks into the classic Minesweeper game to reveal mine locations in real-time.

## Project Status: ✅ ~95% Complete

### ✅ Completed Components

- **Mine Detection Logic** - Core algorithm to detect mine positions from game memory
- **Pixel-to-Grid Conversion** - Converts mouse pixel coordinates to grid coordinates
- **Window Message Hooking** - Intercepts Minesweeper window messages (WM_MOUSEMOVE)
- **Real-time Feedback** - Changes window title to indicate mine detection
- **Memory Reading** - Reads mine grid data from specific game memory addresses
- **DLL Structure** - Complete DLL entry point (DllMain) with proper initialization/cleanup
- **Assembly Implementation** - Fully functional x86 Assembly code using MASM32

### 📋 What's Implemented

```
✓ DllMain() - DLL entry point with process attach/detach handlers
✓ WndProc() - Window message interceptor with mouse tracking
✓ Hook() - Finds and hooks the Minesweeper window
✓ Unhook() - Restores original window procedure
✓ GetMineAreaPos() - Converts pixel coordinates to grid coordinates
✓ HasMine() - Checks if a mine exists at grid position
```

### ⏳ Remaining Work

- **DLL Injection Mechanism** - Need to create the injector program (C/C++) that:
  - Finds the Minesweeper process
  - Allocates memory in the target process
  - Writes the DLL path into that memory
  - Creates a remote thread that calls LoadLibrary()
  - Loads the compiled DLL into Minesweeper

### 🎮 How It Works (Once Injected)

1. Injector finds running Minesweeper process
2. Injects the compiled DLL into the process memory
3. DLL hooks the window message handler
4. When you move the mouse over the game board:
   - Window title changes to **"MLnesweeper"** if hovering over a mine
   - Window title shows **"Minesweeper"** if hovering over safe cells
5. Unhooking occurs automatically when DLL is unloaded

### 🔧 Technical Details

- **Language**: x86 Assembly (MASM32)
- **Target**: Windows Minesweeper (classic version)
- **Method**: Window procedure hooking via SetWindowLongW
- **Memory Addresses Used**:
  - `0x01005334` - Grid width
  - `0x01005338` - Grid height
  - `0x01005340` - Mine grid data (0x8F = mine byte)
- **Offset**: Grid top-left corner at (12px, 55px)
- **Cell Size**: 16x16 pixels per grid cell

### 📁 Files

- `minesweeper_cheat.asm` - Main DLL with all hooking logic
- `cheat.inc` - Header file with constants and function prototypes
- `README.md` - This file

### 🚀 Next Steps

The next phase requires building a **C/C++ injector executable** that:

1. Locates the Minesweeper window/process
2. Uses Windows API (CreateRemoteThread, LoadLibrary) for injection
3. Injects the compiled DLL from this project
4. Provides user interface or command-line options

### 📝 Notes

- This is an educational project demonstrating low-level Windows programming
- Compiled DLL must be in 32-bit format to match Minesweeper
- Requires MASM32 and appropriate compilation tools
- Only works with the classic Windows Minesweeper game

---

**Project Status**: Assembly code complete and functional. Awaiting injector implementation.
