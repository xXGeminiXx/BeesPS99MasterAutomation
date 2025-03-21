; 🐝 BeeBrained's MAT (Master Automation Tool) 🐝
; Built for PS99 automation and beyond.
; Hotkeys, clicks, window switching.
; By BeeBrained - https://www.youtube.com/@BeeBrained-PS99
; Hive hangout: https://discord.gg/QVncFccwek
; Current date: March 21, 2025

#SingleInstance Force
#NoEnv
SetWorkingDir %A_ScriptDir%
SetBatchLines -1

; ==================== CONFIG LOADING ====================
global click_delay_min := 0.5
global click_delay_max := 1.5
global wait_before_click := 0.5
global wait_after_click := 0.5
global offset_range := 5
global timer_interval := 60
global interaction_duration := 5
global max_window_switches := 3
global window_stability_timeout := 5000 ; in ms
global window_title := "Bee’s Target Zone"
global pause_key := "p"
global start_key := "Enter"
global stop_key := "Esc"
global capture_key := "c"
global debounce_delay := 200 ; in ms
global pause_sleep := 100 ; in ms
global retry_attempts := 3
global retry_delay := 100 ; in ms
global error_recovery_delay := 1000 ; in ms
global excluded_titles := "Account Manager"
global coords := []
global running := false
global paused := false
global window_switch_count := 0
global last_switch_time := 0

LoadConfig() {
    global
    IniFile := "BeeConfig.ini"
    IfNotExist, %IniFile%
    {
        MsgBox, Config '%IniFile%' not found. Creating a default one.
        CreateBeeConfig(IniFile)
    }
    
    IniRead, click_delay_min, %IniFile%, BeeSettings, click_delay_min, 0.5
    IniRead, click_delay_max, %IniFile%, BeeSettings, click_delay_max, 1.5
    IniRead, wait_before_click, %IniFile%, BeeSettings, wait_before_click, 0.5
    IniRead, wait_after_click, %IniFile%, BeeSettings, wait_after_click, 0.5
    IniRead, offset_range, %IniFile%, BeeSettings, offset_range, 5
    IniRead, timer_interval, %IniFile%, BeeSettings, timer_interval, 60
    IniRead, interaction_duration, %IniFile%, BeeSettings, interaction_duration, 5
    IniRead, max_window_switches, %IniFile%, BeeSettings, max_window_switches, 3
    IniRead, window_stability_timeout, %IniFile%, BeeSettings, window_stability_timeout, 5000
    IniRead, window_title, %IniFile%, BeeSettings, window_title, Bee’s Target Zone
    IniRead, pause_key, %IniFile%, BeeSettings, pause_key, p
    IniRead, start_key, %IniFile%, BeeSettings, start_key, Enter
    IniRead, stop_key, %IniFile%, BeeSettings, stop_key, Esc
    IniRead, capture_key, %IniFile%, BeeSettings, capture_key, c
    IniRead, debounce_delay, %IniFile%, BeeSettings, debounce_delay, 200
    IniRead, pause_sleep, %IniFile%, BeeSettings, pause_sleep, 100
    IniRead, retry_attempts, %IniFile%, BeeSettings, retry_attempts, 3
    IniRead, retry_delay, %IniFile%, BeeSettings, retry_delay, 100
    IniRead, error_recovery_delay, %IniFile%, BeeSettings, error_recovery_delay, 1000
    IniRead, excluded_titles, %IniFile%, BeeSettings, excluded_titles, Account Manager
    
    ; Ensure click_delay_max is not less than click_delay_min
    if (click_delay_max < click_delay_min)
        click_delay_max := click_delay_min + 0.1
}

CreateBeeConfig(IniFile) {
    IniWrite, 0.5, %IniFile%, BeeSettings, click_delay_min
    IniWrite, 1.5, %IniFile%, BeeSettings, click_delay_max
    IniWrite, 0.5, %IniFile%, BeeSettings, wait_before_click
    IniWrite, 0.5, %IniFile%, BeeSettings, wait_after_click
    IniWrite, 5, %IniFile%, BeeSettings, offset_range
    IniWrite, 60, %IniFile%, BeeSettings, timer_interval
    IniWrite, 5, %IniFile%, BeeSettings, interaction_duration
    IniWrite, 3, %IniFile%, BeeSettings, max_window_switches
    IniWrite, 5000, %IniFile%, BeeSettings, window_stability_timeout
    IniWrite, Bee’s Target Zone, %IniFile%, BeeSettings, window_title
    IniWrite, p, %IniFile%, BeeSettings, pause_key
    IniWrite, Enter, %IniFile%, BeeSettings, start_key
    IniWrite, Esc, %IniFile%, BeeSettings, stop_key
    IniWrite, c, %IniFile%, BeeSettings, capture_key
    IniWrite, 200, %IniFile%, BeeSettings, debounce_delay
    IniWrite, 100, %IniFile%, BeeSettings, pause_sleep
    IniWrite, 3, %IniFile%, BeeSettings, retry_attempts
    IniWrite, 100, %IniFile%, BeeSettings, retry_delay
    IniWrite, 1000, %IniFile%, BeeSettings, error_recovery_delay
    IniWrite, Account Manager, %IniFile%, BeeSettings, excluded_titles
}

