#include <windows.h>
#include <stdio.h>
#include <tlhelp32.h>

#define DLL_NAME "minesweeper_cheat.dll"

// Find the process ID of Minesweeper
DWORD FindProcessByName(const char* processName) {
    DWORD processId = 0;
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    
    if (snapshot == INVALID_HANDLE_VALUE) {
        printf("Failed to create process snapshot.\n");
        return 0;
    }
    
    PROCESSENTRY32 entry;
    entry.dwSize = sizeof(PROCESSENTRY32);
    
    if (Process32First(snapshot, &entry)) {
        do {
            if (strcmp(entry.szExeFile, processName) == 0) {
                processId = entry.th32ProcessID;
                break;
            }
        } while (Process32Next(snapshot, &entry));
    }
    
    CloseHandle(snapshot);
    return processId;
}

// Inject DLL into the target process
BOOL InjectDLL(DWORD processId, const char* dllPath) {
    HANDLE processHandle = OpenProcess(
        PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ,
        FALSE,
        processId
    );
    
    if (processHandle == NULL) {
        printf("Failed to open process (PID: %lu). Error: %lu\n", processId, GetLastError());
        return FALSE;
    }
    
    // Allocate memory in the target process for the DLL path
    size_t dllPathLen = strlen(dllPath) + 1;
    LPVOID remoteBuffer = VirtualAllocEx(
        processHandle,
        NULL,
        dllPathLen,
        MEM_COMMIT | MEM_RESERVE,
        PAGE_READWRITE
    );
    
    if (remoteBuffer == NULL) {
        printf("Failed to allocate memory in target process. Error: %lu\n", GetLastError());
        CloseHandle(processHandle);
        return FALSE;
    }
    
    // Write the DLL path into the allocated memory
    if (!WriteProcessMemory(processHandle, remoteBuffer, (LPVOID)dllPath, dllPathLen, NULL)) {
        printf("Failed to write DLL path to target process. Error: %lu\n", GetLastError());
        VirtualFreeEx(processHandle, remoteBuffer, 0, MEM_RELEASE);
        CloseHandle(processHandle);
        return FALSE;
    }
    
    // Get the address of LoadLibraryA function
    LPVOID loadLibraryAddr = (LPVOID)GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");
    
    if (loadLibraryAddr == NULL) {
        printf("Failed to get LoadLibraryA address. Error: %lu\n", GetLastError());
        VirtualFreeEx(processHandle, remoteBuffer, 0, MEM_RELEASE);
        CloseHandle(processHandle);
        return FALSE;
    }
    
    // Create a remote thread that calls LoadLibraryA with the DLL path
    HANDLE remoteThread = CreateRemoteThread(
        processHandle,
        NULL,
        0,
        (LPTHREAD_START_ROUTINE)loadLibraryAddr,
        remoteBuffer,
        0,
        NULL
    );
    
    if (remoteThread == NULL) {
        printf("Failed to create remote thread. Error: %lu\n", GetLastError());
        VirtualFreeEx(processHandle, remoteBuffer, 0, MEM_RELEASE);
        CloseHandle(processHandle);
        return FALSE;
    }
    
    // Wait for the remote thread to complete
    WaitForSingleObject(remoteThread, INFINITE);
    
    // Cleanup
    VirtualFreeEx(processHandle, remoteBuffer, 0, MEM_RELEASE);
    CloseHandle(remoteThread);
    CloseHandle(processHandle);
    
    printf("DLL injected successfully!\n");
    return TRUE;
}

int main(int argc, char* argv[]) {
    const char* targetProcess = "minesweeper.exe";
    char dllPath[MAX_PATH];
    
    // Get the full path to the DLL
    if (GetFullPathNameA(DLL_NAME, MAX_PATH, dllPath, NULL) == 0) {
        printf("Failed to get full DLL path. Error: %lu\n", GetLastError());
        return 1;
    }
    
    printf("Searching for %s...\n", targetProcess);
    
    // Find Minesweeper process
    DWORD processId = FindProcessByName(targetProcess);
    
    if (processId == 0) {
        printf("Minesweeper process not found. Please start Minesweeper first.\n");
        return 1;
    }
    
    printf("Found Minesweeper (PID: %lu)\n", processId);
    printf("Injecting DLL: %s\n", dllPath);
    
    // Inject the DLL
    if (InjectDLL(processId, dllPath)) {
        printf("Injection completed successfully!\n");
        printf("Move your mouse over the Minesweeper board.\n");
        printf("Window title will show 'MLnesweeper' over mines.\n");
        return 0;
    } else {
        printf("Injection failed!\n");
        return 1;
    }
}