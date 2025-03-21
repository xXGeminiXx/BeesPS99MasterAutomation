#Requires AutoHotkey v2.0
; 🐝 BeeBrained's PS99 Clan Battle Automation Template 🐝
; Last Updated: March 21, 2025

; ===================== REQUIRED GLOBAL VARIABLES =====================

global BB_running := false
global BB_paused := false
global BB_coords := []
global BB_CLICK_DELAY_MAX := 1500
global BB_CLICK_DELAY_MIN := 500
global BB_inventory_mode := false
global BB_pixelsearch_mode := false
global BB_checkstate_mode := false
global BB_PIXELSEARCH_AREA := [0, 0, A_ScreenWidth, A_ScreenHeight]
global BB_PIXELSEARCH_COLOR := "0xFFFFFF"
global BB_PIXELSEARCH_VARIATION := 10
global BB_MOVEMENT_PATTERNS := Map()
global BB_INTERACTION_DURATION := 5000
global BB_CYCLE_INTERVAL := 60000
global BB_ENABLE_DEATH_DETECTION := true
global BB_functionStatus := Map()
global BB_isActivelyProcessing := false
global BB_ENABLE_GENERAL_ACTIONS := true
global BB_START_KEY := "F1"
global BB_STOP_KEY := "F2"
global BB_PAUSE_KEY := "p"
global BB_KEY_SEQUENCE := [["space", 500, 1], ["w", 300, 2], ["f", 200, 1]]
global BB_myGUI := ""
global BB_logFile := A_ScriptDir "\log.txt"
global BB_CONFIG_FILE := A_ScriptDir "\config.ini"
global BB_ENABLE_LOGGING := true
global BB_ENABLED_FUNCTIONS := []
global BB_TEMPLATE_FOLDER := A_ScriptDir "\templates"
global BB_WINDOW_TITLE := "Roblox"
global BB_EXCLUDED_TITLES := ["Roblox Account Manager"]
global BB_TEMPLATES := Map()
global BB_missingTemplatesReported := Map()
global BB_CAPTURE_KEY := "c"
global BB_INVENTORY_KEY := "F3"
global BB_PIXELSEARCH_KEY := "F4"
global BB_CHECKSTATE_KEY := "F5"
global BB_CAMERA_ADJUST_KEY := "F6"
global BB_camera_adjusted_windows := Map()
global BB_TEMPLATE_RETRIES := 3
global BB_CAMERA_ADJUST_SPEED := 10
global BB_DEATH_RECOVERY_DELAY := 3000
global BB_FAILED_INTERACTION_COUNT := 0
global BB_MAX_FAILED_INTERACTIONS := 5
global BB_ANTI_AFK_INTERVAL := 300000  ; 5 minutes
global BB_RECONNECT_CHECK_INTERVAL := 10000  ; 10 seconds
global BB_active_windows := []  ; Cache for active Roblox windows
global BB_last_window_check := 0  ; Timestamp of last window check
global BB_bossFightActive := false
global BB_chestBreakActive := false
global BB_BOSS_FIGHT_INTERVAL := 1000  ; 1 second
global BB_CHEST_BREAK_INTERVAL := 1000  ; 1 second

; ===================== MOVEMENT PATTERNS DEFINITION =====================

BB_MOVEMENT_PATTERNS := Map(
    "circle", [["w", 500, 1], ["d", 300, 1], ["s", 500, 1], ["a", 300, 1]],
    "zigzag", [["w", 400, 1], ["d", 200, 1], ["w", 400, 1], ["a", 200, 1]],
    "forward_backward", [["w", 1000, 1], ["s", 1000, 1]],
    "to_boss", [["w", 1000, 1], ["d", 200, 1]],
    "search", [["w", 500, 1], ["a", 300, 1], ["s", 500, 1], ["d", 300, 1]]
)

; ===================== LOGGING FUNCTION =====================

BB_updateStatusAndLog(action, updateGUI := true) {
    global BB_ENABLE_LOGGING, BB_logFile, BB_myGUI
    if BB_ENABLE_LOGGING {
        FileAppend(A_Now ": " action "`n", BB_logFile)
    }
    if updateGUI && IsObject(BB_myGUI) && BB_myGUI.HasProp("Status") {
        BB_myGUI["Status"].Text := "Status: " (BB_running ? (BB_paused ? "Paused" : "Running") : "Idle") " - " action
    }
    ToolTip action, 0, 100
    SetTimer () => ToolTip(), -1000
}

; ===================== DEFAULT CONFIGURATION =====================

defaultIni := "
(
[Timing]
INTERACTION_DURATION=5000
CYCLE_INTERVAL=60000
CLICK_DELAY_MIN=500
CLICK_DELAY_MAX=1500
DEATH_RECOVERY_DELAY=3000
ANTI_AFK_INTERVAL=300000
RECONNECT_CHECK_INTERVAL=10000
BOSS_FIGHT_INTERVAL=1000
CHEST_BREAK_INTERVAL=1000

[Window]
WINDOW_TITLE=Roblox
EXCLUDED_TITLES=Roblox Account Manager

[Features]
ENABLE_GENERAL_ACTIONS=true
ENABLED_FUNCTIONS=autoHatch,autoRebirth,defeatBoss,breakChest

[Templates]
hatch_button=hatch_button.png
rebirth_button=rebirth_button.png
rebirth_ready=rebirth_ready.png
upgrade_button=upgrade_button.png
convert_button=convert_button.png
raid_boss=raid_boss.png
raid_boss_alt=raid_boss_alt.png
boss_room_entrance=boss_room_entrance.png
chest=chest.png
death_screen=death_screen.png
quest_indicator=quest_indicator.png

[PixelSearch]
PIXELSEARCH_COLOR=0xFFFFFF
PIXELSEARCH_VARIATION=10
PIXELSEARCH_AREA=0,0,SCREEN_WIDTH,SCREEN_HEIGHT

[Camera]
CAMERA_ADJUST_SPEED=10

[Retries]
TEMPLATE_RETRIES=3
MAX_FAILED_INTERACTIONS=5

[Logging]
ENABLE_LOGGING=true
)"

