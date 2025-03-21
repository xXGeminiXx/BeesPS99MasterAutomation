#Requires AutoHotkey v2.0
; 🐝 BeeBrained's PS99 Clan Battle Automation Template 🐝
; Last Updated: March 21, 2025

global running := false
global paused := false
global coords := []
global inventory_mode := false
global pixelsearch_mode := false
global checkstate_mode := false
global myGUI
global logFile := A_ScriptDir "\log.txt"
global CONFIG_FILE := A_ScriptDir "\config.ini"
global ENABLE_LOGGING := true  ; Default to true, configurable

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

loadConfig() {
    global
    if !FileExist(CONFIG_FILE) {
        FileAppend defaultIni, CONFIG_FILE
        logAction("Created default config.ini")
    }
    
    INTERACTION_DURATION := IniRead(CONFIG_FILE, "Timing", "INTERACTION_DURATION", 5000)
    CYCLE_INTERVAL := IniRead(CONFIG_FILE, "Timing", "CYCLE_INTERVAL", 60000)
    CLICK_DELAY_MIN := IniRead(CONFIG_FILE, "Timing", "CLICK_DELAY_MIN", 500)
    CLICK_DELAY_MAX := IniRead(CONFIG_FILE, "Timing", "CLICK_DELAY_MAX", 1500)
    
    WINDOW_TITLE := IniRead(CONFIG_FILE, "Window", "WINDOW_TITLE", "Roblox")
    EXCLUDED_TITLES := StrSplit(IniRead(CONFIG_FILE, "Window", "EXCLUDED_TITLES", "Roblox Account Manager"), ",")
    
    ENABLE_GENERAL_ACTIONS := IniRead(CONFIG_FILE, "Features", "ENABLE_GENERAL_ACTIONS", true)
    ENABLED_FUNCTIONS := StrSplit(IniRead(CONFIG_FILE, "Features", "ENABLED_FUNCTIONS", "autoHatch,autoRebirth"), ",")
    
    TEMPLATES := Map()
    updateTemplates()  ; Auto-detect templates from folder
    
    START_KEY := "F1"
    STOP_KEY := "F2"
    PAUSE_KEY := "p"
    CAPTURE_KEY := "c"
    INVENTORY_KEY := "F3"
    PIXELSEARCH_KEY := "F4"
    CHECKSTATE_KEY := "F5"
    PIXELSEARCH_COLOR := IniRead(CONFIG_FILE, "PixelSearch", "PIXELSEARCH_COLOR", "0xFFFFFF")
    PIXELSEARCH_VARIATION := IniRead(CONFIG_FILE, "PixelSearch", "PIXELSEARCH_VARIATION", 10)
    area := StrSplit(IniRead(CONFIG_FILE, "PixelSearch", "PIXELSEARCH_AREA", "0,0," A_ScreenWidth "," A_ScreenHeight), ",")
    PIXELSEARCH_AREA := [area[1], area[2], area[3], area[4]]  ; Cached at init
    
    ENABLE_LOGGING := IniRead(CONFIG_FILE, "Logging", "ENABLE_LOGGING", true)
    
    MOVEMENT_PATTERNS := Map(
        "circle", [["w", 500, 1], ["d", 300, 1], ["s", 500, 1], ["a", 300, 1]],
        "zigzag", [["w", 400, 1], ["d", 200, 1], ["w", 400, 1], ["a", 200, 1]],
        "forward_backward", [["w", 1000, 1], ["s", 1000, 1]]
    )
    KEY_SEQUENCE := [["space", 500, 1], ["w", 300, 2], ["f", 200, 1]]
    TEMPLATE_FOLDER := A_ScriptDir "\templates"
}

