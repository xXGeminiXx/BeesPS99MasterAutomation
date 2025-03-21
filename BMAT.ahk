#Requires AutoHotkey v2.0
; 🐝 BeeBrained's PS99 Clan Battle Automation Template 🐝
; Last Updated: March 21, 2025

; ===================== REQUIRED GLOBAL VARIABLES =====================

global BB_running := false
global BB_paused := false
global BB_coords := []
global BB_CLICK_DELAY_MAX := 1500  ; Changed to match INI file (in milliseconds)
global BB_CLICK_DELAY_MIN := 500   ; Changed to match INI file (in milliseconds)
global BB_inventory_mode := false
global BB_pixelsearch_mode := false
global BB_PIXELSEARCH_AREA := [0, 0, A_ScreenWidth, A_ScreenHeight]
global BB_PIXELSEARCH_COLOR := "0xFFFFFF"
global BB_PIXELSEARCH_VARIATION := 10
global BB_MOVEMENT_PATTERNS := Map()
global BB_INTERACTION_DURATION := 5000  ; Changed to match INI file (in milliseconds)
global BB_ENABLE_GENERAL_ACTIONS := true
global BB_START_KEY := "F1"
global BB_STOP_KEY := "F2"
global BB_PAUSE_KEY := "p"
global BB_KEY_SEQUENCE := [["space", 500, 1], ["w", 300, 2], ["f", 200, 1]]
global BB_CYCLE_INTERVAL := 60000  ; Changed to match INI file (in milliseconds)
global BB_checkstate_mode := false
global BB_myGUI
global BB_logFile := A_ScriptDir "\log.txt"
global BB_CONFIG_FILE := A_ScriptDir "\config.ini"
global BB_ENABLE_LOGGING := true
global BB_ENABLED_FUNCTIONS := []
global BB_TEMPLATE_FOLDER := A_ScriptDir "\templates"
global BB_WINDOW_TITLE := "Roblox"
global BB_EXCLUDED_TITLES := ["Roblox Account Manager"]
global BB_TEMPLATES := Map()
global BB_ErrorLevel := 0
global BB_CAPTURE_KEY := "c"
global BB_INVENTORY_KEY := "F3"
global BB_PIXELSEARCH_KEY := "F4"
global BB_CHECKSTATE_KEY := "F5"

; ===================== MOVEMENT PATTERNS DEFINITION =====================

BB_MOVEMENT_PATTERNS := Map(
    "circle", [["w", 500, 1], ["d", 300, 1], ["s", 500, 1], ["a", 300, 1]],
    "zigzag", [["w", 400, 1], ["d", 200, 1], ["w", 400, 1], ["a", 200, 1]],
    "forward_backward", [["w", 1000, 1], ["s", 1000, 1]]
)

BB_logAction(action) {
    global BB_ENABLE_LOGGING, BB_logFile
    if BB_ENABLE_LOGGING {
        FileAppend(A_Now ": " action "`n", BB_logFile)
    }
}

defaultIni := "
(
[Timing]
INTERACTION_DURATION=5000
CYCLE_INTERVAL=60000
CLICK_DELAY_MIN=500
CLICK_DELAY_MAX=1500

[Window]
WINDOW_TITLE=Roblox
EXCLUDED_TITLES=Roblox Account Manager

[Features]
ENABLE_GENERAL_ACTIONS=true
ENABLED_FUNCTIONS=autoHatch,autoRebirth

[Templates]
hatch_button=hatch_button.png
rebirth_button=rebirth_button.png
rebirth_ready=rebirth_ready.png
upgrade_button=upgrade_button.png

[PixelSearch]
PIXELSEARCH_COLOR=0xFFFFFF
PIXELSEARCH_VARIATION=10
PIXELSEARCH_AREA=0,0," A_ScreenWidth "," A_ScreenHeight "

[Logging]
ENABLE_LOGGING=true
)"