; ===================== LOAD CONFIGURATION =====================

BB_loadConfig() {
    global BB_CONFIG_FILE, BB_logFile, BB_ENABLE_LOGGING, BB_WINDOW_TITLE, BB_EXCLUDED_TITLES
    global BB_CLICK_DELAY_MIN, BB_CLICK_DELAY_MAX, BB_INTERACTION_DURATION, BB_CYCLE_INTERVAL
    global BB_PIXELSEARCH_COLOR, BB_PIXELSEARCH_VARIATION, BB_PIXELSEARCH_AREA
    global BB_ENABLE_GENERAL_ACTIONS, BB_ENABLED_FUNCTIONS, BB_MOVEMENT_PATTERNS, BB_KEY_SEQUENCE
    global BB_TEMPLATE_FOLDER, BB_TEMPLATES, BB_DEATH_RECOVERY_DELAY, BB_CAMERA_ADJUST_SPEED
    global BB_TEMPLATE_RETRIES, BB_MAX_FAILED_INTERACTIONS, BB_ANTI_AFK_INTERVAL, BB_RECONNECT_CHECK_INTERVAL
    global BB_BOSS_FIGHT_INTERVAL, BB_CHEST_BREAK_INTERVAL

    if !FileExist(BB_CONFIG_FILE) {
        FileAppend(defaultIni, BB_CONFIG_FILE)
        BB_updateStatusAndLog("Created default config.ini")
    }
    
    BB_INTERACTION_DURATION := IniRead(BB_CONFIG_FILE, "Timing", "INTERACTION_DURATION", 5000)
    BB_CYCLE_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "CYCLE_INTERVAL", 60000)
    BB_CLICK_DELAY_MIN := IniRead(BB_CONFIG_FILE, "Timing", "CLICK_DELAY_MIN", 500)
    BB_CLICK_DELAY_MAX := IniRead(BB_CONFIG_FILE, "Timing", "CLICK_DELAY_MAX", 1500)
    BB_DEATH_RECOVERY_DELAY := IniRead(BB_CONFIG_FILE, "Timing", "DEATH_RECOVERY_DELAY", 3000)
    BB_ANTI_AFK_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "ANTI_AFK_INTERVAL", 300000)
    BB_RECONNECT_CHECK_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "RECONNECT_CHECK_INTERVAL", 10000)
    BB_BOSS_FIGHT_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "BOSS_FIGHT_INTERVAL", 1000)
    BB_CHEST_BREAK_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "CHEST_BREAK_INTERVAL", 1000)
    
    BB_WINDOW_TITLE := IniRead(BB_CONFIG_FILE, "Window", "WINDOW_TITLE", "Roblox")
    BB_EXCLUDED_TITLES := StrSplit(IniRead(BB_CONFIG_FILE, "Window", "EXCLUDED_TITLES", "Roblox Account Manager"), ",")
    
    BB_ENABLE_GENERAL_ACTIONS := IniRead(BB_CONFIG_FILE, "Features", "ENABLE_GENERAL_ACTIONS", true)
    BB_ENABLED_FUNCTIONS := StrSplit(IniRead(BB_CONFIG_FILE, "Features", "ENABLED_FUNCTIONS", "autoHatch,autoRebirth,defeatBoss,breakChest"), ",")
    
    BB_TEMPLATE_FOLDER := A_ScriptDir "\templates"
    BB_updateTemplates()
    
    BB_PIXELSEARCH_COLOR := IniRead(BB_CONFIG_FILE, "PixelSearch", "PIXELSEARCH_COLOR", "0xFFFFFF")
    BB_PIXELSEARCH_VARIATION := IniRead(BB_CONFIG_FILE, "PixelSearch", "PIXELSEARCH_VARIATION", 10)
    
    areaStr := IniRead(BB_CONFIG_FILE, "PixelSearch", "PIXELSEARCH_AREA", "0,0,SCREEN_WIDTH,SCREEN_HEIGHT")
    areaStr := RegExReplace(areaStr, "\s*;.*$", "")  ; Remove comments
    areaStr := Trim(areaStr)  ; Remove whitespace
    areaStr := StrReplace(areaStr, "SCREEN_WIDTH", A_ScreenWidth)
    areaStr := StrReplace(areaStr, "SCREEN_HEIGHT", A_ScreenHeight)
    BB_area := StrSplit(areaStr, ",")
    BB_PIXELSEARCH_AREA := [Number(BB_area[1]), Number(BB_area[2]), Number(BB_area[3]), Number(BB_area[4])]
    
    BB_CAMERA_ADJUST_SPEED := IniRead(BB_CONFIG_FILE, "Camera", "CAMERA_ADJUST_SPEED", 10)
    
    BB_TEMPLATE_RETRIES := IniRead(BB_CONFIG_FILE, "Retries", "TEMPLATE_RETRIES", 3)
    BB_MAX_FAILED_INTERACTIONS := IniRead(BB_CONFIG_FILE, "Retries", "MAX_FAILED_INTERACTIONS", 5)
    
    BB_ENABLE_LOGGING := IniRead(BB_CONFIG_FILE, "Logging", "ENABLE_LOGGING", true)

	templateDependencies := Map(
		"autoHatch", ["hatch_button"],
		"autoRebirth", ["rebirth_ready"],
		"autoUpgrade", ["upgrade_button"],
		"autoConvert", ["convert_button"],
		"defeatBoss", ["raid_boss", "raid_boss_alt"],
		"breakChest", ["chest"],
		"navigateToBossRoom", ["boss_room_entrance"],
		"checkGameState", ["raid_boss", "raid_boss_alt", "quest_indicator"],
		"checkPlayerState", ["death_screen"]
	)

    functionsToDisable := []
    for func, templates in templateDependencies {
        for template in templates {
            templatePath := BB_TEMPLATE_FOLDER "\" BB_TEMPLATES[template]
            if !FileExist(templatePath) {
                if !functionsToDisable.Has(func) {
                    functionsToDisable.Push(func)
                }
                break
            }
        }
    }

    for func in functionsToDisable {
        i := 1
        while i <= BB_ENABLED_FUNCTIONS.Length {
            if BB_ENABLED_FUNCTIONS[i] = func {
                BB_ENABLED_FUNCTIONS.RemoveAt(i)
                BB_updateStatusAndLog("Disabled function '" func "' due to missing template(s)")
                break
            }
            i++
        }
        if func = "defeatBoss" {
            SetTimer BB_asyncBossFightLoop, 0
            BB_updateStatusAndLog("Disabled async boss fight loop due to missing templates")
        }
        if func = "breakChest" {
            SetTimer BB_asyncChestBreakLoop, 0
            BB_updateStatusAndLog("Disabled async chest break loop due to missing templates")
        }
    }

    if functionsToDisable.Has("checkPlayerState") {
        BB_checkPlayerState := (*) => true
		BB_ENABLE_DEATH_DETECTION := false
        BB_updateStatusAndLog("Player state checking disabled due to missing death_screen template")
    }
}