updateTemplates() {
    global TEMPLATES, TEMPLATE_FOLDER
    ; Load from config first
    TEMPLATES["hatch_button"] := IniRead(CONFIG_FILE, "Templates", "hatch_button", "hatch_button.png")
    TEMPLATES["rebirth_button"] := IniRead(CONFIG_FILE, "Templates", "rebirth_button", "rebirth_button.png")
    TEMPLATES["rebirth_ready"] := IniRead(CONFIG_FILE, "Templates", "rebirth_ready", "rebirth_ready.png")
    TEMPLATES["upgrade_button"] := IniRead(CONFIG_FILE, "Templates", "upgrade_button", "upgrade_button.png")
    ; Auto-detect new templates in folder
    Loop Files, TEMPLATE_FOLDER "\*.png" {
        name := StrReplace(A_LoopFileName, ".png", "")
        if !TEMPLATES.Has(name) {
            TEMPLATES[name] := A_LoopFileName
            logAction("Auto-detected new template: " A_LoopFileName)
        }
    }
}

setupGUI() {
    global myGUI, ENABLED_FUNCTIONS
    myGUI := Gui("+AlwaysOnTop", "🐝 BeeBrained’s PS99 Clan Battle Template 🐝")
    myGUI.Add("Text", "x10 y10 w380 h20", "🐝 Use " START_KEY " to start, " STOP_KEY " to stop, Esc to exit 🐝")
    myGUI.Add("Text", "x10 y40 w380 h20", "Status: Idle").Name := "Status"
    myGUI.Add("Text", "x10 y60 w380 h20", "Coords Captured: 0").Name := "Coords"
    myGUI.Add("Text", "x10 y80 w380 h20", "PixelSearch: OFF").Name := "PixelSearchStatus"
    myGUI.Add("Text", "x10 y100 w380 h20", "GameState Check: OFF").Name := "GameStateStatus"
    myGUI.Add("Text", "x10 y120 w380 h20", "Active Windows: 0").Name := "WindowCount"
    myGUI.Add("Button", "x10 y140 w120 h30", "Run Movement").OnEvent("Click", runMovementPattern)
    myGUI.Add("Button", "x140 y140 w120 h30", "Reload Config").OnEvent("Click", loadConfigFromFile)
    ; Add checkboxes for functions
    yPos := 180
    for func in ENABLED_FUNCTIONS {
        myGUI.Add("Checkbox", "x10 y" yPos " w120 h20 v" func " Checked1", func).OnEvent("Click", toggleFunction)
        yPos += 20
    }
    myGUI.Show("x0 y0 w400 h" (yPos + 20))
}

toggleFunction(ctrl, *) {
    global ENABLED_FUNCTIONS
    funcName := ctrl.Name
    if ctrl.Value {
        if !ENABLED_FUNCTIONS.Contains(funcName) {
            ENABLED_FUNCTIONS.Push(funcName)
        }
    } else {
        if idx := ENABLED_FUNCTIONS.IndexOf(funcName) {
            ENABLED_FUNCTIONS.RemoveAt(idx)
        }
    }
}

Hotkey START_KEY, startAutomation
Hotkey STOP_KEY, stopAutomation
Hotkey PAUSE_KEY, togglePause
Hotkey CAPTURE_KEY, captureCoords
Hotkey INVENTORY_KEY, toggleInventoryMode
Hotkey PIXELSEARCH_KEY, togglePixelSearchMode
Hotkey CHECKSTATE_KEY, toggleCheckStateMode
Esc::ExitApp

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
    myGUI["PixelSearchStatus"].Text := "PixelSearch: " (pixelsearch_mode ? "ON" : "OFF")
    pixelsearch_mode := !pixelsearch_mode
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
    myGUI["WindowCount"].Text := "Active Windows: " windows.Length
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
    WinRestore(hwnd)
    WinActivate(hwnd)
    WinWaitActive(hwnd, , 2)
    return ErrorLevel = 0
}

