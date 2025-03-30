#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut
; 🐝 BeeBrained's PS99 Mining Event Automation 🐝
; Last Updated: March 29th, 2025
;
; == Main Hotkeys ==
; F1: Start automation
; F2: Stop automation
; P: Pause/Resume automation
; F3: Toggle explosives on/off
; Escape: Exit application
; 
; Explosive Hotkeys (can be customized in config):
; CTRL+B: Use bomb
; CTRL+T: Use TNT crate
; CTRL+N: Use TNT bundle
;
; == Testing Instructions ==
; 1. Ensure Roblox and Pet Simulator 99 are installed and running.
; 2. Place the script in a folder with write permissions (e.g., C:\Apps\BMATMiner).
; 3. Run the script as administrator to ensure proper window activation.
; 4. The script auto-starts, assuming you're in Area 5 with automining active. Use F2 to stop, P to pause/resume, F3 to toggle explosives, and Esc to exit.
; 5. Monitor the GUI and log file (mining_log.txt) for errors.
; 6. If templates fail to validate, ensure an internet connection and check the GitHub repository for the latest template files.
;
; == Debug Mode ==
; Run with "debug" parameter to enable debug mode: .\BMATMiner.ahk debug
; Debug Mode Hotkeys:
; F6: Capture screenshot of current window
; F7: Test hatch menu detection
; F8: Test automine status
; F9: Display current automation status
; F10: Show performance metrics
; F11: Cycle through debug levels (1-5)
; F12: Toggle debug mode on/off
;
; == Included Utility Scripts ==
; - CreateSimpleTemplates.ahk: Creates transparent versions of templates for better detection
; - TestHatchMenuDetection.ahk: Tests the hatch menu detection feature
; - RunHatchTest.bat: Batch file to run the hatch detection test
;
; See BMATMiner_FunctionReference.md for detailed documentation of all functions.
; See ImageDetection_README.md for information about image detection improvements.
;
; == Known Issues ==
; - Template matching may fail if game resolution or UI scaling changes. Adjust templates or confidence levels in BB_smartTemplateMatch if needed.
; - Window activation may fail on some systems. Ensure Roblox is not minimized and run as admin.
; - Assumes default Roblox hotkeys ('f' to open inventory). Update config if different.
; - Reconnect in BB_resetGameState may need manual intervention if Roblox URL launches aren't set up.
; - Screenshot functionality is disabled (placeholder in BB_updateStatusAndLog).
; - Automine detection uses movement validation and template matching with fallback to safer click positions.
; - Window focus can be lost when clicking near top of window - script now uses safer click positions.
; - Errors or GUIs are cleared by pressing 'F' (which also opens the inventory if you're not already in it).

; ===================== Run as Admin =====================

if !A_IsAdmin {
    Run("*RunAs " . A_ScriptFullPath)
    ExitApp()
}

; Initialize BB_DEBUG early before it's used in any functions
global BB_DEBUG := Map(
    "enabled", false,
    "level", 3,
    "stateTracking", true,
    "saveErrorState", true,
    "logConsole", true,
    "logToFile", true,
    "screenshot", true,
    "screenshotFormat", "png",
    "visualOverlay", false,
    "overlayDuration", 2000,
    "performanceTracking", true
)

; ===================== GLOBAL VARIABLES =====================
; Version and Core State
global BB_VERSION := "3.1.1"
global BB_running := false
global BB_paused := false
global BB_SAFE_MODE := false
global BB_ENABLE_LOGGING := true
global BB_FAILED_INTERACTION_COUNT := 0  ; Tracks failed interactions for error recovery
global BB_logFile := A_ScriptDir "\mining_log.txt"

; Hotkeys
global BB_BOMB_HOTKEY := "^b"           ; CTRL+B
global BB_TNT_CRATE_HOTKEY := "^t"      ; CTRL+T
global BB_TNT_BUNDLE_HOTKEY := "^n"     ; CTRL+N
global BB_TELEPORT_HOTKEY := "t"
global BB_INVENTORY_HOTKEY := "f"
global BB_START_STOP_HOTKEY := "F2"
global BB_PAUSE_HOTKEY := "p"
global BB_EXPLOSIVES_TOGGLE_HOTKEY := "F3"
global BB_EXIT_HOTKEY := "Escape"

; Initialize GUI first
BB_setupGUI()  ; Init the GUI

; Other init
BB_loadConfig() ; Load the config

; Register hotkeys based on config
BB_registerHotkeys()

TrayTip("Initialized! Press " . BB_START_STOP_HOTKEY . " to start.", "🐝 BeeBrained's PS99 Mining Event Macro", 0x10)

; State Timeouts
global BB_STATE_TIMEOUTS := Map(
    "DisableAutomine", 30000,    ; 30 seconds
    "TeleportToArea4", 30000,    ; 30 seconds
    "WalkToMerchant", 60000,     ; 60 seconds
    "Shopping", 60000,           ; 60 seconds
    "TeleportToArea5", 30000,    ; 30 seconds
    "EnableAutomine", 30000,     ; 30 seconds
    "Mining", 180000,            ; 3 minutes
    "Error", 30000               ; 30 seconds
)
global BB_stateStartTime := 0
global BB_currentStateTimeout := 0

; Resolution Scaling
global BB_BASE_WIDTH := 1920
global BB_BASE_HEIGHT := 1080
global BB_SCALE_X := 1.0
global BB_SCALE_Y := 1.0
global BB_SCREEN_WIDTH := A_ScreenWidth
global BB_SCREEN_HEIGHT := A_ScreenHeight

; Calculate scaling factors
BB_SCALE_X := BB_SCREEN_WIDTH / BB_BASE_WIDTH
BB_SCALE_Y := BB_SCREEN_HEIGHT / BB_BASE_HEIGHT
BB_updateStatusAndLog("Resolution scaling: " . Round(BB_SCALE_X, 2) . "x" . Round(BB_SCALE_Y, 2))

; State Management
global BB_automationState := "Idle"
global BB_stateHistory := []
global BB_gameStateEnsured := false
global BB_lastGameStateReset := 0
global BB_GAME_STATE_COOLDOWN := 30000  ; 30 seconds cooldown

; Timing and Intervals
global BB_CLICK_DELAY_MIN := 500        ; 0.5 seconds
global BB_CLICK_DELAY_MAX := 1500       ; 1.5 seconds
global BB_INTERACTION_DURATION := 5000   ; 5 seconds
global BB_CYCLE_INTERVAL := 180000      ; 3 minutes
global BB_ANTI_AFK_INTERVAL := 300000   ; 5 minutes
global BB_RECONNECT_CHECK_INTERVAL := 10000  ; 10 seconds

; Explosive Management
global BB_ENABLE_EXPLOSIVES := false
global BB_BOMB_INTERVAL := 10000        ; 10 seconds
global BB_TNT_CRATE_INTERVAL := 30000   ; 30 seconds
global BB_TNT_BUNDLE_INTERVAL := 15000  ; 15 seconds
global BB_lastBombStatus := "Idle"
global BB_lastTntCrateStatus := "Idle"
global BB_lastTntBundleStatus := "Idle"

; File System and Logging
global BB_TEMPLATE_FOLDER := A_ScriptDir "\mining_templates"
global BB_BACKUP_TEMPLATE_FOLDER := A_ScriptDir "\backup_templates"

; Window Management
global BB_WINDOW_TITLE := "Roblox"
global BB_EXCLUDED_TITLES := []
global BB_active_windows := []
global BB_last_window_check := 0
global BB_WINDOW_CHECK_INTERVAL := 5000  ; 5 seconds

; Template Management
global BB_TEMPLATES := Map()
global BB_missingTemplatesReported := Map()
global BB_TEMPLATE_RETRIES := 3
global BB_validTemplates := 0
global BB_totalTemplates := 0
global BB_imageCache := Map()

; Game State and Error Handling
global BB_MAX_FAILED_INTERACTIONS := 5
global BB_MAX_BUY_ATTEMPTS := 6
global BB_isAutofarming := false
global BB_currentArea := "Unknown"
global BB_merchantState := "Not Interacted"
global BB_lastError := "None"

; Performance Monitoring
global BB_performanceData := Map(
    "ClickAt", 0,
    "TemplateMatch", Map(),
    "MerchantInteract", 0,
    "MovementCheck", 0,
    "BlockDetection", 0,
    "StateTransition", 0
)

; Template Success Metrics - Used to determine which templates are critical
; Higher values (>0.7) indicate critical templates that warrant extra matching attempts
global BB_TEMPLATE_SUCCESS_METRIC := Map(
    "automine_button", 0.9,
    "buy_button", 0.8,
    "autofarm_on", 0.9,
    "autofarm_off", 0.9,
    "go_to_top_button", 0.8,
    "area_4_button", 0.8,
    "area_5_button", 0.8,
    "mining_merchant", 0.8,
    "error_message", 0.75,
    "teleport_button", 0.8
)

; ===================== DEFAULT CONFIGURATION =====================

defaultIni := "
(
[Timing]
INTERACTION_DURATION=5000
CYCLE_INTERVAL=180000
CLICK_DELAY_MIN=500
CLICK_DELAY_MAX=1500
ANTI_AFK_INTERVAL=300000
RECONNECT_CHECK_INTERVAL=10000
BOMB_INTERVAL=10000
TNT_CRATE_INTERVAL=30000
TNT_BUNDLE_INTERVAL=15000

[Window]
WINDOW_TITLE=Pet Simulator 99
EXCLUDED_TITLES=Roblox Account Manager

[Features]
ENABLE_EXPLOSIVES=false
SAFE_MODE=false

[Templates]
automine_button=automine_button.png
teleport_button=teleport_button.png
area_4_button=area_4_button.png
area_5_button=area_5_button.png
mining_merchant=mining_merchant.png
buy_button=buy_button.png
merchant_window=merchant_window.png
autofarm_on=autofarm_on.png
autofarm_off=autofarm_off.png
error_message=error_message.png
error_message_alt1=error_message_alt1.png
connection_lost=connection_lost.png
emerald_block=emerald_block.png
go_to_top_button=go_to_top_button.png

[Hotkeys]
; Modified hotkey format: Use ^ for CTRL, ! for ALT, + for SHIFT, # for WIN
; Single letters/keys don't need special formatting (e.g., t, f, p, etc.)
BOMB_HOTKEY=^b
TNT_CRATE_HOTKEY=^t
TNT_BUNDLE_HOTKEY=^n
TELEPORT_HOTKEY=t
INVENTORY_HOTKEY=f
START_STOP_HOTKEY=F2
PAUSE_HOTKEY=p
EXPLOSIVES_TOGGLE_HOTKEY=F3
EXIT_HOTKEY=Escape
JUMP_HOTKEY=Space

[Colors]
; Color format: 0xRRGGBB (hex)
ERROR_RED_1=0xFF0000
ERROR_RED_2=0xE31212
ERROR_RED_3=0xC10000
STATUS_GREEN=0x00FF00
STATUS_RED=0xFF0000
; Area 4 color ranges (min,max) for different material types
AREA4_EARTH_TONES_MIN=0x5A3A14
AREA4_EARTH_TONES_MAX=0x7A501A
AREA4_GOLDEN_AMBER_MIN=0x856E2B
AREA4_GOLDEN_AMBER_MAX=0x9D8638
AREA4_WOOD_DARK_MIN=0x4A3210
AREA4_WOOD_DARK_MAX=0x634523
AREA4_WOOD_MEDIUM_MIN=0x8B7355
AREA4_WOOD_MEDIUM_MAX=0xA0876B
AREA4_WOOD_LIGHT_MIN=0xB39169
AREA4_WOOD_LIGHT_MAX=0xCCA77F
AREA4_BROWN_MEDIUM_MIN=0x5D4B35
AREA4_BROWN_MEDIUM_MAX=0x74614A
; Pickaxe detection colors
PICKAXE_BROWN_1=0x5A3A14
PICKAXE_BROWN_2=0x6B4618
PICKAXE_BROWN_3=0x7A501A

[Thresholds]
; Various threshold values used in color matching and detection
COLOR_MATCH_THRESHOLD=70
COLOR_CLUSTER_THRESHOLD=50
ERROR_COLOR_THRESHOLD=50
MOVEMENT_THRESHOLD=2
BRIGHTNESS_DARK_THRESHOLD=80
BRIGHTNESS_BRIGHT_THRESHOLD=140
PATTERN_MATCH_CONFIDENCE=40
AREA_VERIFY_CONFIDENCE=50

[Retries]
TEMPLATE_RETRIES=3
MAX_FAILED_INTERACTIONS=5
MAX_BUY_ATTEMPTS=6

[Logging]
ENABLE_LOGGING=true
)"

; ===================== UTILITY FUNCTIONS =====================

BB_setState(newState) {
    global BB_automationState, BB_stateHistory, BB_FAILED_INTERACTION_COUNT
    global BB_STATE_TIMEOUTS, BB_stateStartTime, BB_currentStateTimeout
    global BB_ERROR_RETRY_ATTEMPTS
    
    BB_stateHistory.Push({state: BB_automationState, time: A_Now})
    if (BB_stateHistory.Length > 10)
        BB_stateHistory.RemoveAt(1)
    
    ; Set timeout for new state
    BB_stateStartTime := A_TickCount
    BB_currentStateTimeout := BB_STATE_TIMEOUTS.Has(newState) ? BB_STATE_TIMEOUTS[newState] : 30000
    
    BB_automationState := newState
    ; Reset failed interaction count and error retry attempts on successful state transition (unless transitioning to Error)
    if (newState != "Error") {
        BB_FAILED_INTERACTION_COUNT := 0
        BB_ERROR_RETRY_ATTEMPTS := 0
        BB_updateStatusAndLog("Reset failed interaction count and retry attempts on successful state transition")
    }
    BB_updateStatusAndLog("State changed: " . newState . " (Timeout: " . BB_currentStateTimeout . "ms)")
}

; Opens the inventory.
; Parameters:
;   hwnd: The handle of the Roblox window to check for movement.
; Returns: True if the inventory was opened, False otherwise.
BB_openInventory(hwnd := 0) {
    if (!hwnd) {
        hwnd := WinGetID("A")
    }
    
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("No Roblox window active for inventory action", true, true)
        return false
    }
    
    ; Send the inventory hotkey (default 'f')
    global BB_INVENTORY_HOTKEY
    BB_sendHotkeyWithDownUp(BB_INVENTORY_HOTKEY)
    BB_updateStatusAndLog("Opened inventory with hotkey: " BB_INVENTORY_HOTKEY)
    Sleep(500)  ; Brief delay to allow inventory to open
    
    return true
}

; Detects in-game movement by monitoring pixel changes in specified regions.
; Parameters:
;   hwnd: The handle of the Roblox window to check for movement.
; Returns: True if movement is detected, False otherwise.
; Notes:
;   - Uses pixel sampling at 5 strategic points across the game window
;   - Compares colors between frames to detect changes above BB_MOVEMENT_THRESHOLD
;   - Implements performance optimization with caching for frequent calls
;   - Critical for validating if automining is active and character is moving
;   - Logs detailed debugging information when BB_DEBUG.level > 3
;   - Integrates with performance tracking system
BB_detectMovement(hwnd) {
    global BB_performanceData
    startTime := A_TickCount
    
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Invalid Roblox window handle for movement detection: " . hwnd, true, true)
        return false
    }
    
    ; Get window position and size
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    static previousColors := []
    static lastCheckTime := 0
    
    ; Determine if we should use cached points or sample new ones
    currentTime := A_TickCount
    useCache := (currentTime - lastCheckTime < 500) && previousColors.Length > 0
    
    ; Define sampling region based on window dimensions (center area most likely to show movement)
    ; Optimize: Use fewer sampling points (5 instead of 9) for better performance
    regions := [
        [winX + winW/2, winY + winH/2],       ; Center
        [winX + winW/3, winY + winH/3],       ; Upper left third
        [winX + 2*winW/3, winY + winH/3],     ; Upper right third
        [winX + winW/3, winY + 2*winH/3],     ; Lower left third
        [winX + 2*winW/3, winY + 2*winH/3]    ; Lower right third
    ]
    
    ; If we're using cached values, compare with previous samples
    if (useCache) {
        changeCount := 0
        threshold := 2  ; Reduced threshold (need fewer changes to identify movement)
        
        for index, region in regions {
            try {
                newColor := PixelGetColor(region[1], region[2], "RGB")
                if (index <= previousColors.Length && newColor != previousColors[index]) {
                    changeCount++
                }
            } catch as err {
                BB_updateStatusAndLog("PixelGetColor error at [" . region[1] . "," . region[2] . "]: " . err.Message, true)
            }
        }
        
        result := (changeCount >= threshold)
        elapsed := A_TickCount - startTime
        
        ; Update performance tracking
        BB_performanceData["MovementCheck"] := (BB_performanceData["MovementCheck"] * 0.8) + (elapsed * 0.2)
        
        ; Only update log with significant results (moving or not moving)
        if (result) {
            BB_updateStatusAndLog("Movement detected with " . changeCount . " changes (cached comparison)")
        }
        
        BB_updateStatusAndLog("Movement check took " . elapsed . "ms")
        return result
    }
    
    ; If no cache or cache expired, sample new points
    newColors := []
    
    ; Sample all regions
    for region in regions {
        try {
            color := PixelGetColor(region[1], region[2], "RGB")
            newColors.Push(color)
        } catch as err {
            BB_updateStatusAndLog("PixelGetColor error at [" . region[1] . "," . region[2] . "]: " . err.Message, true)
            newColors.Push("ERROR")
        }
    }
    
    ; If this is the first check or cache expired, just store colors and return true
    if (previousColors.Length == 0) {
        previousColors := newColors
        lastCheckTime := currentTime
        
        elapsed := A_TickCount - startTime
        BB_performanceData["MovementCheck"] := elapsed
        BB_updateStatusAndLog("Initial movement check (baseline established) took " . elapsed . "ms")
        return true
    }
    
    ; Compare with previous samples
    changeCount := 0
    threshold := 2  ; Reduced threshold
    
    for index, color in newColors {
        if (index <= previousColors.Length && color != "ERROR" && previousColors[index] != "ERROR" && color != previousColors[index]) {
            changeCount++
        }
    }
    
    ; Update cache for next check
    previousColors := newColors
    lastCheckTime := currentTime
    
    result := (changeCount >= threshold)
    elapsed := A_TickCount - startTime
    
    ; Update performance tracking
    BB_performanceData["MovementCheck"] := (BB_performanceData["MovementCheck"] * 0.8) + (elapsed * 0.2)
    
    ; Only log movement detection, not lack of movement (reduces log spam)
    if (result) {
        BB_updateStatusAndLog("Movement detected with " . changeCount . " changes")
    }
    
    BB_updateStatusAndLog("Movement check took " . elapsed . "ms")
    return result
}

; Performs periodic anti-AFK actions to prevent disconnection.
; This function is called on a timer to keep the game session active.
; Notes:
;   - Only runs when script is active and not paused
;   - Verifies active Roblox window before performing actions
;   - Simulates player actions like jumping and movement
;   - Uses random movement directions to appear more natural
;   - Includes delays to allow game to process actions
;   - Logs all anti-AFK actions for monitoring
BB_antiAfkLoop() {
    global BB_running, BB_paused, BB_ANTI_AFK_INTERVAL, BB_JUMP_HOTKEY
    if (!BB_running || BB_paused) {
        BB_updateStatusAndLog("Anti-AFK loop skipped (not running or paused)")
        return
    }
    
    hwnd := WinGetID("A")
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("No Roblox window active for anti-AFK action", true)
        return
    }
    
    ; Simulate a jump to prevent AFK detection using configurable jump key
    SendInput("{" . BB_JUMP_HOTKEY . " down}")
    Sleep(100)
    SendInput("{" . BB_JUMP_HOTKEY . " up}")
    BB_updateStatusAndLog("Anti-AFK action: Jumped to prevent disconnect")
    Sleep(500)  ; Add a delay to allow the game to process the jump
    
    ; Optional: Random movement to mimic player activity
    moveDir := Random(1, 4)
    moveKey := (moveDir = 1) ? "w" : (moveDir = 2) ? "a" : (moveDir = 3) ? "s" : "d"
    SendInput("{" . moveKey . " down}")
    Sleep(Random(500, 1000))
    SendInput("{" . moveKey . " up}")
    BB_updateStatusAndLog("Anti-AFK action: Moved " . moveKey . " to prevent disconnect")
}