; ===================== TEMPLATE MANAGEMENT =====================

BB_updateTemplates() {
    global BB_TEMPLATES, BB_TEMPLATE_FOLDER
    BB_TEMPLATES["hatch_button"] := IniRead(BB_CONFIG_FILE, "Templates", "hatch_button", "hatch_button.png")
    BB_TEMPLATES["rebirth_button"] := IniRead(BB_CONFIG_FILE, "Templates", "rebirth_button", "rebirth_button.png")
    BB_TEMPLATES["rebirth_ready"] := IniRead(BB_CONFIG_FILE, "Templates", "rebirth_ready", "rebirth_ready.png")
    BB_TEMPLATES["upgrade_button"] := IniRead(BB_CONFIG_FILE, "Templates", "upgrade_button", "upgrade_button.png")
    BB_TEMPLATES["convert_button"] := IniRead(BB_CONFIG_FILE, "Templates", "convert_button", "convert_button.png")
    BB_TEMPLATES["raid_boss"] := IniRead(BB_CONFIG_FILE, "Templates", "raid_boss", "raid_boss.png")
    BB_TEMPLATES["raid_boss_alt"] := IniRead(BB_CONFIG_FILE, "Templates", "raid_boss_alt", "raid_boss_alt.png")
    BB_TEMPLATES["boss_room_entrance"] := IniRead(BB_CONFIG_FILE, "Templates", "boss_room_entrance", "boss_room_entrance.png")
    BB_TEMPLATES["chest"] := IniRead(BB_CONFIG_FILE, "Templates", "chest", "chest.png")
    BB_TEMPLATES["death_screen"] := IniRead(BB_CONFIG_FILE, "Templates", "death_screen", "death_screen.png")
    BB_TEMPLATES["quest_indicator"] := IniRead(BB_CONFIG_FILE, "Templates", "quest_indicator", "quest_indicator.png")
    
    Loop Files, BB_TEMPLATE_FOLDER "\*.png" {
        name := StrReplace(A_LoopFileName, ".png", "")
        if !BB_TEMPLATES.Has(name) {
            BB_TEMPLATES[name] := A_LoopFileName
            BB_updateStatusAndLog("Auto-detected new template: " A_LoopFileName)
        }
    }
}

; ===================== GUI SETUP =====================