BB_loadConfig() {
    global BB_CONFIG_FILE, BB_logFile, BB_ENABLE_LOGGING, BB_WINDOW_TITLE, BB_EXCLUDED_TITLES
    global BB_CLICK_DELAY_MIN, BB_CLICK_DELAY_MAX, BB_INTERACTION_DURATION, BB_CYCLE_INTERVAL
    global BB_PIXELSEARCH_COLOR, BB_PIXELSEARCH_VARIATION, BB_PIXELSEARCH_AREA
    global BB_ENABLE_GENERAL_ACTIONS, BB_ENABLED_FUNCTIONS, BB_MOVEMENT_PATTERNS, BB_KEY_SEQUENCE
    global BB_TEMPLATE_FOLDER, BB_TEMPLATES

    if !FileExist(BB_CONFIG_FILE) {
        FileAppend(defaultIni, BB_CONFIG_FILE)
        BB_logAction("Created default config.ini")
    }
    
    ; ===================== LOAD CONFIGURATION =====================
    BB_INTERACTION_DURATION := IniRead(BB_CONFIG_FILE, "Timing", "INTERACTION_DURATION", 5000)
    BB_CYCLE_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "CYCLE_INTERVAL", 60000)
    BB_CLICK_DELAY_MIN := IniRead(BB_CONFIG_FILE, "Timing", "CLICK_DELAY_MIN", 500)
    BB_CLICK_DELAY_MAX := IniRead(BB_CONFIG_FILE, "Timing", "CLICK_DELAY_MAX", 1500)
    
    BB_WINDOW_TITLE := IniRead(BB_CONFIG_FILE, "Window", "WINDOW_TITLE", "Roblox")
    BB_EXCLUDED_TITLES := StrSplit(IniRead(BB_CONFIG_FILE, "Window", "EXCLUDED_TITLES", "Roblox Account Manager"), ",")
    
    BB_ENABLE_GENERAL_ACTIONS := IniRead(BB_CONFIG_FILE, "Features", "ENABLE_GENERAL_ACTIONS", true)
    BB_ENABLED_FUNCTIONS := StrSplit(IniRead(BB_CONFIG_FILE, "Features", "ENABLED_FUNCTIONS", "autoHatch,autoRebirth"), ",")
    
    ; ===================== TEMPLATE MANAGEMENT =====================
    BB_TEMPLATE_FOLDER := A_ScriptDir "\templates"
    BB_updateTemplates()
    
    ; ===================== PIXELSEARCH SETTINGS =====================
    BB_PIXELSEARCH_COLOR := IniRead(BB_CONFIG_FILE, "PixelSearch", "PIXELSEARCH_COLOR", "0xFFFFFF")
    BB_PIXELSEARCH_VARIATION := IniRead(BB_CONFIG_FILE, "PixelSearch", "PIXELSEARCH_VARIATION", 10)
    BB_area := StrSplit(IniRead(BB_CONFIG_FILE, "PixelSearch", "PIXELSEARCH_AREA", "0,0," A_ScreenWidth "," A_ScreenHeight), ",")
    BB_PIXELSEARCH_AREA := [BB_area[1], BB_area[2], BB_area[3], BB_area[4]]
    
    ; ===================== LOGGING SETTINGS =====================
    BB_ENABLE_LOGGING := IniRead(BB_CONFIG_FILE, "Logging", "ENABLE_LOGGING", true)
}

BB_updateTemplates() {
    global BB_TEMPLATES, BB_TEMPLATE_FOLDER
    ; Load templates from config
    BB_TEMPLATES["hatch_button"] := IniRead(BB_CONFIG_FILE, "Templates", "hatch_button", "hatch_button.png")
    BB_TEMPLATES["rebirth_button"] := IniRead(BB_CONFIG_FILE, "Templates", "rebirth_button", "rebirth_button.png")
    BB_TEMPLATES["rebirth_ready"] := IniRead(BB_CONFIG_FILE, "Templates", "rebirth_ready", "rebirth_ready.png")
    BB_TEMPLATES["upgrade_button"] := IniRead(BB_CONFIG_FILE, "Templates", "upgrade_button", "upgrade_button.png")
    
    ; Auto-detect new templates in folder
    Loop Files, BB_TEMPLATE_FOLDER "\*.png" {
        name := StrReplace(A_LoopFileName, ".png", "")
        if !BB_TEMPLATES.Has(name) {
            BB_TEMPLATES[name] := A_LoopFileName
            BB_logAction("Auto-detected new template: " A_LoopFileName)
        }
    }
}

