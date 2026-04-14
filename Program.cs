using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

class Program {
    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", SetLastError = true)]
    static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, out IntPtr lpThreadId);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr hObject);

    static void Main(string[] args) {
        string dllPath = @"C:\Users\Matei\Desktop\CheatMinesweeper\cheat.dll";
        string winTitle = "Minesweeper";

        try {
            IntPtr hWnd = FindWindow(null, winTitle);
            if (hWnd == IntPtr.Zero) {
                Console.WriteLine("[-] Minesweeper not found");
                return;
            }
            Console.WriteLine("[+] Minesweeper found");

            uint pid = 0;
            GetWindowThreadProcessId(hWnd, out pid);
            Console.WriteLine("[+] PID: " + pid);

            // 0x001F0FFF = PROCESS_ALL_ACCESS
            IntPtr hProcess = OpenProcess(0x001F0FFF, false, pid);
            if (hProcess == IntPtr.Zero) {
                Console.WriteLine("[-] Can't open process");
                return;
            }
            Console.WriteLine("[+] Process open");

            uint size = (uint)(dllPath.Length + 1);
            IntPtr buf = VirtualAllocEx(hProcess, IntPtr.Zero, size, 0x1000, 0x40);
            if (buf == IntPtr.Zero) {
                Console.WriteLine("[-] Can't allocate memory");
                return;
            }
            Console.WriteLine("[+] Memory allocated");

            byte[] bytes = Encoding.ASCII.GetBytes(dllPath);
            IntPtr written = IntPtr.Zero;
            WriteProcessMemory(hProcess, buf, bytes, size, out written);
            Console.WriteLine("[+] DLL path written");

            IntPtr k32 = GetModuleHandle("kernel32.dll");
            IntPtr loadLib = GetProcAddress(k32, "LoadLibraryA");

            IntPtr tid = IntPtr.Zero;
            IntPtr hThread = CreateRemoteThread(hProcess, IntPtr.Zero, 0, loadLib, buf, 0, out tid);
            if (hThread == IntPtr.Zero) {
                Console.WriteLine("[-] Can't create thread");
                return;
            }
            Console.WriteLine("[+] DLL loaded. Running loaded thread...");

            WaitForSingleObject(hThread, 5000);
            CloseHandle(hThread);
            
            Console.WriteLine("[+] Done! Title will change when the cursor is on a mine...");
            
            Thread.Sleep(2000);
            
            CloseHandle(hProcess);
            Console.WriteLine("[+] Injector closed.");
        }
        catch (Exception ex) {
            Console.WriteLine("[-] Error: " + ex.Message);
        }
    }
}