BB_setupGUI() {
    global BB_myGUI, BB_ENABLED_FUNCTIONS, BB_functionStatus
    BB_myGUI := Gui("+AlwaysOnTop", "🐝 BeeBrained’s PS99 Clan Battle Macro 🐝")
    BB_myGUI.OnEvent("Close", BB_exitApp)  ; Bind "X" to exit
    BB_myGUI.Add("Text", "x10 y10 w380 h20", "🐝 Use " BB_START_KEY " to start, " BB_STOP_KEY " to stop, Esc to exit 🐝")
    BB_myGUI.Add("Text", "x10 y40 w380 h20", "Status: Idle").Name := "Status"
    BB_myGUI.Add("Text", "x10 y60 w380 h20", "Coords Captured: 0").Name := "Coords"
    BB_myGUI.Add("Text", "x10 y80 w380 h20", "PixelSearch: OFF").Name := "PixelSearchStatus"
    BB_myGUI.Add("Text", "x10 y100 w380 h20", "GameState Check: OFF").Name := "GameStateStatus"
    BB_myGUI.Add("Text", "x10 y120 w380 h20", "Active Windows: 0").Name := "WindowCount"
    BB_myGUI.Add("Button", "x10 y140 w120 h30", "Run Movement").OnEvent("Click", BB_runMovementPattern)
    BB_myGUI.Add("Button", "x140 y140 w120 h30", "Reload Config").OnEvent("Click", BB_loadConfigFromFile)
    BB_myGUI.Add("Button", "x270 y140 w120 h30", "Adjust Camera").OnEvent("Click", BB_setCameraTopDown)
    
    yPos := 180
    for func in BB_ENABLED_FUNCTIONS {
        BB_myGUI.Add("Checkbox", "x10 y" yPos " w120 h20 v" func " Checked1", func).OnEvent("Click", BB_toggleFunction)
        BB_myGUI.Add("Text", "x140 y" yPos " w20 h20 BackgroundGreen", "").Name := func "Status"
        BB_functionStatus[func] := "Idle"
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
        i := 1
        while i <= BB_ENABLED_FUNCTIONS.Length {
            if BB_ENABLED_FUNCTIONS[i] = funcName {
                BB_ENABLED_FUNCTIONS.RemoveAt(i)
                break
            }
            i++
        }
    }
}

; ===================== HOTKEYS =====================

Hotkey(BB_START_KEY, BB_startAutomation)
Hotkey(BB_STOP_KEY, BB_stopAutomation)
Hotkey(BB_PAUSE_KEY, BB_togglePause)
Hotkey(BB_CAPTURE_KEY, BB_captureCoords)
Hotkey(BB_INVENTORY_KEY, BB_toggleInventoryMode)
Hotkey(BB_PIXELSEARCH_KEY, BB_togglePixelSearchMode)
Hotkey(BB_CHECKSTATE_KEY, BB_toggleCheckStateMode)
Hotkey(BB_CAMERA_ADJUST_KEY, BB_setCameraTopDown)
Hotkey("Esc", BB_exitApp)

; ===================== CORE FUNCTIONS =====================

BB_startAutomation(*) {
    global BB_running, BB_paused
    if BB_running
        return
    BB_running := true
    BB_paused := false
    BB_updateStatus("Running - Anti-AFK Only")
    SetTimer BB_antiAFKLoop, BB_ANTI_AFK_INTERVAL
    SetTimer BB_reconnectCheckLoop, BB_RECONNECT_CHECK_INTERVAL  ; Keep window check
}

BB_stopAutomation(*) {
    global BB_running, BB_paused
    BB_running := false
    BB_paused := false
    SetTimer BB_automationLoop, 0
    SetTimer BB_asyncCollectLoop, 0
    SetTimer BB_asyncConvertLoop, 0
    SetTimer BB_antiAFKLoop, 0
    SetTimer BB_reconnectCheckLoop, 0
    SetTimer BB_asyncBossFightLoop, 0
    SetTimer BB_asyncChestBreakLoop, 0
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
    BB_myGUI["Coords"].Text := "Coords Captured: " BB_coords.Length
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
    BB_updateStatusAndLog(text, false)
    if IsObject(BB_myGUI) && BB_myGUI.HasProp("Status") {
        BB_myGUI["Status"].Text := "Status: " text
    }
}

BB_updateFunctionStatus(func, status) {
    global BB_myGUI, BB_functionStatus
    BB_functionStatus[func] := status
    color := (status = "Success" ? "Green" : status = "Failed" ? "Red" : "Yellow")
    if IsObject(BB_myGUI) && BB_myGUI.HasProp(func "Status") {
        BB_myGUI[func "Status"].Opt("Background" color)
    }
}

BB_updateActiveWindows() {
    global BB_active_windows, BB_last_window_check, BB_WINDOW_TITLE, BB_EXCLUDED_TITLES, BB_myGUI
    currentTime := A_TickCount
    if (currentTime - BB_last_window_check < 5000) {
        return BB_active_windows
    }
    
    BB_active_windows := []
    for hwnd in WinGetList() {
        title := WinGetTitle(hwnd)
        if (InStr(title, BB_WINDOW_TITLE) && !BB_hasExcludedTitle(title) && WinGetProcessName(hwnd) = "RobloxPlayerBeta.exe") {
            BB_active_windows.Push(hwnd)
        }
    }
    if IsObject(BB_myGUI) && BB_myGUI.HasProp("WindowCount") {
        BB_myGUI["WindowCount"].Text := "Active Windows: " BB_active_windows.Length
    }
    BB_last_window_check := currentTime
    return BB_active_windows
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
    if (WinWaitActive(hwnd, , 2) = 0) {
        BB_updateStatusAndLog("Failed to bring Roblox window to front: " hwnd)
        return false
    }
    return true
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
    hwnd := WinGetID("A")
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("No Roblox window active for clicking at x=" x ", y=" y)
        return false
    }
    WinGetPos(&winX, &winY, &winW, &winH, hwnd)
    if (x < winX || x > (winX + winW) || y < winY || y > (winY + winH)) {
        BB_updateStatusAndLog("Click coordinates x=" x ", y=" y " are outside Roblox window")
        return false
    }
    delay := Random(BB_CLICK_DELAY_MIN, BB_CLICK_DELAY_MAX)
    MouseMove x, y, 10
    Sleep delay
    Click
    return true
}