; ==================== HOTKEY SETUP ====================
SetupHotkeys() {
    global
    Hotkey, %stop_key%, StopAutomation
    Hotkey, %start_key%, StartAutomation
    Hotkey, %pause_key%, TogglePause
    Hotkey, %capture_key%, CaptureCoords
    Hotkey, +%capture_key%, MsgBoxCaptureTemplates ; Placeholder for template capture
}

MsgBoxCaptureTemplates:
    MsgBox, Template capturing is not supported in this AHK version. Use Python version for CV2 features.
return

; ==================== AUTOMATION CORE ====================
StartAutomation() {
    global
    if (!running) {
        running := true
        paused := false
        ToolTip, Automation started. Use '%stop_key%' to stop, '%pause_key%' to pause., 0, 0
        SetTimer, MainLoop, 100
    }
}

StopAutomation() {
    global
    running := false
    paused := false
    SetTimer, MainLoop, Off
    ToolTip
    MsgBox, Automation stopped.
}

TogglePause() {
    global
    if (running) {
        paused := !paused
        ToolTip, % (paused ? "Paused." : "Resumed."), 0, 0
        Sleep, %debounce_delay%
    }
}

CaptureCoords() {
    global
    Sleep, 500
    MouseGetPos, x, y
    coords.Push([x, y])
    ToolTip, Captured coords: x=%x%, y=%y% (Total: % coords.Length()), 0, 0
    Sleep, 1000
    ToolTip
}

ClickAt(x, y) {
    global
    Sleep, % Round(wait_before_click * 1000)
    Random, offset_x, -%offset_range%, %offset_range%
    Random, offset_y, -%offset_range%, %offset_range%
    Random, delay, % Round(click_delay_min * 1000), % Round(click_delay_max * 1000)
    MouseMove, % x + offset_x, % y + offset_y, 10 ; Slower move for human-like behavior
    Sleep, %delay%
    Click
    Sleep, % Round(wait_after_click * 1000)
    ToolTip, Clicked at x=%x%, y=%y%., 0, 0
    Sleep, 500
    ToolTip
}

BringToFront(window_title) {
    global
    Sleep, 50
    IfWinExist, %window_title%
    {
        WinRestore, %window_title%
        WinActivate, %window_title%
        ToolTip, Activated window: %window_title%, 0, 0
        Sleep, 500
        ToolTip
        return true
    }
    ToolTip, Window '%window_title%' not found., 0, 0
    Sleep, 1000
    ToolTip
    return false
}

MainLoop:
    global
    if (!running)
        return
    if (paused) {
        Sleep, %pause_sleep%
        return
    }
    
    ; Find Roblox windows
    WinGet, roblox_list, List, Roblox
    if (roblox_list = 0) {
        ToolTip, No Roblox windows found. Waiting 10s..., 0, 0
        Sleep, 10000
        ToolTip
        return
    }
    
    ToolTip, Found %roblox_list% Roblox window(s)., 0, 0
    Sleep, 1000
    ToolTip
    
    Loop, %roblox_list%
    {
        if (!running)
            break
        hwnd := roblox_list%A_Index%
        WinGetTitle, current_title, ahk_id %hwnd%
        if (InStr(current_title, excluded_titles))
            continue
        if (BringToFront(current_title)) {
            start_time := A_TickCount
            while (A_TickCount - start_time < interaction_duration * 1000) {
                if (!running || paused)
                    break
                if (coords.Length() > 0) {
                    for index, coord in coords {
                        ClickAt(coord[1], coord[2])
                    }
                }
                Sleep, 1000
            }
        }
        
        WinGetActiveTitle, active_window
        if (active_window != last_window) {
            window_switch_count++
            last_window := active_window
            last_switch_time := A_TickCount
            if (window_switch_count >= max_window_switches) {
                MsgBox, Too many window switches. Stopping.
                Gosub, StopAutomation
                break
            }
        } else if (A_TickCount - last_switch_time > window_stability_timeout) {
            window_switch_count := Max(0, window_switch_count - 1)
        }
    }
    
    ToolTip, Cycle done. Waiting %timer_interval%s., 0, 0
    Sleep, % timer_interval * 1000
    ToolTip
return

; ==================== MAIN EXECUTION ====================
MsgBox, 🐝 BeeBrained’s MAT booting up! 🐝
LoadConfig()
SetupHotkeys()
TrayTip, BeeBrained’s MAT, Ready! Press %start_key% to start., 10
return

Esc::ExitApp ; Emergency exit
