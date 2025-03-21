#Requires AutoHotkey v2.0
; 🐝 BeeBrained's PS99 Clan Battle Automation Template 🐝
; A modular baseline for automating Pet Simulator 99 clan battle events in Roblox.
; By BeeBrained - https://www.youtube.com/@BeeBrained-PS99
; Hive Hangout: https://discord.gg/QVncFccwek

; ================== How to Use ==================
; 1. Place template images (e.g., hatch_button.png) in a "templates" folder in the script directory.
; 2. Create and edit "config.ini" in the script directory to customize settings.
; 3. Launch the script, position your character in the event area, and press F1 to start.
; 4. Update templates and config after game updates if the UI or mechanics change.
; 5. Ensure Gdip_All.ahk is in the script directory for template matching (download from AHK forums).
; 6. Use responsibly—automation may violate game terms of service.

; ================== Global Variables ==================
global running := false
global paused := false
global coords := []    ; Array for captured coordinates
global inventory_mode := false
global pixelsearch_mode := false
global checkstate_mode := false
global myGUI
global GdipToken      ; For Gdip library (template matching)
global logFile := A_ScriptDir "\log.txt"
global CONFIG_FILE := A_ScriptDir "\config.ini"

; ================== Load Configuration ==================
loadConfig() {
    global
    ; Default settings
    INTERACTION_DURATION := 5000
    CYCLE_INTERVAL := 60000
    CLICK_DELAY_MIN := 500
    CLICK_DELAY_MAX := 1500
    WINDOW_TITLE := "Roblox"
    EXCLUDED_TITLES := ["Roblox Account Manager"]
    ENABLE_GENERAL_ACTIONS := true
    ENABLED_FUNCTIONS := ["autoHatch", "autoRebirth"]
    KEY_SEQUENCE := [["space", 500, 1], ["w", 300, 2], ["f", 200, 1]]
    TEMPLATES := Map("hatch_button", "hatch_button.png", "rebirth_button", "rebirth_button.png", "rebirth_ready", "rebirth_ready.png", "upgrade_button", "upgrade_button.png")
    START_KEY := "F1"
    STOP_KEY := "F2"
    PAUSE_KEY := "p"
    CAPTURE_KEY := "c"
    INVENTORY_KEY := "F3"
    PIXELSEARCH_KEY := "F4"
    CHECKSTATE_KEY := "F5"
    PIXELSEARCH_COLOR := "0xFFFFFF"
    PIXELSEARCH_VARIATION := 10
    PIXELSEARCH_AREA := [0, 0, A_ScreenWidth, A_ScreenHeight]
    MOVEMENT_PATTERNS := Map("circle", [["w", 500, 1], ["d", 300, 1], ["s", 500, 1], ["a", 300, 1]], "zigzag", [["w", 400, 1], ["d", 200, 1], ["w", 400, 1], ["a", 200, 1]], "forward_backward", [["w", 1000, 1], ["s", 1000, 1]])
    TEMPLATE_FOLDER := A_ScriptDir "\templates"

    ; Load from config.ini if exists
    if FileExist(CONFIG_FILE) {
        INTERACTION_DURATION := IniRead(CONFIG_FILE, "Timing", "INTERACTION_DURATION", INTERACTION_DURATION)
        CYCLE_INTERVAL := IniRead(CONFIG_FILE, "Timing", "CYCLE_INTERVAL", CYCLE_INTERVAL)
        CLICK_DELAY_MIN := IniRead(CONFIG_FILE, "Timing", "CLICK_DELAY_MIN", CLICK_DELAY_MIN)
        CLICK_DELAY_MAX := IniRead(CONFIG_FILE, "Timing", "CLICK_DELAY_MAX", CLICK_DELAY_MAX)
        WINDOW_TITLE := IniRead(CONFIG_FILE, "Window", "WINDOW_TITLE", WINDOW_TITLE)
        EXCLUDED_TITLES := StrSplit(IniRead(CONFIG_FILE, "Window", "EXCLUDED_TITLES", "Roblox Account Manager"), ",")
        ENABLE_GENERAL_ACTIONS := IniRead(CONFIG_FILE, "Features", "ENABLE_GENERAL_ACTIONS", ENABLE_GENERAL_ACTIONS)
        ENABLED_FUNCTIONS := StrSplit(IniRead(CONFIG_FILE, "Features", "ENABLED_FUNCTIONS", "autoHatch,autoRebirth"), ",")
        ; Note: KEY_SEQUENCE and other arrays may need manual parsing if customized in config
    }
}

