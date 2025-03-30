#Requires AutoHotkey v2.0
; 🐝 BeeBrained's PS99 Master Automation Tool (BMAT) 🐝
; Version 2.0.0
; Last Updated: March 30, 2025
;
; A versatile automation powerhouse built for efficiency and flexibility,
; perfect for repetitive tasks in Pet Simulator 99 and beyond.
;
; Repository: https://github.com/xXGeminiXx/BeesPS99MasterAutomation
;
; Created by: BeeBrained
; YouTube: @BeeBrained-PS99
; Discord: Hive Hangout (https://discord.gg/QVncFccwek)

; ===================== SCRIPT INITIALIZATION =====================
#SingleInstance Force
DetectHiddenWindows True
SetWorkingDir A_ScriptDir

; Set coordinate modes
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
SendMode("Event")

; Create logs directory if it doesn't exist
if !DirExist(A_ScriptDir "\logs")
    DirCreate(A_ScriptDir "\logs")

; Initialize BB_DEBUG early before it's used in any functions
global BB_DEBUG := Map(
    "enabled", true,  ; Enable debug by default
    "level", 6,       ; Set to maximum debug level
    "logTemplateMatches", true,
    "logPerformance", true,
    "logWindowUpdates", true,
    "saveScreenshots", true
)

; Version information
BB_VERSION := "2.0.0"

; ===================== GLOBAL VARIABLES =====================
; File System
global BB_CONFIG_FILE := A_ScriptDir "\bmat_config.ini"
global BB_LOG_FILE := A_ScriptDir "\logs\log_" . FormatTime(, "yyyyMMdd") . ".txt"
global BB_TEMPLATE_DIR := A_ScriptDir "\templates"
global BB_CONFIG_DIR := A_ScriptDir "\configs"
global BB_TEMPLATE_FOLDER := A_ScriptDir "\templates"
global BB_BACKUP_TEMPLATE_FOLDER := A_ScriptDir "\backup_templates"

; Create necessary directories
for dir in [BB_TEMPLATE_DIR, BB_CONFIG_DIR, BB_BACKUP_TEMPLATE_FOLDER] {
    if !DirExist(dir)
        DirCreate(dir)
}

; Ensure config file exists with proper settings
if !FileExist(BB_CONFIG_FILE) {
    defaultIni := "[Logging]`n"
    defaultIni .= "ENABLE_LOGGING=true`n"
    defaultIni .= "`n[Debug]`n"
    defaultIni .= "ENABLED=true`n"
    defaultIni .= "LEVEL=6`n"
    defaultIni .= "LOG_TEMPLATE_MATCHES=true`n"
    defaultIni .= "LOG_PERFORMANCE=true`n"
    defaultIni .= "LOG_WINDOW_UPDATES=true`n"
    defaultIni .= "SAVE_SCREENSHOTS=true`n"
    
    try {
        FileAppend(defaultIni, BB_CONFIG_FILE)
    } catch as err {
        MsgBox("Failed to create default config file: " . err.Message, "Config Error", 0x10)
    }
}

; State Management
global BB_automationState := "Idle"  ; Idle, Interacting, Processing, Navigating, Error
global BB_isRunning := false
global BB_isPaused := false
global BB_debugMode := false
global BB_lastWindowCheck := 0
global BB_activeWindows := []
global BB_currentWindow := 0
global BB_FAILED_INTERACTION_COUNT := 0
global BB_lastInteractionTime := 0
global BB_stateHistory := []
global BB_gameStateEnsured := false
global BB_lastGameStateReset := 0
global BB_currentState := "Unknown"
global BB_lastError := "None"

; GUI Elements
global BB_mainGui := ""
global BB_statusText := ""
global BB_debugText := ""
global BB_configDropdown := ""
global BB_commandPanel := ""
global BB_debugControls := Map()

; Error Handling
global BB_MAX_FAILED_INTERACTIONS := 5
global BB_ERROR_COLORS := ["0xFF0000", "0x990000"]
global BB_ERROR_COLOR_THRESHOLD := 15
global BB_ERROR_BASE_DELAY := 1000      ; Base delay of 1 second
global BB_ERROR_BACKOFF_FACTOR := 2     ; Double delay each retry
global BB_ERROR_MAX_RETRIES := 5        ; Maximum retry attempts
global BB_ERROR_RETRY_ATTEMPTS := 0     ; Current retry attempt count
global BB_ERROR_MAX_DELAY := 30000      ; Maximum delay cap (30 seconds)

; Performance and Caching
global BB_performanceStats := Map()
global BB_templateCache := Map()
global BB_TEMPLATES := Map()
global BB_missingTemplatesReported := Map()
global BB_imageCache := Map()
global BB_performanceData := Map()
global BB_TEMPLATE_SUCCESS_METRIC := Map()

; Version and Core State
global BB_VERSION := "2.0.0"
global BB_running := false
global BB_paused := false
global BB_SAFE_MODE := false
global BB_ENABLE_LOGGING := true
global BB_logFile := A_ScriptDir "\bmat_log.txt"

; Hotkeys
global BB_TELEPORT_HOTKEY := "t"
global BB_INVENTORY_HOTKEY := "f"
global BB_START_STOP_HOTKEY := "F2"
global BB_PAUSE_HOTKEY := "p"
global BB_EXIT_HOTKEY := "Escape"
global BB_JUMP_HOTKEY := "Space"

; State Timeouts
global BB_STATE_TIMEOUTS := Map(
    "Idle", 30000,            ; 30 seconds
    "Interacting", 30000,     ; 30 seconds
    "Navigating", 30000,      ; 30 seconds
    "Processing", 60000,      ; 60 seconds
    "Error", 30000            ; 30 seconds
)
global BB_stateStartTime := 0
global BB_currentStateTimeout := 0
global BB_GAME_STATE_COOLDOWN := 30000  ; 30 seconds cooldown

; Resolution Scaling
global BB_BASE_WIDTH := 1920
global BB_BASE_HEIGHT := 1080
global BB_SCALE_X := 1.0
global BB_SCALE_Y := 1.0
global BB_SCREEN_WIDTH := A_ScreenWidth
global BB_SCREEN_HEIGHT := A_ScreenHeight

; Timing and Intervals
global BB_CLICK_DELAY_MIN := 500        ; 0.5 seconds
global BB_CLICK_DELAY_MAX := 1500       ; 1.5 seconds
global BB_INTERACTION_DURATION := 5000  ; 5 seconds
global BB_CYCLE_INTERVAL := 180000      ; 3 minutes
global BB_ANTI_AFK_INTERVAL := 300000   ; 5 minutes
global BB_RECONNECT_CHECK_INTERVAL := 10000  ; 10 seconds
global BB_WINDOW_CHECK_INTERVAL := 5000  ; 5 seconds

; Window Management
global BB_WINDOW_TITLE := "Roblox"
global BB_EXCLUDED_TITLES := []
global BB_active_windows := []
global BB_last_window_check := 0

; Template Management
global BB_TEMPLATE_RETRIES := 3
global BB_validTemplates := 0
global BB_totalTemplates := 0

; ===================== RUN AS ADMIN =====================

if !A_IsAdmin {
    Run("*RunAs " . A_ScriptFullPath)
    ExitApp()
}

; ===================== GLOBAL VARIABLES =====================
; Version and Core State
global BB_VERSION := "2.0.0"
global BB_running := false
global BB_paused := false
global BB_SAFE_MODE := false
global BB_ENABLE_LOGGING := true
global BB_FAILED_INTERACTION_COUNT := 0  ; Tracks failed interactions for error recovery
global BB_logFile := A_ScriptDir "\bmat_log.txt"
global BB_myGUI := ""  ; Initialize GUI object

; Hotkeys
global BB_TELEPORT_HOTKEY := "t"
global BB_INVENTORY_HOTKEY := "f"
global BB_START_STOP_HOTKEY := "F2"
global BB_PAUSE_HOTKEY := "p"
global BB_EXIT_HOTKEY := "Escape"
global BB_JUMP_HOTKEY := "Space"

; Initialize GUI first
BB_setupGUI()  ; Init the GUI

; Other init
BB_loadConfig() ; Load the config

; Register hotkeys based on config
BB_registerHotkeys()

TrayTip("Initialized! Press " . BB_START_STOP_HOTKEY . " to start.", "🐝 BeeBrained's PS99 Automation", 0x10)

; State Timeouts
global BB_STATE_TIMEOUTS := Map(
    "Idle", 30000,            ; 30 seconds
    "Interacting", 30000,     ; 30 seconds
    "Navigating", 30000,      ; 30 seconds
    "Processing", 60000,      ; 60 seconds
    "Error", 30000            ; 30 seconds
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
global BB_INTERACTION_DURATION := 5000  ; 5 seconds
global BB_CYCLE_INTERVAL := 180000      ; 3 minutes
global BB_ANTI_AFK_INTERVAL := 300000   ; 5 minutes
global BB_RECONNECT_CHECK_INTERVAL := 10000  ; 10 seconds

; File System and Logging
global BB_TEMPLATE_FOLDER := A_ScriptDir "\templates"
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
global BB_currentState := "Unknown"
global BB_lastError := "None"

; Performance Monitoring
global BB_performanceData := Map(
    "ClickAt", 0,
    "TemplateMatch", Map(),
    "MovementCheck", 0,
    "StateTransition", 0
)

; Template Success Metrics - Used to determine which templates are critical
; Higher values (>0.7) indicate critical templates that warrant extra matching attempts
global BB_TEMPLATE_SUCCESS_METRIC := Map(
    "button", 0.9,
    "menu_button", 0.8,
    "dialog_button", 0.85,
    "error_message", 0.75,
    "navigation_button", 0.8
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

[Window]
WINDOW_TITLE=Roblox
EXCLUDED_TITLES=Roblox Account Manager

[Features]
SAFE_MODE=false
ENABLE_AUTO_RECONNECT=true

[Templates]
button=button.png
menu_button=menu_button.png
dialog_button=dialog_button.png
error_message=error_message.png
connection_lost=connection_lost.png
navigation_button=navigation_button.png

[Hotkeys]
; Modified hotkey format: Use ^ for CTRL, ! for ALT, + for SHIFT, # for WIN
; Single letters/keys don't need special formatting (e.g., t, f, p, etc.)
TELEPORT_HOTKEY=t
INVENTORY_HOTKEY=f
START_STOP_HOTKEY=F2
PAUSE_HOTKEY=p
EXIT_HOTKEY=Escape
JUMP_HOTKEY=Space

[Colors]
; Color format: 0xRRGGBB (hex)
ERROR_RED_1=0xFF0000
ERROR_RED_2=0xE31212
ERROR_RED_3=0xC10000
STATUS_GREEN=0x00FF00
STATUS_RED=0xFF0000

[Thresholds]
; Various threshold values used in color matching and detection
COLOR_MATCH_THRESHOLD=70
COLOR_CLUSTER_THRESHOLD=50
ERROR_COLOR_THRESHOLD=50
MOVEMENT_THRESHOLD=2
BRIGHTNESS_DARK_THRESHOLD=80
BRIGHTNESS_BRIGHT_THRESHOLD=140
PATTERN_MATCH_CONFIDENCE=40

[Retries]
TEMPLATE_RETRIES=3
MAX_FAILED_INTERACTIONS=5

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
    global BB_ENABLE_LOGGING, BB_logFile, BB_myGUI, BB_lastError
    global BB_FAILED_INTERACTION_COUNT
    static firstRun := true
    
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
                        newLogFile := A_ScriptDir "\bmat_log_" . timestamp . ".txt"
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
    
    ; Safely update GUI if it exists and updateGUI is true
    if (updateGUI && IsSet(BB_myGUI) && IsObject(BB_myGUI)) {
        try {
            BB_myGUI["Status"].Text := (BB_running ? (BB_paused ? "Paused" : "Running") : "Idle")
            BB_myGUI["Status"].SetFont(BB_running ? (BB_paused ? "cOrange" : "cGreen") : "cRed")
            BB_myGUI["WindowCount"].Text := BB_active_windows.Length
            BB_myGUI["AutomationStatus"].Text := (BB_running ? (BB_paused ? "PAUSED" : "RUNNING") : "OFF")
            BB_myGUI["AutomationStatus"].SetFont(BB_running ? (BB_paused ? "cOrange" : "cGreen") : "cRed")
            BB_myGUI["TemplateStatus"].Text := BB_validTemplates . "/" . BB_totalTemplates
            BB_myGUI["TemplateStatus"].SetFont(BB_validTemplates = BB_totalTemplates ? "cGreen" : "cRed")
            BB_myGUI["CurrentState"].Text := BB_automationState
            BB_myGUI["FailedCount"].Text := BB_FAILED_INTERACTION_COUNT
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
    local localPath := BB_TEMPLATE_DIR "\" fileName
    local backupPath := BB_BACKUP_TEMPLATE_FOLDER "\" fileName
    local templateUrl := "https://raw.githubusercontent.com/xXGeminiXx/BeesPS99MasterAutomation/main/templates/" . fileName

    try {
        ; First check if template exists and is valid
        if FileExist(localPath) {
            validationResult := BB_validateImage(localPath)
            if (validationResult = "Valid" || InStr(validationResult, "Assumed Valid")) {
                BB_updateStatusAndLog("Template already exists and is valid: " . fileName)
                return true
            }
            BB_updateStatusAndLog("Existing template invalid: " . validationResult . " - Attempting redownload", true, true)
        }

        ; Download template
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
    
    ; Create a more robust PowerShell command with error handling and TLS 1.2
    psCommand := "
    (
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
        try {
            $ProgressPreference = 'SilentlyContinue';
            $wc = New-Object System.Net.WebClient;
            $wc.Headers.Add('User-Agent', 'PowerShell/7.0');
            $wc.DownloadFile('" . url . "', '" . dest . "');
            if (Test-Path '" . dest . "') {
                $size = (Get-Item '" . dest . "').Length;
                if ($size -gt 0) { exit 0; }
                else { Write-Error 'Downloaded file is empty'; exit 1; }
            }
            else { Write-Error 'File not created'; exit 1; }
        }
        catch {
            Write-Error $_.Exception.Message;
            exit 1;
        }
    )"
    
    try {
        SplitPath(dest, , &dir)
        if !DirExist(dir) {
            DirCreate(dir)
            BB_updateStatusAndLog("Created directory: " . dir)
        }
        
        exitCode := RunWait('PowerShell -NoProfile -ExecutionPolicy Bypass -Command "' . psCommand . '"', , "Hide")
        if (exitCode != 0) {
            throw Error("PowerShell exited with code " . exitCode)
        }
        
        if FileExist(dest) {
            fileSize := FileGetSize(dest)
            if (fileSize > 0) {
                BB_updateStatusAndLog("Download succeeded using PowerShell => " . dest . " (Size: " . fileSize . " bytes)")
                Sleep(1000)
                return true
            }
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
    if (!hwnd || WinGetProcessName(hwnd) != "RobloxPlayEerBeta.exe") {
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
    global BB_ANTI_AFK_INTERVAL, BB_RECONNECT_CHECK_INTERVAL
    global BB_SAFE_MODE
    global BB_TELEPORT_HOTKEY, BB_INVENTORY_HOTKEY, BB_START_STOP_HOTKEY, BB_PAUSE_HOTKEY, BB_EXIT_HOTKEY, BB_JUMP_HOTKEY
    global BB_performanceData
    global BB_ENABLE_LOGGING  ; Just declare, don't initialize here
    
    ; Load logging settings
    BB_ENABLE_LOGGING := IniRead(BB_CONFIG_FILE, "Logging", "ENABLE_LOGGING", true)
    
    ; Color globals
    global BB_ERROR_COLORS, BB_STATUS_GREEN, BB_STATUS_RED
    
    ; Threshold globals
    global BB_COLOR_MATCH_THRESHOLD, BB_COLOR_CLUSTER_THRESHOLD, BB_ERROR_COLOR_THRESHOLD
    global BB_MOVEMENT_THRESHOLD, BB_BRIGHTNESS_DARK_THRESHOLD, BB_BRIGHTNESS_BRIGHT_THRESHOLD
    global BB_PATTERN_MATCH_CONFIDENCE
    
    ; File system globals
    global BB_CONFIG_FILE := A_ScriptDir "\bmat_config.ini"
    global BB_TEMPLATE_FOLDER := A_ScriptDir "\templates"
    global BB_BACKUP_TEMPLATE_FOLDER := A_ScriptDir "\backup_templates"

    if !FileExist(BB_CONFIG_FILE) {
        FileAppend(defaultIni, BB_CONFIG_FILE)
        BB_updateStatusAndLog("Created default bmat_config.ini")
    }

    if !DirExist(BB_TEMPLATE_FOLDER)
        DirCreate(BB_TEMPLATE_FOLDER)
    if !DirExist(BB_BACKUP_TEMPLATE_FOLDER)
        DirCreate(BB_BACKUP_TEMPLATE_FOLDER)

    BB_validTemplates := 0
    BB_totalTemplates := 0
    BB_TEMPLATES := Map()  ; Initialize BB_TEMPLATES as a Map before using it

    ; Initialize templates
    for templateName, fileName in Map(
        "button", "button.png",
        "menu_button", "menu_button.png",
        "dialog_button", "dialog_button.png",
        "error_message", "error_message.png",
        "error_message_alt1", "error_message_alt1.png",
        "connection_lost", "connection_lost.png",
        "navigation_button", "navigation_button.png"
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

    ; Always initialize BB_performanceData to ensure it exists
    BB_performanceData := Map(
        "ClickAt", 0,
        "TemplateMatch", Map(),
        "MovementCheck", 0,
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

    BB_SAFE_MODE := IniRead(BB_CONFIG_FILE, "Features", "SAFE_MODE", false)

    ; Load all hotkeys
    BB_TELEPORT_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "TELEPORT_HOTKEY", "t")
    BB_INVENTORY_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "INVENTORY_HOTKEY", "f")
    BB_START_STOP_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "START_STOP_HOTKEY", "F2")
    BB_PAUSE_HOTKEY := IniRead(BB_CONFIG_FILE, "Hotkeys", "PAUSE_HOTKEY", "p")
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

    BB_updateStatusAndLog("Loaded configuration values from " . BB_CONFIG_FILE)
}

; ===================== GUI SETUP =====================
BB_setupGUI() {
    global BB_mainGui, BB_statusText, BB_debugText, BB_configDropdown, BB_commandPanel, BB_debugControls
    
    ; Create main GUI window
    BB_mainGui := Gui("+Resize +MinSize400x600", "BMAT v" . BB_VERSION)
    
    ; Status section
    BB_mainGui.Add("GroupBox", "x10 y10 w380 h100", "Status")
    BB_statusText := BB_mainGui.Add("Text", "x20 y30 w360 h70", "Initializing...")
    
    ; Command panel
    BB_mainGui.Add("GroupBox", "x10 y120 w380 h280", "Command Panel")
    BB_commandPanel := BB_mainGui.Add("ListView", "x20 y140 w360 h250", ["Command", "Status"])
    
    ; Configuration section
    BB_mainGui.Add("GroupBox", "x10 y410 w380 h90", "Configuration")
    BB_mainGui.Add("Text", "x20 y430 w80 h20", "Config Preset:")
    BB_configDropdown := BB_mainGui.Add("DropDownList", "x100 y430 w200", BB_getConfigPresets())
    BB_mainGui.Add("Button", "x310 y430 w70 h25", "Save").OnEvent("Click", BB_saveConfigButtonClick)
    BB_mainGui.Add("Button", "x20 y460 w180 h30", "Load Selected Config").OnEvent("Click", BB_loadConfigButtonClick)
    BB_mainGui.Add("Button", "x210 y460 w170 h30", "Reset to Default").OnEvent("Click", BB_resetConfigButtonClick)
    
    ; Debug controls
    BB_mainGui.Add("GroupBox", "x10 y510 w380 h130", "Debug Controls")
    
    ; Debug level dropdown
    BB_mainGui.Add("Text", "x20 y530 w80 h20", "Debug Level:")
    BB_debugControls["levelDropdown"] := BB_mainGui.Add("DropDownList", "x100 y530 w60", ["1", "2", "3", "4", "5", "6"])
    BB_debugControls["levelDropdown"].Value := BB_DEBUG["level"]
    BB_debugControls["levelDropdown"].OnEvent("Change", BB_debugLevelChange)
    
    ; Debug toggle button
    BB_debugControls["toggleBtn"] := BB_mainGui.Add("Button", "x170 y530 w100 h25", BB_DEBUG["enabled"] ? "Debug ON" : "Debug OFF")
    BB_debugControls["toggleBtn"].OnEvent("Click", BB_debugToggleClick)
    
    ; Debug options
    BB_debugControls["templateLog"] := BB_mainGui.Add("Checkbox", "x20 y560 w160 h20", "Log Template Matches")
    BB_debugControls["templateLog"].Value := BB_DEBUG["logTemplateMatches"]
    BB_debugControls["templateLog"].OnEvent("Click", BB_debugOptionClick)
    
    BB_debugControls["perfLog"] := BB_mainGui.Add("Checkbox", "x190 y560 w160 h20", "Log Performance")
    BB_debugControls["perfLog"].Value := BB_DEBUG["logPerformance"]
    BB_debugControls["perfLog"].OnEvent("Click", BB_debugOptionClick)
    
    BB_debugControls["windowLog"] := BB_mainGui.Add("Checkbox", "x20 y585 w160 h20", "Log Window Updates")
    BB_debugControls["windowLog"].Value := BB_DEBUG["logWindowUpdates"]
    BB_debugControls["windowLog"].OnEvent("Click", BB_debugOptionClick)
    
    BB_debugControls["screenshots"] := BB_mainGui.Add("Checkbox", "x190 y585 w160 h20", "Save Screenshots")
    BB_debugControls["screenshots"].Value := BB_DEBUG["saveScreenshots"]
    BB_debugControls["screenshots"].OnEvent("Click", BB_debugOptionClick)
    
    ; Debug text area
    BB_debugText := BB_mainGui.Add("Edit", "x20 y610 w360 h20 +ReadOnly", "Debug Output")
    
    ; Show the GUI
    BB_mainGui.Show()
}

BB_debugLevelChange(ctrl, *) {
    BB_DEBUG["level"] := Integer(ctrl.Value)
    BB_log("Debug level changed to: " . BB_DEBUG["level"], 1)
    BB_updateDebugText("Debug level: " . BB_DEBUG["level"])
}

BB_debugToggleClick(ctrl, *) {
    BB_DEBUG["enabled"] := !BB_DEBUG["enabled"]
    ctrl.Text := BB_DEBUG["enabled"] ? "Debug ON" : "Debug OFF"
    BB_log("Debug mode " . (BB_DEBUG["enabled"] ? "enabled" : "disabled"), 1)
    BB_updateDebugText("Debug mode: " . (BB_DEBUG["enabled"] ? "ON" : "OFF"))
}

BB_debugOptionClick(ctrl, *) {
    switch ctrl.Name {
        case "templateLog":
            BB_DEBUG["logTemplateMatches"] := ctrl.Value
            setting := "Template match logging"
        case "perfLog":
            BB_DEBUG["logPerformance"] := ctrl.Value
            setting := "Performance logging"
        case "windowLog":
            BB_DEBUG["logWindowUpdates"] := ctrl.Value
            setting := "Window update logging"
        case "screenshots":
            BB_DEBUG["saveScreenshots"] := ctrl.Value
            setting := "Screenshot saving"
    }
    BB_log(setting . (ctrl.Value ? " enabled" : " disabled"), 1)
    BB_updateDebugText(setting . ": " . (ctrl.Value ? "ON" : "OFF"))
}

BB_updateDebugText(text) {
    if BB_debugText
        BB_debugText.Value := text
}

; ===================== HOTKEYS =====================
; Register all hotkeys dynamically after loading configuration
BB_registerHotkeys() {
    global BB_START_STOP_HOTKEY, BB_PAUSE_HOTKEY, BB_EXIT_HOTKEY, BB_INVENTORY_HOTKEY
    
    ; Main Control Hotkeys
    try {
        Hotkey(BB_START_STOP_HOTKEY, BB_stopAutomation)    ; Default: F2 - Start/Stop
        Hotkey(BB_PAUSE_HOTKEY, BB_togglePause)            ; Default: p - Pause/Resume
        Hotkey(BB_EXIT_HOTKEY, BB_exitApp)                 ; Default: Escape - Exit Application
        
        ; Game Interaction Hotkeys
        Hotkey(BB_INVENTORY_HOTKEY, BB_openInventory)      ; Default: f - Open Inventory
        
        BB_updateStatusAndLog("Registered all hotkeys successfully")
    } catch as err {
        BB_updateStatusAndLog("Error registering hotkeys: " . err.Message, true, true)
        MsgBox("Error registering hotkeys: " . err.Message . "`n`nPlease check your hotkey configuration in bmat_config.ini", "Hotkey Error", 0x10)
    }
}

; ===================== CORE FUNCTIONS =====================
BB_startAutomation(*) {
    global BB_running, BB_paused, BB_automationState
    global BB_ERROR_RETRY_ATTEMPTS, BB_myGUI
    
    if BB_running {
        BB_updateStatusAndLog("Already running, ignoring start request")
        return
    }
    BB_running := true
    BB_paused := false
    BB_automationState := "Idle"
    BB_ERROR_RETRY_ATTEMPTS := 0  ; Reset retry counter when starting automation
    
    BB_updateStatusAndLog("Starting automation...")
    SetTimer(BB_reconnectCheckLoop, BB_RECONNECT_CHECK_INTERVAL)
    SetTimer(BB_antiAfkLoop, BB_ANTI_AFK_INTERVAL) ; Start anti-AFK timer
    BB_updateStatusAndLog("Anti-AFK timer started with interval: " . BB_ANTI_AFK_INTERVAL . "ms")
    
    SetTimer(BB_automationLoop, 1000)
    BB_updateStatusAndLog("Automation loop started")
}
; Stops the mining automation.
; Parameters:
;   None
; Returns: None
; Notes:
;   - Stops all timers and resets the automation state
BB_stopAutomation(*) {
    global BB_running, BB_paused, BB_automationState
    BB_running := false
    BB_paused := false
    BB_automationState := "Idle"
    SetTimer(BB_automationLoop, 0)
    SetTimer(BB_reconnectCheckLoop, 0)
    SetTimer(BB_antiAfkLoop, 0) ; Stop anti-AFK timer
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
    global BB_active_windows, BB_last_window_check, BB_WINDOW_CHECK_INTERVAL
    global BB_WINDOW_TITLE, BB_EXCLUDED_TITLES
    
    ; Check if we need to update (5 second cooldown)
    if (A_TickCount - BB_last_window_check < BB_WINDOW_CHECK_INTERVAL)
        return BB_active_windows
    
    BB_last_window_check := A_TickCount
    BB_active_windows := []
    
    ; Get all windows with matching title
    windows := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    
    ; Sort windows to prioritize active window
    activeHwnd := WinGetID("A")
    if (activeHwnd && WinGetProcessName(activeHwnd) = "RobloxPlayerBeta.exe")
        BB_active_windows.Push(activeHwnd)
    
    ; Add other windows
    for hwnd in windows {
        if (hwnd != activeHwnd) {
            title := WinGetTitle("ahk_id " . hwnd)
            isExcluded := false
            for excludedTitle in BB_EXCLUDED_TITLES {
                if (InStr(title, excludedTitle)) {
                    isExcluded := true
                    break
                }
            }
            if (!isExcluded)
                BB_active_windows.Push(hwnd)
        }
    }
    
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
    
    ; Check specifically excluded titles
    for excluded in BB_EXCLUDED_TITLES {
        if InStr(title, excluded) {
            return true
        }
    }
    
    ; Additional browser detection patterns
    if (RegExMatch(title, " - Chrome$") || 
        RegExMatch(title, " - Edge$") ||
        RegExMatch(title, " - Firefox$") ||
        RegExMatch(title, " - Opera$") ||
        RegExMatch(title, " - Brave$") ||
        RegExMatch(title, " - Safari$") ||
        InStr(title, "Firefox") ||
        InStr(title, "Chrome") ||
        InStr(title, "Opera") ||
        InStr(title, "Brave") ||
        InStr(title, "Safari") ||
        InStr(title, "Edge")) {
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
    
    ; Check for error templates
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
        
        ; Basic error recovery actions
        errorActions := Map(
            "TeleportToArea4", () => (BB_openTeleportMenu(hwnd), BB_teleportToArea("area_4_button", hwnd)),
            "Shopping", () => (BB_interactWithMerchant(hwnd)),
            "TeleportToArea5", () => (BB_openTeleportMenu(hwnd), BB_teleportToArea("area_5_button", hwnd)),
            "Idle", () => (SendInput("{" . BB_JUMP_HOTKEY . " down}"), Sleep(100), SendInput("{" . BB_JUMP_HOTKEY . " up}"), Sleep(500))
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
    global BB_currentLocation, BB_automationState, BB_FAILED_INTERACTION_COUNT
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
        Run("roblox://placeId=8737899170")  ; PS99 place ID
        BB_updateStatusAndLog("Attempted to reopen Pet Simulator 99")
    } catch as err {
        BB_updateStatusAndLog("Failed to reopen Roblox: " . err.Message, true, true)
        return false
    }
    
    Sleep(30000)
    
    BB_currentLocation := "Unknown"
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
    try {
        versionUrl := "https://raw.githubusercontent.com/xXGeminiXx/BeesPS99MasterAutomation/main/version.txt"
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
    } catch as err {
        BB_updateStatusAndLog("Failed to check for updates: " . err.Message, true, true)
    }
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
    Sleep(3000)

    ; Wait for any animations or transitions
    Sleep(1000)

    BB_updateStatusAndLog("Completed teleport attempt")
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
BB_automationLoop() {
    global BB_running, BB_paused, BB_automationState, BB_FAILED_INTERACTION_COUNT, BB_MAX_FAILED_INTERACTIONS
    global BB_STATE_TIMEOUTS, BB_stateStartTime, BB_currentStateTimeout, BB_gameStateEnsured
    
    if (!BB_running || BB_paused) {
        BB_updateStatusAndLog("Automation loop skipped (not running or paused)")
        return
    }
    
    ; Check for state timeout
    if (BB_automationState != "Idle") {
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
                BB_setState("Interacting")
            
            case "Interacting":
                BB_updateStatusAndLog("Performing interaction...")
                Sleep(BB_INTERACTION_DURATION)
                BB_setState("Processing")
            
            case "Processing":
                BB_updateStatusAndLog("Processing...")
                Sleep(1000)
                BB_setState("Navigating")
            
            case "Navigating":
                BB_updateStatusAndLog("Navigating...")
                Sleep(1000)
                BB_setState("Idle")
            
            case "Error":
                if (BB_handleError()) {
                    BB_setState("Idle")  ; Try again from idle state
                } else {
                    BB_stopAutomation()  ; Stop if max retries reached and reset failed
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
    SetTimer(BB_automationLoop, 0)
    SetTimer(BB_reconnectCheckLoop, 0)
    BB_updateStatusAndLog("Script terminated")
    ExitApp()
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
BB_updateStatusAndLog("Anti-AFK timer will start when automation begins") ; Update status and log
BB_updateStatusAndLog("Script initialized. Press F1 to start automation.") ; Update status and log

TrayTip("Initialized! Press F1 to start.", "🐝 BeeBrained's PS99 Automation", 0x10)

; Performance Tracking


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
        
        case "status":
            statusMsg := "Current State: " . BB_automationState . "`n"
            statusMsg .= "Running: " . (BB_running ? "Yes" : "No") . "`n"
            statusMsg .= "Paused: " . (BB_paused ? "Yes" : "No") . "`n"
            statusMsg .= "Current Location: " . BB_currentLocation . "`n"
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

BB_getPerformanceStats() {
    stats := "Performance Statistics:`n"
    stats .= "Click Operations: " . Round(BB_performanceData["ClickAt"]) . "ms avg`n"
    stats .= "Movement Checks: " . Round(BB_performanceData["MovementCheck"]) . "ms avg`n"
    stats .= "State Transitions: " . Round(BB_performanceData["StateTransition"]) . "ms avg`n"
    
    stats .= "`nTemplate Matching Times:`n"
    for templateName, time in BB_performanceData["TemplateMatch"] {
        stats .= templateName . ": " . Round(time) . "ms avg`n"
    }
    
    return stats
}

BB_teleportToLocation(locationTemplate, hwnd) {
    global BB_currentLocation
    
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        BB_updateStatusAndLog("Invalid window handle for teleport", true)
        return false
    }
    
    ; Get window dimensions for validation
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    if (!winW || !winH) {
        BB_updateStatusAndLog("Failed to get window dimensions for location teleport", true)
        return false
    }
    
    BB_updateStatusAndLog("Looking for " . locationTemplate . " in teleport menu")
    
    ; Wait for teleport menu to fully load
    Sleep(3000)
    
    ; Try template matching with higher tolerance for location buttons
    FoundX := -1
    FoundY := -1
    
    ; Search in the teleport menu area
    searchArea := [
        winX + 5,                    ; Left edge with small margin
        winY + 50,                   ; Start higher in the screen
        winX + (winW/2),             ; Half the screen width 
        winY + (winH/2)              ; Half the screen height
    ]
    
    BB_updateStatusAndLog("Searching for " . locationTemplate . " in area: " . Round(searchArea[1]) . "," . Round(searchArea[2]) . "," . Round(searchArea[3]) . "," . Round(searchArea[4]))
    
    ; Verify template exists first
    templatePath := BB_TEMPLATE_FOLDER . "\" . BB_TEMPLATES[locationTemplate]
    if (!FileExist(templatePath)) {
        BB_updateStatusAndLog("Template file not found: " . templatePath, true)
        return false
    }
    
    ; Try template matching with higher tolerance (60) for location buttons
    if (BB_smartTemplateMatch(locationTemplate, &FoundX, &FoundY, hwnd, searchArea, 60)) {
        BB_updateStatusAndLog("Found " . locationTemplate . " at x=" . FoundX . ", y=" . FoundY)
        
        ; Click slightly offset from found position
        clickX := FoundX + 35  ; Offset X
        clickY := FoundY + 25  ; Offset Y
        
        ; Ensure click is within window bounds
        clickX := Max(winX + 5, Min(clickX, winX + winW - 5))
        clickY := Max(winY + 5, Min(clickY, winY + winH - 5))
        
        BB_updateStatusAndLog("Clicking " . locationTemplate . " at x=" . clickX . ", y=" . clickY . " (template match)")
        BB_clickAt(clickX, clickY)
        
        ; Wait for teleport to complete
        Sleep(5000)
        
        ; Update current location based on template
        BB_currentLocation := locationTemplate
        BB_updateStatusAndLog("Teleported to " . BB_currentLocation)
        return true
    }
    
    BB_updateStatusAndLog("Failed to find location button: " . locationTemplate, true)
    return false
}

BB_handleError() {
    BB_ERROR_RETRY_ATTEMPTS++
    retryDelay := BB_ERROR_BASE_DELAY * (BB_ERROR_BACKOFF_FACTOR ** (BB_ERROR_RETRY_ATTEMPTS - 1))
    retryDelay := Min(retryDelay, BB_ERROR_MAX_DELAY)
    
    BB_log("Error recovery attempt " . BB_ERROR_RETRY_ATTEMPTS . " with " . (retryDelay / 1000) . "s delay", 2)
    BB_updateGUI()
    
    Sleep(retryDelay)
    
    if (BB_ERROR_RETRY_ATTEMPTS >= BB_ERROR_MAX_RETRIES) {
        BB_log("Max retries reached, resetting game state", 2)
        BB_resetGameState()
        BB_ERROR_RETRY_ATTEMPTS := 0
        return false
    }
    
    return true
}

BB_resetErrorState() {
    BB_ERROR_RETRY_ATTEMPTS := 0
    BB_FAILED_INTERACTION_COUNT := 0
}

; ===================== UTILITY FUNCTIONS =====================

; Cleanup function called when script exits
BB_cleanup(*) {
    global BB_running, BB_paused, BB_automationState
    
    BB_running := false
    BB_paused := false
    BB_automationState := "Idle"
    
    ; Stop all timers
    SetTimer(BB_automationLoop, 0)
    SetTimer(BB_reconnectCheckLoop, 0)
    SetTimer(BB_antiAfkLoop, 0)
    
    ; Save any pending state
    BB_saveConfig()
    
    BB_updateStatusAndLog("Cleanup completed")
}

; Creates the default configuration file
BB_createDefaultConfig() {
    global BB_CONFIG_FILE, defaultIni
    
    if FileExist(BB_CONFIG_FILE) {
        BB_updateStatusAndLog("Config file already exists, skipping creation")
        return
    }
    
    try {
        FileAppend(defaultIni, BB_CONFIG_FILE)
        BB_updateStatusAndLog("Created default config file at: " . BB_CONFIG_FILE)
    } catch as err {
        BB_updateStatusAndLog("Error creating default config: " . err.Message, true, true)
        MsgBox("Failed to create default config file: " . err.Message, "Config Error", 0x10)
    }
}

; Logs a message to the log file and optionally to the GUI
BB_log(message, level := 1) {
    global BB_ENABLE_LOGGING, BB_LOG_FILE, BB_DEBUG
    
    if (!BB_ENABLE_LOGGING)
        return
        
    if (BB_DEBUG["enabled"] && level > BB_DEBUG["level"])
        return
        
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    logMessage := timestamp . " [" . level . "] " . message . "`n"
    
    try {
        FileAppend(logMessage, BB_LOG_FILE)
    } catch as err {
        ; If we can't write to the log file, at least show the message
        OutputDebug(message)
    }
}

; Sends a hotkey with proper down/up events
BB_sendHotkeyWithDownUp(hotkey) {
    try {
        SendInput("{" . hotkey . " down}")
        Sleep(50)  ; Small delay between down and up
        SendInput("{" . hotkey . " up}")
        return true
    } catch as err {
        BB_updateStatusAndLog("Error sending hotkey " . hotkey . ": " . err.Message, true, true)
        return false
    }
}

; Scales coordinates based on screen resolution
BB_scaleCoordinates(x, y) {
    global BB_SCALE_X, BB_SCALE_Y
    
    return [
        Round(x * BB_SCALE_X),
        Round(y * BB_SCALE_Y)
    ]
}

; Calculates the distance between two colors in RGB space
ColorDistance(color1, color2) {
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF
    
    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF
    
    return Sqrt((r2-r1)**2 + (g2-g1)**2 + (b2-b1)**2)
}

; Gets list of available config presets
BB_getConfigPresets() {
    global BB_CONFIG_DIR
    
    presets := ["Default"]
    
    if !DirExist(BB_CONFIG_DIR)
        return presets
        
    try {
        loop files BB_CONFIG_DIR "\*.ini" {
            presetName := SubStr(A_LoopFileName, 1, -4)  ; Remove .ini extension
            if (presetName != "config")
                presets.Push(presetName)
        }
    } catch as err {
        BB_updateStatusAndLog("Error reading config presets: " . err.Message, true, true)
    }
    
    return presets
}

; Handles save config button click
BB_saveConfigButtonClick(*) {
    global BB_configDropdown, BB_CONFIG_FILE
    
    selectedPreset := BB_configDropdown.Text
    if (selectedPreset = "Default") {
        BB_updateStatusAndLog("Cannot save to Default preset", true)
        return
    }
    
    try {
        if !DirExist(BB_CONFIG_DIR)
            DirCreate(BB_CONFIG_DIR)
            
        targetFile := BB_CONFIG_DIR "\" . selectedPreset . ".ini"
        FileCopy(BB_CONFIG_FILE, targetFile, true)
        BB_updateStatusAndLog("Saved config to preset: " . selectedPreset)
    } catch as err {
        BB_updateStatusAndLog("Error saving config preset: " . err.Message, true, true)
        MsgBox("Failed to save config preset: " . err.Message, "Save Error", 0x10)
    }
}

; Handles reset config button click
BB_resetConfigButtonClick(*) {
    global BB_CONFIG_FILE
    
    try {
        FileDelete(BB_CONFIG_FILE)
        BB_createDefaultConfig()
        BB_loadConfig()
        BB_updateStatusAndLog("Reset to default configuration")
    } catch as err {
        BB_updateStatusAndLog("Error resetting config: " . err.Message, true, true)
        MsgBox("Failed to reset configuration: " . err.Message, "Reset Error", 0x10)
    }
}

; Handles load config button click
BB_loadConfigButtonClick(*) {
    global BB_configDropdown, BB_CONFIG_FILE, BB_CONFIG_DIR
    
    selectedPreset := BB_configDropdown.Text
    if (selectedPreset = "Default") {
        BB_loadConfig()  ; Reload default config
        BB_updateStatusAndLog("Loaded default config")
        return
    }
    
    try {
        sourceFile := BB_CONFIG_DIR "\" . selectedPreset . ".ini"
        if !FileExist(sourceFile) {
            BB_updateStatusAndLog("Config preset not found: " . selectedPreset, true)
            return
        }
        
        FileCopy(sourceFile, BB_CONFIG_FILE, true)
        BB_loadConfig()  ; Reload the config
        BB_updateStatusAndLog("Loaded config preset: " . selectedPreset)
    } catch as err {
        BB_updateStatusAndLog("Error loading config preset: " . err.Message, true, true)
        MsgBox("Failed to load config preset: " . err.Message, "Load Error", 0x10)
    }
}

; Updates GUI elements with current state
BB_updateGUI() {
    global BB_running, BB_paused, BB_automationState, BB_active_windows
    global BB_validTemplates, BB_totalTemplates, BB_FAILED_INTERACTION_COUNT
    global BB_lastError, BB_mainGui
    
    if (!IsSet(BB_mainGui) || !IsObject(BB_mainGui))
        return
        
    try {
        BB_mainGui["Status"].Text := (BB_running ? (BB_paused ? "Paused" : "Running") : "Idle")
        BB_mainGui["Status"].SetFont(BB_running ? (BB_paused ? "cOrange" : "cGreen") : "cRed")
        BB_mainGui["WindowCount"].Text := BB_active_windows.Length
        BB_mainGui["AutomationStatus"].Text := (BB_running ? (BB_paused ? "PAUSED" : "RUNNING") : "OFF")
        BB_mainGui["AutomationStatus"].SetFont(BB_running ? (BB_paused ? "cOrange" : "cGreen") : "cRed")
        BB_mainGui["TemplateStatus"].Text := BB_validTemplates . "/" . BB_totalTemplates
        BB_mainGui["TemplateStatus"].SetFont(BB_validTemplates = BB_totalTemplates ? "cGreen" : "cRed")
        BB_mainGui["CurrentState"].Text := BB_automationState
        BB_mainGui["FailedCount"].Text := BB_FAILED_INTERACTION_COUNT
        BB_mainGui["LastError"].Text := BB_lastError
        BB_mainGui["LastError"].SetFont(BB_lastError != "None" ? "cRed" : "cBlack")
    } catch as err {
        ; Silently fail GUI updates if there's an error
        ; This prevents script crashes if GUI elements aren't ready
    }
}

; Captures a screenshot for debugging purposes
BB_captureScreenForDebug(hwnd, filename) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false
        
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
        if !DirExist(A_ScriptDir . "\debug")
            DirCreate(A_ScriptDir . "\debug")
            
        ; Use AutoHotkey v2's screenshot method
        BB_mainGui.Screenshot(A_ScriptDir . "\debug\" . filename, x . "|" . y . "|" . w . "|" . h)
        return true
    } catch as err {
        BB_updateStatusAndLog("Error capturing debug screenshot: " . err.Message, true, true)
        return false
    }
}

; Detects if the hatch menu is open
BB_detectHatchMenu(hwnd, debugMode := false) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false
        
    try {
        ; This is a stub for future implementation
        ; Will be implemented when hatching functionality is added
        return false
    } catch as err {
        BB_updateStatusAndLog("Error detecting hatch menu: " . err.Message, true, true)
        return false
    }
}

; Stub for merchant interaction - to be implemented in future
BB_interactWithMerchant(hwnd) {
    ; This is a stub for future merchant functionality
    BB_updateStatusAndLog("Merchant interaction not yet implemented")
    return false
}

; Saves current configuration to file
BB_saveConfig() {
    global BB_CONFIG_FILE, BB_ENABLE_LOGGING, BB_WINDOW_TITLE, BB_EXCLUDED_TITLES
    global BB_CLICK_DELAY_MIN, BB_CLICK_DELAY_MAX, BB_INTERACTION_DURATION, BB_CYCLE_INTERVAL
    global BB_TEMPLATE_FOLDER, BB_BACKUP_TEMPLATE_FOLDER, BB_TEMPLATE_RETRIES, BB_MAX_FAILED_INTERACTIONS
    global BB_ANTI_AFK_INTERVAL, BB_RECONNECT_CHECK_INTERVAL
    global BB_SAFE_MODE
    global BB_TELEPORT_HOTKEY, BB_INVENTORY_HOTKEY, BB_START_STOP_HOTKEY, BB_PAUSE_HOTKEY, BB_EXIT_HOTKEY, BB_JUMP_HOTKEY
    
    try {
        ; Save timing values
        IniWrite(BB_INTERACTION_DURATION, BB_CONFIG_FILE, "Timing", "INTERACTION_DURATION")
        IniWrite(BB_CYCLE_INTERVAL, BB_CONFIG_FILE, "Timing", "CYCLE_INTERVAL")
        IniWrite(BB_CLICK_DELAY_MIN, BB_CONFIG_FILE, "Timing", "CLICK_DELAY_MIN")
        IniWrite(BB_CLICK_DELAY_MAX, BB_CONFIG_FILE, "Timing", "CLICK_DELAY_MAX")
        IniWrite(BB_ANTI_AFK_INTERVAL, BB_CONFIG_FILE, "Timing", "ANTI_AFK_INTERVAL")
        IniWrite(BB_RECONNECT_CHECK_INTERVAL, BB_CONFIG_FILE, "Timing", "RECONNECT_CHECK_INTERVAL")
        
        ; Save window settings
        IniWrite(BB_WINDOW_TITLE, BB_CONFIG_FILE, "Window", "WINDOW_TITLE")
        IniWrite(Array.Join(BB_EXCLUDED_TITLES, ","), BB_CONFIG_FILE, "Window", "EXCLUDED_TITLES")
        
        ; Save features
        IniWrite(BB_SAFE_MODE, BB_CONFIG_FILE, "Features", "SAFE_MODE")
        
        ; Save hotkeys
        IniWrite(BB_TELEPORT_HOTKEY, BB_CONFIG_FILE, "Hotkeys", "TELEPORT_HOTKEY")
        IniWrite(BB_INVENTORY_HOTKEY, BB_CONFIG_FILE, "Hotkeys", "INVENTORY_HOTKEY")
        IniWrite(BB_START_STOP_HOTKEY, BB_CONFIG_FILE, "Hotkeys", "START_STOP_HOTKEY")
        IniWrite(BB_PAUSE_HOTKEY, BB_CONFIG_FILE, "Hotkeys", "PAUSE_HOTKEY")
        IniWrite(BB_EXIT_HOTKEY, BB_CONFIG_FILE, "Hotkeys", "EXIT_HOTKEY")
        IniWrite(BB_JUMP_HOTKEY, BB_CONFIG_FILE, "Hotkeys", "JUMP_HOTKEY")
        
        ; Save retry settings
        IniWrite(BB_TEMPLATE_RETRIES, BB_CONFIG_FILE, "Retries", "TEMPLATE_RETRIES")
        IniWrite(BB_MAX_FAILED_INTERACTIONS, BB_CONFIG_FILE, "Retries", "MAX_FAILED_INTERACTIONS")
        
        ; Save logging settings
        IniWrite(BB_ENABLE_LOGGING, BB_CONFIG_FILE, "Logging", "ENABLE_LOGGING")
        
        BB_updateStatusAndLog("Saved configuration to " . BB_CONFIG_FILE)
        return true
    } catch as err {
        BB_updateStatusAndLog("Error saving configuration: " . err.Message, true, true)
        return false
    }
}