pressKey(key, duration, repeat) {
    Loop repeat {
        Send "{" key " down}"
        Sleep duration
        Send "{" key " up}"
        Sleep Random(50, 150)
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
    PixelSearch &FoundX, &FoundY, PIXELSEARCH_AREA[1], PIXELSEARCH_AREA[2], PIXELSEARCH_AREA[3], PIXELSEARCH_AREA[4], PIXELSEARCH_COLOR, PIXELSEARCH_VARIATION
    if ErrorLevel {
        logAction("PixelSearch failed for color " PIXELSEARCH_COLOR " in area " PIXELSEARCH_AREA[1] "," PIXELSEARCH_AREA[2] "-" PIXELSEARCH_AREA[3] "," PIXELSEARCH_AREA[4])
        return false
    }
    return true
}

templateMatch(templateName, &FoundX, &FoundY) {
    ; Use AutoHotkey's built-in ImageSearch to find the template on the screen
    templatePath := TEMPLATE_FOLDER "\" TEMPLATES[templateName]
    if !FileExist(templatePath) {
        logAction("Template not found: " templatePath)
        return false
    }

    ; Search the entire screen for the template image
    ; Variation of 0 for exact match; adjust if needed for more leniency
    ImageSearch &FoundX, &FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, *0 %templatePath%
    if ErrorLevel {
        logAction("Template match failed for: " templateName)
        return false
    }

    ; Adjust coordinates to the center of the found image for clicking
    ImageInfo := ImageGetInfo(templatePath)
    if ImageInfo {
        FoundX += ImageInfo.Width // 2
        FoundY += ImageInfo.Height // 2
    }

    return true
}

; Helper function to get image dimensions (width and height) for centering clicks
ImageGetInfo(imagePath) {
    try {
        ; Use GDI (not GDI+) to get image dimensions without external libraries
        hBitmap := DllCall("LoadImage", "UInt", 0, "Str", imagePath, "UInt", 0, "Int", 0, "Int", 0, "UInt", 0x10, "Ptr")
        if !hBitmap {
            logAction("Failed to load image for dimensions: " imagePath)
            return false
        }

        VarSetCapacity(BITMAP, 32, 0)
        DllCall("GetObject", "Ptr", hBitmap, "Int", 32, "Ptr", &BITMAP)
        width := NumGet(BITMAP, 4, "Int")
        height := NumGet(BITMAP, 8, "Int")
        DllCall("DeleteObject", "Ptr", hBitmap)
        return {Width: width, Height: height}
    } catch {
        logAction("Error getting image dimensions for: " imagePath)
        return false
    }
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

autoHatch() {
    FoundX := 0, FoundY := 0
    if templateMatch("hatch_button", &FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
    } else {
        logAction("autoHatch failed to detect hatch_button")
    }
}

autoRebirth() {
    FoundX := 0, FoundY := 0
    if templateMatch("rebirth_ready", &FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
    } else {
        logAction("autoRebirth failed to detect rebirth_ready")
    }
}

autoUpgrade() {
    FoundX := 0, FoundY := 0
    if templateMatch("upgrade_button", &FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
    } else {
        logAction("autoUpgrade failed to detect upgrade_button")
    }
}

autoCollect() {
    FoundX := 0, FoundY := 0
    if pixelSearchColor(&FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
        logAction("Collected item at x=" FoundX ", y=" FoundY)
    }
}

autoConvert() {
    FoundX := 0, FoundY := 0
    if templateMatch("convert_button", &FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
        logAction("Converted resource at x=" FoundX ", y=" FoundY)
    } else {
        logAction("autoConvert failed to detect convert_button")
    }
}

detectUIElement(element) {
    FoundX := 0, FoundY := 0
    if templateMatch(element, &FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
    }
}

checkGameState() {
    FoundX := 0, FoundY := 0
    if pixelSearchColor(&FoundX, &FoundY) {
        logAction("Game state: Resource detected at x=" FoundX ", y=" FoundY)
    }
}

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
                Sleep Random(800, 1200)
            }
        }
    }
    updateStatus("Waiting (" CYCLE_INTERVAL // 1000 "s)")
    Sleep CYCLE_INTERVAL
}

logAction(action) {
    if ENABLE_LOGGING {
        FileAppend A_Now ": " action "`n", logFile
    }
}

loadConfigFromFile(*) {
    loadConfig()
    MsgBox "Configuration reloaded from " CONFIG_FILE
}

loadConfig()
setupGUI()
TrayTip "🐝 BeeBrained’s PS99 Template", "Ready! Press " START_KEY " to start.", 10