; ================== Gdip Setup ==================
#Include Gdip_All.ahk
initGdip() {
    global GdipToken
    if !GdipToken := Gdip_Startup() {
        MsgBox "Failed to initialize Gdip library. Template matching will not work."
    }
}

; ================== GUI Setup ==================
setupGUI() {
    global myGUI
    myGUI := Gui("+AlwaysOnTop", "🐝 BeeBrained’s PS99 Clan Battle Template 🐝")
    myGUI.Add("Text", "x10 y10 w380 h20", "🐝 Use " START_KEY " to start, " STOP_KEY " to stop, Esc to exit 🐝")
    myGUI.Add("Text", "x10 y40 w380 h20", "Status: Idle").Name := "Status"
    myGUI.Add("Text", "x10 y60 w380 h20", "Coords Captured: 0").Name := "Coords"
    myGUI.Add("Text", "x10 y80 w380 h20", "PixelSearch: OFF").Name := "PixelSearchStatus"
    myGUI.Add("Text", "x10 y100 w380 h20", "GameState Check: OFF").Name := "GameStateStatus"
    myGUI.Add("Button", "x10 y120 w120 h30", "Run Movement").OnEvent("Click", runMovementPattern)
    myGUI.Add("Button", "x140 y120 w120 h30", "Reload Config").OnEvent("Click", loadConfigFromFile)
    myGUI.Show("x0 y0 w400 h150")
}

; ================== Hotkeys ==================
Hotkey START_KEY, startAutomation
Hotkey STOP_KEY, stopAutomation
Hotkey PAUSE_KEY, togglePause
Hotkey CAPTURE_KEY, captureCoords
Hotkey INVENTORY_KEY, toggleInventoryMode
Hotkey PIXELSEARCH_KEY, togglePixelSearchMode
Hotkey CHECKSTATE_KEY, toggleCheckStateMode
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
        Sleep 200
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

togglePixelSearchMode(*) {
    global pixelsearch_mode
    pixelsearch_mode := !pixelsearch_mode
    myGUI["PixelSearchStatus"].Text := "PixelSearch: " (pixelsearch_mode ? "ON" : "OFF")
    ToolTip "PixelSearch Mode: " (pixelsearch_mode ? "ON" : "OFF"), 0, 100
    Sleep 1000
    ToolTip
}

toggleCheckStateMode(*) {
    global checkstate_mode
    checkstate_mode := !checkstate_mode
    myGUI["GameStateStatus"].Text := "GameState Check: " (checkstate_mode ? "ON" : "OFF")
    ToolTip "GameState Check Mode: " (checkstate_mode ? "ON" : "OFF"), 0, 100
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
        Sleep Random(50, 150)  ; Random delay for human-like behavior
    }
}