BB_setupGUI() {
    global BB_myGUI, BB_ENABLED_FUNCTIONS
    BB_myGUI := Gui("+AlwaysOnTop", "🐝 BeeBrained’s PS99 Clan Battle Template 🐝")
    BB_myGUI.Add("Text", "x10 y10 w380 h20", "🐝 Use " BB_START_KEY " to start, " BB_STOP_KEY " to stop, Esc to exit 🐝")
    BB_myGUI.Add("Text", "x10 y40 w380 h20", "Status: Idle").Name := "Status"
    BB_myGUI.Add("Text", "x10 y60 w380 h20", "Coords Captured: 0").Name := "Coords"
    BB_myGUI.Add("Text", "x10 y80 w380 h20", "PixelSearch: OFF").Name := "PixelSearchStatus"
    BB_myGUI.Add("Text", "x10 y100 w380 h20", "GameState Check: OFF").Name := "GameStateStatus"
    BB_myGUI.Add("Text", "x10 y120 w380 h20", "Active Windows: 0").Name := "WindowCount"
    BB_myGUI.Add("Button", "x10 y140 w120 h30", "Run Movement").OnEvent("Click", BB_runMovementPattern)
    BB_myGUI.Add("Button", "x140 y140 w120 h30", "Reload Config").OnEvent("Click", BB_loadConfigFromFile)
    
    ; Add checkboxes for functions
    yPos := 180
    for func in BB_ENABLED_FUNCTIONS {
        BB_myGUI.Add("Checkbox", "x10 y" yPos " w120 h20 v" func " Checked1", func).OnEvent("Click", BB_toggleFunction)
        yPos += 20
    }
    
    BB_myGUI.Show("x0 y0 w400 h" (yPos + 20))
}

BB_toggleFunction(ctrl, *) {
    global BB_ENABLED_FUNCTIONS
    funcName := ctrl.Name
    if ctrl.Value {
        if !BB_ENABLED_FUNCTIONS.Contains(funcName) {
            BB_ENABLED_FUNCTIONS.Push(funcName)
        }
    } else {
        if idx := BB_ENABLED_FUNCTIONS.IndexOf(funcName) {
            BB_ENABLED_FUNCTIONS.RemoveAt(idx)
        }
    }
}

Hotkey(BB_START_KEY, BB_startAutomation)
Hotkey(BB_STOP_KEY, BB_stopAutomation)
Hotkey(BB_PAUSE_KEY, BB_togglePause)
Hotkey(BB_CAPTURE_KEY, BB_captureCoords)
Hotkey(BB_INVENTORY_KEY, BB_toggleInventoryMode)
Hotkey(BB_PIXELSEARCH_KEY, BB_togglePixelSearchMode)
Hotkey(BB_CHECKSTATE_KEY, BB_toggleCheckStateMode)
Hotkey("Esc", BB_exitApp)

BB_startAutomation(*) {
    global BB_running, BB_paused
    if BB_running
        return
    BB_running := true
    BB_paused := false
    BB_updateStatus("Running")
    SetTimer BB_automationLoop, 100
}

BB_stopAutomation(*) {
    global BB_running, BB_paused
    BB_running := false
    BB_paused := false
    SetTimer BB_automationLoop, "Off"
    BB_updateStatus("Idle")
}

BB_togglePause(*) {
    global BB_running, BB_paused
    if BB_running {
        BB_paused := !BB_paused
        BB_updateStatus(BB_paused ? "Paused" : "Running")
        Sleep 200
    }
}

BB_captureCoords(*) {
    global BB_coords, BB_myGUI
    Sleep 500
    MouseGetPos(&x, &y)
    BB_coords.Push([x, y])
    BB_myGUI["Coords"].Text := "Coords Captured: " BB_coords.Length()
    ToolTip "Captured: x=" x ", y=" y, 0, 100
    Sleep 1000
    ToolTip
}

BB_toggleInventoryMode(*) {
    global BB_inventory_mode
    BB_inventory_mode := !BB_inventory_mode
    ToolTip "Inventory Mode: " (BB_inventory_mode ? "ON" : "OFF"), 0, 100
    Sleep 1000
    ToolTip
}

BB_togglePixelSearchMode(*) {
    global BB_pixelsearch_mode, BB_myGUI
    BB_pixelsearch_mode := !BB_pixelsearch_mode
    BB_myGUI["PixelSearchStatus"].Text := "PixelSearch: " (BB_pixelsearch_mode ? "ON" : "OFF")
    ToolTip "PixelSearch Mode: " (BB_pixelsearch_mode ? "ON" : "OFF"), 0, 100
    Sleep 1000
    ToolTip
}

