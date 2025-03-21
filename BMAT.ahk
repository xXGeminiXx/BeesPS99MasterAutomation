#Requires AutoHotkey v2.0
; 🐝 BeeBrained's PS99 Clan Battle Automation Template 🐝
; A modular baseline for automating Pet Simulator 99 clan battle events in Roblox.
; By BeeBrained - https://www.youtube.com/@BeeBrained-PS99
; Hive Hangout: https://discord.gg/QVncFccwek

; ================== How to Use ==================
; 1. Place template images (e.g., hatch_button.png, rebirth_ready.png) in a "templates" folder in the script directory.
; 2. Edit ENABLED_FUNCTIONS to include the functions needed for the current event, e.g., ["autoHatch", "autoRebirth"].
; 3. If general actions are needed, set ENABLE_GENERAL_ACTIONS to true and define KEY_SEQUENCE and capture coords as necessary.
; 4. Launch the script, position your character in the event area, and press F1 to start.
; 5. Update templates if the UI changes in game updates.
; 6. Ensure Gdip_All.ahk is in the script directory for template matching (download from AHK forums).

; ================== Configurable Settings ==================
; **Timing (in milliseconds)**
INTERACTION_DURATION := 5000  ; Duration to interact with each window
CYCLE_INTERVAL := 60000       ; Time between full cycles (default: 60s)
CLICK_DELAY_MIN := 500        ; Min delay between clicks
CLICK_DELAY_MAX := 1500       ; Max delay between clicks

; **Window Settings**
WINDOW_TITLE := "Roblox"      ; Target window title
EXCLUDED_TITLES := ["Roblox Account Manager"]  ; Titles to exclude

; **Enabled Features**
ENABLE_GENERAL_ACTIONS := true  ; Whether to run general key sequences and coord clicks
ENABLED_FUNCTIONS := ["autoHatch", "autoRebirth"]  ; List of functions to run

; **Key Sequences (edit these for each event)**
; Format: Array of [key, duration_ms, repeat_count]
KEY_SEQUENCE := [
    ["space", 500, 1],   ; Jump (Spacebar)
    ["w", 300, 2],       ; Move forward twice
    ["f", 200, 1]        ; Open/close inventory or interact
]

; **Template Names (define templates for UI elements)**
TEMPLATES := Map(
    "hatch_button", "hatch_button.png",
    "rebirth_button", "rebirth_button.png",
    "rebirth_ready", "rebirth_ready.png",
    "upgrade_button", "upgrade_button.png"
)

; **Hotkey Configuration**
START_KEY := "F1"      ; Start automation
STOP_KEY := "F2"       ; Stop automation
PAUSE_KEY := "p"       ; Pause/resume
CAPTURE_KEY := "c"     ; Capture mouse position
INVENTORY_KEY := "F3"  ; Toggle inventory click mode
PIXELSEARCH_KEY := "F4"; Toggle PixelSearch mode
CHECKSTATE_KEY := "F5" ; Toggle game state checking (placeholder)

; **PixelSearch Settings (based on screenshots)**
PIXELSEARCH_COLOR := "0xFFFFFF"  ; White glow (e.g., Titanic Chest glow)
PIXELSEARCH_VARIATION := 10      ; Color variation tolerance
PIXELSEARCH_AREA := [0, 0, A_ScreenWidth, A_ScreenHeight]  ; Search entire screen

; **Movement Patterns (for navigating tycoons or areas)**
MOVEMENT_PATTERNS := Map(
    "circle", [["w", 500, 1], ["d", 300, 1], ["s", 500, 1], ["a", 300, 1]],  ; Circle pattern
    "zigzag", [["w", 400, 1], ["d", 200, 1], ["w", 400, 1], ["a", 200, 1]],  ; Zigzag pattern
    "forward_backward", [["w", 1000, 1], ["s", 1000, 1]]                     ; Forward and back
)

; **Folder for Templates**
TEMPLATE_FOLDER := A_ScriptDir "\templates"  ; Templates folder in script directory

; ================== Global Variables ==================
global running := false
global paused := false
global coords := []    ; Array for captured coordinates
global inventory_mode := false
global pixelsearch_mode := false
global checkstate_mode := false
global myGUI
global GdipToken  ; For Gdip library (template matching)

; ================== Gdip Setup (for Template Matching) ==================
#Include Gdip_All.ahk  ; Requires Gdip library
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
    myGUI.Add("Button", "x10 y120 w120 h30", "Run Movement Pattern").OnEvent("Click", runMovementPattern)
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

; ================== PixelSearch Function ==================
pixelSearchColor(&FoundX, &FoundY) {
    try {
        PixelSearch &FoundX, &FoundY, PIXELSEARCH_AREA[1], PIXELSEARCH_AREA[2], PIXELSEARCH_AREA[3], PIXELSEARCH_AREA[4], PIXELSEARCH_COLOR, PIXELSEARCH_VARIATION
        return true
    } catch {
        return false
    }
}

; ================== Template Matching Function ==================
templateMatch(templateName, &FoundX, &FoundY) {
    if !FileExist(TEMPLATE_FOLDER "\" TEMPLATES[templateName]) {
        ToolTip "Template " templateName " not found!", 0, 100
        Sleep 1000
        ToolTip
        return false
    }

    ; Capture screen and load template
    pBitmapScreen := Gdip_BitmapFromScreen()
    pBitmapTemplate := Gdip_CreateBitmapFromFile(TEMPLATE_FOLDER "\" TEMPLATES[templateName])
    
    ; Search for template on screen (90% match threshold)
    result := Gdip_ImageSearch(pBitmapScreen, pBitmapTemplate, &FoundX, &FoundY, 0, 0, 0, 0, 0.9)
    
    ; Clean up
    Gdip_DisposeImage(pBitmapScreen)
    Gdip_DisposeImage(pBitmapTemplate)
    
    return result && FoundX != "" && FoundY != ""
}

; ================== Movement Pattern Function ==================
runMovementPattern(*) {
    global running, paused
    if !running || paused
        return
    ToolTip "Running Movement Pattern: circle", 0, 100
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

detectUIElement(element) {
    FoundX := 0, FoundY := 0
    if templateMatch(element, &FoundX, &FoundY) {
        clickAt(FoundX, FoundY)
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
                    if func = "autoHatch" {
                        autoHatch()
                    } else if func = "autoRebirth" {
                        autoRebirth()
                    } else if func = "autoUpgrade" {
                        autoUpgrade()
                    }
                    ; Add more functions as needed
                }
                if inventory_mode {
                    inventoryClick()
                }
                if pixelsearch_mode {
                    FoundX := 0, FoundY := 0
                    if pixelSearchColor(&FoundX, &FoundY) {
                        clickAt(FoundX, FoundY)
                    }
                }
                if checkstate_mode {
                    checkGameState()
                }
                Sleep 1000
            }
        }
    }
    updateStatus("Waiting (" CYCLE_INTERVAL // 1000 "s)")
    Sleep CYCLE_INTERVAL
}

; ================== Placeholder Functions ==================
checkGameState() {
    ; Placeholder: Add logic to detect game state (e.g., tower height for Valentine’s Tower)
    ; Example: Use PixelSearch or template matching for event-specific conditions
}

; ================== Main Execution ==================
initGdip()  ; Initialize Gdip for template matching
setupGUI()
TrayTip "🐝 BeeBrained’s PS99 Template", "Ready! Press " START_KEY " to start.", 10
