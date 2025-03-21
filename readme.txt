Repository Files Navigation
- README
- MIT License

🐝 **BeeBrained’s MAT (Master Automation Tool)** 🐝
A versatile automation tool designed for efficiency and flexibility, perfect for repetitive tasks in games like Pet Simulator 99 (PS99) and beyond. Available in two flavors: a feature-rich Python version with GUI and OpenCV template matching, and a lightweight AutoHotkey (AHK) version focused on simplicity and coordinate clicking.

**Created by:** BeeBrained
- 📺 YouTube: [@BeeBrained-PS99](https://www.youtube.com/@BeeBrained-PS99)
- 💬 Discord: [Hive Hangout](https://discord.gg/QVncFccwek)

---
## Features
### Python Version (BMAT.py)
- **Configurable Settings:** Loads from BeeConfig.ini with validation and defaults.
- **Hotkeys & GUI:** Control via hotkeys (Enter, Esc, P, C, Shift+C, WASD) and a 400x400 GUI with matching buttons.
- **Window Cycling:** Finds and switches between target windows (e.g., Roblox), with customizable exclusions.
- **Coordinate Clicking:** Capture and click positions with randomization for natural behavior.
- **Template Matching:** Uses OpenCV to detect and interact with on-screen images (e.g., buttons, items).
- **Anti-AFK Movement:** Simulates WASD key presses to keep sessions active.
- **Robust Error Handling:** Retries failed actions and ensures clean shutdowns.

### AHK Version (BMAT.ahk)
- **Configurable Settings:** Loads from BeeConfig.ini with basic validation and defaults.
- **Hotkeys:** Control via Enter (start), Esc (stop), P (pause/resume), and C (capture coords).
- **Window Cycling:** Detects and switches between Roblox windows, with customizable exclusions.
- **Coordinate Clicking:** Capture and click positions with randomized timing.
- **Lightweight:** No external dependencies—just AutoHotkey.
- **Limitations:** No GUI (uses ToolTips/MsgBoxes), no template matching, no WASD movement.

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
  - BeeConfig.ini auto-generates if missing.

### AHK Version (BMAT.ahk)
- **Prerequisites:**
  - AutoHotkey v2.0+ (https://www.autohotkey.com/)
- **Download:**
  - Clone or download ZIP: `git clone https://github.com/xXGeminiXx/BeesPS99MasterAutomation.git`
- **Run:**
  - Double-click BMAT.ahk or run via: `"C:\Program Files\AutoHotkey\AutoHotkey.exe" BMAT.ahk`
  - BeeConfig.ini auto-generates if missing.

---
## Usage
### Python Version (BMAT.py)
- **Launch:** Run to open the GUI.
- **Capture Targets:**
  - Coords: Press C or click “Capture Coords” to record positions.
  - Templates: Press Shift+C or click “Capture Templates” to select ROIs (ESC to cancel).
- **Control:**
  - Start: Press Enter or click “Start”.
  - Pause/Resume: Press P or click “Pause/Resume”.
  - Stop: Press Esc or click “Stop”.
  - Move: Use WASD or buttons (when running, not paused).
- **Monitor:** GUI shows state (Idle/Running/Paused), coord count, and template count.

### AHK Version (BMAT.ahk)
- **Launch:** Run to initialize (tray tip confirms readiness).
- **Capture Targets:**
  - Coords: Press C to record positions (ToolTip feedback).
- **Control:**
  - Start: Press Enter.
  - Pause/Resume: Press P.
  - Stop: Press Esc (or tray icon).
- **Monitor:** ToolTips show state and actions.

---
## Configuration
Both versions use BeeConfig.ini. Key options:
- **click_delay_min/max:** Timing range for clicks (seconds).
- **timer_interval:** Seconds between window cycles.
- **excluded_titles:** Window titles to skip (comma-separated).
- **Python-only:** match_threshold (0.0-1.0 for template matching).
Edit BeeConfig.ini to customize, or let the script generate defaults.

---
## License
Open-source under the MIT License. Use it, modify it, share it—keep the buzz alive!

---
## Shoutouts
Thanks to the PS99 community for the inspiration. Join the hive on Discord and check my YouTube for automation tips!

🐝 **Happy automating, hive!** 🐝

---
## About
A dual-implementation automation tool for Pet Simulator 99 and beyond. Python offers full features; AHK provides a lightweight alternative. Use at your discretion.