clickAt(x, y) {
    Random delay, CLICK_DELAY_MIN, CLICK_DELAY_MAX
    MouseMove x, y, 10
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

pixelSearchColor(&FoundX, &FoundY) {
    try {
        PixelSearch &FoundX, &FoundY, PIXELSEARCH_AREA[1], PIXELSEARCH_AREA[2], PIXELSEARCH_AREA[3], PIXELSEARCH_AREA[4], PIXELSEARCH_COLOR, PIXELSEARCH_VARIATION
        return true
    } catch {
        return false
    }
}

templateMatch(templateName, &FoundX, &FoundY) {
    if !FileExist(TEMPLATE_FOLDER "\" TEMPLATES[templateName]) {
        logAction("Template " templateName " not found!")
        return false
    }
    pBitmapScreen := Gdip_BitmapFromScreen()
    pBitmapTemplate := Gdip_CreateBitmapFromFile(TEMPLATE_FOLDER "\" TEMPLATES[templateName])
    result := Gdip_ImageSearch(pBitmapScreen, pBitmapTemplate, &FoundX, &FoundY, 0, 0, 0, 0, 0.9)
    Gdip_DisposeImage(pBitmapScreen)
    Gdip_DisposeImage(pBitmapTemplate)
    return result && FoundX != "" && FoundY != ""
}

runMovementPattern(*) {
    global running, paused
    if !running || paused
        return
    ToolTip "Running Movement: circle", 0, 100
    for seq in MOVEMENT_PATTERNS["circle"] {
        pressKey(seq[1], seq[2], seq[3])
    }
    Sleep 1000
    ToolTip
}

; ================== Automation Functions ==================
autoHatch() {
    detectUIElement("hatch_button")
}

autoRebirth() {
    FoundX := 0, FoundY := 0
    if templateMatch("rebirth_ready", &FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
    }
}

autoUpgrade() {
    detectUIElement("upgrade_button")
}

autoCollect() {
    FoundX := 0, FoundY := 0
    if pixelSearchColor(&FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
        logAction("Collected item at x=" FoundX ", y=" FoundY)
    }
}

autoConvert() {
    ; Example for glitch cores to glitch gifts
    FoundX := 0, FoundY := 0
    if templateMatch("convert_button", &FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
        logAction("Converted resource at x=" FoundX ", y=" FoundY)
    }
}

detectUIElement(element) {
    FoundX := 0, FoundY := 0
    if templateMatch(element, &FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
    }
}

checkGameState() {
    ; Example: Check for glitch gift availability
    FoundX := 0, FoundY := 0
    if pixelSearchColor(&FoundX, &FoundY) {
        logAction("Game state: Resource detected at x=" FoundX ", y=" FoundY)
    }
}

; ================== Main Automation Loop ==================
automationLoop() {
    global running, paused, inventory_mode, pixelsearch_mode, checkstate_mode
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
                if ENABLE_GENERAL_ACTIONS {
                    for seq in KEY_SEQUENCE {
                        pressKey(seq[1], seq[2], seq[3])
                    }
                    if (coords.Length > 0) {
                        for coord in coords {
                            clickAt(coord[1], coord[2])
                        }
                    }
                }
                for func in ENABLED_FUNCTIONS {
                    if func = "autoHatch"
                        autoHatch()
                    else if func = "autoRebirth"
                        autoRebirth()
                    else if func = "autoUpgrade"
                        autoUpgrade()
                    else if func = "autoCollect"
                        autoCollect()
                    else if func = "autoConvert"
                        autoConvert()
                }
                if inventory_mode
                    inventoryClick()
                if pixelsearch_mode {
                    FoundX := 0, FoundY := 0
                    if pixelSearchColor(&FoundX, &FoundY)
                        clickAt(FoundX, FoundY)
                }
                if checkstate_mode
                    checkGameState()
                Sleep Random(800, 1200)  ; Random delay for safety
            }
        }
    }
    updateStatus("Waiting (" CYCLE_INTERVAL // 1000 "s)")
    Sleep CYCLE_INTERVAL
}

; ================== Utility Functions ==================
logAction(action) {
    FileAppend A_Now ": " action "`n", logFile
}

loadConfigFromFile(*) {
    loadConfig()
    MsgBox "Configuration reloaded from " CONFIG_FILE
}

; ================== Main Execution ==================
loadConfig()
initGdip()
setupGUI()
TrayTip "🐝 BeeBrained’s PS99 Template", "Ready! Press " START_KEY " to start.", 10