; Updates the status and log file with a message.
; Parameters:
;   message: The message to log.
;   updateGUI: Whether to update the GUI.
;   isError: Whether the message is an error.
;   takeScreenshot: Whether to take a screenshot.
BB_updateStatusAndLog(message, updateGUI := true, isError := false, takeScreenshot := false) {
    global BB_ENABLE_LOGGING, BB_logFile, BB_myGUI, BB_isAutofarming, BB_currentArea, BB_merchantState, BB_lastError
    global BB_lastBombStatus, BB_lastTntCrateStatus, BB_lastTntBundleStatus, BB_validTemplates, BB_totalTemplates
    static firstRun := true
    static emeraldBlockCount := 0
    
    if BB_ENABLE_LOGGING {
        timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        logMessage := "[" . timestamp . "] " . (isError ? "ERROR: " : "") . message . "`n"
        
        if firstRun {
            try {
                FileDelete(BB_logFile)
            } catch {
                ; Ignore if file doesn't exist
            }
            firstRun := false
        }

        ; Add retry logic for file access
        maxRetries := 3
        retryDelay := 100  ; 100ms between retries
        loop maxRetries {
            try {
                FileAppend(logMessage, BB_logFile)
                break
            } catch as err {
                if (A_Index = maxRetries) {
                    ; If all retries failed, try to create a new log file with timestamp
                    try {
                        timestamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
                        newLogFile := A_ScriptDir "\mining_log_" . timestamp . ".txt"
                        FileAppend(logMessage, newLogFile)
                        BB_updateStatusAndLog("Created new log file: " . newLogFile, true, true)
                    } catch {
                        ; If even creating a new file fails, just skip logging
                        BB_updateStatusAndLog("Failed to write to log file after all retries", true, true)
                    }
                } else {
                    Sleep(retryDelay)
                }
            }
        }
    }
    
    if isError
        BB_lastError := message
    
    ; Reset emerald block count if requested
    if (message = "Resetting emerald block count") {
        emeraldBlockCount := 0
    }
    
    ; Update emerald block count
    if (InStr(message, "Found") && InStr(message, "emerald blocks")) {
        RegExMatch(message, "Found\s+(\d+)\s+emerald\s+block(s)?", &match)
        emeraldBlockCount += match[1]
    }
    
    ; Take a screenshot if requested
    if (takeScreenshot) {
        screenshotFilename := "error_" . FormatTime(, "yyyyMMdd_HHmmss") . ".png"
        BB_takeScreenshot(WinGetID("A"), screenshotFilename)
    }
    
    ; Safely update GUI if it exists and updateGUI is true
    if (updateGUI && IsSet(BB_myGUI) && IsObject(BB_myGUI)) {
        try {
            BB_myGUI["Status"].Text := (BB_running ? (BB_paused ? "Paused" : "Running") : "Idle")
            BB_myGUI["Status"].SetFont(BB_running ? (BB_paused ? "cOrange" : "cGreen") : "cRed")
            BB_myGUI["WindowCount"].Text := BB_active_windows.Length
            BB_myGUI["AutofarmStatus"].Text := (BB_isAutofarming ? "ON" : "OFF")
            BB_myGUI["AutofarmStatus"].SetFont(BB_isAutofarming ? "cGreen" : "cRed")
            BB_myGUI["ExplosivesStatus"].Text := (BB_ENABLE_EXPLOSIVES ? "ON" : "OFF")
            BB_myGUI["ExplosivesStatus"].SetFont(BB_ENABLE_EXPLOSIVES ? "cGreen" : "cRed")
            BB_myGUI["TemplateStatus"].Text := BB_validTemplates . "/" . BB_totalTemplates
            BB_myGUI["TemplateStatus"].SetFont(BB_validTemplates = BB_totalTemplates ? "cGreen" : "cRed")
            BB_myGUI["CurrentArea"].Text := BB_currentArea
            BB_myGUI["MerchantState"].Text := BB_merchantState
            BB_myGUI["BombStatus"].Text := BB_lastBombStatus
            BB_myGUI["TntCrateStatus"].Text := BB_lastTntCrateStatus
            BB_myGUI["TntBundleStatus"].Text := BB_lastTntBundleStatus
            BB_myGUI["EmeraldBlockCount"].Text := emeraldBlockCount
            BB_myGUI["LastAction"].Text := message
            BB_myGUI["LastError"].Text := BB_lastError
            BB_myGUI["LastError"].SetFont(isError ? "cRed" : "cBlack")
        } catch as err {
            ; Silently fail GUI updates if there's an error
            ; This prevents script crashes if GUI elements aren't ready
        }
    }
    
    ToolTip message, 0, 100
    SetTimer(() => ToolTip(), -3000)
}
; Clears the log file.
BB_clearLog(*) {
    global BB_logFile
    FileDelete(BB_logFile)
    BB_updateStatusAndLog("Log file cleared")
}
; Validates an image file.
; Parameters:
;   filePath: The path to the image file to validate.
; Returns: A string indicating the validation result.
; Notes:
;   - Checks if the file exists

BB_validateImage(filePath) {
    if !FileExist(filePath) {
        return "File does not exist"
    }
    if (StrLower(SubStr(filePath, -3)) != "png") {
        return "Invalid file extension"
    }
    fileSize := FileGetSize(filePath)
    if (fileSize < 8) {
        BB_updateStatusAndLog("File too small to be a PNG: " . fileSize . " bytes (Path: " . filePath . ")", true)
        return "File too small"
    }
    BB_updateStatusAndLog("File assumed valid (skipped FileOpen check): " . filePath)
    return "Assumed Valid (Skipped FileOpen)"
}
; Downloads a template file from a URL and validates it.
; Parameters:
;   templateName: The name of the template to download.
;   fileName: The name of the file to download.
BB_downloadTemplate(templateName, fileName) {
    global BB_TEMPLATE_FOLDER, BB_BACKUP_TEMPLATE_FOLDER, BB_validTemplates, BB_totalTemplates
    BB_totalTemplates++
    templateUrl := "https://raw.githubusercontent.com/xXGeminiXx/BMATMiner/main/mining_templates/" . fileName
    localPath := BB_TEMPLATE_FOLDER . "\" . fileName
    backupPath := BB_BACKUP_TEMPLATE_FOLDER . "\" . fileName

    if !FileExist(localPath) {
        try {
            BB_updateStatusAndLog("Attempting to download " . fileName . " from " . templateUrl)
            downloadWithStatus(templateUrl, localPath)
            validationResult := BB_validateImage(localPath)
            if (validationResult = "Valid" || InStr(validationResult, "Assumed Valid")) {
                BB_validTemplates++
                BB_updateStatusAndLog("Downloaded and validated template: " . fileName)
            } else {
                BB_updateStatusAndLog("Validation failed: " . validationResult, true, true)
                if FileExist(backupPath) {
                    FileCopy(backupPath, localPath, 1)
                    validationResult := BB_validateImage(localPath)
                    if (validationResult = "Valid" || InStr(validationResult, "Assumed Valid")) {
                        BB_validTemplates++
                        BB_updateStatusAndLog("Using backup template for " . fileName)
                    } else {
                        BB_updateStatusAndLog("Backup invalid: " . validationResult, true, true)
                    }
                }
            }
        } catch as err {
            BB_updateStatusAndLog("Download failed: " . err.Message, true, true)
            if FileExist(backupPath) {
                FileCopy(backupPath, localPath, 1)
                validationResult := BB_validateImage(localPath)
                if (validationResult = "Valid" || InStr(validationResult, "Assumed Valid")) {
                    BB_validTemplates++
                    BB_updateStatusAndLog("Using backup template for " . fileName)
                } else {
                    BB_updateStatusAndLog("Backup invalid: " . validationResult, true, true)
                }
            } else {
                BB_updateStatusAndLog("No backup available for " . fileName, true, true)
            }
        }
    } else {
        validationResult := BB_validateImage(localPath)
        if (validationResult = "Valid" || InStr(validationResult, "Assumed Valid")) {
            BB_validTemplates++
            BB_updateStatusAndLog("Template already exists and is valid: " . fileName)
        } else {
            BB_updateStatusAndLog("Existing template invalid: " . validationResult . " - Attempting redownload", true, true)
            try {
                BB_updateStatusAndLog("Attempting to redownload " . fileName . " from " . templateUrl)
                downloadWithStatus(templateUrl, localPath)
                validationResult := BB_validateImage(localPath)
                if (validationResult = "Valid" || InStr(validationResult, "Assumed Valid")) {
                    BB_validTemplates++
                    BB_updateStatusAndLog("Redownloaded and validated template: " . fileName)
                } else {
                    BB_updateStatusAndLog("Redownloaded template invalid: " . validationResult, true, true)
                }
            } catch as err {
                BB_updateStatusAndLog("Redownload failed: " . err.Message, true, true)
            }
        }
    }
}
; Downloads a file from a URL using PowerShell.
; Parameters:
;   url: The URL of the file to download.
;   dest: The local path to save the downloaded file.
; Returns: True if download succeeds, False otherwise.
; Notes:
;   - Uses PowerShell to download files
BB_httpDownload(url, dest) {
    BB_updateStatusAndLog("Attempting PowerShell download for: " . url)
    psCommand := "(New-Object System.Net.WebClient).DownloadFile('" . url . "','" . dest . "')"
    try {
        SplitPath(dest, , &dir)
        if !DirExist(dir) {
            DirCreate(dir)
            BB_updateStatusAndLog("Created directory: " . dir)
        }
        exitCode := RunWait("PowerShell -NoProfile -Command " . Chr(34) . psCommand . Chr(34), , "Hide")
        if (exitCode != 0) {
            throw Error("PowerShell exited with code " . exitCode)
        }
        maxWait := 10
        loop maxWait {
            if FileExist(dest) {
                fileSize := FileGetSize(dest)
                if (fileSize > 0) {
                    BB_updateStatusAndLog("Download succeeded using PowerShell => " . dest . " (Size: " . fileSize . " bytes)")
                    Sleep(1000)
                    return true
                }
            }
            Sleep(1000)
        }
        throw Error("File not created or empty after download")
    } catch as err {
        BB_updateStatusAndLog("PowerShell download failed: " . err.Message, true, true)
        if FileExist(dest) {
            FileDelete(dest)
        }
        return false
    }
}

; Activates a Roblox window robustly, ensuring it is ready for interaction.
; Parameters:
;   hwnd: The handle of the window to activate.
; Returns: True if activation is successful, False otherwise.
BB_robustWindowActivation(hwnd) {
    global BB_updateStatusAndLog
    
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Window does not exist: " . hwnd, true, true)
        return false
    }
    
    ; Check if the window is already active
    if (WinActive("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Window already active: " . hwnd)
        return true
    }
    
    ; Attempt to activate the window
    loop 3 {
        try {
            WinActivate("ahk_id " . hwnd)
            Sleep(500)  ; Increased delay to ensure activation
            if (WinActive("ahk_id " . hwnd)) {
                BB_updateStatusAndLog("Window activated successfully: " . hwnd)
                return true
            }
        } catch as err {
            BB_updateStatusAndLog("Error activating window " . hwnd . ": " . err.Message, true, true)
        }
        Sleep(500)
    }
    
    BB_updateStatusAndLog("Failed to activate window after 3 attempts: " . hwnd, true, true)
    return false
}
; Clicks at a specified position in the Roblox window.
; Parameters:
;   x: The x-coordinate to click (absolute screen coordinates)
;   y: The y-coordinate to click (absolute screen coordinates)
; Returns: True if click succeeds, False otherwise.
; Notes:
;   - Verifies active Roblox window before clicking
;   - Validates input coordinates and window boundaries
;   - Applies resolution scaling to coordinates based on BB_SCALE_X and BB_SCALE_Y
;   - Uses randomized delays between BB_CLICK_DELAY_MIN and BB_CLICK_DELAY_MAX
;   - Records performance metrics for optimization
;   - Handles errors gracefully with detailed logging
BB_clickAt(x, y) {
    global BB_CLICK_DELAY_MIN, BB_CLICK_DELAY_MAX, BB_performanceData, BB_updateStatusAndLog
    
    ; Validate input coordinates
    if (!IsNumber(x) || !IsNumber(y)) {
        BB_updateStatusAndLog("Invalid coordinates provided to BB_clickAt: x=" . x . ", y=" . y, true, true)
        return false
    }
    
    hwnd := WinGetID("A")
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("No Roblox window active for clicking at x=" . x . ", y=" . y, true)
        return false
    }
    
    try {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
        
        ; Validate window position and size
        if (!IsNumber(winX) || !IsNumber(winY) || !IsNumber(winW) || !IsNumber(winH)) {
            BB_updateStatusAndLog("Invalid window position/size: x=" . winX . ", y=" . winY . ", w=" . winW . ", h=" . winH, true, true)
            return false
        }
        
        ; Scale coordinates relative to window
        scaledCoords := BB_scaleCoordinates(x - winX, y - winY)
        scaledX := winX + scaledCoords[1]
        scaledY := winY + scaledCoords[2]
        
        ; Check if coordinates are within window bounds
        if (scaledX < winX || scaledX > winX + winW || scaledY < winY || scaledY > winY + winH) {
            BB_updateStatusAndLog("Click coordinates x=" . scaledX . ", y=" . scaledY . " are outside window bounds", true)
            return false
        }
        
        startTime := A_TickCount
        delay := Random(BB_CLICK_DELAY_MIN, BB_CLICK_DELAY_MAX)
        
        ; Move mouse to coordinates
        MouseMove(scaledX, scaledY, 10)
        Sleep(delay)

        ; Send click down
        Send("{LButton down}")
        BB_updateStatusAndLog("Mouse down at x=" . scaledX . ", y=" . scaledY)
        
        ; Small delay to simulate a natural click duration
        clickDuration := Random(50, 150)
        Sleep(clickDuration)
        
        ; Send click up
        Send("{LButton up}")
        BB_updateStatusAndLog("Mouse up at x=" . scaledX . ", y=" . scaledY . " after " . clickDuration . "ms")
        
        ; Calculate and update average click time
        elapsed := A_TickCount - startTime
        BB_performanceData["ClickAt"] := BB_performanceData.Has("ClickAt") ? (BB_performanceData["ClickAt"] + elapsed) / 2 : elapsed
        BB_updateStatusAndLog("Completed click at x=" . scaledX . ", y=" . scaledY . " (total: " . elapsed . "ms)")
        return true
        
    } catch as err {
        BB_updateStatusAndLog("Error in BB_clickAt: " . err.Message, true, true)
        return false
    }
}

; Helper function to check if a value is a number
IsNumber(value) {
    if (value = "")
        return false
    if value is Number
        return true
    return false
}

; Downloads a file from a URL and validates its size and format.
; Parameters:
;   url: The URL of the file to download.
;   dest: The local path to save the downloaded file.
; Returns: True if download succeeds, False otherwise.
; Notes:
;   - Uses HTTP download function
downloadWithStatus(url, dest) {
    localPath := dest  ; Initialize localPath at the beginning of the function
    try {
        if (!BB_httpDownload(url, dest)) {
            throw Error("Download failed")
        }
        Sleep(1000)
        fileSize := FileGetSize(dest)
        BB_updateStatusAndLog("Downloaded file size: " . fileSize . " bytes")
        if (fileSize < 8) {
            throw Error("File too small to be a PNG: " . fileSize . " bytes")
        }
        return true
    } catch as err {
        BB_updateStatusAndLog("downloadWithStatus failed: " . err.Message, true, true)
        if (FileExist(dest)) {
            FileDelete(dest)
        }
        throw err
    }
}
; Joins an array of strings into a single string with a specified delimiter.
; Parameters:
;   arr: The array of strings to join.
;   delimiter: The delimiter to use between strings.
; Returns: A single string containing all elements of the array, separated by the delimiter.
; Notes:
;   - Uses a loop to concatenate the strings
StrJoin(arr, delimiter) {
    result := ""
    for i, value in arr
        result .= (i > 1 ? delimiter : "") . value
    return result
}

