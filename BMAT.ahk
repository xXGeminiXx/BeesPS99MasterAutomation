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
    
    ; ===================== MOVEMENT PATTERNS =====================
    BB_MOVEMENT_PATTERNS := Map(
        "circle", [["w", 500, 1], ["d", 300, 1], ["s", 500, 1], ["a", 300, 1]],
        "zigzag", [["w", 400, 1], ["d", 200, 1], ["w", 400, 1], ["a", 200, 1]],
        "forward_backward", [["w", 1000, 1], ["s", 1000, 1]]
    )
    BB_KEY_SEQUENCE := [["space", 500, 1], ["w", 300, 2], ["f", 200, 1]]
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
