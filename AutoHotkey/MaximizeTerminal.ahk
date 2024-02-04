#Requires AutoHotkey v2.0
#SingleInstance
Persistent

WinPrioritize(&App_exe, &ID_prev := 0, &MinMax_prev := -2)
{
    ID := WinActive("ahk_exe " App_exe)
    MinMax := (ID) ? WinGetMinMax("ahk_exe " App_exe) : -2

    if ((ID != ID_prev || MinMax != MinMax_prev) && MinMax = 1)
    {
        WinMinimizeAll
        WinRestore("ahk_exe " App_exe)
    }

    ID_prev := ID
    MinMax_prev := MinMax
}

APP_EXE := "WindowsTerminal.exe"
ID_global := 0
MinMax_global := -2
WinPrioritize_WindowsTerminal := WinPrioritize.bind(&APP_EXE, &ID_global, &MinMax_global)
SetTimer(WinPrioritize_WindowsTerminal, 500)