BB_inventoryClick() {
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
    global BB_PIXELSEARCH_COLOR, BB_PIXELSEARCH_VARIATION
    ; Get the active window (should be Roblox after BB_bringToFront)
    hwnd := WinGetID("A")
    if (!hwnd) {
        BB_updateStatusAndLog("No active window found for PixelSearch")
        return false
    }
    ; Get the window's position and size
    WinGetPos(&winX, &winY, &winW, &winH, hwnd)
    ; Define the search area as the window's boundaries
    searchArea := [winX, winY, winX + winW, winY + winH]
    PixelSearch &FoundX, &FoundY, searchArea[1], searchArea[2], searchArea[3], searchArea[4], BB_PIXELSEARCH_COLOR, BB_PIXELSEARCH_VARIATION
    if (FoundX = "" || FoundY = "") {
        BB_updateStatusAndLog("PixelSearch failed for color " BB_PIXELSEARCH_COLOR " in window area x=" searchArea[1] ", y=" searchArea[2] " to x=" searchArea[3] ", y=" searchArea[4])
        return false
    }
    return true
}

BB_templateMatch(templateName, &FoundX, &FoundY, altTemplate := "") {
    global BB_TEMPLATE_FOLDER, BB_TEMPLATES, BB_TEMPLATE_RETRIES, BB_missingTemplatesReported
    templates := [templateName]
    if (altTemplate != "") {
        templates.Push(altTemplate)
    }
    
    templateFound := false
    for template in templates {
        templatePath := BB_TEMPLATE_FOLDER "\" BB_TEMPLATES[template]
        if !FileExist(templatePath) {
            if !BB_missingTemplatesReported.Has(template) {
                BB_updateStatusAndLog("Template not found: " templatePath)
                BB_missingTemplatesReported[template] := true
            }
            continue
        }
        templateFound := true
        
        retryCount := 0
        while (retryCount < BB_TEMPLATE_RETRIES) {
            try {
                BB_updateFunctionStatus(templateName, "Retrying")
                ImageSearch(&FoundX, &FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, "*10 " templatePath)
                if (FoundX >= 0 && FoundX <= A_ScreenWidth && FoundY >= 0 && FoundY <= A_ScreenHeight) {
                    BB_updateStatusAndLog("Template match succeeded for: " template " at x=" FoundX ", y=" FoundY)
                    return true
                }
            } catch {
                BB_updateStatusAndLog("Template match failed for: " template " (attempt " retryCount + 1 ")")
            }
            retryCount++
            Sleep 500
        }
    }
    if (templateFound) {
        BB_updateStatusAndLog("All template matches failed for: " templateName)
    }
    return false
}

BB_setCameraTopDown(*) {
    global BB_camera_adjusted_windows, BB_CAMERA_ADJUST_SPEED, BB_WINDOW_TITLE
    windows := BB_updateActiveWindows()
    if (windows.Length = 0) {
        BB_updateStatusAndLog("No Roblox windows found for camera adjustment. Ensure Roblox is running.")
        return
    }
    
    for hwnd in windows {
        ; Ensure focus
        focusAttempts := 0
        maxAttempts := 3
        while (focusAttempts < maxAttempts) {
            if BB_bringToFront(hwnd) {
                Sleep 500  ; Give Roblox time to fully activate
                if (InStr(WinGetTitle("A"), BB_WINDOW_TITLE) && WinGetProcessName("A") = "RobloxPlayerBeta.exe") {
                    break
                }
                BB_updateStatusAndLog("Roblox window " hwnd " lost focus after activation, retrying (" focusAttempts + 1 "/" maxAttempts ")")
            }
            focusAttempts++
            Sleep 500
        }
        
        if (focusAttempts >= maxAttempts) {
            BB_updateStatusAndLog("Failed to reliably activate Roblox window " hwnd " after " maxAttempts " attempts, skipping")
            continue
        }
        
        ; Get window position and size
        WinGetPos(&winX, &winY, &winW, &winH, hwnd)
        startX := winX + winW / 2
        startY := winY + winH / 2
        targetY := winY + winH - 50  ; Downward drag for top-down
        
        ; Log initial intent
        BB_updateStatusAndLog("Adjusting camera for window " hwnd " at x=" startX ", y=" startY " to y=" targetY " (window: x=" winX ", y=" winY ", w=" winW ", h=" winH ")")
        
        ; Use window-relative coordinates
        CoordMode "Mouse", "Window"
        
        ; Move to starting position
        relStartX := startX - winX
        relStartY := startY - winY
        relTargetY := targetY - winY
        MouseMove relStartX, relStartY, 0
        Sleep 500  ; Ensure Roblox registers the position
        
        ; Wake-up click
        Click "Left"
        Sleep 500
        
        ; Start drag
        Click "Down Right"
        Sleep 200  ; Hold before moving
        if (WinGetID("A") != hwnd) {
            BB_updateStatusAndLog("Focus lost after right-click down in window " hwnd ", aborting")
            Click "Up Right"
            continue
        }
        
        ; Perform drag downward
        MouseMove relStartX, relTargetY, 5  ; Slow drag
        Sleep 1000  ; Hold drag for 1 second to mimic manual timing
        MouseGetPos(&midX, &midY)
        BB_updateStatusAndLog("Mid-drag position for window " hwnd ": x=" midX ", y=" midY)
        
        ; Release
        Click "Up Right"
        Sleep 200
        
        ; Log final position
        MouseGetPos(&endX, &endY)
        BB_updateStatusAndLog("Camera adjusted to top-down view for window " hwnd " (final mouse pos: x=" endX ", y=" endY ")")
        BB_camera_adjusted_windows[hwnd] := true
    }
    CoordMode "Mouse", "Screen"  ; Reset to default
}

