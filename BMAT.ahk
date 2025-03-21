#Requires AutoHotkey v2.0
; 🐝 BeeBrained's PS99 Clan Battle Automation Template 🐝
; A modular baseline for automating Pet Simulator 99 clan battle events in Roblox.
; By BeeBrained - https://www.youtube.com/@BeeBrained-PS99
; Hive Hangout: https://discord.gg/QVncFccwek

; ================== Configurable Settings ==================
; Timing (in milliseconds)
INTERACTION_DURATION := 5000  ; Duration to interact with each window
CYCLE_INTERVAL := 60000       ; Time between full cycles (default: 60s)
CLICK_DELAY_MIN := 500        ; Min delay between clicks
CLICK_DELAY_MAX := 1500       ; Max delay between clicks

; Window Settings
WINDOW_TITLE := "Roblox"      ; Target window title
EXCLUDED_TITLES := ["Roblox Account Manager"]  ; Titles to exclude

; Key Sequences (edit these for each event)
; Format: Array of [key, duration_ms, repeat_count]
KEY_SEQUENCE := [
    ["space", 500, 1],   ; Jump (Spacebar)
    ["w", 300, 2],       ; Move forward twice
    ["f", 200, 1]        ; Open/close inventory or interact
]

; Hotkey Configuration
START_KEY := "F1"      ; Start automation
STOP_KEY := "F2"       ; Stop automation
PAUSE_KEY := "p"       ; Pause/resume
CAPTURE_KEY := "c"     ; Capture mouse position
INVENTORY_KEY := "F3"  ; Toggle inventory click mode

; ================== Global Variables ==================
global running := false
global paused := false
global coords := []    ; Array for captured coordinates
global inventory_mode := false
global myGUI

; ================== GUI Setup ==================
setupGUI() {
    global myGUI
    myGUI := Gui("+AlwaysOnTop", "🐝 BeeBrained’s PS99 Clan Battle Template 🐝")
    myGUI.Add("Text", "x10 y10 w380 h20", "🐝 Use " START_KEY " to start, " STOP_KEY " to stop, Esc to exit 🐝")
    myGUI.Add("Text", "x10 y40 w380 h20", "Status: Idle").Name := "Status"
    myGUI.Add("Text", "x10 y60 w380 h20", "Coords Captured: 0").Name := "Coords"
    myGUI.Show("x0 y0 w400 h100")
}

; ================== Hotkeys ==================
Hotkey START_KEY, startAutomation
Hotkey STOP_KEY, stopAutomation
Hotkey PAUSE_KEY, togglePause
Hotkey CAPTURE_KEY, captureCoords
Hotkey INVENTORY_KEY, toggleInventoryMode
Esc::ExitApp

; ================== Core Functions ==================
startAutomation(*) {
    global running, paused
    if running
        return
    running := true
    paused := false
    updateStatus("Running")
    SetTimer automationLoop, 100
}

stopAutomation(*) {
    global running, paused
    running := false
    paused := false
    SetTimer automationLoop, "Off"
    updateStatus("Idle")
}

togglePause(*) {
    global running, paused
    if running {
        paused := !paused
        updateStatus(paused ? "Paused" : "Running")
        Sleep 200  ; Debounce
    }
}

captureCoords(*) {
    Sleep 500
    MouseGetPos(&x, &y)
    coords.Push([x, y])
    myGUI["Coords"].Text := "Coords Captured: " coords.Length()
    ToolTip "Captured: x=" x ", y=" y, 0, 100
    Sleep 1000
    ToolTip
}

toggleInventoryMode(*) {
    global inventory_mode
    inventory_mode := !inventory_mode
    ToolTip "Inventory Mode: " (inventory_mode ? "ON" : "OFF"), 0, 100
    Sleep 1000
    ToolTip
}

updateStatus(text) {
    myGUI["Status"].Text := "Status: " text
}

findRobloxWindows() {
    windows := []
    for hwnd in WinGetList() {
        title := WinGetTitle(hwnd)
        if (InStr(title, WINDOW_TITLE) && !hasExcludedTitle(title) && WinGetProcessName(hwnd) = "RobloxPlayerBeta.exe") {
            windows.Push(hwnd)
        }
    }
    return windows
}

hasExcludedTitle(title) {
    for excluded in EXCLUDED_TITLES {
        if InStr(title, excluded)
            return true
    }
    return false
}

bringToFront(hwnd) {
    try {
        WinRestore(hwnd)
        WinActivate(hwnd)
        WinWaitActive(hwnd, , 2)
        return true
    } catch {
        return false
    }
}

pressKey(key, duration, repeat) {
    Loop repeat {
        Send "{" key " down}"
        Sleep duration
        Send "{" key " up}"
        Sleep 100  ; Small delay between repeats
    }
}

clickAt(x, y) {
    Random delay, CLICK_DELAY_MIN, CLICK_DELAY_MAX
    MouseMove x, y, 10  ; Smooth movement
    Sleep delay
    Click
}

inventoryClick() {
    MouseGetPos(&x, &y)
    Send "{f down}"
    Sleep 200
    Send "{f up}"
    Sleep 500
    clickAt(x, y)
    Sleep 500
    Send "{f down}"
    Sleep 200
    Send "{f up}"
}

automationLoop() {
    global running, paused, inventory_mode
    if (!running || paused)
        return

    windows := findRobloxWindows()
    if (windows.Length = 0) {
        updateStatus("No Roblox windows found")
        Sleep 10000
        return
    }

    updateStatus("Running (" windows.Length " windows)")
    for hwnd in windows {
        if (!running || paused)
            break
        if bringToFront(hwnd) {
            startTime := A_TickCount
            while (A_TickCount - startTime < INTERACTION_DURATION && running && !paused) {
                for seq in KEY_SEQUENCE {
                    pressKey(seq[1], seq[2], seq[3])
                }
                if (coords.Length > 0) {
                    for coord in coords {
                        clickAt(coord[1], coord[2])
                    }
                }
                if inventory_mode {
                    inventoryClick()
                }
                Sleep 1000
            }
        }
    }
    updateStatus("Waiting (" CYCLE_INTERVAL // 1000 "s)")
    Sleep CYCLE_INTERVAL
}

; ================== Main Execution ==================
setupGUI()
TrayTip "🐝 BeeBrained’s PS99 Template", "Ready! Press " START_KEY " to start.", 10