; ===================== LOAD CONFIGURATION =====================
BB_loadConfig() {
    global BB_CONFIG_FILE, BB_logFile, BB_ENABLE_LOGGING, BB_WINDOW_TITLE, BB_EXCLUDED_TITLES
    global BB_CLICK_DELAY_MIN, BB_CLICK_DELAY_MAX, BB_INTERACTION_DURATION, BB_CYCLE_INTERVAL
    global BB_TEMPLATE_FOLDER, BB_BACKUP_TEMPLATE_FOLDER, BB_TEMPLATES, BB_TEMPLATE_RETRIES, BB_MAX_FAILED_INTERACTIONS
    global BB_ANTI_AFK_INTERVAL, BB_RECONNECT_CHECK_INTERVAL, BB_BOMB_INTERVAL
    global BB_TNT_CRATE_INTERVAL, BB_TNT_BUNDLE_INTERVAL, BB_ENABLE_EXPLOSIVES, BB_SAFE_MODE
    global BB_BOMB_HOTKEY, BB_TNT_CRATE_HOTKEY, BB_TNT_BUNDLE_HOTKEY, BB_TELEPORT_HOTKEY, BB_MAX_BUY_ATTEMPTS
    global BB_validTemplates, BB_totalTemplates, BB_INVENTORY_HOTKEY, BB_START_STOP_HOTKEY, BB_PAUSE_HOTKEY, BB_EXPLOSIVES_TOGGLE_HOTKEY, BB_EXIT_HOTKEY, BB_JUMP_HOTKEY
    global BB_performanceData  ; Add BB_performanceData to the global declarations
    
    ; Color globals
    global BB_ERROR_COLORS, BB_STATUS_GREEN, BB_STATUS_RED
    global BB_AREA4_COLOR_RANGES, BB_PICKAXE_COLORS
    
    ; Threshold globals
    global BB_COLOR_MATCH_THRESHOLD, BB_COLOR_CLUSTER_THRESHOLD, BB_ERROR_COLOR_THRESHOLD
    global BB_MOVEMENT_THRESHOLD, BB_BRIGHTNESS_DARK_THRESHOLD, BB_BRIGHTNESS_BRIGHT_THRESHOLD
    global BB_PATTERN_MATCH_CONFIDENCE, BB_AREA_VERIFY_CONFIDENCE
    
    ; File system globals
    global BB_CONFIG_FILE := A_ScriptDir "\mining_config.ini"
    global BB_TEMPLATE_FOLDER := A_ScriptDir "\mining_templates"
    global BB_BACKUP_TEMPLATE_FOLDER := A_ScriptDir "\backup_templates"

    if !FileExist(BB_CONFIG_FILE) {
        FileAppend(defaultIni, BB_CONFIG_FILE)
        BB_updateStatusAndLog("Created default mining_config.ini")
    }

    if !DirExist(BB_TEMPLATE_FOLDER)
        DirCreate(BB_TEMPLATE_FOLDER)
    if !DirExist(BB_BACKUP_TEMPLATE_FOLDER)
        DirCreate(BB_BACKUP_TEMPLATE_FOLDER)

    BB_validTemplates := 0
    BB_totalTemplates := 0
    BB_TEMPLATES := Map()  ; Initialize BB_TEMPLATES as a Map before using it

	for templateName, fileName in Map(
		"automine_button", "automine_button.png",
		"teleport_button", "teleport_button.png",
		"area_4_button", "area_4_button.png",
		"emerald_block", "emerald_block.png",
		"area_5_button", "area_5_button.png",
		"mining_merchant", "mining_merchant.png",
		"buy_button", "buy_button.png",
		"merchant_window", "merchant_window.png",
		"autofarm_on", "autofarm_on.png",
		"autofarm_off", "autofarm_off.png",
		"go_to_top_button", "go_to_top_button.png",
		"error_message", "error_message.png",        ; Added
		"error_message_alt1", "error_message_alt1.png",  ; Added
		"connection_lost", "connection_lost.png",     ; Added
		"emerald_block", "emerald_block.png",
		"go_to_top_button", "go_to_top_button.png"
	) {
		BB_downloadTemplate(templateName, fileName)
		BB_TEMPLATES[templateName] := fileName
	}

    BB_updateStatusAndLog("Template validation summary: " . BB_validTemplates . "/" . BB_totalTemplates . " templates are valid")

    ; Load timing values
    BB_INTERACTION_DURATION := IniRead(BB_CONFIG_FILE, "Timing", "INTERACTION_DURATION", 5000)
    BB_CYCLE_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "CYCLE_INTERVAL", 180000)
    BB_CLICK_DELAY_MIN := IniRead(BB_CONFIG_FILE, "Timing", "CLICK_DELAY_MIN", 500)
    BB_CLICK_DELAY_MAX := IniRead(BB_CONFIG_FILE, "Timing", "CLICK_DELAY_MAX", 1500)
    BB_ANTI_AFK_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "ANTI_AFK_INTERVAL", 300000)
    BB_RECONNECT_CHECK_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "RECONNECT_CHECK_INTERVAL", 10000)
    BB_BOMB_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "BOMB_INTERVAL", 10000)
    BB_TNT_CRATE_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "TNT_CRATE_INTERVAL", 30000)
    BB_TNT_BUNDLE_INTERVAL := IniRead(BB_CONFIG_FILE, "Timing", "TNT_BUNDLE_INTERVAL", 15000)

    ; Always initialize BB_performanceData to ensure it exists
    BB_performanceData := Map(
        "ClickAt", 0,
        "TemplateMatch", Map(),
        "MerchantInteract", 0,
        "MovementCheck", 0,
        "BlockDetection", 0,
        "StateTransition", 0
    )
    BB_updateStatusAndLog("Initialized performance data in loadConfig")

    if BB_performanceData.Has("ClickAt") {
        avgClickTime := BB_performanceData["ClickAt"]
        BB_CLICK_DELAY_MIN := Max(500, avgClickTime - 100)
        BB_CLICK_DELAY_MAX := Max(1500, avgClickTime + 100)
        BB_updateStatusAndLog("Adjusted click delays: Min=" . BB_CLICK_DELAY_MIN . ", Max=" . BB_CLICK_DELAY_MAX . " based on performance")
    } else {
        BB_updateStatusAndLog("No performance data available, using default click delays: Min=" . BB_CLICK_DELAY_MIN . ", Max=" . BB_CLICK_DELAY_MAX)
    }

    BB_WINDOW_TITLE := IniRead(BB_CONFIG_FILE, "Window", "WINDOW_TITLE", "Pet Simulator 99")
    excludedStr := IniRead(BB_CONFIG_FILE, "Window", "EXCLUDED_TITLES", "Roblox Account Manager")
    BB_EXCLUDED_TITLES := StrSplit(excludedStr, ",")

    BB_ENABLE_EXPLOSIVES := IniRead(BB_CONFIG_FILE, "Features", "ENABLE_EXPLOSIVES", false)
    BB_SAFE_MODE := IniRead(BB_CONFIG_FILE, "Features", "SAFE_MODE", false)

    ; Load all hotkeys
    BB_BOMB_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "BOMB_HOTKEY", "^b")
    BB_TNT_CRATE_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "TNT_CRATE_HOTKEY", "^t")
    BB_TNT_BUNDLE_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "TNT_BUNDLE_HOTKEY", "^n")
    BB_TELEPORT_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "TELEPORT_HOTKEY", "t")
    BB_INVENTORY_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "INVENTORY_HOTKEY", "f")
    BB_START_STOP_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "START_STOP_HOTKEY", "F2")
    BB_PAUSE_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "PAUSE_HOTKEY", "p")
    BB_EXPLOSIVES_TOGGLE_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "EXPLOSIVES_TOGGLE_HOTKEY", "F3")
    BB_EXIT_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "EXIT_HOTKEY", "Escape")
    BB_JUMP_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "JUMP_HOTKEY", "Space")
    
    ; Load error detection colors
    BB_ERROR_COLORS := [
        IniRead(BB_CONFIG_FILE, "Colors", "ERROR_RED_1", "0xFF0000"),
        IniRead(BB_CONFIG_FILE, "Colors", "ERROR_RED_2", "0xE31212"),
        IniRead(BB_CONFIG_FILE, "Colors", "ERROR_RED_3", "0xC10000")
    ]
    
    ; Load status colors
    BB_STATUS_GREEN := IniRead(BB_CONFIG_FILE, "Colors", "STATUS_GREEN", "0x00FF00")
    BB_STATUS_RED := IniRead(BB_CONFIG_FILE, "Colors", "STATUS_RED", "0xFF0000")
    
    ; Load Area 4 color ranges
    BB_AREA4_COLOR_RANGES := [
        [[IniRead(BB_CONFIG_FILE, "Colors", "AREA4_EARTH_TONES_MIN", "0x5A3A14"), 
          IniRead(BB_CONFIG_FILE, "Colors", "AREA4_EARTH_TONES_MAX", "0x7A501A")], 
          "Brown earth tones"],
          
        [[IniRead(BB_CONFIG_FILE, "Colors", "AREA4_GOLDEN_AMBER_MIN", "0x856E2B"), 
          IniRead(BB_CONFIG_FILE, "Colors", "AREA4_GOLDEN_AMBER_MAX", "0x9D8638")], 
          "Golden amber"],
          
        [[IniRead(BB_CONFIG_FILE, "Colors", "AREA4_WOOD_DARK_MIN", "0x4A3210"), 
          IniRead(BB_CONFIG_FILE, "Colors", "AREA4_WOOD_DARK_MAX", "0x634523")], 
          "Dark wood browns"],
          
        [[IniRead(BB_CONFIG_FILE, "Colors", "AREA4_WOOD_MEDIUM_MIN", "0x8B7355"), 
          IniRead(BB_CONFIG_FILE, "Colors", "AREA4_WOOD_MEDIUM_MAX", "0xA0876B")], 
          "Medium wood browns"],
          
        [[IniRead(BB_CONFIG_FILE, "Colors", "AREA4_WOOD_LIGHT_MIN", "0xB39169"), 
          IniRead(BB_CONFIG_FILE, "Colors", "AREA4_WOOD_LIGHT_MAX", "0xCCA77F")], 
          "Light wood/sand colors"],
          
        [[IniRead(BB_CONFIG_FILE, "Colors", "AREA4_BROWN_MEDIUM_MIN", "0x5D4B35"), 
          IniRead(BB_CONFIG_FILE, "Colors", "AREA4_BROWN_MEDIUM_MAX", "0x74614A")], 
          "Medium-dark browns"]
    ]
    
    ; Load pickaxe detection colors
    BB_PICKAXE_COLORS := [
        IniRead(BB_CONFIG_FILE, "Colors", "PICKAXE_BROWN_1", "0x5A3A14"),
        IniRead(BB_CONFIG_FILE, "Colors", "PICKAXE_BROWN_2", "0x6B4618"),
        IniRead(BB_CONFIG_FILE, "Colors", "PICKAXE_BROWN_3", "0x7A501A")
    ]
    
    ; Load threshold values
    BB_COLOR_MATCH_THRESHOLD := IniRead(BB_CONFIG_FILE, "Thresholds", "COLOR_MATCH_THRESHOLD", 70)
    BB_COLOR_CLUSTER_THRESHOLD := IniRead(BB_CONFIG_FILE, "Thresholds", "COLOR_CLUSTER_THRESHOLD", 50)
    BB_ERROR_COLOR_THRESHOLD := IniRead(BB_CONFIG_FILE, "Thresholds", "ERROR_COLOR_THRESHOLD", 50)
    BB_MOVEMENT_THRESHOLD := IniRead(BB_CONFIG_FILE, "Thresholds", "MOVEMENT_THRESHOLD", 2)
    BB_BRIGHTNESS_DARK_THRESHOLD := IniRead(BB_CONFIG_FILE, "Thresholds", "BRIGHTNESS_DARK_THRESHOLD", 80)
    BB_BRIGHTNESS_BRIGHT_THRESHOLD := IniRead(BB_CONFIG_FILE, "Thresholds", "BRIGHTNESS_BRIGHT_THRESHOLD", 140)
    BB_PATTERN_MATCH_CONFIDENCE := IniRead(BB_CONFIG_FILE, "Thresholds", "PATTERN_MATCH_CONFIDENCE", 40)
    BB_AREA_VERIFY_CONFIDENCE := IniRead(BB_CONFIG_FILE, "Thresholds", "AREA_VERIFY_CONFIDENCE", 50)

    BB_TEMPLATE_RETRIES := IniRead(BB_CONFIG_FILE, "Retries", "TEMPLATE_RETRIES", 3)
    BB_MAX_FAILED_INTERACTIONS := IniRead(BB_CONFIG_FILE, "Retries", "MAX_FAILED_INTERACTIONS", 5)
    BB_MAX_BUY_ATTEMPTS := IniRead(BB_CONFIG_FILE, "Retries", "MAX_BUY_ATTEMPTS", 6)

    BB_ENABLE_LOGGING := IniRead(BB_CONFIG_FILE, "Logging", "ENABLE_LOGGING", true)
    
    BB_updateStatusAndLog("Loaded configuration values from " . BB_CONFIG_FILE)
}

; ===================== GUI SETUP =====================
; Sets up the user interface for the mining automation script.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Creates a comprehensive monitoring and control interface
;   - Key GUI sections include:
;     * Script status indicators (running state, window count, autofarm)
;     * Game state monitoring (current area, merchant interaction)
;     * Explosives status tracking
;     * Emerald block counter for resource tracking
;     * Error and action logging with detailed history
;     * Configuration and control buttons
;   - Updates dynamically via BB_updateStatusAndLog function
;   - Includes debug controls for advanced troubleshooting
;   - Colors indicate status (green=active, red=inactive/error)
BB_setupGUI() {
    global BB_myGUI, BB_VERSION, BB_BOMB_HOTKEY, BB_TNT_CRATE_HOTKEY, BB_TNT_BUNDLE_HOTKEY
    global BB_START_STOP_HOTKEY, BB_PAUSE_HOTKEY, BB_EXPLOSIVES_TOGGLE_HOTKEY, BB_EXIT_HOTKEY
    global BB_DEBUG
    
    BB_myGUI := Gui("", "🐝 BeeBrained's PS99 Mining Event Macro v" . BB_VERSION . " 🐝")
    BB_myGUI.OnEvent("Close", BB_exitApp)
    
    BB_myGUI.Add("Text", "x10 y10 w400 h20 Center", "🐝 BeeBrained's PS99 Mining Event Macro v" . BB_VERSION . " 🐝")
    
    ; Display current hotkey configuration
    hotkeyText := "Hotkeys: " . BB_START_STOP_HOTKEY . " (Start/Stop) | " . BB_PAUSE_HOTKEY . " (Pause) | "
    hotkeyText .= BB_EXPLOSIVES_TOGGLE_HOTKEY . " (Explosives) | " . BB_EXIT_HOTKEY . " (Exit) | "
    hotkeyText .= BB_BOMB_HOTKEY . " (Bomb) | " . BB_TNT_CRATE_HOTKEY . " (TNT Crate) | " . BB_TNT_BUNDLE_HOTKEY . " (TNT Bundle)"
    
    BB_myGUI.Add("Text", "x10 y30 w400 h25 Center", hotkeyText)
    
    BB_myGUI.Add("GroupBox", "x10 y60 w400 h120", "Script Status")
    BB_myGUI.Add("Text", "x20 y80 w180 h20", "Status:")
    BB_myGUI.Add("Text", "x200 y80 w200 h20", "Idle").Name := "Status"
    BB_myGUI.Add("Text", "x20 y100 w180 h20", "Active Windows:")
    BB_myGUI.Add("Text", "x200 y100 w200 h20", "0").Name := "WindowCount"
    BB_myGUI.Add("Text", "x20 y120 w180 h20", "Autofarm:")
    BB_myGUI.Add("Text", "x200 y120 w200 h20 cRed", "Unknown").Name := "AutofarmStatus"
    BB_myGUI.Add("Text", "x20 y140 w180 h20", "Explosives:")
    BB_myGUI.Add("Text", "x200 y140 w200 h20 cRed", "OFF").Name := "ExplosivesStatus"
    BB_myGUI.Add("Text", "x20 y160 w180 h20", "Templates Valid:")
    BB_myGUI.Add("Text", "x200 y160 w200 h20", "0/0").Name := "TemplateStatus"
    
    BB_myGUI.Add("GroupBox", "x10 y190 w400 h100", "Game State")
    BB_myGUI.Add("Text", "x20 y210 w180 h20", "Current Area:")
    BB_myGUI.Add("Text", "x200 y210 w200 h20", "Unknown").Name := "CurrentArea"
    BB_myGUI.Add("Text", "x20 y230 w180 h20", "Merchant Interaction:")
    BB_myGUI.Add("Text", "x200 y230 w200 h20", "Not Interacted").Name := "MerchantState"
    BB_myGUI.Add("Text", "x20 y250 w180 h20", "Emerald Blocks Found:")
    BB_myGUI.Add("Text", "x200 y250 w200 h20", "0").Name := "EmeraldBlockCount"
    
    BB_myGUI.Add("GroupBox", "x10 y300 w400 h80", "Explosives Status")
    BB_myGUI.Add("Text", "x20 y320 w180 h20", "Bomb:")
    BB_myGUI.Add("Text", "x200 y320 w200 h20", "Idle").Name := "BombStatus"
    BB_myGUI.Add("Text", "x20 y340 w180 h20", "TNT Crate:")
    BB_myGUI.Add("Text", "x200 y340 w200 h20", "Idle").Name := "TntCrateStatus"
    BB_myGUI.Add("Text", "x20 y360 w180 h20", "TNT Bundle:")
    BB_myGUI.Add("Text", "x200 y360 w200 h20", "Idle").Name := "TntBundleStatus"
    
    BB_myGUI.Add("GroupBox", "x10 y390 w400 h100", "Last Action/Error")
    BB_myGUI.Add("Text", "x20 y410 w180 h20", "Last Action:")
    BB_myGUI.Add("Text", "x200 y410 w200 h40 Wrap", "None").Name := "LastAction"
    BB_myGUI.Add("Text", "x20 y450 w180 h20", "Last Error:")
    BB_myGUI.Add("Text", "x200 y450 w200 h40 Wrap cRed", "None").Name := "LastError"
	
	BB_myGUI.Add("Text", "x20 y270 w180 h20", "Failed Interactions:")
	BB_myGUI.Add("Text", "x200 y270 w200 h20", "0").Name := "FailedCount"
	; Update in BB_updateStatusAndLog
	BB_myGUI["FailedCount"].Text := BB_FAILED_INTERACTION_COUNT
    
    ; First row of buttons
    BB_myGUI.Add("Button", "x10 y500 w120 h30", "Reload Config").OnEvent("Click", BB_loadConfigFromFile)
    BB_myGUI.Add("Button", "x150 y500 w120 h30", "Show Stats").OnEvent("Click", (*) => MsgBox(BB_getPerformanceStats()))
    BB_myGUI.Add("Button", "x290 y500 w120 h30", "Toggle Explosives").OnEvent("Click", BB_toggleExplosives)
    
    ; Second row of buttons and dropdown
    BB_myGUI.Add("Button", "x10 y540 w120 h30", "Clear Log").OnEvent("Click", BB_clearLog)
    
    ; Add debug level dropdown
    BB_myGUI.Add("Text", "x150 y545 w80 h20", "Debug Level:")
    debugLevelDropdown := BB_myGUI.Add("DropDownList", "x240 y540 w80 h200 Choose" . BB_DEBUG["level"], ["1", "2", "3", "4", "5"])
    debugLevelDropdown.Name := "DebugLevel"
    debugLevelDropdown.OnEvent("Change", DebugLevelChanged)
    
    ; Add debug toggle button
    debugToggleBtn := BB_myGUI.Add("Button", "x340 y540 w70 h30", BB_DEBUG["enabled"] ? "Debug ON" : "Debug OFF")
    debugToggleBtn.Name := "DebugToggle"
    debugToggleBtn.OnEvent("Click", ToggleDebug)
    
    BB_myGUI.Show("x0 y0 w420 h580")
}

; Handler for debug level dropdown change
DebugLevelChanged(ctrl, *) {
    global BB_DEBUG
    newLevel := Integer(ctrl.Value)
    if (newLevel >= 1 && newLevel <= 5) {
        BB_DEBUG["level"] := newLevel
        BB_updateStatusAndLog("Debug level changed to: " . BB_DEBUG["level"])
    }
}

; Handler for debug toggle button
ToggleDebug(ctrl, *) {
    global BB_DEBUG
    BB_DEBUG["enabled"] := !BB_DEBUG["enabled"]
    ctrl.Text := BB_DEBUG["enabled"] ? "Debug ON" : "Debug OFF"
    BB_updateStatusAndLog("Debug mode " . (BB_DEBUG["enabled"] ? "enabled" : "disabled"))
}

; ===================== HOTKEYS =====================
; Register all hotkeys dynamically after loading configuration
BB_registerHotkeys() {
    global BB_START_STOP_HOTKEY, BB_PAUSE_HOTKEY, BB_EXPLOSIVES_TOGGLE_HOTKEY, BB_EXIT_HOTKEY
    global BB_BOMB_HOTKEY, BB_TNT_CRATE_HOTKEY, BB_TNT_BUNDLE_HOTKEY, BB_INVENTORY_HOTKEY
    
    ; Main Control Hotkeys
    try {
        Hotkey(BB_START_STOP_HOTKEY, BB_stopAutomation)    ; Default: F2 - Start/Stop
        Hotkey(BB_PAUSE_HOTKEY, BB_togglePause)            ; Default: p - Pause/Resume
        Hotkey(BB_EXPLOSIVES_TOGGLE_HOTKEY, BB_toggleExplosives)  ; Default: F3 - Toggle Explosives
        Hotkey(BB_EXIT_HOTKEY, BB_exitApp)                 ; Default: Escape - Exit Application
        
        ; Explosive Hotkeys
        Hotkey(BB_BOMB_HOTKEY, BB_useBomb)                ; Default: CTRL+B - Use Bomb
        Hotkey(BB_TNT_CRATE_HOTKEY, BB_useTntCrate)       ; Default: CTRL+T - Use TNT Crate
        Hotkey(BB_TNT_BUNDLE_HOTKEY, BB_useTntBundle)     ; Default: CTRL+N - Use TNT Bundle
        
        ; Game Interaction Hotkeys - Teleport removed as it doesn't exist in PS99
        Hotkey(BB_INVENTORY_HOTKEY, BB_openInventory)      ; Default: f - Open Inventory
        
        BB_updateStatusAndLog("Registered all hotkeys successfully")
    } catch as err {
        BB_updateStatusAndLog("Error registering hotkeys: " . err.Message, true, true)
        MsgBox("Error registering hotkeys: " . err.Message . "`n`nPlease check your hotkey configuration in mining_config.ini", "Hotkey Error", 0x10)
    }
}

; ===================== CORE FUNCTIONS =====================
BB_startAutomation(*) {
    global BB_running, BB_paused, BB_currentArea, BB_automationState, BB_ENABLE_EXPLOSIVES
    global BB_ERROR_RETRY_ATTEMPTS, BB_myGUI
    
    if BB_running {
        BB_updateStatusAndLog("Already running, ignoring start request")
        return
    }
    BB_running := true
    BB_paused := false
    BB_currentArea := "Area 5"
    BB_automationState := "Idle"
    BB_ERROR_RETRY_ATTEMPTS := 0  ; Reset retry counter when starting automation
    
    BB_updateStatusAndLog("Running - Starting Mining Automation")
    SetTimer(BB_reconnectCheckLoop, BB_RECONNECT_CHECK_INTERVAL)
    SetTimer(BB_antiAfkLoop, BB_ANTI_AFK_INTERVAL) ; Start anti-AFK timer
    BB_updateStatusAndLog("Anti-AFK timer started with interval: " . BB_ANTI_AFK_INTERVAL . "ms")
    if BB_ENABLE_EXPLOSIVES {
        SetTimer(BB_bombLoop, BB_BOMB_INTERVAL)
        SetTimer(BB_tntCrateLoop, BB_TNT_CRATE_INTERVAL)
        SetTimer(BB_tntBundleLoop, BB_TNT_BUNDLE_INTERVAL)
        BB_updateStatusAndLog("Explosives timers started")
    } else {
        SetTimer(BB_bombLoop, 0)
        SetTimer(BB_tntCrateLoop, 0)
        SetTimer(BB_tntBundleLoop, 0)
        BB_updateStatusAndLog("Explosives timers disabled")
    }
    SetTimer(BB_miningAutomationLoop, 1000)
    ; Reset emerald block count
    BB_updateStatusAndLog("Resetting emerald block count", false)
    BB_myGUI["EmeraldBlockCount"].Text := "0"
}
; Stops the mining automation.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Stops all timers and resets the automation state
BB_stopAutomation(*) {
    global BB_running, BB_paused, BB_currentArea, BB_merchantState, BB_automationState
    BB_running := false
    BB_paused := false
    BB_currentArea := "Unknown"
    BB_merchantState := "Not Interacted"
    BB_automationState := "Idle"
    SetTimer(BB_miningAutomationLoop, 0)
    SetTimer(BB_reconnectCheckLoop, 0)
    SetTimer(BB_antiAfkLoop, 0) ; Stop anti-AFK timer
    SetTimer(BB_bombLoop, 0)
    SetTimer(BB_tntCrateLoop, 0)
    SetTimer(BB_tntBundleLoop, 0)
    BB_updateStatusAndLog("Stopped automation")
}
; Toggles the pause state of the mining automation.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Switches the pause state of the automation
;   - Updates the status log with the new pause state
BB_togglePause(*) {
    global BB_running, BB_paused
    if BB_running {
        BB_paused := !BB_paused
        BB_updateStatusAndLog(BB_paused ? "Paused" : "Resumed")
        Sleep 200
    }
}