BB_navigateToBossRoom() {
    FoundX := 0, FoundY := 0
    searchAttempts := 0
    maxSearchAttempts := 3
    
    while (searchAttempts < maxSearchAttempts) {
        if BB_templateMatch("boss_room_entrance", &FoundX, &FoundY) {
            BB_clickAt(FoundX, FoundY)
            BB_updateStatusAndLog("Navigated to boss room entrance at x=" FoundX ", y=" FoundY)
            Sleep 2000
            
            startPosX := 0, startPosY := 0
            MouseGetPos(&startPosX, &startPosY)
            for seq in BB_MOVEMENT_PATTERNS["to_boss"] {
                BB_pressKey(seq[1], seq[2], seq[3])
                Sleep 500
                if BB_pixelSearchColor(&FoundX, &FoundY) {
                    BB_updateStatusAndLog("Detected progress marker at x=" FoundX ", y=" FoundY)
                    break
                }
            }
            endPosX := 0, endPosY := 0
            MouseGetPos(&endPosX, &endPosY)
            distance := Sqrt((endPosX - startPosX) ** 2 + (endPosY - startPosY) ** 2)
            BB_updateStatusAndLog("Moved distance: " distance)
            if (distance < 10) {
                BB_updateStatusAndLog("Failed to move significantly, possible navigation issue")
                return false
            }
            return true
        } else {
            BB_updateStatusAndLog("Boss room entrance not found, searching (attempt " searchAttempts + 1 ")")
            for seq in BB_MOVEMENT_PATTERNS["search"] {
                BB_pressKey(seq[1], seq[2], seq[3])
            }
            searchAttempts++
            Sleep 1000
        }
    }
    BB_updateStatusAndLog("Failed to find boss room entrance after " maxSearchAttempts " attempts")
    return false
}

BB_defeatBoss() {
    global BB_FAILED_INTERACTION_COUNT, BB_MAX_FAILED_INTERACTIONS
    FoundX := 0, FoundY := 0
    if BB_templateMatch("raid_boss", &FoundX, &FoundY, "raid_boss_alt") {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Attacking boss at x=" FoundX ", y=" FoundY)
        Sleep 1000
        
        if !BB_templateMatch("raid_boss", &FoundX, &FoundY, "raid_boss_alt") {
            BB_updateStatusAndLog("Boss defeated")
            BB_updateFunctionStatus("defeatBoss", "Success")
            return "defeated"
        }
        BB_FAILED_INTERACTION_COUNT := 0
        BB_updateFunctionStatus("defeatBoss", "Success")
        return "attacking"
    } else {
        BB_updateStatusAndLog("Failed to detect raid boss")
        BB_FAILED_INTERACTION_COUNT++
        if (BB_FAILED_INTERACTION_COUNT >= BB_MAX_FAILED_INTERACTIONS) {
            BB_updateStatusAndLog("Too many failed interactions, resetting camera")
            BB_resetCameraAdjustment()
            BB_FAILED_INTERACTION_COUNT := 0
        }
        BB_updateFunctionStatus("defeatBoss", "Failed")
        return "not_found"
    }
}

BB_breakChest() {
    global BB_FAILED_INTERACTION_COUNT, BB_MAX_FAILED_INTERACTIONS
    FoundX := 0, FoundY := 0
    if BB_templateMatch("chest", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Breaking chest at x=" FoundX ", y=" FoundY)
        Sleep 1000
        BB_FAILED_INTERACTION_COUNT := 0
        BB_updateFunctionStatus("breakChest", "Success")
        return true
    } else {
        BB_updateStatusAndLog("Failed to detect chest")
        BB_FAILED_INTERACTION_COUNT++
        if (BB_FAILED_INTERACTION_COUNT >= BB_MAX_FAILED_INTERACTIONS) {
            BB_updateStatusAndLog("Too many failed interactions, resetting camera")
            BB_resetCameraAdjustment()
            BB_FAILED_INTERACTION_COUNT := 0
        }
        BB_updateFunctionStatus("breakChest", "Failed")
        return false
    }
}

BB_checkPlayerState() {
    global BB_ENABLE_DEATH_DETECTION, BB_DEATH_RECOVERY_DELAY
    if (!BB_ENABLE_DEATH_DETECTION) {
        return true
    }
    FoundX := 0, FoundY := 0
    if BB_templateMatch("death_screen", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Player died, respawning at x=" FoundX ", y=" FoundY)
        Sleep BB_DEATH_RECOVERY_DELAY
        BB_resetCameraAdjustment()
        return false
    }
    return true
}

BB_resetCameraAdjustment() {
    global BB_camera_adjusted_windows
    for hwnd in BB_camera_adjusted_windows {
        BB_camera_adjusted_windows[hwnd] := false
    }
    BB_updateStatusAndLog("Camera adjustment reset")
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
    global BB_FAILED_INTERACTION_COUNT, BB_MAX_FAILED_INTERACTIONS
    FoundX := 0, FoundY := 0
    if BB_templateMatch("hatch_button", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Hatched egg at x=" FoundX ", y=" FoundY)
        BB_FAILED_INTERACTION_COUNT := 0
        BB_updateFunctionStatus("autoHatch", "Success")
    } else {
        BB_updateStatusAndLog("BB_autoHatch failed to detect hatch_button")
        BB_FAILED_INTERACTION_COUNT++
        if (BB_FAILED_INTERACTION_COUNT >= BB_MAX_FAILED_INTERACTIONS) {
            BB_updateStatusAndLog("Too many failed interactions, resetting camera")
            BB_resetCameraAdjustment()
            BB_FAILED_INTERACTION_COUNT := 0
        }
        BB_updateFunctionStatus("autoHatch", "Failed")
    }
}

