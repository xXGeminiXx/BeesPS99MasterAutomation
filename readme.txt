Here’s an updated README that incorporates all the new features we’ve added to both the Python (`BMAT.py`) and AutoHotkey (`BMAT.ahk`) versions of **BeeBrained’s MAT (Master Automation Tool)**. It includes detailed explanations of the enhancements like dynamic pixel search areas, log rotation, GUI improvements, function controls, and config management, while keeping the structure clear and engaging.

---

# Repository Files Navigation
- README
- MIT License

🐝 **BeeBrained’s MAT (Master Automation Tool)** 🐝  
A versatile automation powerhouse built for efficiency and flexibility, perfect for repetitive tasks in games like Pet Simulator 99 (PS99) and beyond. Available in two flavors: a feature-packed Python version with a slick GUI and OpenCV template matching, and a lightweight AutoHotkey (AHK) version focused on simplicity and reliability.

**Created by:** BeeBrained  
- 📺 YouTube: [@BeeBrained-PS99](https://www.youtube.com/@BeeBrained-PS99)  
- 💬 Discord: [Hive Hangout](https://discord.gg/QVncFccwek)

---

## Features

### Python Version (BMAT.py)
- **Configurable Settings:** Loads from `BeeConfig.ini` with robust validation and defaults, now supporting dynamic pixel search areas and logging toggles.
- **Hotkeys & Enhanced GUI:** Control via hotkeys (Enter, Esc, P, C, Shift+C) and a 400x500 GUI with buttons, checkboxes, and dropdowns for ultimate control.
- **Window Cycling:** Seamlessly switches between target windows (e.g., Roblox), with customizable exclusions and stability checks.
- **Coordinate Clicking:** Capture and click positions with randomized timing and offsets for natural behavior.
- **Template Matching:** Uses OpenCV to detect and interact with on-screen images (e.g., buttons, items), with configurable thresholds and grayscale options.
- **Function-Specific Automation:** Dedicated functions (`autoHatch`, `autoRebirth`, etc.) for precise task automation, toggleable via GUI.
- **Dynamic Pixel Search Area:** Set custom screen regions for template matching via GUI, saved to config.
- **Logging System:** Detailed action logging with daily rotation (e.g., `logs/log_YYYYMMDD.txt`), toggleable live via GUI, with a “View Log” button.
- **Command Panel:** Test individual functions (e.g., `autoHatch`) directly from the GUI with visual feedback (green indicators).
- **Config Management:** Save and load multiple configurations from a `configs` folder via GUI dropdown.
- **Anti-AFK Movement:** Simulates key presses (future enhancement potential).
- **Robust Error Handling:** Retries failed actions, logs errors, and ensures clean shutdowns.

### AHK Version (BMAT.ahk)
- **Configurable Settings:** Loads from `config.ini` with validation, now including pixel search areas and logging options.
- **Hotkeys & GUI:** Control via hotkeys (F1, F2, P, C, etc.) and a compact GUI with checkboxes and buttons, replacing ToolTips/MsgBoxes.
- **Window Cycling:** Detects and switches between Roblox windows, with customizable exclusions and process verification.
- **Coordinate Clicking:** Capture and click positions with randomized delays, now with GUI feedback.
- **Template Matching:** Uses Gdip for image detection (requires `Gdip_All.ahk`), supporting auto-detected templates from a folder.
- **Function-Specific Automation:** Functions like `autoHatch`, `autoRebirth`, etc., toggleable via GUI checkboxes.
- **Dynamic Pixel Search Area:** Define custom search regions via GUI, saved to config.
- **Logging System:** Detailed logs with daily rotation (e.g., `logs/log_YYYYMMDD.txt`), toggleable via GUI, with a “View Log” option.
- **Command Panel:** Test functions directly from the GUI with visual indicators (green dots).
- **Config Management:** Save and load multiple configs from a `configs` folder via GUI dropdown.
- **Anti-AFK Movement:** Simulates WASD-like movement patterns (e.g., circle, zigzag) via GUI button.
- **Lightweight:** Minimal dependencies (just AutoHotkey v2.0+ and optional Gdip).

---

## Installation

### Python Version (BMAT.py)
- **Prerequisites:**
  - Python 3.8+
  - Install libraries: `pip install pyautogui keyboard pywin32 opencv-python numpy`
- **Download:**
  - Clone or download ZIP: `git clone https://github.com/xXGeminiXx/BeesPS99MasterAutomation.git`
- **Run:**
  - Navigate to folder and execute: `python BMAT.py`
  - `BeeConfig.ini` auto-generates if missing, with `logs` and `configs` folders created as needed.

### AHK Version (BMAT.ahk)
- **Prerequisites:**
  - AutoHotkey v2.0+ (https://www.autohotkey.com/)
  - Optional: `Gdip_All.ahk` for template matching (place in same directory)
- **Download:**
  - Clone or download ZIP: `git clone https://github.com/xXGeminiXx/BeesPS99MasterAutomation.git`
- **Run:**
  - Double-click `BMAT.ahk` or run via: `"C:\Program Files\AutoHotkey\AutoHotkey.exe" BMAT.ahk`
  - `config.ini` auto-generates if missing, with `logs`, `configs`, and `templates` folders created as needed.

---

## Usage

### Python Version (BMAT.py)
- **Launch:** Run to open the GUI.
- **Capture Targets:**
  - **Coords:** Press C or click “Capture Coords” to record positions.
  - **Templates:** Press Shift+C or click “Capture Templates” to select ROIs (ESC to cancel).
  - **Search Area:** Click “Set Search Area” and click two points to define the region.
- **Control:**
  - **Start:** Press Enter or click “Start”.
  - **Pause/Resume:** Press P or click “Pause/Resume”.
  - **Stop:** Press Esc or click “Stop”.
  - **Functions:** Toggle via checkboxes; test with “Test [func]” buttons.
  - **Logging:** Enable/disable via checkbox; view with “View Log”.
  - **Configs:** Save with name entry and “Save Config”; load from dropdown.
- **Monitor:** GUI shows state, coord/template counts, function status (green indicators), and active windows.

### AHK Version (BMAT.ahk)
- **Launch:** Run to open the GUI (tray tip confirms readiness).
- **Capture Targets:**
  - **Coords:** Press C to record positions (GUI updates).
  - **Templates:** Auto-detected from `templates` folder (add .png files); no manual capture yet.
  - **Search Area:** Click “Set Search Area” and click two points to define.
- **Control:**
  - **Start:** Press F1 or click “Start” (future GUI button).
  - **Pause/Resume:** Press P or click “Pause” (future GUI button).
  - **Stop:** Press F2 or Esc (or tray icon).
  - **Functions:** Toggle via checkboxes; test with “Test [func]” buttons.
  - **Logging:** Enable/disable via checkbox; view with “View Log”.
  - **Configs:** Save with name entry and “Save Config”; load from dropdown.
  - **Movement:** Click “Run Movement” for anti-AFK patterns.
- **Monitor:** GUI shows state, coord count, function status (green dots), and active windows.

---

## Configuration
Both versions use an INI file (`BeeConfig.ini` for Python, `config.ini` for AHK). Key options:
- **click_delay_min/max:** Timing range for clicks (seconds for Python, milliseconds for AHK).
- **timer_interval/interaction_duration:** Cycle and interaction timing (seconds for Python, milliseconds for AHK).
- **excluded_titles:** Window titles to skip (comma-separated).
- **pixelsearch_area:** Custom screen region for detection (x1,y1,x2,y2).
- **enable_logging:** Toggle logging (1/0 for Python, true/false for AHK).
- **Python-only:** `match_threshold` (0.0-1.0), `use_greyscale` (1/0).
- **AHK-only:** `ENABLED_FUNCTIONS` (comma-separated list), template file names.

Edit the INI file to customize, or use GUI controls to adjust settings live (e.g., search area, logging, functions).

---

## License
Open-source under the MIT License. Use it, modify it, share it—keep the buzz alive!

---

## Shoutouts
Thanks to the PS99 community for the inspiration. Join the hive on Discord and check my YouTube for automation tips and tutorials!

🐝 **Happy automating, hive!** 🐝

---

## About
A dual-implementation automation tool for Pet Simulator 99 and beyond. The Python version offers a full-featured experience with advanced GUI controls and template matching, while the AHK version provides a lightweight, script-driven alternative with surprising depth. Use at your discretion—perfect for grinding, collecting, or just keeping the game alive while you sip some honey!

---

### Explanation of New Features
- **Dynamic Pixel Search Area**: Both versions now let you set a custom screen region via GUI, making detection more precise and configurable without editing files manually.
- **Logging System**: Daily log rotation keeps files manageable, with GUI toggles and viewers for real-time control and review.
- **Function-Specific Automation**: Dedicated functions (e.g., `autoHatch`) are now toggleable and testable via GUI, with visual indicators for activity feedback.
- **Config Management**: Save and load multiple configs from a GUI dropdown, ideal for switching setups on the fly.
- **Enhanced GUI**: Python’s GUI grew to 400x500 for more controls; AHK added a GUI with checkboxes and buttons, replacing basic ToolTips.
- **Command Panel**: Test functions directly from the GUI, streamlining setup and debugging.