; Ensures the game UI is in a state where the automine button is visible by resetting the UI.
; Parameters:
;   hwnd: The handle of the Roblox window to ensure the state for.
BB_ensureGameState(hwnd) {
    global BB_updateStatusAndLog
    
    BB_updateStatusAndLog("Ensuring game state for reliable automine button detection (hwnd: " . hwnd . ")")
    
    if (!hwnd || !WinExist("ahk_id " . hwnd) || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("Invalid Roblox window handle for ensuring game state: " . hwnd, true, true)
        return
    }
    
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    
    ; Click in the top-right corner of the window to close any popups
    closeX := winX + winW - 50
    closeY := winY + 50
    BB_clickAt(closeX, closeY)
    BB_updateStatusAndLog("Clicked top-right corner to close potential popups at x=" . closeX . ", y=" . closeY)
    Sleep(500)
    
    ; Click in the center of the window to dismiss any other overlays
    centerX := winX + (winW / 2)
    centerY := winY + (winH / 2)
    BB_clickAt(centerX, centerY)
    BB_updateStatusAndLog("Clicked center of window to dismiss overlays at x=" . centerX . ", y=" . centerY)
    Sleep(500)
    
    BB_updateStatusAndLog("Game state ensured: UI reset")
}
; Toggles the use of explosives in the mining automation.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Switches the use of explosives on and off
;   - Updates the status log with the new state
BB_toggleExplosives(*) {
    global BB_ENABLE_EXPLOSIVES, BB_myGUI
    BB_ENABLE_EXPLOSIVES := !BB_ENABLE_EXPLOSIVES
    if BB_ENABLE_EXPLOSIVES {
        SetTimer(BB_bombLoop, BB_BOMB_INTERVAL)
        SetTimer(BB_tntCrateLoop, BB_TNT_CRATE_INTERVAL)
        SetTimer(BB_tntBundleLoop, BB_TNT_BUNDLE_INTERVAL)
        BB_updateStatusAndLog("Explosives Enabled - Timers started")
    } else {
        SetTimer(BB_bombLoop, 0)
        SetTimer(BB_tntCrateLoop, 0)
        SetTimer(BB_tntBundleLoop, 0)
        BB_updateStatusAndLog("Explosives Disabled - Timers stopped")
    }
}
; Updates the list of active Roblox windows.
; Parameters:
;   None
; Returns: An array of active Roblox window handles
; Notes:
;   - Checks for active Roblox windows based on window title and process name
;   - Filters out excluded titles defined in BB_EXCLUDED_TITLES
;   - Prioritizes the currently active window in the returned array
;   - Implements caching to avoid frequent window enumeration (5 second timeout)
;   - Updates the BB_active_windows global variable for use by other functions
BB_updateActiveWindows() {
    global BB_active_windows, BB_last_window_check
    
    ; Skip if checked recently (within 5 seconds)
    currentTime := A_TickCount
    if (currentTime - BB_last_window_check < 5000) {
        BB_updateStatusAndLog("Window check skipped (recently checked)")
        return BB_active_windows
    }
    
    ; Reset active windows list
    BB_active_windows := []
    activeHwnd := WinGetID("A")
    
    try {
        ; Get all windows with exact title "Roblox"
        winList := WinGetList("Roblox")
        
        ; Process each window
    for hwnd in winList {
        try {
                if (WinGetProcessName(hwnd) = "RobloxPlayerBeta.exe") {
                    ; Prioritize active window by adding it first
                    if (hwnd = activeHwnd) {
                        BB_active_windows.InsertAt(1, hwnd)
                    } else {
                BB_active_windows.Push(hwnd)
                    }
                    BB_updateStatusAndLog("Found Roblox window (hwnd: " hwnd ", active: " (hwnd = activeHwnd ? "Yes" : "No") ")")
            }
        } catch as err {
                BB_updateStatusAndLog("Error processing window " hwnd ": " err.Message, true, true)
            }
        }
    } catch as err {
        BB_updateStatusAndLog("Failed to retrieve window list: " err.Message, true, true)
    }
    
    BB_last_window_check := currentTime
    BB_updateStatusAndLog("Found " BB_active_windows.Length " valid Roblox windows")
    return BB_active_windows
}
; Checks if a window title contains any excluded titles.
; Parameters:
;   title: The title of the window to check.
; Returns: True if the title contains an excluded title, False otherwise.
; Notes:
;   - Checks against a list of excluded titles
BB_hasExcludedTitle(title) {
    global BB_EXCLUDED_TITLES
    for excluded in BB_EXCLUDED_TITLES {
        if InStr(title, excluded)
            return true
    }
    return false
}

; ===================== ERROR HANDLING =====================

; Checks for error messages on the screen (e.g., connection lost, generic errors).
; Parameters:
;   hwnd: The handle of the Roblox window to check.
; Returns: True if an error is detected, False otherwise.
; Notes:
;   - Critical error detection and recovery function
;   - Uses dual detection approach:
;     1. Template matching for known error dialogs and messages
;     2. Pixel-based color detection as fallback for unknown errors
;   - Implements state-based recovery actions based on current automation state
;   - Tracks failed recovery attempts and will reset game if threshold exceeded
;   - Takes screenshots of error conditions for troubleshooting
;   - Robust error handling with graceful fallbacks at each detection step
BB_checkForError(hwnd) {
    global BB_updateStatusAndLog, BB_ERROR_COLORS, BB_ERROR_COLOR_THRESHOLD, BB_JUMP_HOTKEY
    
    errorDetected := false
    errorType := ""
    FoundX := ""
    FoundY := ""
    
    ; Re-enabled error template checks
    errorTypes := ["error_message", "error_message_alt1", "connection_lost"]
    for type in errorTypes {
        if BB_smartTemplateMatch(type, &FoundX, &FoundY, hwnd) {
            errorDetected := true
            errorType := type
            BB_updateStatusAndLog("WARNING: Error detected (" . errorType . " at x=" . FoundX . ", y=" . FoundY . ")", true, true, true)
            break
        } else {
            BB_updateStatusAndLog("Info: Template '" . type . "' not found during error check")
        }
    }
    
    ; Add pixel-based error detection as a fallback
    if (!errorDetected) {
        ; Get window position and size
        WinGetPos(&winX, &winY, &winWidth, &winHeight, "ahk_id " . hwnd)
        
        ; Check common locations for error messages (typically red text or buttons)
        errorCheckRegions := [
            [winX + winWidth/2 - 150, winY + winHeight/2 - 50, 300, 100],  ; Center of screen
            [winX + winWidth - 200, winY + 50, 150, 100]                   ; Top-right (alerts)
        ]
        
        ; Use configurable error colors
        for region in errorCheckRegions {
            loop {
                x := region[1] + (A_Index - 1) * 20
                if (x >= region[1] + region[3])
                    break
                loop {
                    y := region[2] + (A_Index - 1) * 20
                    if (y >= region[2] + region[4])
                        break
                    try {
                        pixelColor := PixelGetColor(x, y, "RGB")
                        
                        ; Check if the pixel color is within threshold of error colors
                        for errorColor in BB_ERROR_COLORS {
                            if (ColorDistance(pixelColor, errorColor) < BB_ERROR_COLOR_THRESHOLD) {
                                errorDetected := true
                                errorType := "pixel_error"
                                FoundX := x
                                FoundY := y
                                BB_updateStatusAndLog("WARNING: Potential error detected by color at x=" . x . ", y=" . y, true, true, true)
                                break 4  ; Break out of all loops
                            }
                        }
                    } catch as err {
                        continue
                    }
                }
            }
        }
    }
    
    if errorDetected {
        BB_updateStatusAndLog("Handling error: " . errorType)
        
        ; Use configurable jump hotkey for space actions
        errorActions := Map(
            "DisableAutomine", () => (BB_disableAutomine(hwnd)),
            "TeleportToArea4", () => (BB_openTeleportMenu(hwnd), BB_teleportToArea("area_4_button", hwnd)),
            "Shopping", () => (BB_interactWithMerchant(hwnd)),
            "TeleportToArea5", () => (BB_openTeleportMenu(hwnd), BB_teleportToArea("area_5_button", hwnd)),
            "EnableAutomine", () => (BB_enableAutomine(hwnd)),
            "Idle", () => (SendInput("{" . BB_JUMP_HOTKEY . " down}"), Sleep(100), SendInput("{" . BB_JUMP_HOTKEY . " up}"), Sleep(500)),
            "Mining", () => (SendInput("{" . BB_JUMP_HOTKEY . " down}"), Sleep(100), SendInput("{" . BB_JUMP_HOTKEY . " up}"), Sleep(500))
        )
        
        action := errorActions.Has(BB_automationState) ? errorActions[BB_automationState] : errorActions["Idle"]
        actionResult := action()
        
        BB_updateStatusAndLog("Attempted recovery from error in state " . BB_automationState . " (Result: " . (actionResult ? "Success" : "Failed") . ")")
        
        global BB_FAILED_INTERACTION_COUNT
        BB_FAILED_INTERACTION_COUNT++
        if (BB_FAILED_INTERACTION_COUNT >= BB_MAX_FAILED_INTERACTIONS) {
            BB_updateStatusAndLog("Too many failed recoveries (" . BB_FAILED_INTERACTION_COUNT . "), attempting to reset game state", true, true)
            if !BB_resetGameState() {
                BB_stopAutomation()
                return true
            }
        }
        
        return true
    }
    
    BB_updateStatusAndLog("No errors detected on screen")
    return false
}