BB_toggleCheckStateMode(*) {
    global BB_checkstate_mode, BB_myGUI
    BB_checkstate_mode := !BB_checkstate_mode
    BB_myGUI["GameStateStatus"].Text := "GameState Check: " (BB_checkstate_mode ? "ON" : "OFF")
    ToolTip "GameState Check Mode: " (BB_checkstate_mode ? "ON" : "OFF"), 0, 100
    Sleep 1000
    ToolTip
}

BB_updateStatus(text) {
    global BB_myGUI
    BB_myGUI["Status"].Text := "Status: " text
}

BB_findRobloxWindows() {
    global BB_myGUI, BB_WINDOW_TITLE, BB_EXCLUDED_TITLES
    windows := []
    for hwnd in WinGetList() {
        title := WinGetTitle(hwnd)
        if (InStr(title, BB_WINDOW_TITLE) && !BB_hasExcludedTitle(title) && WinGetProcessName(hwnd) = "RobloxPlayerBeta.exe") {
            windows.Push(hwnd)
        }
    }
    BB_myGUI["WindowCount"].Text := "Active Windows: " windows.Length
    return windows
}

BB_hasExcludedTitle(title) {
    global BB_EXCLUDED_TITLES
    for excluded in BB_EXCLUDED_TITLES {
        if InStr(title, excluded)
            return true
    }
    return false
}

BB_bringToFront(hwnd) {
    WinRestore(hwnd)
    WinActivate(hwnd)
    WinWaitActive(hwnd, , 2)
    return WinWaitActive(hwnd, , 2) != 0
}

BB_pressKey(key, duration, repeat) {
    Loop repeat {
        Send "{" key " down}"
        Sleep duration
        Send "{" key " up}"
        Sleep Random(50, 150)
    }
}

BB_clickAt(x, y) {
    global BB_CLICK_DELAY_MIN, BB_CLICK_DELAY_MAX
    delay := Random(BB_CLICK_DELAY_MIN, BB_CLICK_DELAY_MAX)
    MouseMove x, y, 10
    Sleep delay
    Click
}

BB_inventoryClick() {
    global BB_clickAt
    MouseGetPos(&x, &y)
    Send "{f down}"
    Sleep 200
    Send "{f up}"
    Sleep 500
    BB_clickAt(x, y)
    Sleep 500
    Send "{f down}"
    Sleep 200
    Send "{f up}"
}

BB_pixelSearchColor(&FoundX, &FoundY) {
    global BB_PIXELSEARCH_AREA, BB_PIXELSEARCH_COLOR, BB_PIXELSEARCH_VARIATION
    PixelSearch &FoundX, &FoundY, BB_PIXELSEARCH_AREA[1], BB_PIXELSEARCH_AREA[2], BB_PIXELSEARCH_AREA[3], BB_PIXELSEARCH_AREA[4], BB_PIXELSEARCH_COLOR, BB_PIXELSEARCH_VARIATION
    if (FoundX = "" || FoundY = "") {
        BB_logAction("PixelSearch failed for color " BB_PIXELSEARCH_COLOR " in area " BB_PIXELSEARCH_AREA[1] "," BB_PIXELSEARCH_AREA[2] "-" BB_PIXELSEARCH_AREA[3] "," BB_PIXELSEARCH_AREA[4])
        return false
    }
    return true
}

BB_templateMatch(templateName, &FoundX, &FoundY) {
    global BB_TEMPLATE_FOLDER, BB_TEMPLATES
    templatePath := BB_TEMPLATE_FOLDER "\" BB_TEMPLATES[templateName]
    
    if !FileExist(templatePath) {
        BB_logAction("Template not found: " templatePath)
        return false
    }
    
    try {
        ImageSearch(&FoundX, &FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, "*0 " templatePath)
        return true
    } catch {
        BB_logAction("Template match failed for: " templateName)
        return false
    }
}

BB_runMovementPattern(*) {
    global BB_running, BB_paused, BB_MOVEMENT_PATTERNS
    if !BB_running || BB_paused
        return
    ToolTip "Running Movement: circle", 0, 100
    for seq in BB_MOVEMENT_PATTERNS["circle"] {
        BB_pressKey(seq[1], seq[2], seq[3])
    }
    Sleep 1000
    ToolTip
}