BB_autoRebirth() {
    global BB_FAILED_INTERACTION_COUNT, BB_MAX_FAILED_INTERACTIONS
    FoundX := 0, FoundY := 0
    if BB_templateMatch("rebirth_ready", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Rebirthed at x=" FoundX ", y=" FoundY)
        BB_FAILED_INTERACTION_COUNT := 0
        BB_updateFunctionStatus("autoRebirth", "Success")
    } else {
        BB_updateStatusAndLog("BB_autoRebirth failed to detect rebirth_ready")
        BB_FAILED_INTERACTION_COUNT++
        if (BB_FAILED_INTERACTION_COUNT >= BB_MAX_FAILED_INTERACTIONS) {
            BB_updateStatusAndLog("Too many failed interactions, resetting camera")
            BB_resetCameraAdjustment()
            BB_FAILED_INTERACTION_COUNT := 0
        }
        BB_updateFunctionStatus("autoRebirth", "Failed")
    }
}

BB_autoUpgrade() {
    global BB_FAILED_INTERACTION_COUNT, BB_MAX_FAILED_INTERACTIONS
    FoundX := 0, FoundY := 0
    if BB_templateMatch("upgrade_button", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Upgraded at x=" FoundX ", y=" FoundY)
        BB_FAILED_INTERACTION_COUNT := 0
        BB_updateFunctionStatus("autoUpgrade", "Success")
    } else {
        BB_updateStatusAndLog("BB_autoUpgrade failed to detect upgrade_button")
        BB_FAILED_INTERACTION_COUNT++
        if (BB_FAILED_INTERACTION_COUNT >= BB_MAX_FAILED_INTERACTIONS) {
            BB_updateStatusAndLog("Too many failed interactions, resetting camera")
            BB_resetCameraAdjustment()
            BB_FAILED_INTERACTION_COUNT := 0
        }
        BB_updateFunctionStatus("autoUpgrade", "Failed")
    }
}

BB_autoCollect() {
    FoundX := 0, FoundY := 0
    if BB_pixelSearchColor(&FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Collected item at x=" FoundX ", y=" FoundY)
        BB_updateFunctionStatus("autoCollect", "Success")
    } else {
        BB_updateFunctionStatus("autoCollect", "Failed")
    }
}

BB_autoConvert() {
    FoundX := 0, FoundY := 0
    if BB_templateMatch("convert_button", &FoundX, &FoundY) {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Converted resource at x=" FoundX ", y=" FoundY)
        BB_updateFunctionStatus("autoConvert", "Success")
    } else {
        BB_updateStatusAndLog("BB_autoConvert failed to detect convert_button")
        BB_updateFunctionStatus("autoConvert", "Failed")
    }
}

BB_checkGameState() {
    FoundX := 0, FoundY := 0
    if BB_pixelSearchColor(&FoundX, &FoundY) {
        BB_updateStatusAndLog("Game state: Resource detected at x=" FoundX ", y=" FoundY)
        BB_autoCollect()
    }
    ; Check if "defeatBoss" is in BB_ENABLED_FUNCTIONS
    for func in BB_ENABLED_FUNCTIONS {
        if (func = "defeatBoss") {
            if BB_templateMatch("raid_boss", &FoundX, &FoundY, "raid_boss_alt") {
                BB_updateStatusAndLog("Game state: In boss room")
                return "in_boss_room"
            }
            break  ; Exit loop once checked
        }
    }
    ; Check if "breakChest" is in BB_ENABLED_FUNCTIONS
    for func in BB_ENABLED_FUNCTIONS {
        if (func = "breakChest") {
            if BB_templateMatch("quest_indicator", &FoundX, &FoundY) {
                BB_updateStatusAndLog("Game state: Quest indicator detected at x=" FoundX ", y=" FoundY)
                return "in_quest_area"
            }
            break  ; Exit loop once checked
        }
    }
    return "unknown"
}

BB_antiAFKLoop() {
    global BB_running, BB_paused, BB_isActivelyProcessing
    if (!BB_running || BB_paused || BB_isActivelyProcessing)
        return
    BB_pressKey("space", 100, 1)
    Sleep Random(500, 1000)  ; Random delay between keys
    BB_pressKey("r", 100, 1)
    BB_updateStatusAndLog("Anti-AFK: Pressed space and r to prevent kick")
}

BB_reconnectCheckLoop() {
    global BB_running, BB_paused, BB_isActivelyProcessing, BB_RECONNECT_CHECK_INTERVAL
    if (!BB_running || BB_paused || BB_isActivelyProcessing)
        return
    windows := BB_updateActiveWindows()
    if (windows.Length = 0) {
        BB_updateStatus("No Roblox windows found, waiting for reconnect")
        BB_updateStatusAndLog("No Roblox windows found, waiting for reconnect")
        Sleep 5000
        if BB_running
            SetTimer BB_reconnectCheckLoop, 2000
    } else {
        if BB_running
            SetTimer BB_reconnectCheckLoop, BB_RECONNECT_CHECK_INTERVAL
    }
}