; Attempts to go to the top of the mining area.
; Parameters:
;   None
; Returns: True if successful, False otherwise.
; Notes:
;   - Searches for the "Go to Top" button on the right side of the screen
BB_goToTop() {
    FoundX := ""
    FoundY := ""
    BB_updateStatusAndLog("Attempting to go to the top of the mining area...")
    
    ; Get the active Roblox window
    hwnd := WinGetID("A")
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("No Roblox window active for 'Go to Top' action", true, true)
        return false
    }
    
    ; Search for the "Go to Top" button on the right side of the screen
    searchArea := [A_ScreenWidth - 300, 50, A_ScreenWidth - 50, 150]
    
    loop 3 {
        if BB_smartTemplateMatch("go_to_top_button", &FoundX, &FoundY, hwnd, searchArea) {
            BB_clickAt(FoundX, FoundY)
            BB_updateStatusAndLog("Clicked 'Go to Top' button at x=" . FoundX . ", y=" . FoundY)
            Sleep(5000)  ; Wait for the player to reach the top
            return true
        } else {
            BB_updateStatusAndLog("Info: 'go_to_top_button' not found on attempt " . A_Index)
            Sleep(1000)
        }
    }
    
    BB_updateStatusAndLog("Failed to find 'Go to Top' button after 3 attempts")
    return false
}
; Resets the game state to the initial state.
; Parameters:
;   None
; Returns: True if successful, False otherwise.
; Notes:
;   - Closes all active Roblox windows via WinClose
;   - Attempts to reopen Pet Simulator 99 using Roblox URL protocol
;   - Waits 30 seconds for game to reload
;   - Resets all state variables to initial values
;   - Handles errors during window closure and reopening
;   - Used as a last resort when multiple error recovery attempts fail
BB_resetGameState() {
    global BB_currentArea, BB_merchantState, BB_isAutofarming, BB_automationState, BB_FAILED_INTERACTION_COUNT
    BB_updateStatusAndLog("Attempting to reset game state")
    
    windows := BB_updateActiveWindows()
    for hwnd in windows {
        try {
            WinClose("ahk_id " . hwnd)
            BB_updateStatusAndLog("Closed Roblox window: " . hwnd)
        } catch as err {
            BB_updateStatusAndLog("Failed to close Roblox window " . hwnd . ": " . err.Message, true, true)
            return false
        }
    }
    
    Sleep(5000)
    
    try {
        Run("roblox://placeId=105")
        BB_updateStatusAndLog("Attempted to reopen Pet Simulator 99")
    } catch as err {
        BB_updateStatusAndLog("Failed to reopen Roblox: " . err.Message, true, true)
        return false
    }
    
    Sleep(30000)
    
    BB_currentArea := "Unknown"
    BB_merchantState := "Not Interacted"
    BB_isAutofarming := false
    BB_automationState := "Idle"
    BB_FAILED_INTERACTION_COUNT := 0
    
    windows := BB_updateActiveWindows()
    if (windows.Length > 0) {
        BB_updateStatusAndLog("Game state reset successful, resuming automation")
        return true
    } else {
        BB_updateStatusAndLog("Failed to reset game state: No Roblox windows found after restart", true, true)
        return false
    }
}
; Checks for updates from the GitHub repository.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Retrieves the latest version from the version.txt file
;   - Compares the current version with the remote version
BB_checkForUpdates() {
    global BB_VERSION
    versionUrl := "https://raw.githubusercontent.com/xXGeminiXx/BMATMiner/main/version.txt"
    maxRetries := 3
    retryDelay := 2000
    
    loop maxRetries {
        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", versionUrl, false)
            http.Send()
            if (http.Status != 200) {
                throw Error("HTTP status " . http.Status . " received")
            }
            latestVersion := Trim(http.ResponseText, " `t`r`n")
            if (!RegExMatch(latestVersion, "^\d+\.\d+\.\d+$")) {
                throw Error("Invalid version format: '" . latestVersion . "'")
            }
            BB_updateStatusAndLog("Current version: " . BB_VERSION . " | Remote version: " . latestVersion)
            
            ; Split versions into components for numeric comparison
            currentParts := StrSplit(BB_VERSION, ".")
            latestParts := StrSplit(latestVersion, ".")
            
            if (currentParts[1] > latestParts[1] 
                || (currentParts[1] = latestParts[1] && currentParts[2] > latestParts[2])
                || (currentParts[1] = latestParts[1] && currentParts[2] = latestParts[2] && currentParts[3] > latestParts[3])) {
                BB_updateStatusAndLog("You're running a development version! 🛠️")
                MsgBox("Oho! Running version " . BB_VERSION . " while latest release is " . latestVersion . "?`n`nYou must be one of the developers! 😎`nOr... did you find this in the future? 🤔", "Developer Version", 0x40)
            } else if (latestVersion != BB_VERSION) {
                BB_updateStatusAndLog("New version available: " . latestVersion . " (current: " . BB_VERSION . ")")
                MsgBox("A new version (" . latestVersion . ") is available! Current version: " . BB_VERSION . ". Please update from the GitHub repository.", "Update Available", 0x40)
            } else {
                BB_updateStatusAndLog("Script is up to date (version: " . BB_VERSION . ")")
            }
            return
        } catch as err {
            BB_updateStatusAndLog("Failed to check for updates (attempt " . A_Index . "): " . err.Message, true, true)
            if (A_Index < maxRetries) {
                BB_updateStatusAndLog("Retrying in " . (retryDelay / 1000) . " seconds...")
                Sleep(retryDelay)
            }
        }
    }
    BB_updateStatusAndLog("Failed to check for updates after " . maxRetries . " attempts", true, true)
}
; Enables automining in the game.
; Parameters:
;   hwnd: The handle of the Roblox window to interact with.
; Returns: True if successful, False otherwise.
BB_enableAutomine(hwnd) {
    global BB_isAutofarming
    
    BB_updateStatusAndLog("Attempting to enable automining...")
    
    ; Find and click the automine button using its template
    FoundX := ""
    FoundY := ""
    if BB_smartTemplateMatch("automine_button", &FoundX, &FoundY, hwnd) {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Clicked automine button at x=" . FoundX . ", y=" . FoundY . " to enable automining")
    } else {
        ; Fallback to fixed coordinates if template matching fails
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
        clickX := winX + 60
        clickY := winY + 550
        BB_clickAt(clickX, clickY)
        BB_updateStatusAndLog("Automine button not found, clicked at fixed position x=" . clickX . ", y=" . clickY . " to enable automining")
    }
    
    Sleep(2000)
    
    ; Validate using pixel movement
    regions := [
        [A_ScreenWidth//3, A_ScreenHeight//3],
        [2*A_ScreenWidth//3, A_ScreenHeight//3],
        [A_ScreenWidth//2, A_ScreenHeight//2],
        [A_ScreenWidth//3, 2*A_ScreenHeight//3],
        [2*A_ScreenWidth//3, 2*A_ScreenHeight//3]
    ]
    
    initialColors := []
    for region in regions {
        color := PixelGetColor(region[1], region[2], "RGB")
        initialColors.Push(color)
    }
    
    Sleep(1000)
    isMoving := false
    loop 3 {
        for index, region in regions {
            newColor := PixelGetColor(region[1], region[2], "RGB")
            if (newColor != initialColors[index]) {
                isMoving := true
                break
            }
        }
        if (isMoving) {
            break
        }
        Sleep(500)
    }
    
    if (isMoving) {
        BB_updateStatusAndLog("Pixel movement detected after enabling, automining enabled successfully")
        BB_isAutofarming := true
        return true
    } else {
        BB_updateStatusAndLog("No pixel movement detected, assuming automining is ON anyway")
        BB_isAutofarming := true
        return true
    }
}

; Detects emerald blocks in the game window and updates the GUI counter
; Parameters:
;   blockPositions: Array to store detected block positions
;   hwnd: The handle of the Roblox window
; Returns: True if any blocks found, False otherwise
BB_detectEmeraldBlocks(&blockPositions, hwnd) {
    startTime := A_TickCount
    
    global BB_myGUI
    
    ; Initialize empty array for block positions
    blockPositions := []
    
    ; Try detection multiple times to account for animations/effects
    loop 3 {
        if (BB_smartTemplateMatch("emerald_block", &FoundX, &FoundY, hwnd)) {
            ; Check if this position is already recorded (within 10 pixels)
            isNewBlock := true
            for block in blockPositions {
                if (Abs(block.x - FoundX) < 10 && Abs(block.y - FoundY) < 10) {
                    isNewBlock := false
            break
        }
            }
            
            ; Add new block position if not already recorded
            if (isNewBlock) {
                blockPositions.Push({x: FoundX, y: FoundY})
                BB_updateStatusAndLog("Found emerald block at x=" . FoundX . ", y=" . FoundY)
            }
        }
        Sleep(500)  ; Wait for potential animations/effects to change
    }
    
    elapsed := A_TickCount - startTime
    BB_performanceData["BlockDetection"] := 
        BB_performanceData.Has("BlockDetection") ? 
        (BB_performanceData["BlockDetection"] + elapsed) / 2 : elapsed
    
    BB_updateStatusAndLog("Block detection took " . elapsed . "ms")
    
    ; Update GUI if blocks were found
    if (blockPositions.Length > 0) {
        BB_updateStatusAndLog("Found " . blockPositions.Length . " emerald blocks")
        
        ; Safely update the GUI counter
        try {
            currentCount := StrToInt(BB_myGUI["EmeraldBlockCount"].Text)
            if (!IsNumber(currentCount)) {
                currentCount := 0
            }
            BB_myGUI["EmeraldBlockCount"].Text := currentCount + blockPositions.Length
    } catch as err {
            BB_updateStatusAndLog("Failed to update GUI counter: " . err.Message, true)
        }
        
        return true
    }
    
    BB_updateStatusAndLog("No emerald blocks detected")
    return false
}

; Helper function to safely convert string to integer
StrToInt(str) {
    if (str = "") {
        return 0
    }
    return Integer(str)
}

; Opens the teleport menu in the game 
; Parameters:
;   hwnd: The handle of the Roblox window to interact with.
; Returns: True if successful, False otherwise
BB_openTeleportMenu(hwnd) {
    global BB_SCALE_X, BB_SCALE_Y, BB_isAutofarming
    
    BB_updateStatusAndLog("Attempting to open teleport menu...")
    
    ; Get window position and size for positioning
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    if (!winW || !winH) {
        BB_updateStatusAndLog("Failed to get window dimensions for teleport", true)
        return false
    }
    
    BB_updateStatusAndLog("Window dimensions: " . winW . "x" . winH)
    
    ; First try template matching for teleport button
    FoundX := -1
    FoundY := -1
    templateUsed := false
    
    ; CRITICAL FIX: Search EXTREMELY high in the window
    ; Log shows click at (137,306) hit autohatch, so search area needs to be much higher
    searchArea := [
        winX + 1,         ; Left edge (FIXED: ensure positive integer)
        winY + 1,         ; EXTREMELY HIGH top boundary (FIXED: ensure positive integer)
        winX + (winW/3),  ; 1/3 of window width
        winY + 100        ; Keep search very limited to top area only (FIXED: lower to avoid invalid area)
    ]
    
    ; Try template matching first - stricter tolerance
    BB_updateStatusAndLog("Attempting template match in area: " . Round(searchArea[1]) . "," . Round(searchArea[2]) . "," . Round(searchArea[3]) . "," . Round(searchArea[4]))
    if (BB_smartTemplateMatch("teleport_button", &FoundX, &FoundY, hwnd, searchArea, 40)) {
        BB_updateStatusAndLog("Found teleport button with template match at x=" . FoundX . ", y=" . FoundY)
        
        ; Use template location but with a fixed Y offset to click higher
        clickX := FoundX + 30  ; Center X of button
        clickY := FoundY + 30  ; Center Y of button
        
        ; Log whether this is using template or fallback
        BB_updateStatusAndLog("TEMPLATE MATCH: Using teleport template at x=" . clickX . ", y=" . clickY)
        templateUsed := true
    } else {
        BB_updateStatusAndLog("No template match found, using EXTREMELY HIGH grid-based approach", true)
        
        ; If template fails, use grid-based approach with 4x2 grid at MUCH higher position
        ; First row: Gift, Teleport
        ; Second row: Hoverboard, Autohatch
        
        ; Calculate grid dimensions - EXTREMELY TOP OF WINDOW position
        gridStartX := winX + 40   ; Left edge of grid
        gridStartY := winY + 5    ; ABSOLUTE TOP OF WINDOW (FIXED: was 30, now 5)
        
        ; Width and height for the grid cells
        cellWidth := 70
        cellHeight := 25          ; MUCH SMALLER HEIGHT (FIXED: was 70, now 25)
        
        ; Target teleport specifically (2nd position, top row)
        teleportX := gridStartX + cellWidth
        teleportY := gridStartY
        
        ; Calculate center of button
        clickX := teleportX + (cellWidth/2)
        clickY := teleportY + (cellHeight/2)
        
        BB_updateStatusAndLog("GRID FALLBACK: Using EXTREMELY HIGH position at x=" . clickX . ", y=" . clickY . " (y was 306 before)")
    }
    
    ; Ensure coordinates are within window bounds
    clickX := Max(winX + 10, Min(clickX, winX + winW - 10))
    clickY := Max(winY + 10, Min(clickY, winY + winH - 10))
    
    ; Click with clear logging
    if (templateUsed)
        BB_updateStatusAndLog("Clicking TEMPLATE teleport position at x=" . clickX . ", y=" . clickY)
    else
        BB_updateStatusAndLog("Clicking FALLBACK teleport position at x=" . clickX . ", y=" . clickY)
    
    BB_clickAt(clickX, clickY)
    
    ; Wait for teleport menu to appear
    Sleep(3000)
    
    ; Check if the click triggered automining toggle (important movement check)
    if (BB_checkAutofarming(hwnd) != BB_isAutofarming) {
        ; If automining state changed, it means we didn't hit teleport
        BB_updateStatusAndLog("Warning: Automining state changed - teleport click missed", true)
        
        ; Try clicking EVEN HIGHER - absolute top of window
        fallbackX := clickX
        fallbackY := winY + 40  ; Extremely top area - almost touching window border
        
        BB_updateStatusAndLog("EMERGENCY FALLBACK: Trying position at absolute top of window: x=" . fallbackX . ", y=" . fallbackY)
        BB_clickAt(fallbackX, fallbackY)
        
        ; Wait for teleport menu to appear
        Sleep(3000)
    }
    
    BB_updateStatusAndLog("Teleport menu should now be open")
    return true
}

; Teleports to the specified area after the teleport menu is open
; Uses a more reliable approach with adjusted positions for Area 4 button
; Parameters:
;   areaTemplate: The template name for the area button (e.g., "area_4_button")
;   hwnd: The handle of the Roblox window to interact with.
; Returns: True if teleport succeeds, False otherwise
BB_teleportToArea(areaTemplate, hwnd) {
    global BB_currentArea
    
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Invalid window handle for teleport", true)
        return false
    }
    
    ; Get window dimensions for validation
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    if (!winW || !winH) {
        BB_updateStatusAndLog("Failed to get window dimensions for area teleport", true)
        return false
    }
    
    BB_updateStatusAndLog("Looking for " . areaTemplate . " in teleport menu")
    
    ; Wait longer for teleport menu to fully load (increased from 2000ms)
    Sleep(3000)
    
    ; Try template matching with higher tolerance for area buttons
    FoundX := -1
    FoundY := -1
    
    ; Modified search area to look in top half of screen
    searchArea := [
        winX + 5,                    ; Left edge with small margin
        winY + 50,                   ; Start higher in the screen
        winX + (winW/2),             ; Half the screen width 
        winY + (winH/2)              ; Half the screen height
    ]
    
    BB_updateStatusAndLog("Searching for " . areaTemplate . " in area: " . Round(searchArea[1]) . "," . Round(searchArea[2]) . "," . Round(searchArea[3]) . "," . Round(searchArea[4]))
    
    ; Verify template exists first
    templatePath := BB_TEMPLATE_FOLDER . "\" . BB_TEMPLATES[areaTemplate]
    if (!FileExist(templatePath)) {
        BB_updateStatusAndLog("Template file not found: " . templatePath, true)
        ; Continue anyway with fallbacks
    } else {
        BB_updateStatusAndLog("Using area template: " . templatePath)
    }
    
    ; Try template matching with higher tolerance (60) for area buttons
    if (BB_smartTemplateMatch(areaTemplate, &FoundX, &FoundY, hwnd, searchArea, 60)) {
        BB_updateStatusAndLog("Found " . areaTemplate . " at x=" . FoundX . ", y=" . FoundY)
        
        ; Click slightly offset from found position
        clickX := FoundX + 35  ; Offset X
        clickY := FoundY + 25  ; Offset Y
        
        ; Ensure click is within window bounds
        clickX := Max(winX + 5, Min(clickX, winX + winW - 5))
        clickY := Max(winY + 5, Min(clickY, winY + winH - 5))
        
        BB_updateStatusAndLog("Clicking " . areaTemplate . " at x=" . clickX . ", y=" . clickY . " (template match)")
        BB_clickAt(clickX, clickY)
        
        ; Wait for teleport to complete
        Sleep(5000)
        
        ; Update current area based on template
        BB_currentArea := (areaTemplate = "area_4_button") ? "Area 4" : "Area 5"
        BB_updateStatusAndLog("Teleporting to " . BB_currentArea)
        return true
    } else {
        BB_updateStatusAndLog("No template match found for " . areaTemplate . ", using fixed positions", true)
    }
    
    ; If template fails, use fixed positions based on the teleport menu layout
    BB_updateStatusAndLog("Using fixed positions for " . areaTemplate)
    
    ; Area-specific positions - Area 4 is typically upper left, Area 5 is typically upper right
    positions := []
    
    if (areaTemplate = "area_4_button") {
        ; Area 4 commonly appears in these positions after teleport menu opens
        positions := [
            [winX + 120, winY + 180],    ; Upper left area
            [winX + 80, winY + 180],     ; Further left
            [winX + 120, winY + 220],    ; Slightly lower
            [winX + 80, winY + 220],     ; Lower left
            [winX + 160, winY + 180],    ; Upper middle
            [winX + 160, winY + 220]     ; Middle
        ]
    } else {
        ; Area 5 commonly appears in these positions
        positions := [
            [winX + 320, winY + 180],    ; Upper right
            [winX + 280, winY + 180],    ; Upper middle-right
            [winX + 320, winY + 220],    ; Slightly lower right
            [winX + 280, winY + 220],    ; Middle right
            [winX + 240, winY + 180],    ; Upper middle
            [winX + 240, winY + 220]     ; Middle
        ]
    }
    
    ; Try each fixed position
    for pos in positions {
        clickX := pos[1]
        clickY := pos[2]
        
        ; Ensure coordinates are within window bounds
        clickX := Max(winX + 5, Min(clickX, winX + winW - 5))
        clickY := Max(winY + 5, Min(clickY, winY + winH - 5))
        
        BB_updateStatusAndLog("Clicking " . areaTemplate . " at fixed position: x=" . clickX . ", y=" . clickY)
        BB_clickAt(clickX, clickY)
        
        ; Wait between clicks
        Sleep(1200)  ; Increased wait time
    }
    
    ; Update current area based on template
    BB_currentArea := (areaTemplate = "area_4_button") ? "Area 4" : "Area 5"
    BB_updateStatusAndLog("Teleporting to " . BB_currentArea)
    
    ; Wait for teleport to complete
    Sleep(5000)
    
    return true
}

; Interacts with the mining merchant in Area 4.
; Parameters:
;   hwnd: The handle of the Roblox window to interact with.
; Returns: True if successful, False otherwise.
BB_interactWithMerchant(hwnd) {
    global BB_merchantState
    BB_updateStatusAndLog("Attempting to interact with merchant in Area 4...")
    
    ; Simulate walking to the merchant (hold 'w' to move forward)
    BB_updateStatusAndLog("Walking forward to merchant (holding 'w' for 5 seconds)")
    SendInput("{w down}")
    Sleep(5000)  ; Adjust this duration based on how long it takes to reach the merchant
    SendInput("{w up}")
    
    ; Interact with the merchant (default interaction key is 'e' in Roblox)
    SendInput("{e down}")
    Sleep(100)
    SendInput("{e up}")
    BB_updateStatusAndLog("Sent 'e' to interact with merchant")
    Sleep(2000)  ; Wait for the merchant window to open
    
    BB_merchantState := "Interacted"
    return true
}

; Buys items from the merchant using template matching
; Parameters:
;   hwnd: The handle of the Roblox window
; Returns: True if purchase succeeds, False otherwise
BB_buyMerchantItems(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Invalid window handle for merchant", true)
        return false
    }
    
    ; Try to find and click the buy button template
    if (BB_smartTemplateMatch("buy_button", &FoundX, &FoundY, hwnd)) {
        if (BB_clickAt(FoundX, FoundY)) {
            BB_updateStatusAndLog("Clicked buy button")
            Sleep(1000)
            return true
        }
    }
    
    BB_updateStatusAndLog("Failed to find merchant buy button", true)
    return false
}

; Disables automining in the game.
; Parameters:
;   hwnd: The handle of the Roblox window to interact with.
; Returns: True if successful, False otherwise.
BB_disableAutomine(hwnd) {
    global BB_isAutofarming, BB_FAILED_INTERACTION_COUNT, BB_MAX_FAILED_INTERACTIONS
    
    BB_updateStatusAndLog("Initiating automining disable process...")
    
    ; Get window position and size
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    if (!winW || !winH) {
        BB_updateStatusAndLog("Failed to get window dimensions", true)
        return false
    }
    
    BB_updateStatusAndLog("Window dimensions: " . winW . "x" . winH)
    
    ; Try template matching for automine button with a restricted search area
    FoundX := -1
    FoundY := -1
    
    ; Define search area specifically for the bottom left where automine button should be
    searchArea := [
        winX + 40,                   ; Keep X=40 minimum
        winY + (winH - 150),         ; Bottom area, but not too close to edge
        winX + 150,                  ; Limited width to prevent false matches
        winY + winH - 5              ; Stop just before bottom edge
    ]
    
    BB_updateStatusAndLog("Searching for automine button in area: " . 
        Round(searchArea[1]) . "," . Round(searchArea[2]) . "," . Round(searchArea[3]) . "," . Round(searchArea[4]))
    
    ; Try template matching with a moderate tolerance (45)
    if (BB_smartTemplateMatch("automine_button", &FoundX, &FoundY, hwnd, searchArea, 45)) {
        BB_updateStatusAndLog("Found automine button at x=" . FoundX . ", y=" . FoundY)
        
        ; Calculate click position relative to button center, but maintain X=40 minimum
        clickX := Max(winX + 40, FoundX + 25)
        clickY := FoundY + 25
        
        BB_updateStatusAndLog("Clicking automine at template match: x=" . clickX . ", y=" . clickY)
        BB_clickAt(clickX, clickY)
        Sleep(2500)
        
        ; Check if automining was disabled
        if (!BB_checkAutofarming(hwnd)) {
            BB_updateStatusAndLog("Automining disabled successfully with template match")
            BB_isAutofarming := false
            return true
        }
    } else {
        BB_updateStatusAndLog("No template match found for automine button, using fixed positions", true)
    }
    
    ; If template match failed or didn't work, use fixed positions 
    
    ; First attempt - exact position from log success
    clickX1 := winX + 52  ; Use exact position since we know X=40 is minimum
    clickY1 := winY + 459
    BB_updateStatusAndLog("Clicking automine at fixed primary position: x=" . clickX1 . ", y=" . clickY1)
    BB_clickAt(clickX1, clickY1)
    Sleep(3000)
    
    ; Check if automining was disabled
    if (!BB_checkAutofarming(hwnd)) {
        BB_updateStatusAndLog("Automining disabled successfully with primary position")
        BB_isAutofarming := false
        return true
    }
    
    ; Second attempt - try slightly to the right
    clickX2 := winX + 70  
    clickY2 := winY + 459
    BB_updateStatusAndLog("Clicking automine at fixed secondary position: x=" . clickX2 . ", y=" . clickY2)
    BB_clickAt(clickX2, clickY2)
    Sleep(3000)
    
    ; Check again
    if (!BB_checkAutofarming(hwnd)) {
        BB_updateStatusAndLog("Automining disabled successfully with secondary position")
        BB_isAutofarming := false
        return true
    }
    
    ; Third attempt - further right
    clickX3 := winX + 85
    clickY3 := winY + 459
    BB_updateStatusAndLog("Clicking automine at fixed tertiary position: x=" . clickX3 . ", y=" . clickY3)
    BB_clickAt(clickX3, clickY3)
    Sleep(3000)
    
    ; Final check
    if (!BB_checkAutofarming(hwnd)) {
        BB_updateStatusAndLog("Automining disabled successfully with tertiary position")
        BB_isAutofarming := false
        return true
    }
    
    ; If we get here, all attempts failed
    BB_updateStatusAndLog("Failed to disable automining after all attempts", true)
    BB_FAILED_INTERACTION_COUNT++
    return false
}

; Check if the screen is still moving (indicating mining is active)
; Returns true if movement is detected, false if the screen is mostly static
BB_isScreenStillMoving(hwnd, maxAttempts := 3, attemptDelay := 1000) {
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    
    ; Sample points across the screen
    regions := [
        [winX + winW//4, winY + winH//4],         ; Top-left quadrant
        [winX + 3*winW//4, winY + winH//4],       ; Top-right quadrant
        [winX + winW//2, winY + winH//2],         ; Center
        [winX + winW//4, winY + 3*winH//4],       ; Bottom-left quadrant
        [winX + 3*winW//4, winY + 3*winH//4],     ; Bottom-right quadrant
        [winX + winW//2, winY + winH//4],         ; Middle-top
        [winX + winW//2, winY + 3*winH//4],       ; Middle-bottom
        [winX + winW//4, winY + winH//2],         ; Middle-left
        [winX + 3*winW//4, winY + winH//2]        ; Middle-right
    ]
    
    ; Loop through each attempt
    Loop maxAttempts {
        attempt := A_Index
        ; Capture initial colors
        initialColors := []
        for region in regions {
            try {
                color := PixelGetColor(region[1], region[2], "RGB")
                initialColors.Push(color)
            } catch as err {
                BB_updateStatusAndLog("Error getting pixel color: " . err.Message, true)
                initialColors.Push("ERROR")
            }
        }
        
        ; Wait to check for changes
        Sleep(attemptDelay)
        
        ; Count changes
        changeCount := 0
        threshold := 3  ; At least 3 points need to change to consider it "moving"
        
        for index, region in regions {
            try {
                newColor := PixelGetColor(region[1], region[2], "RGB")
                if (initialColors[index] != "ERROR" && newColor != initialColors[index]) {
                    changeCount++
                    BB_updateStatusAndLog("Pixel change at region " . index . ": " . initialColors[index] . " -> " . newColor)
                }
            } catch as err {
                BB_updateStatusAndLog("Error getting comparison pixel color: " . err.Message, true)
            }
        }
        
        BB_updateStatusAndLog("Movement check " . attempt . "/" . maxAttempts . ": " . changeCount . " changes detected (threshold: " . threshold . ")")
        
        ; If few changes, screen is not moving much
        if (changeCount < threshold) {
            return false  ; Not moving
        }
    }
    
    return true  ; Still moving after all attempts
}

; ===================== EXPLOSIVES FUNCTIONS =====================
; Sends a hotkey with down and up actions.
; Parameters:
;   hotkey: The hotkey to send.
; Returns: True if successful, False otherwise.
BB_sendHotkeyWithDownUp(hotkey) {
    hwnd := WinGetID("A")
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("No Roblox window active for hotkey: " . hotkey, true, true)
        return false
    }

    modifiers := ""
    key := hotkey
    if (InStr(hotkey, "^")) {
        modifiers .= "Ctrl "
        key := StrReplace(key, "^", "")
    }
    if (InStr(hotkey, "+")) {
        modifiers .= "Shift "
        key := StrReplace(key, "+", "")
    }
    if (InStr(hotkey, "!")) {
        modifiers .= "Alt "
        key := StrReplace(key, "!", "")
    }

    if (InStr(modifiers, "Ctrl")) {
        SendInput("{Ctrl down}")
    }
    if (InStr(modifiers, "Shift")) {
        SendInput("{Shift down}")
    }
    if (InStr(modifiers, "Alt")) {
        SendInput("{Alt down}")
    }

    SendInput("{" . key . " down}")
    Sleep(100)
    SendInput("{" . key . " up}")

    if (InStr(modifiers, "Alt")) {
        SendInput("{Alt up}")
    }
    if (InStr(modifiers, "Shift")) {
        SendInput("{Shift up}")
    }
    if (InStr(modifiers, "Ctrl")) {
        SendInput("{Ctrl up}")
    }
    Sleep(100)
    return true
}

; Uses a bomb in the game.
; Parameters:
;   hwnd: The handle of the Roblox window to interact with.
BB_useBomb(hwnd) {
    global BB_BOMB_HOTKEY, BB_lastBombStatus
    BB_sendHotkeyWithDownUp(BB_BOMB_HOTKEY)
    BB_lastBombStatus := "Used at " . A_Now
    BB_updateStatusAndLog("Used bomb with hotkey: " . BB_BOMB_HOTKEY)
    BB_checkForError(hwnd)  ; Pass hwnd here
}

; Uses a TNT crate in the game.
; Parameters:
;   hwnd: The handle of the Roblox window to interact with.
BB_useTntCrate(hwnd) {
    global BB_TNT_CRATE_HOTKEY, BB_lastTntCrateStatus
    BB_sendHotkeyWithDownUp(BB_TNT_CRATE_HOTKEY)
    BB_lastTntCrateStatus := "Used at " . A_Now
    BB_updateStatusAndLog("Used TNT crate with hotkey: " . BB_TNT_CRATE_HOTKEY)
    BB_checkForError(hwnd)  ; Pass hwnd here
}

; Uses a TNT bundle in the game.
; Parameters:
;   hwnd: The handle of the Roblox window to interact with.
BB_useTntBundle(hwnd) {
    global BB_TNT_BUNDLE_HOTKEY, BB_lastTntBundleStatus
    BB_sendHotkeyWithDownUp(BB_TNT_BUNDLE_HOTKEY)
    BB_lastTntBundleStatus := "Used at " . A_Now
    BB_updateStatusAndLog("Used TNT bundle with hotkey: " . BB_TNT_BUNDLE_HOTKEY)
    BB_checkForError(hwnd)  ; Pass hwnd here
}
; Loops through bomb usage.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Checks if the script is running, not paused, and explosives are enabled
;   - Verifies active Roblox window and active mining state before using bomb
;   - Uses configurable hotkey and interval from settings
;   - Part of the explosive mining system that increases mining effectiveness
BB_bombLoop() {
    global BB_running, BB_paused, BB_ENABLE_EXPLOSIVES, BB_isAutofarming
    
    if (!BB_running || BB_paused || !BB_ENABLE_EXPLOSIVES) {
        BB_updateStatusAndLog("Bomb loop skipped (not running, paused, or explosives off)")
        return
    }
    
    hwnd := WinGetID("A")
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("No Roblox window active for bomb loop", true, true)
        return
    }
    
    
    if (BB_checkAutofarming(hwnd)) {
        BB_useBomb(hwnd)  ; Pass hwnd here
    } else {
        BB_updateStatusAndLog("Bomb loop skipped (not autofarming)")
    }
}
; Loops through TNT crate usage.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Checks if the script is running, not paused, and explosives are enabled
;   - Verifies active Roblox window and active mining state before using TNT crate
;   - Uses configurable hotkey and interval from settings
;   - Higher power explosive than bombs with longer cooldown
;   - Used to clear larger areas during mining
BB_tntCrateLoop() {
    global BB_running, BB_paused, BB_ENABLE_EXPLOSIVES, BB_isAutofarming
    
    if (!BB_running || BB_paused || !BB_ENABLE_EXPLOSIVES) {
        BB_updateStatusAndLog("TNT crate loop skipped (not running, paused, or explosives off)")
        return
    }
    
    hwnd := WinGetID("A")
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("No Roblox window active for TNT crate loop", true, true)
        return
    }
    
    if (BB_checkAutofarming(hwnd)) {
        BB_useTntCrate(hwnd)  ; Pass hwnd here
    } else {
        BB_updateStatusAndLog("TNT crate loop skipped (not autofarming)")
    }
}
; Loops through TNT bundle usage.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Checks if the script is running, not paused, and explosives are enabled
;   - Verifies active Roblox window and active mining state before using TNT bundle
;   - Uses configurable hotkey and interval from settings
;   - Medium-power explosive between bomb and TNT crate
;   - Balanced explosive option for regular mining
BB_tntBundleLoop() {
    global BB_running, BB_paused, BB_ENABLE_EXPLOSIVES, BB_isAutofarming
    
    if (!BB_running || BB_paused || !BB_ENABLE_EXPLOSIVES) {
        BB_updateStatusAndLog("TNT bundle loop skipped (not running, paused, or explosives off)")
        return
    }
    
    hwnd := WinGetID("A")
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
        BB_updateStatusAndLog("No Roblox window active for TNT bundle loop", true, true)
        return
    }
    
    if (BB_checkAutofarming(hwnd)) {
        BB_useTntBundle(hwnd)  ; Pass hwnd here
    } else {
        BB_updateStatusAndLog("TNT bundle loop skipped (not autofarming)")
    }
}

; ===================== STATE MACHINE AUTOMATION LOOP =====================
; Loops through the mining automation cycle.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Core automation state machine driving the entire mining process
;   - Implements a robust state-based workflow with the following states:
;     * Idle: Starting point for each cycle
;     * DisableAutomine: Ensures mining is stopped before teleporting
;     * TeleportToArea4: Handles teleporting to the merchant area
;     * WalkToMerchant: Navigates to the merchant NPC
;     * Shopping: Purchases items from the merchant 
;     * TeleportToArea5: Returns to the primary mining area
;     * EnableAutomine: Restarts the mining process
;     * Mining: Active mining state with timed duration
;     * Error: Special state for handling and recovering from errors
;   - Features sophisticated error handling with:
;     * State timeouts to prevent workflow getting stuck
;     * Incremental failed interaction tracking
;     * Exponential backoff for error recovery
;     * Automatic game reset when recovery fails
;   - Operates on all detected Roblox windows
BB_miningAutomationLoop() {
    global BB_running, BB_paused, BB_automationState, BB_FAILED_INTERACTION_COUNT, BB_MAX_FAILED_INTERACTIONS
    global BB_currentArea, BB_merchantState, BB_isAutofarming, BB_CYCLE_INTERVAL, BB_ENABLE_EXPLOSIVES, gameStateEnsured
    global BB_STATE_TIMEOUTS, BB_stateStartTime, BB_currentStateTimeout
    
    if (!BB_running || BB_paused) {
        BB_updateStatusAndLog("Automation loop skipped (not running or paused)")
        return
    }
    
    ; Check for state timeout
    if (BB_automationState != "Idle" && BB_automationState != "Mining") {
        if (A_TickCount - BB_stateStartTime > BB_currentStateTimeout) {
            BB_updateStatusAndLog("State timeout reached for " . BB_automationState, true, true)
            BB_FAILED_INTERACTION_COUNT++
            BB_setState("Error")
            return
        }
    }
    
    gameStateEnsured := false
    BB_updateStatusAndLog("Starting automation cycle, gameStateEnsured reset")
    
    windows := BB_updateActiveWindows()
    if (windows.Length == 0) {
        BB_updateStatusAndLog("No Roblox windows found")
        return
    }
    
    ; Loops through the windows and performs the automation cycle.
    for hwnd in windows {
        if (!BB_running || BB_paused) {
            BB_updateStatusAndLog("Automation loop interrupted")
            break
        }
        if !BB_robustWindowActivation(hwnd) {
            BB_FAILED_INTERACTION_COUNT++
            BB_updateStatusAndLog("Skipping window due to activation failure")
            continue
        }
        Sleep(500)
        
        if BB_checkForError(hwnd) {
            BB_setState("Error")
            continue
        }
        
        ; Switches through the automation states.
        switch BB_automationState {
            case "Idle":
                BB_updateStatusAndLog("Starting new cycle...")
                if BB_checkAutofarming(hwnd) {
                    BB_updateStatusAndLog("Autofarming is active, disabling...")
                    BB_setState("DisableAutomine")
                } else {
                    BB_updateStatusAndLog("Autofarming not active, proceeding with cycle")
                    BB_setState("DisableAutomine")  ; Still go through disable to ensure clean state
                }
            
            case "DisableAutomine":
                if BB_isAutofarming {
                    if BB_disableAutomine(hwnd) {
                        BB_updateStatusAndLog("Autofarming disabled, teleporting to Area 4")
                        Sleep(1000)  ; Wait for mining effects to stop
                        BB_setState("TeleportToArea4")
                    } else {
                        BB_FAILED_INTERACTION_COUNT++
                        BB_setState("Error")
                    }
                } else {
                    BB_updateStatusAndLog("Autofarming already disabled, teleporting to Area 4")
                    BB_setState("TeleportToArea4")
                }
            
            case "TeleportToArea4":
                if BB_openTeleportMenu(hwnd) {
                    Sleep(1000)  ; Wait for menu to open
                    if BB_teleportToArea("area_4_button", hwnd) {
                        BB_updateStatusAndLog("Teleported to Area 4, walking to merchant")
                        Sleep(5000)  ; Wait for teleport to complete
                        BB_setState("WalkToMerchant")
                    } else {
                        BB_FAILED_INTERACTION_COUNT++
                        BB_setState("Error")
                    }
                } else {
                    BB_FAILED_INTERACTION_COUNT++
                    BB_setState("Error")
                }
            
            case "WalkToMerchant":
                if (BB_walkToMerchant(hwnd)) {
                    BB_merchantState := "Interacted"
                    BB_setState("Shopping")
                } else {
                    BB_FAILED_INTERACTION_COUNT++
                    BB_setState("Error")
                }
            
            case "Shopping":
                if BB_buyMerchantItems(hwnd) {
                    BB_updateStatusAndLog("Shopping complete, closing merchant")
                    Sleep(1000)  ; Wait for purchases to complete
                    SendInput("{e down}")  ; Close merchant with 'e' key
                    Sleep(100)
                    SendInput("{e up}")
                    Sleep(2000)  ; Wait for merchant to close
                    BB_setState("TeleportToArea5")
                } else {
                    BB_FAILED_INTERACTION_COUNT++
                    BB_setState("Error")
                }
            
            case "TeleportToArea5":
                if BB_openTeleportMenu(hwnd) {
                    Sleep(1000)  ; Wait for menu to open
                    if BB_teleportToArea("area_5_button", hwnd) {
                        BB_updateStatusAndLog("Teleported to Area 5, enabling automining")
                        Sleep(5000)  ; Wait for teleport to complete
                        BB_setState("EnableAutomine")
                    } else {
                        BB_FAILED_INTERACTION_COUNT++
                        BB_setState("Error")
                    }
                } else {
                    BB_FAILED_INTERACTION_COUNT++
                    BB_setState("Error")
                }
            
            case "EnableAutomine":
                if BB_enableAutomine(hwnd) {
                    BB_updateStatusAndLog("Automining enabled, starting mining phase")
                    BB_setState("Mining")
                } else {
                    BB_FAILED_INTERACTION_COUNT++
                    BB_setState("Error")
                }
            
            case "Mining":
                BB_updateStatusAndLog("Mining in Area 5 for ~3 minutes")
                startTime := A_TickCount
                while (A_TickCount - startTime < BB_CYCLE_INTERVAL) {
                    if (!BB_running || BB_paused) {
                        BB_updateStatusAndLog("Mining interrupted")
                        break
                    }
                    if BB_checkForError(hwnd) {
                        BB_setState("Error")
                        break
                    }
                    Sleep(5000)
                }
                BB_setState("Idle")  ; Start new cycle
            
            case "Error":
                if (BB_FAILED_INTERACTION_COUNT >= BB_MAX_FAILED_INTERACTIONS) {
                    BB_updateStatusAndLog("Too many failed interactions, attempting reset", true, true)
                    if BB_resetGameState() {
                        BB_ERROR_RETRY_ATTEMPTS := 0  ; Reset retry counter after successful reset
                        BB_setState("Idle")
                    } else {
                        BB_stopAutomation()
                    }
                } else {
                    ; Dynamic retry with increasing delays
                    BB_ERROR_RETRY_ATTEMPTS++
                    
                    ; Calculate exponential backoff delay
                    retryDelay := BB_ERROR_BASE_DELAY * (BB_ERROR_BACKOFF_FACTOR ** (BB_ERROR_RETRY_ATTEMPTS - 1))
                    
                    ; Cap the maximum delay at 30 seconds
                    retryDelay := Min(retryDelay, 30000)
                    
                    BB_updateStatusAndLog("Recovering from error state, retry attempt " . BB_ERROR_RETRY_ATTEMPTS . 
                        " with " . (retryDelay / 1000) . "s delay", true)
                    
                    ; Wait with the dynamic delay before retrying
                    Sleep(retryDelay)
                    
                    ; If we've reached max retries, attempt a reset
                    if (BB_ERROR_RETRY_ATTEMPTS >= BB_ERROR_MAX_RETRIES) {
                        BB_updateStatusAndLog("Reached maximum retry attempts (" . BB_ERROR_MAX_RETRIES . 
                            "), attempting reset", true, true)
                        if BB_resetGameState() {
                            BB_ERROR_RETRY_ATTEMPTS := 0  ; Reset retry counter
                            BB_setState("Idle")
                        } else {
                            BB_stopAutomation()
                        }
                    } else {
                        BB_setState("Idle")
                    }
                }
        }
    }
}

; ===================== ANTI-AFK AND RECONNECT FUNCTIONS =====================
; Reconnects to the game if the connection is lost.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Checks if the script is running and not paused

BB_reconnectCheckLoop() {
    global BB_running, BB_paused
    if (!BB_running || BB_paused)
        return
    windows := BB_updateActiveWindows()
    if (windows.Length = 0) {
        BB_updateStatusAndLog("No Roblox windows found, waiting for reconnect")
    }
}

; ===================== UTILITY FUNCTIONS =====================
; Loads the configuration from a file.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Loads the configuration from a file

BB_loadConfigFromFile(*) {
    BB_loadConfig()
    MsgBox("Configuration reloaded from " . BB_CONFIG_FILE)
}
; Exits the application.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Sets the running state to false
;   - Stops all timers
BB_exitApp(*) {
    global BB_running
    BB_running := false
    SetTimer(BB_miningAutomationLoop, 0)
    SetTimer(BB_reconnectCheckLoop, 0)
    SetTimer(BB_bombLoop, 0)
    SetTimer(BB_tntCrateLoop, 0)
    SetTimer(BB_tntBundleLoop, 0)
    BB_updateStatusAndLog("Script terminated")
    ExitApp()
}

; Checks if automining is currently active in the game.
; Parameters:
;   hwnd: The handle of the Roblox window to check.
; Returns: True if automining is on, False if it's off.
; Notes:
;   - Critical function for determining mining automation state
;   - Uses a multi-layered detection approach in order of reliability:
;     1. Movement detection (most reliable indicator of active mining)
;     2. Template-based status indicator detection via BB_checkAutomineStatus
;   - Maintains global BB_isAutofarming state for other functions
;   - Falls back to conservative OFF assumption when detection methods fail
;   - Provides detailed logging of detection process for troubleshooting
BB_checkAutofarming(hwnd, takeScreenshot := false) {
    global BB_updateStatusAndLog, BB_isAutofarming

    ; First check for movement which is the most reliable indicator
    if (BB_detectMovement(hwnd)) {
        BB_updateStatusAndLog("Detected pixel movement - Autofarming is ON")
        BB_isAutofarming := true
        return true
    }
    
    ; If no movement detected, try improved automine status detection
    if (BB_checkAutomineStatus(hwnd)) {
        return BB_isAutofarming  ; Return the state determined by BB_checkAutomineStatus
    }
    
    ; If all detection methods failed, assume it's OFF
    BB_updateStatusAndLog("Unable to detect autofarming state, assuming OFF", true)
    BB_isAutofarming := false
    return false
}

; Improved function to check automine status using multiple detection methods
; Parameters:
;   hwnd: The handle of the Roblox window to check
; Returns: True if detection succeeded (regardless of on/off state), False if detection failed
; Notes:
;   - Secondary detection layer called by BB_checkAutofarming when movement detection fails
;   - Implements four distinct detection approaches in sequence:
;     1. Template matching for active automine indicator (ON)
;     2. Template matching for inactive automine indicator (OFF)
;     3. Automine button location + status dot color detection
;     4. Direct pixel scanning for status indicator colors
;   - Provides extensive logging for troubleshooting detection failures
;   - Sets global BB_isAutofarming state based on best available information
;   - More reliable than single-method detection approaches
BB_checkAutomineStatus(hwnd) {
    global BB_isAutofarming, BB_updateStatusAndLog, BB_TEMPLATE_FOLDER
    
    BB_updateStatusAndLog("Checking automine status with improved detection...")
    
    ; Get window position and size
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    if (!winW || !winH) {
        BB_updateStatusAndLog("Failed to get window dimensions for automine status check", true)
        return false
    }
    
    ; Define search area for the automine button (bottom left corner)
    searchArea := [
        winX + 20,                  ; Left edge with small margin
        winY + (winH - 200),        ; Bottom area, not too close to edge
        winX + 150,                 ; Limited width search
        winY + winH - 20            ; Stop just before bottom edge
    ]
    
    ; Method 1: Try to find ON state template with high transparency
    FoundX := -1
    FoundY := -1
    if (BB_smartTemplateMatch("autofarm_on", &FoundX, &FoundY, hwnd, searchArea, 60)) {
        BB_updateStatusAndLog("Found autofarm ON indicator at x=" . FoundX . ", y=" . FoundY)
        BB_isAutofarming := true
        return true
    }
    
    ; Method 2: Try to find OFF state template with high transparency
    FoundX := -1
    FoundY := -1
    if (BB_smartTemplateMatch("autofarm_off", &FoundX, &FoundY, hwnd, searchArea, 60)) {
        BB_updateStatusAndLog("Found autofarm OFF indicator at x=" . FoundX . ", y=" . FoundY)
        BB_isAutofarming := false
        return true
    }
    
    ; Method 3: Find the automine button first, then check the color of the status dot
    FoundX := -1
    FoundY := -1
    
    ; Try to find the automine button (will use both template and pixel methods)
    if (BB_smartTemplateMatch("automine_button", &FoundX, &FoundY, hwnd, searchArea, 40)) {
        BB_updateStatusAndLog("Found automine button at x=" . FoundX . ", y=" . FoundY)
        
        ; Look for the status dot relative to the found button
        ; Typical offset from button top-left to status dot (adjust based on your template)
        dotOffsetX := 25
        dotOffsetY := 25
        
        try {
            ; Check color of the status indicator
            dotX := FoundX + dotOffsetX
            dotY := FoundY + dotOffsetY
            
            ; Make sure the coordinates are within window bounds
            if (dotX >= winX && dotX <= winX + winW && dotY >= winY && dotY <= winY + winH) {
                dotColor := PixelGetColor(dotX, dotY, "RGB")
                
                ; Use the global status color variables
                colorTolerance := BB_COLOR_MATCH_THRESHOLD
                
                ; Check if dot color indicates ON (green) or OFF (red)
                if (BB_isColorSimilar(dotColor, greenColor, colorTolerance)) {
                    BB_updateStatusAndLog("Status dot is GREEN (ON) at x=" . dotX . ", y=" . dotY)
                    BB_isAutofarming := true
                    return true
                } else if (BB_isColorSimilar(dotColor, redColor, colorTolerance)) {
                    BB_updateStatusAndLog("Status dot is RED (OFF) at x=" . dotX . ", y=" . dotY)
                    BB_isAutofarming := false
                    return true
                } else {
                    BB_updateStatusAndLog("Status dot color unrecognized: " . Format("0x{:06X}", dotColor), true)
                    ; Continue to try other methods
                }
            }
        } catch as err {
            BB_updateStatusAndLog("Error checking status dot: " . err.Message, true)
            ; Continue to try other methods
        }
    }
    
    ; Method 4: Direct pixel scanning
    ; Define characteristics of the status indicator
    greenDotColor := 0x00FF00  ; Pure green for ON (example)
    redDotColor := 0xFF0000    ; Pure red for OFF (example)
    colorTolerance := 40
    
    ; Scan the search area for status indicator colors
    y := searchArea[2]
    while (y <= searchArea[4]) {
        x := searchArea[1]
        while (x <= searchArea[3]) {
            try {
                currentColor := PixelGetColor(x, y, "RGB")
                
                ; Check if color matches green or red status indicator
                if (BB_isColorSimilar(currentColor, greenDotColor, colorTolerance)) {
                    ; Verify this is truly a status indicator by checking surrounding pixels
                    if (BB_verifyColorCluster(x, y, currentColor, colorTolerance, 2, 3)) {
                        BB_updateStatusAndLog("Found green status indicator by pixel scanning at x=" . x . ", y=" . y)
                        BB_isAutofarming := true
                        return true
                    }
                } else if (BB_isColorSimilar(currentColor, redDotColor, colorTolerance)) {
                    if (BB_verifyColorCluster(x, y, currentColor, colorTolerance, 2, 3)) {
                        BB_updateStatusAndLog("Found red status indicator by pixel scanning at x=" . x . ", y=" . y)
                        BB_isAutofarming := false
                        return true
                    }
                }
            } catch as err {
                ; Skip errors and continue
            }
            
            x += 5  ; Step size, check every 5th pixel (adjust as needed)
        }
        
        y += 5  ; Step size
    }
    
    BB_updateStatusAndLog("Automine status detection failed with all methods", true)
    return false
}

; Improved template matching function with performance optimizations
; Now uses caching to avoid repeated template matching for the same template in quick succession
; Parameters:
;   templateName: The name of the template to match.
;   FoundX: Output variable for the found X coordinate.
;   FoundY: Output variable for the found Y coordinate.
;   hwnd: The handle of the window to search in.
;   searchRegion: Optional array containing [x1, y1, x2, y2] coordinates for the search region.
;   variationPercent: Tolerance for image variations (default: 30)
; Returns: True if the template is found, False otherwise.
; Notes:
;   - Core image recognition function used throughout the script
;   - Uses an adaptive multi-method approach with different tolerance levels
;   - Implements intelligent caching to reduce unnecessary searches
;   - Tracks performance metrics for each template type
;   - Prioritizes critical templates with additional search attempts
;   - Works with transparent PNG templates for better recognition
;   - Automatically scales coordinates to match window dimensions
;   - Handles errors gracefully to prevent script crashes
BB_smartTemplateMatch(templateName, &FoundX, &FoundY, hwnd := 0, searchRegion := 0, variationPercent := 30) {
    global BB_TEMPLATE_FOLDER, BB_TEMPLATE_SUCCESS_METRIC
    global BB_performanceData
    static templateCache := Map()
    static lastMatchTime := Map()
    static cacheTimeout := 3000  ; Cache results for 3 seconds
    
    ; Initialize result variables
    FoundX := -1
    FoundY := -1
    
    ; Handle case when no hwnd is provided
    if (!hwnd) {
        hwnd := WinGetID("A")  ; Get active window
        if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayerBeta.exe") {
            BB_updateStatusAndLog("No Roblox window active for template matching: " . templateName, true, true)
            return false
        }
    }
    
    ; Get cache key that includes template name and window handle
    cacheKey := templateName . ":" . hwnd
    
    ; Check if we have a recent result for this template+window in cache
    currentTime := A_TickCount
    if (lastMatchTime.Has(cacheKey) && (currentTime - lastMatchTime[cacheKey] < cacheTimeout)) {
        if (templateCache.Has(cacheKey)) {
            cacheResult := templateCache[cacheKey]
            if (cacheResult.found) {
                FoundX := cacheResult.x
                FoundY := cacheResult.y
                BB_updateStatusAndLog("Using cached result for template '" . templateName . "' [Cache age: " . 
                                      (currentTime - lastMatchTime[cacheKey]) . "ms]")
                return true
            } else {
                BB_updateStatusAndLog("Using cached negative result for template '" . templateName . "' [Cache age: " . 
                                      (currentTime - lastMatchTime[cacheKey]) . "ms]")
                return false
            }
        }
    }
    
    startTime := A_TickCount
    
    ; Define the template file path
    templateFile := BB_TEMPLATE_FOLDER . "\" . templateName . ".png"
    if (!FileExist(templateFile)) {
        BB_updateStatusAndLog("Template file not found: " . templateFile, true, true)
        
        ; Cache the negative result
        templateCache[cacheKey] := {found: false}
        lastMatchTime[cacheKey] := currentTime
        
        return false
    }
    
    ; Get window position
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    
    ; Default search region is the entire window
    if (!IsObject(searchRegion) || !searchRegion.Length) {
        searchRegion := [winX, winY, winX + winW, winY + winH]
    }
    
    ; Ensure values are integers for *ImageSearch
    for i, val in searchRegion
        searchRegion[i] := Round(val)
    
    ; Method 1: Try with specified variation first (faster)
    try {
        if (ImageSearch(&FoundX, &FoundY, searchRegion[1], searchRegion[2], searchRegion[3], searchRegion[4], 
                      "*" . variationPercent . " " . templateFile)) {
            elapsed := A_TickCount - startTime
            
            ; Track performance metrics for template matching
            if (!BB_performanceData["TemplateMatch"].Has(templateName)) {
                BB_performanceData["TemplateMatch"][templateName] := elapsed
            } else {
                ; Average with previous times (weighted toward recent results)
                BB_performanceData["TemplateMatch"][templateName] := 
                    (BB_performanceData["TemplateMatch"][templateName] * 0.7) + (elapsed * 0.3)
            }
            
            BB_updateStatusAndLog("Found template '" . templateName . "' at x=" . FoundX . ", y=" . FoundY . 
                                 " [Method 1, Time: " . elapsed . "ms]")
            
            ; Cache the result
            templateCache[cacheKey] := {found: true, x: FoundX, y: FoundY}
            lastMatchTime[cacheKey] := currentTime
            
            return true
        }
    } catch as err {
        BB_updateStatusAndLog("Error in template match method 1: " . err.Message, true, true)
    }
    
    ; Method 2: Try with lower variation if first method fails
    try {
        if (ImageSearch(&FoundX, &FoundY, searchRegion[1], searchRegion[2], searchRegion[3], searchRegion[4], 
                      "*" . (variationPercent - 10) . " " . templateFile)) {
            elapsed := A_TickCount - startTime
            
            ; Track performance metrics
            if (!BB_performanceData["TemplateMatch"].Has(templateName)) {
                BB_performanceData["TemplateMatch"][templateName] := elapsed
            } else {
                BB_performanceData["TemplateMatch"][templateName] := 
                    (BB_performanceData["TemplateMatch"][templateName] * 0.7) + (elapsed * 0.3)
            }
            
            BB_updateStatusAndLog("Found template '" . templateName . "' at x=" . FoundX . ", y=" . FoundY . 
                                 " [Method 2, Time: " . elapsed . "ms]")
            
            ; Cache the result
            templateCache[cacheKey] := {found: true, x: FoundX, y: FoundY}
            lastMatchTime[cacheKey] := currentTime
            
            return true
        }
    } catch as err {
        BB_updateStatusAndLog("Error in template match method 2: " . err.Message, true, true)
    }
    
    ; For critical templates, try a third time with higher variation
    if (BB_TEMPLATE_SUCCESS_METRIC.Has(templateName) && BB_TEMPLATE_SUCCESS_METRIC[templateName] > 0.7) {
        try {
            if (ImageSearch(&FoundX, &FoundY, searchRegion[1], searchRegion[2], searchRegion[3], searchRegion[4], 
                          "*" . (variationPercent + 10) . " " . templateFile)) {
                elapsed := A_TickCount - startTime
                
                ; Track performance
                if (!BB_performanceData["TemplateMatch"].Has(templateName)) {
                    BB_performanceData["TemplateMatch"][templateName] := elapsed
                } else {
                    BB_performanceData["TemplateMatch"][templateName] := 
                        (BB_performanceData["TemplateMatch"][templateName] * 0.7) + (elapsed * 0.3)
                }
                
                BB_updateStatusAndLog("Found template '" . templateName . "' at x=" . FoundX . ", y=" . FoundY . 
                                    " [Method 3, Time: " . elapsed . "ms]")
                
                ; Cache the result
                templateCache[cacheKey] := {found: true, x: FoundX, y: FoundY}
                lastMatchTime[cacheKey] := currentTime
                
                return true
            }
        } catch as err {
            BB_updateStatusAndLog("Error in template match method 3: " . err.Message, true, true)
        }
    }
    
    elapsed := A_TickCount - startTime
    BB_updateStatusAndLog("Failed to find template '" . templateName . "' [Time: " . elapsed . "ms]", true, true)
    
    ; Cache the negative result
    templateCache[cacheKey] := {found: false}
    lastMatchTime[cacheKey] := currentTime
    
    return false
}

; Validation function for error templates
; Parameters:
;   x: The x-coordinate of the match.
;   y: The y-coordinate of the match.
;   color1: The first color to compare.
;   color2: The second color to compare.
; Returns: The difference between the two colors.
; Notes:
;   - Calculates the difference between two colors
BB_colorDifference(color1, color2) {
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF
    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF
    return Abs(r1 - r2) + Abs(g1 - g2) + Abs(b1 - b2)
}

; Helper function: Verify if a pixel is part of a color cluster (to avoid false positives)
; Parameters:
;   x: The x-coordinate of the pixel.
;   y: The y-coordinate of the pixel.
;   targetColor: The color to verify.
;   tolerance: The tolerance for color similarity.
;   radius: The radius of the grid to search.
;   requiredMatches: The number of matches required to verify the color cluster.
BB_verifyColorCluster(x, y, targetColor, tolerance, radius := 3, requiredMatches := 5) {
    matches := 0
    
    ; Check a small grid around the pixel
    offsetX := -radius
    while (offsetX <= radius) {
        offsetY := -radius
        while (offsetY <= radius) {
            try {
                checkColor := PixelGetColor(x + offsetX, y + offsetY, "RGB")
                if (BB_isColorSimilar(checkColor, targetColor, tolerance)) {
                    matches++
                    if (matches >= requiredMatches) {
                        return true
                    }
                }
            } catch {
                ; Skip errors (e.g., out-of-bounds pixel access)
                offsetY++
                continue
            }
            offsetY++
        }
        offsetX++
    }
    
    return false
}

; Helper function: Check if colors are similar within tolerance
; Parameters:
;   color1: The first color to compare.
;   color2: The second color to compare.
;   tolerance: The tolerance for color similarity.
; Returns: True if the colors are similar, False otherwise.
; Notes:
;   - Extracts RGB components and checks if each component is within tolerance
BB_isColorSimilar(color1, color2, tolerance := 20) {
    ; Extract RGB components
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF
    
    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF
    
    ; Check if each component is within tolerance
    return (Abs(r1 - r2) <= tolerance) && (Abs(g1 - g2) <= tolerance) && (Abs(b1 - b2) <= tolerance)
}

; Helper function: Detect UI elements by analyzing screen structure
; Parameters:
;   searchArea: The area to search for UI elements.
;   FoundX: The x-coordinate of the found match.
;   FoundY: The y-coordinate of the found match.
BB_detectUIElements(searchArea, &FoundX, &FoundY) {
    ; Set initial values
    FoundX := 0
    FoundY := 0
    
    ; Define parameters for UI detection
    stepSize := 10
    lineLength := 40
    colorVariance := 15
    
    ; Look for horizontal lines (common in UI elements)
    y := searchArea[2]
    while (y <= searchArea[4]) {
        x := searchArea[1]
        while (x <= searchArea[3] - lineLength) {
            try {
                baseColor := PixelGetColor(x, y, "RGB")
                lineConsistent := true
                
                ; Check if we have a consistent horizontal line
                i := 1
                while (i <= lineLength) {
                    checkColor := PixelGetColor(x + i, y, "RGB")
                    if (!BB_isColorSimilar(baseColor, checkColor, colorVariance)) {
                        lineConsistent := false
            break
                    }
                    i++
                }
                
                ; If we found a consistent line, check if it's likely a UI element
                if (lineConsistent) {
                    ; Check for color contrast above and below the line
                    aboveColor := PixelGetColor(x + (lineLength // 2), y - 5, "RGB")
                    belowColor := PixelGetColor(x + (lineLength // 2), y + 5, "RGB")
                    
                    if (!BB_isColorSimilar(baseColor, aboveColor, colorVariance) || 
                        !BB_isColorSimilar(baseColor, belowColor, colorVariance)) {
                        ; This might be a UI border!
                        FoundX := x + (lineLength // 2)
                        FoundY := y
                        BB_updateStatusAndLog("Potential UI element detected at x=" . FoundX . ", y=" . FoundY)
                        return true
                    }
                }
            } catch {
                ; Continue on error (e.g., out-of-bounds pixel access)
                x += stepSize
            continue
            }
            x += stepSize
        }
        y += stepSize
    }
    
    ; Look for vertical lines (also common in UI elements)
    x := searchArea[1]
    while (x <= searchArea[3]) {
        y := searchArea[2]
        while (y <= searchArea[4] - lineLength) {
            try {
                baseColor := PixelGetColor(x, y, "RGB")
                lineConsistent := true
                
                ; Check if we have a consistent vertical line
                i := 1
                while (i <= lineLength) {
                    checkColor := PixelGetColor(x, y + i, "RGB")
                    if (!BB_isColorSimilar(baseColor, checkColor, colorVariance)) {
                        lineConsistent := false
                break
                    }
                    i++
                }
                
                ; If we found a consistent line, check if it's likely a UI element
                if (lineConsistent) {
                    ; Check for color contrast to the left and right of the line
                    leftColor := PixelGetColor(x - 5, y + (lineLength // 2), "RGB")
                    rightColor := PixelGetColor(x + 5, y + (lineLength // 2), "RGB")
                    
                    if (!BB_isColorSimilar(baseColor, leftColor, colorVariance) || 
                        !BB_isColorSimilar(baseColor, rightColor, colorVariance)) {
                        ; This might be a UI border!
                        FoundX := x
                        FoundY := y + (lineLength // 2)
                        BB_updateStatusAndLog("Potential UI element detected at x=" . FoundX . ", y=" . FoundY)
                        return true
                    }
                }
            } catch {
                ; Continue on error
                y += stepSize ; Increment y by stepSize
                continue
            }
            y += stepSize ; Increment y by stepSize
        }
        x += stepSize ; Increment x by stepSize
    }
    ;
    return false
}

; ===================== INITIALIZATION =====================

; BB_setupGUI() ; Setup the GUI - Already called at line 99, removing duplicate call
BB_loadConfig() ; Load the config
BB_checkForUpdates() ; Check for updates

; Set up debug mode based on command line parameters
if (A_Args.Length > 0 && A_Args[1] = "debug") {
    BB_DEBUG["enabled"] := true
    BB_DEBUG["level"] := 5
    
    ; Register debug hotkeys
    Hotkey("F6", (*) => BB_debugHotkeyHandler("screenshot"))
    Hotkey("F7", (*) => BB_debugHotkeyHandler("hatchmenu"))
    Hotkey("F8", (*) => BB_debugHotkeyHandler("automine"))
    Hotkey("F9", (*) => BB_debugHotkeyHandler("status"))
    Hotkey("F10", (*) => BB_debugHotkeyHandler("metrics"))
    Hotkey("F11", (*) => BB_debugHotkeyHandler("nextLevel"))
    Hotkey("F12", (*) => BB_debugHotkeyHandler("toggleDebug"))
    
    BB_updateStatusAndLog("Debug mode enabled - Level: " . BB_DEBUG["level"], true, true)
    TrayTip("Debug Mode Enabled", "Press F6-F12 for debug functions", 0x10)
} else {
    BB_DEBUG["enabled"] := false
    BB_updateStatusAndLog("Running in standard mode")
}

Hotkey("F1", BB_startAutomation)  ; Add F1 to start automation
Hotkey(BB_BOMB_HOTKEY, (*) => (hwnd := WinGetID("A"), BB_useBomb(hwnd))) ; Use bomb
Hotkey(BB_TNT_CRATE_HOTKEY, (*) => (hwnd := WinGetID("A"), BB_useTntCrate(hwnd))) ; Use TNT crate
Hotkey(BB_TNT_BUNDLE_HOTKEY, (*) => (hwnd := WinGetID("A"), BB_useTntBundle(hwnd))) ; Use TNT bundle
; SetTimer(BB_antiAfkLoop, BB_ANTI_AFK_INTERVAL) ; Start anti-AFK timer - Moved to BB_startAutomation
BB_updateStatusAndLog("Anti-AFK timer will start when automation begins") ; Update status and log
BB_updateStatusAndLog("Explosives hotkeys bound successfully") ; Update status and log
BB_updateStatusAndLog("Script initialized. Press F1 to start automation.") ; Update status and log

TrayTip("Initialized! Press F1 to start.", "🐝 BeeBrained's PS99 Mining Event Macro", 0x10)

; Performance Tracking
; We already initialized BB_performanceData globally, don't reinitialize it here
; global BB_performanceData := Map()       ; Performance metrics tracking

; ===================== FUNCTION DEFINITIONS =====================

; Verifies that the merchant menu is open.
; Parameters:
;   hwnd: The window handle to use.
; Returns:
;   true if the merchant menu is open, false otherwise.
BB_verifyMerchantMenuOpen(hwnd) {
    loop 3 {
        if (BB_smartTemplateMatch("merchant_window", &FoundX, &FoundY, hwnd)) {
            BB_updateStatusAndLog("Merchant menu verified open at x=" . FoundX . ", y=" . FoundY)
            return true
        }
        Sleep(1000)
    }
    BB_updateStatusAndLog("Merchant menu not found after 3 attempts", true)
    return false
}

; Finds and clicks a template in the game window.
; Parameters:
;   templateName: The name of the template to find and click.
;   hwnd: The window handle to use.
; Returns:
;   true if successful, false otherwise.
BB_findAndClickTemplate(templateName, hwnd) {
    FoundX := ""
    FoundY := ""
    
    if BB_smartTemplateMatch(templateName, &FoundX, &FoundY, hwnd) {
        BB_clickAt(FoundX, FoundY)
        BB_updateStatusAndLog("Clicked template '" . templateName . "' at x=" . FoundX . ", y=" . FoundY)
        return true
    }
    
    BB_updateStatusAndLog("Failed to find template '" . templateName . "'", true, true)
    return false
}

; New function to verify Area 4
BB_verifyArea4(hwnd) {
    global BB_AREA4_COLOR_RANGES, BB_COLOR_MATCH_THRESHOLD, BB_BRIGHTNESS_DARK_THRESHOLD
    global BB_BRIGHTNESS_BRIGHT_THRESHOLD, BB_PATTERN_MATCH_CONFIDENCE, BB_AREA_VERIFY_CONFIDENCE
    global BB_COLOR_CLUSTER_THRESHOLD
    
    BB_updateStatusAndLog("Verifying Area 4 with enhanced detection...")
    
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Invalid window handle for Area 4 verification", true)
        return false
    }
    
    verificationMethods := 0
    verificationSuccess := 0
    
    ; Method 1: Primary template detection - Area 4 marker
    verificationMethods++
    if (BB_smartTemplateMatch("area_4_marker", &FoundX, &FoundY, hwnd)) {
        verificationSuccess++
        BB_updateStatusAndLog("Area 4 verified via visual marker at x=" . FoundX . ", y=" . FoundY)
    } else {
        BB_updateStatusAndLog("Area 4 marker template not found")
    }
    
    ; Method 2: Secondary template detection - Mining merchant
    verificationMethods++
    if (BB_smartTemplateMatch("mining_merchant", &FoundX, &FoundY, hwnd)) {
        verificationSuccess++
        BB_updateStatusAndLog("Area 4 verified via merchant presence at x=" . FoundX . ", y=" . FoundY)
    } else {
        BB_updateStatusAndLog("Mining merchant template not found")
    }
    
    ; Method 3: Dynamic color fingerprinting for Area 4
    verificationMethods++
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    
    ; Define a more comprehensive set of sampling points for better coverage
    samplePoints := [
        [winX + winW/2, winY + winH/4],       ; Top middle
        [winX + winW/2, winY + winH/2],       ; Center
        [winX + winW/4, winY + winH/2],       ; Left middle
        [winX + 3*winW/4, winY + winH/2],     ; Right middle
        [winX + winW/2, winY + 3*winH/4],     ; Bottom middle
        [winX + winW/3, winY + winH/3],       ; Upper left diagonal
        [winX + 2*winW/3, winY + 2*winH/3]    ; Lower right diagonal
    ]
    
    colorMatches := Map()
    totalSamples := samplePoints.Length * BB_AREA4_COLOR_RANGES.Length
    matchCount := 0
    
    BB_updateStatusAndLog("Analyzing " . samplePoints.Length . " points across " . BB_AREA4_COLOR_RANGES.Length . " color ranges")
    
    for pointIndex, point in samplePoints {
        try {
            pixelColor := PixelGetColor(point[1], point[2], "RGB")
            BB_updateStatusAndLog("Sample point " . pointIndex . " [" . Round(point[1] - winX) . "," . Round(point[2] - winY) . "] color: " . Format("0x{:06X}", pixelColor))
            
            for rangeIndex, colorRange in BB_AREA4_COLOR_RANGES {
                rangeMin := colorRange[1][1]
                rangeMax := colorRange[1][2]
                rangeDesc := colorRange[2]
                
                colorDiff1 := ColorDistance(pixelColor, rangeMin)
                colorDiff2 := ColorDistance(pixelColor, rangeMax)
                bestDiff := Min(colorDiff1, colorDiff2)
                
                ; Using configurable threshold value
                if (bestDiff < BB_COLOR_MATCH_THRESHOLD) {
                    matchCount++
                    BB_updateStatusAndLog("Color match: " . rangeDesc . " (diff: " . Round(bestDiff) . ")")
                    
                    ; Track which ranges matched
                    if (!colorMatches.Has(rangeDesc))
                        colorMatches[rangeDesc] := 0
                    colorMatches[rangeDesc]++
                    
                    ; No need to check other ranges for this point if we found a match
                    break
                }
            }
        } catch as err {
            BB_updateStatusAndLog("Error checking pixel at [" . point[1] . "," . point[2] . "]: " . err.Message, true)
        }
    }
    
    ; Calculate confidence percentage based on match coverage across sampling points
    matchConfidence := (matchCount / samplePoints.Length) * 100
    
    BB_updateStatusAndLog("Color analysis results: " . matchCount . " matches out of " . samplePoints.Length . " points (" . Round(matchConfidence) . "% confidence)")
    
    ; For detailed logging, show which color ranges matched
    for rangeName, count in colorMatches {
        BB_updateStatusAndLog("Color range '" . rangeName . "' matched " . count . " times")
    }
    
    ; Consider color analysis successful if we have at least configured confidence or 3+ matches
    if (matchConfidence >= BB_PATTERN_MATCH_CONFIDENCE || matchCount >= 3) {
        verificationSuccess++
        BB_updateStatusAndLog("Area 4 verified via color analysis with " . Round(matchConfidence) . "% confidence")
    }
    
    ; Method 4: Pattern recognition for Area 4's characteristic layout
    verificationMethods++
    layoutFeatures := 0
    
    ; Check for horizontal cave pattern (more open darker space at bottom of screen)
    try {
        bottomRowY := winY + (winH * 0.85)
        brightSpots := 0
        darkSpots := 0
        
        loop 10 {
            i := A_Index - 1  ; i will range from 0 to 9
            x := winX + (winW * (i / 10))
            try {
                color := PixelGetColor(x, bottomRowY, "RGB")
                brightness := ((color & 0xFF) + ((color >> 8) & 0xFF) + ((color >> 16) & 0xFF)) / 3
                
                if (brightness < BB_BRIGHTNESS_DARK_THRESHOLD)
                    darkSpots++
                else if (brightness > BB_BRIGHTNESS_BRIGHT_THRESHOLD)
                    brightSpots++
            } catch as err {
                continue
            }
        }
        
        if (darkSpots >= 5) {  ; Area 4 typically has darker bottom area
            layoutFeatures++
            BB_updateStatusAndLog("Layout feature: Bottom cave pattern detected (" . darkSpots . " dark spots)")
        }
    } catch as err {
        BB_updateStatusAndLog("Error checking horizontal pattern: " . err.Message, true)
    }
    
    ; Check for vertical wall pattern
    try {
        rightColumnX := winX + (winW * 0.8)
        sameColorCount := 0
        prevColor := 0
        
        loop 5 {
            i := A_Index + 2  ; i will range from 3 to 7
            y := winY + (winH * (i / 10))
            try {
                color := PixelGetColor(rightColumnX, y, "RGB")
                
                if (prevColor != 0) {
                    if (ColorDistance(color, prevColor) < BB_COLOR_CLUSTER_THRESHOLD)
                        sameColorCount++
                }
                
                prevColor := color
            } catch as err {
                continue
            }
        }
        
        if (sameColorCount >= 3) {  ; Vertical wall consistency
            layoutFeatures++
            BB_updateStatusAndLog("Layout feature: Vertical wall pattern detected (" . sameColorCount . " consistent colors)")
        }
    } catch as err {
        BB_updateStatusAndLog("Error checking vertical pattern: " . err.Message, true)
    }
    
    ; Check for overhead cave pattern (darker at top)
    try {
        topRowY := winY + (winH * 0.15)
        darkPixels := 0
        
        loop 10 {
            i := A_Index - 1  ; i will range from 0 to 9
            x := winX + (winW * (i / 10))
            try {
                color := PixelGetColor(x, topRowY, "RGB")
                brightness := ((color & 0xFF) + ((color >> 8) & 0xFF) + ((color >> 16) & 0xFF)) / 3
                
                if (brightness < 100)
                    darkPixels++
            } catch as err {
                continue
            }
        }
        
        if (darkPixels >= 4) {  ; Area 4 often has darker ceiling
            layoutFeatures++
            BB_updateStatusAndLog("Layout feature: Overhead cave pattern detected (" . darkPixels . " dark pixels)")
        }
    } catch as err {
        BB_updateStatusAndLog("Error checking overhead pattern: " . err.Message, true)
    }
    
    ; Consider pattern analysis successful if we found at least 2 layout features
    if (layoutFeatures >= 2) {
        verificationSuccess++
        BB_updateStatusAndLog("Area 4 verified via pattern recognition (" . layoutFeatures . " features)")
    }
    
    ; Make final determination based on verification methods
    successRate := (verificationSuccess / verificationMethods) * 100
    
    BB_updateStatusAndLog("Area 4 verification: " . verificationSuccess . "/" . verificationMethods . 
                         " methods succeeded (" . Round(successRate) . "% confidence)")
    
    ; Success if over configured threshold% of methods succeeded
    if (successRate >= BB_AREA_VERIFY_CONFIDENCE) {
        BB_updateStatusAndLog("Area 4 verified with " . Round(successRate) . "% confidence")
        return true
    } else {
        BB_updateStatusAndLog("Area 4 verification failed with only " . Round(successRate) . "% confidence", true)
        return false
    }
}

; Fixes the camera view by centering it
; Parameters:
;   hwnd: The handle of the Roblox window
BB_fixCameraView(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Invalid window handle for camera reset", true)
        return false
    }
    
    BB_updateStatusAndLog("Resetting camera view...")
    
    ; Get window position and size
    WinGetPos(&winX, &winY, &winWidth, &winHeight, "ahk_id " . hwnd)
    if (!winWidth || !winHeight) {
        BB_updateStatusAndLog("Failed to get window dimensions", true)
        return false
    }
    
    ; Calculate center of window
    centerX := winX + (winWidth / 2)
    centerY := winY + (winHeight / 2)
    
    ; Move mouse to center
    if (!BB_clickAt(centerX, centerY)) {
        BB_updateStatusAndLog("Failed to move mouse to center", true)
        return false
    }
    Sleep(100)
    
    ; Right click and hold
    Click("right down")
    Sleep(100)
    
    ; Move mouse to reset view
    MouseMove(centerX + 100, centerY, 2, "R")
    Sleep(100)
    
    ; Release right click
    Click("right up")
    Sleep(100)
    
    BB_updateStatusAndLog("Camera view reset complete")
    return true
}

; Walks to and interacts with the merchant
; Parameters:
;   hwnd: The handle of the Roblox window
; Returns: True if merchant menu opens, False otherwise
BB_walkToMerchant(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Invalid window handle for merchant interaction", true)
        return false
    }

    ; First, fix the camera view
    if (!BB_fixCameraView(hwnd)) {
        BB_updateStatusAndLog("Failed to fix camera view", true)
        return false
    }

    ; Try to find merchant directly
    if (BB_smartTemplateMatch("mining_merchant", &FoundX, &FoundY, hwnd)) {
        BB_updateStatusAndLog("Merchant found, clicking...")
        if (!BB_clickAt(FoundX, FoundY)) {
            BB_updateStatusAndLog("Failed to click merchant location", true)
            return false
        }
        
        Sleep(2000)  ; Wait for any movement to complete
        
        ; Press E to interact
        Send("{e down}")
        Sleep(100)
        Send("{e up}")
        
        ; Verify merchant menu opened
        return BB_verifyMerchantMenuOpen(hwnd)
    }
    
    ; If merchant not found, try walking forward
    BB_updateStatusAndLog("Merchant not found, attempting to walk forward")
    
    ; Walk forward for 3 seconds
    Send("{w down}")
    Sleep(3000)
    Send("{w up}")
    Sleep(1000)  ; Wait for movement to stop
    
    ; Try interacting
    Send("{e down}")
    Sleep(100)
    Send("{e up}")
    
    ; Final verification
    if (BB_verifyMerchantMenuOpen(hwnd)) {
        BB_updateStatusAndLog("Successfully opened merchant menu")
        return true
    }
    
    BB_updateStatusAndLog("Failed to interact with merchant", true)
    return false
}

; Add function to get performance statistics
BB_getPerformanceStats() {
    stats := "Performance Statistics:`n"
    stats .= "Click Operations: " . Round(BB_performanceData["ClickAt"]) . "ms avg`n"
    stats .= "Movement Checks: " . Round(BB_performanceData["MovementCheck"]) . "ms avg`n"
    stats .= "Merchant Interactions: " . Round(BB_performanceData["MerchantInteract"]) . "ms avg`n"
    stats .= "Block Detection: " . Round(BB_performanceData["BlockDetection"]) . "ms avg`n"
    
    stats .= "`nTemplate Matching Times:`n"
    for templateName, time in BB_performanceData["TemplateMatch"] {
        stats .= templateName . ": " . Round(time) . "ms avg`n"
    }
    
    return stats
}

; ===================== UTILITY FUNCTIONS =====================

; Scales coordinates based on current screen resolution
; Parameters:
;   x: The x-coordinate to scale (relative to window)
;   y: The y-coordinate to scale (relative to window)
; Returns: Array containing scaled [x, y] coordinates
; Notes:
;   - Applies global BB_SCALE_X and BB_SCALE_Y factors to coordinates
;   - Rounds results to ensure integer pixel values
;   - Used to adjust coordinates for different screen resolutions
;   - Ensures consistent positioning across different display setups
BB_scaleCoordinates(x, y) {
    global BB_SCALE_X, BB_SCALE_Y
    return [Round(x * BB_SCALE_X), Round(y * BB_SCALE_Y)]
}

; Scales a single coordinate based on current screen resolution
; Parameters:
;   value: The value to scale
;   isX: True to scale by X factor, False to scale by Y factor
; Returns: Scaled value (integer)
; Notes:
;   - Applies BB_SCALE_X or BB_SCALE_Y factor based on isX parameter
;   - Rounds result to ensure integer pixel values
;   - Utility function for one-dimensional scaling operations
BB_scaleValue(value, isX := true) {
    global BB_SCALE_X, BB_SCALE_Y
    return Round(value * (isX ? BB_SCALE_X : BB_SCALE_Y))
}

; Scales a region array [x1, y1, x2, y2] based on current screen resolution
; Parameters:
;   region: Array containing [x1, y1, x2, y2] coordinates
; Returns: Array containing scaled coordinates
; Notes:
;   - Applies appropriate scaling factors to each coordinate
;   - Used for scaling search regions for template matching
;   - Ensures scaled regions are properly aligned with screen elements
;   - Returns integer values for all coordinates
BB_scaleRegion(region) {
    return [
        BB_scaleValue(region[1], true),
        BB_scaleValue(region[2], false),
        BB_scaleValue(region[3], true),
        BB_scaleValue(region[4], false)
    ]
}

; Specialized function to find the automine button using pixel-based detection
; This is used as a fallback when template matching fails
; Parameters:
;   hwnd: The handle of the Roblox window to search in
;   FoundX: Output variable for the found X coordinate
;   FoundY: Output variable for the found Y coordinate
; Returns: True if button is found, False otherwise
BB_findAutomineButtonByPixel(hwnd, &FoundX, &FoundY) {
    global BB_PICKAXE_COLORS, BB_STATUS_GREEN, BB_STATUS_RED, BB_COLOR_CLUSTER_THRESHOLD
    static lastFoundCoords := {}, cacheTimeout := 30000 ; Cache timeout in ms
    
    ; Initialize output variables
    FoundX := -1
    FoundY := -1
    
    ; Get window position and size
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    if (!winW || !winH) {
        BB_updateStatusAndLog("Failed to get window dimensions for pixel detection", true)
        return false
    }
    
    ; Check cache first - if we found this button recently, try that position first
    if (lastFoundCoords.HasOwnProp("hwnd") && lastFoundCoords.hwnd = hwnd 
        && lastFoundCoords.HasOwnProp("timestamp") 
        && A_TickCount - lastFoundCoords.timestamp < cacheTimeout) {
        
        ; Check if coordinates are within window bounds
        if (lastFoundCoords.x >= winX && lastFoundCoords.x <= winX + winW &&
            lastFoundCoords.y >= winY && lastFoundCoords.y <= winY + winH) {
                
            BB_updateStatusAndLog("Trying cached automine button location at x=" . lastFoundCoords.x . ", y=" . lastFoundCoords.y)
            
            ; Verify the cached location still has matching colors
            try {
                currentColor := PixelGetColor(lastFoundCoords.x, lastFoundCoords.y, "RGB")
                
                ; Check if color still matches a pickaxe color
                pickaxeFound := false
                for pickaxeColor in BB_PICKAXE_COLORS {
                    if (BB_isColorSimilar(currentColor, pickaxeColor, 40)) {
                        pickaxeFound := true
                        break
                    }
                }
                
                if (pickaxeFound && BB_verifyColorCluster(lastFoundCoords.x, lastFoundCoords.y, currentColor, 40, 3, 3)) {
                    FoundX := lastFoundCoords.x
                    FoundY := lastFoundCoords.y
                    BB_updateStatusAndLog("Automine button found at cached position: x=" . FoundX . ", y=" . FoundY)
                    
                    ; Update timestamp to extend cache validity
                    lastFoundCoords.timestamp := A_TickCount
                    return true
                } else {
                    BB_updateStatusAndLog("Cached position no longer valid, performing full scan")
                }
            } catch as err {
                BB_updateStatusAndLog("Error checking cached position: " . err.Message, true)
            }
        }
    }
    
    ; Set search area to bottom-left portion of the window where automine button usually is
    searchStartX := winX + 20
    searchEndX := winX + 150
    searchStartY := winY + (winH - 200)
    searchEndY := winY + winH - 20
    
    ; Use configurable colors for detection
    colorTolerance := 40       ; Tolerance for color matching
    
    BB_updateStatusAndLog("Searching for automine button by pixel in area: " . 
        searchStartX . "," . searchStartY . " to " . searchEndX . "," . searchEndY)
    
    ; Initial step sizes for scanning - will be adjusted dynamically
    initialStepX := 15
    initialStepY := 15
    minStepX := 2
    minStepY := 2
    
    ; Configure adaptive scanning strategy
    ; First, scan with larger steps to quickly cover the area
    stepX := initialStepX
    stepY := initialStepY
    
    ; Perform multi-pass scan with decreasing step sizes
    loop 3 {
        currentPass := A_Index
        BB_updateStatusAndLog("Pixel scan pass " . currentPass . " with step size X=" . stepX . ", Y=" . stepY)
        
        ; Start position depends on the pass to avoid sampling the same pixels
        offsetX := Mod(currentPass-1, stepX)
        offsetY := Mod(currentPass-1, stepY)
        
        ; Look for potential pickaxe colors
        y := searchStartY + offsetY
        while (y <= searchEndY) {
            x := searchStartX + offsetX
            while (x <= searchEndX) {
                try {
                    currentColor := PixelGetColor(x, y, "RGB")
                    
                    ; Check if this pixel matches any of our expected pickaxe colors
                    pickaxeFound := false
                    for pickaxeColor in BB_PICKAXE_COLORS {
                        if (BB_isColorSimilar(currentColor, pickaxeColor, colorTolerance)) {
                            pickaxeFound := true
                            break
                        }
                    }
                    
                    if (pickaxeFound) {
                        ; Potential pickaxe found, look for status dot nearby
                        BB_updateStatusAndLog("Potential pickaxe pixel found at x=" . x . ", y=" . y)
                        
                        ; Adaptive grid checking - use more checks for later passes
                        gridPoints := currentPass == 1 ? [-15, 0, 15] : [-15, -10, -5, 0, 5, 10, 15]
                        
                        ; Check a grid around the found pixel for the status dot
                        for offsetY in gridPoints {
                            for offsetX in gridPoints {
                                try {
                                    checkX := x + offsetX
                                    checkY := y + offsetY
                                    
                                    if (checkX < searchStartX || checkX > searchEndX || 
                                        checkY < searchStartY || checkY > searchEndY) {
                                        continue  ; Skip if outside search area
                                    }
                                    
                                    dotColor := PixelGetColor(checkX, checkY, "RGB")
                                    
                                    ; Check if this pixel is similar to green or red (status dot)
                                    if (BB_isColorSimilar(dotColor, BB_STATUS_GREEN, colorTolerance) || 
                                        BB_isColorSimilar(dotColor, BB_STATUS_RED, colorTolerance)) {
                                        
                                        ; Found potential status dot near pickaxe pixel
                                        BB_updateStatusAndLog("Found potential status dot at x=" . checkX . ", y=" . checkY)
                                        
                                        ; Verify this is likely the button by checking for a cluster of similar colors
                                        if (BB_verifyColorCluster(x, y, currentColor, colorTolerance, 3, 3)) {
                                            FoundX := x
                                            FoundY := y
                                            BB_updateStatusAndLog("Automine button found by pixel detection at x=" . FoundX . ", y=" . FoundY)
                                            
                                            ; Cache successful result
                                            lastFoundCoords := {
                                                hwnd: hwnd,
                                                x: x,
                                                y: y,
                                                timestamp: A_TickCount
                                            }
                                            
                                            return true
                                        }
                                    }
                                } catch as err {
                                    ; Skip errors (e.g., out-of-bounds pixel access)
                                    continue
                                }
                            }
                        }
                    }
                } catch as err {
                    ; Skip errors (e.g., out-of-bounds pixel access)
                    BB_updateStatusAndLog("Error during pixel check: " . err.Message, true)
                }
                
                x += stepX
            }
            
            y += stepY
        }
        
        ; Reduce step size for next pass for more detailed scanning
        stepX := Max(minStepX, Floor(stepX / 2))
        stepY := Max(minStepY, Floor(stepY / 2))
        
        ; If we've already found it, no need for additional passes
        if (FoundX > 0 && FoundY > 0) {
            break
        }
    }
    
    BB_updateStatusAndLog("No automine button found by pixel detection")
    return false
}

; Debug hotkey handler function
BB_debugHotkeyHandler(action) {
    global BB_DEBUG
    hwnd := WinGetID("A")
    
    switch action {
        case "screenshot":
            BB_captureScreenForDebug(hwnd, "debug_manual_capture.png")
            BB_updateStatusAndLog("Debug: Manual screenshot captured")
        
        case "hatchmenu":
            isHatchMenu := BB_detectHatchMenu(hwnd, true)
            BB_updateStatusAndLog("Debug: Hatch menu detection result: " . (isHatchMenu ? "Found" : "Not Found"))
        
        case "automine":
            isAutofarming := BB_checkAutofarming(hwnd)
            BB_updateStatusAndLog("Debug: Autofarming status: " . (isAutofarming ? "ON" : "OFF"))
        
        case "status":
            statusMsg := "Current State: " . BB_automationState . "`n"
            statusMsg .= "Running: " . (BB_running ? "Yes" : "No") . "`n"
            statusMsg .= "Paused: " . (BB_paused ? "Yes" : "No") . "`n"
            statusMsg .= "Autofarming: " . (BB_isAutofarming ? "Yes" : "No") . "`n"
            statusMsg .= "Current Area: " . BB_currentArea . "`n"
            statusMsg .= "Explosives: " . (BB_ENABLE_EXPLOSIVES ? "Enabled" : "Disabled")
            MsgBox(statusMsg, "Automation Status", 0x40)
        
        case "metrics":
            MsgBox(BB_getPerformanceStats(), "Performance Metrics", 0x40)
        
        case "nextLevel":
            BB_DEBUG["level"] := Mod(BB_DEBUG["level"], 5) + 1
            BB_updateStatusAndLog("Debug level changed to: " . BB_DEBUG["level"])
        
        case "toggleDebug":
            BB_DEBUG["enabled"] := !BB_DEBUG["enabled"]
            BB_updateStatusAndLog("Debug mode " . (BB_DEBUG["enabled"] ? "enabled" : "disabled"))
    }
}

; Captures a screenshot for debugging purposes
BB_captureScreenForDebug(hwnd, filename := "") {
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Invalid window handle for screenshot", true)
        return false
    }
    
    debugFolder := A_ScriptDir . "\debug_screenshots"
    if !DirExist(debugFolder) {
        DirCreate(debugFolder)
    }
    
    if (filename == "") {
        filename := "debug_" . FormatTime(, "yyyyMMdd_HHmmss") . ".png"
    }
    
    fullPath := debugFolder . "\" . filename
    
    try {
        WinGetPos(&winX, &winY, &winWidth, &winHeight, "ahk_id " . hwnd)
        pToken := Gdip_Startup()
        pBitmap := Gdip_BitmapFromScreen(winX . "|" . winY . "|" . winWidth . "|" . winHeight)
        Gdip_SaveBitmapToFile(pBitmap, fullPath)
        Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)
        BB_updateStatusAndLog("Debug screenshot saved to: " . fullPath)
        return true
    } catch as err {
        BB_updateStatusAndLog("Error taking screenshot: " . err.Message, true)
        return false
    }
}

; Helper function to calculate the distance between two RGB colors
; Parameters:
;   color1: First RGB color (format: 0xRRGGBB)
;   color2: Second RGB color (format: 0xRRGGBB)
; Returns: A value representing the distance between the colors
ColorDistance(color1, color2) {
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF
    
    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF
    
    return Sqrt((r2-r1)**2 + (g2-g1)**2 + (b2-b1)**2)
}