BB_autoHatch() {
    FoundX := 0, FoundY := 0
    if BB_templateMatch("hatch_button", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
    } else {
        BB_logAction("BB_autoHatch failed to detect hatch_button")
    }
}

BB_autoRebirth() {
    FoundX := 0, FoundY := 0
    if BB_templateMatch("rebirth_ready", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
    } else {
        BB_logAction("BB_autoRebirth failed to detect rebirth_ready")
    }
}

BB_autoUpgrade() {
    FoundX := 0, FoundY := 0
    if BB_templateMatch("upgrade_button", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
    } else {
        BB_logAction("BB_autoUpgrade failed to detect upgrade_button")
    }
}

BB_autoCollect() {
    FoundX := 0, FoundY := 0
    if BB_pixelSearchColor(&FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
        BB_logAction("Collected item at x=" FoundX ", y=" FoundY)
    }
}

BB_autoConvert() {
    FoundX := 0, FoundY := 0
    if BB_templateMatch("convert_button", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
        BB_logAction("Converted resource at x=" FoundX ", y=" FoundY)
    } else {
        BB_logAction("BB_autoConvert failed to detect convert_button")
    }
}

BB_detectUIElement(element) {
    FoundX := 0, FoundY := 0
    if BB_templateMatch(element, &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
    }
}

BB_checkGameState() {
    FoundX := 0, FoundY := 0
    if BB_pixelSearchColor(&FoundX, &FoundY) {
        BB_logAction("Game state: Resource detected at x=" FoundX ", y=" FoundY)
    }
}

BB_automationLoop() {
    global BB_running, BB_paused, BB_inventory_mode, BB_pixelsearch_mode, BB_checkstate_mode
    global BB_KEY_SEQUENCE, BB_coords, BB_ENABLED_FUNCTIONS, BB_INTERACTION_DURATION, BB_ENABLE_GENERAL_ACTIONS
    if (!BB_running || BB_paused)
        return

    windows := BB_findRobloxWindows()
    if (windows.Length = 0) {
        BB_updateStatus("No Roblox windows found")
        Sleep 10000
        return
    }

    BB_updateStatus("Running (" windows.Length " windows)")
    for hwnd in windows {
        if (!BB_running || BB_paused)
            break
        if BB_bringToFront(hwnd) {
            startTime := A_TickCount
            while (A_TickCount - startTime < BB_INTERACTION_DURATION && BB_running && !BB_paused) {
                if BB_ENABLE_GENERAL_ACTIONS {
                    for seq in BB_KEY_SEQUENCE {
                        BB_pressKey(seq[1], seq[2], seq[3])
                    }
                    if (BB_coords.Length > 0) {
                        for coord in BB_coords {
                            BB_clickAt(coord[1], coord[2])
                        }
                    }
                }
                for func in BB_ENABLED_FUNCTIONS {
                    if func = "autoHatch"
                        BB_autoHatch()
                    else if func = "autoRebirth"
                        BB_autoRebirth()
                    else if func = "autoUpgrade"
                        BB_autoUpgrade()
                    else if func = "autoCollect"
                        BB_autoCollect()
                    else if func = "autoConvert"
                        BB_autoConvert()
                }
                if BB_inventory_mode
                    BB_inventoryClick()
                if BB_pixelsearch_mode {
                    FoundX := 0, FoundY := 0
                    if BB_pixelSearchColor(&FoundX, &FoundY)
                        BB_clickAt(FoundX, FoundY)
                }
                if BB_checkstate_mode
                    BB_checkGameState()
                Sleep Random(800, 1200)
            }
        }
    }
    BB_updateStatus("Waiting (" BB_CYCLE_INTERVAL // 1000 "s)")
    Sleep BB_CYCLE_INTERVAL
}

BB_loadConfigFromFile(*) {
    BB_loadConfig()
    MsgBox "Configuration reloaded from " BB_CONFIG_FILE
}

BB_exitApp(*) {
    ExitApp()
}

; Initialize the script
BB_loadConfig()  ; Load configuration first
BB_setupGUI()
TrayTip "Ready! Press " BB_START_KEY " to start.", "🐝 BeeBrained's PS99 Template", 0x10