BB_asyncCollectLoop() {
    global BB_running, BB_paused, BB_inventory_mode, BB_isActivelyProcessing
    if (!BB_running || BB_paused || BB_inventory_mode || !BB_checkPlayerState() || BB_isActivelyProcessing)
        return
    windows := BB_updateActiveWindows()
    for hwnd in windows {
        if BB_bringToFront(hwnd) {
            BB_autoCollect()
        }
    }
}

BB_asyncConvertLoop() {
    global BB_running, BB_paused, BB_inventory_mode, BB_isActivelyProcessing, BB_ENABLED_FUNCTIONS
    if (!BB_running || BB_paused || BB_inventory_mode || !BB_checkPlayerState() || BB_isActivelyProcessing || !BB_ENABLED_FUNCTIONS.Contains("autoConvert"))
        return
    windows := BB_updateActiveWindows()
    for hwnd in windows {
        if BB_bringToFront(hwnd) {
            BB_autoConvert()
        }
    }
}

BB_asyncBossFightLoop() {
    global BB_running, BB_paused, BB_bossFightActive, BB_inventory_mode, BB_isActivelyProcessing
    if (!BB_running || BB_paused || BB_inventory_mode || !BB_checkPlayerState() || BB_bossFightActive || BB_isActivelyProcessing)
        return
    BB_bossFightActive := true
    windows := BB_updateActiveWindows()
    for hwnd in windows {
        if BB_bringToFront(hwnd) {
            state := BB_checkGameState()
            if (state = "in_boss_room") {
                result := BB_defeatBoss()
                if (result = "defeated") {
                    BB_updateStatusAndLog("Boss defeated in async loop")
                    BB_bossFightActive := false
                    return
                }
            }
        }
    }
    BB_bossFightActive := false
    if BB_running
        SetTimer BB_asyncBossFightLoop, BB_BOSS_FIGHT_INTERVAL
}

BB_asyncChestBreakLoop() {
    global BB_running, BB_paused, BB_chestBreakActive, BB_inventory_mode, BB_isActivelyProcessing
    if (!BB_running || BB_paused || BB_inventory_mode || !BB_checkPlayerState() || BB_chestBreakActive || BB_isActivelyProcessing)
        return
    BB_chestBreakActive := true
    windows := BB_updateActiveWindows()
    for hwnd in windows {
        if BB_bringToFront(hwnd) {
            state := BB_checkGameState()
            if (state = "in_quest_area" || state = "unknown") {
                BB_breakChest()
            }
        }
    }
    BB_chestBreakActive := false
    if BB_running
        SetTimer BB_asyncChestBreakLoop, BB_CHEST_BREAK_INTERVAL
}

BB_automationLoop() {
    global BB_running, BB_paused, BB_inventory_mode, BB_pixelsearch_mode, BB_checkstate_mode
    global BB_KEY_SEQUENCE, BB_coords, BB_ENABLED_FUNCTIONS, BB_INTERACTION_DURATION, BB_ENABLE_GENERAL_ACTIONS, BB_isActivelyProcessing
    if (!BB_running || BB_paused)
        return

    windows := BB_updateActiveWindows()
    if (windows.Length = 0) {
        BB_updateStatus("No Roblox windows found")
        BB_isActivelyProcessing := false
        Sleep 10000
        return
    }

    BB_updateStatus("Running (" windows.Length " windows)")
    BB_isActivelyProcessing := true
    for hwnd in windows {
        if (!BB_running || BB_paused)
            break
        if BB_bringToFront(hwnd) {
            if (!BB_camera_adjusted_windows.Has(hwnd) || !BB_camera_adjusted_windows[hwnd]) {
                BB_setCameraTopDown()
            }
            
            if (!BB_checkPlayerState()) {
                continue
            }
            
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
                state := BB_checkGameState()
                for func in BB_ENABLED_FUNCTIONS {
                    if func = "autoHatch" && (state = "in_quest_area" || state = "unknown")
                        BB_autoHatch()
                    else if func = "autoRebirth" && (state = "in_quest_area" || state = "unknown")
                        BB_autoRebirth()
                    else if func = "autoUpgrade" && (state = "in_quest_area" || state = "unknown")
                        BB_autoUpgrade()
                    else if func = "defeatBoss" {
                        if (state != "in_boss_room") {
                            BB_navigateToBossRoom()
                        }
                    }
                    else if func = "breakChest" && (state = "in_quest_area" || state = "unknown") {
                    }
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
    BB_isActivelyProcessing := false
    BB_updateStatus("Waiting (" BB_CYCLE_INTERVAL // 1000 "s)")
    Sleep BB_CYCLE_INTERVAL
}

BB_loadConfigFromFile(*) {
    BB_loadConfig()
    MsgBox "Configuration reloaded from " BB_CONFIG_FILE
}

BB_exitApp(*) {
    global BB_running
    BB_running := false  ; Stop all timers
    SetTimer BB_antiAFKLoop, 0
    SetTimer BB_reconnectCheckLoop, 0
    SetTimer BB_automationLoop, 0
    SetTimer BB_asyncCollectLoop, 0
    SetTimer BB_asyncConvertLoop, 0
    SetTimer BB_asyncBossFightLoop, 0
    SetTimer BB_asyncChestBreakLoop, 0
    BB_updateStatusAndLog("Script terminated")
    ExitApp()  ; Fully exit the application
}

; ===================== INITIALIZATION =====================

BB_setupGUI()
BB_loadConfig()
TrayTip "Ready! Press " BB_START_KEY " to start.", "🐝 BeeBrained's PS99 Template", 0x10
