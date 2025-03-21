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
- **Configurable Settings:** Loads from `BeeConfig.ini` with robust validation and defaults, supporting dynamic pixel search areas and logging toggles.
- **Hotkeys & Enhanced GUI:** Control via hotkeys (Enter, Esc, P, C, Shift+C) and a 400x500 GUI with buttons, checkboxes, and dropdowns for ultimate control.
- **Window Cycling:** Seamlessly switches between Roblox windows, with customizable exclusions and stability checks.
- **Coordinate Clicking:** Capture and click positions with randomized timing and offsets for natural behavior.
- **Template Matching:** Uses OpenCV to detect and interact with on-screen images (e.g., buttons, items), with configurable thresholds and grayscale options.
- **Function-Specific Automation:** Dedicated functions (`autoHatch`, `autoRebirth`, `autoUpgrade`, `autoCollect`, `autoConvert`) for precise task automation, toggleable via GUI.
- **Dynamic Pixel Search Area:** Set custom screen regions for template matching via GUI, saved to config.
- **Logging System:** Detailed action logging with daily rotation (e.g., `logs/log_YYYYMMDD.txt`), toggleable live via GUI, with a “View Log” button.
- **Command Panel:** Test individual functions directly from the GUI with visual feedback (green indicators).
- **Config Management:** Save and load multiple configurations from a `configs` folder via GUI dropdown.
- **Anti-AFK Movement:** Simulates key presses to prevent disconnection.
- **Robust Error Handling:** Retries failed actions, logs errors, and ensures clean shutdowns.

### AHK Version (BMAT.ahk)
- **Configurable Settings:** Loads from `config.ini` with validation, supporting pixel search areas and logging options.
- **Hotkeys & GUI:** Control via hotkeys (F1, F2, P, C, etc.) and a GUI with checkboxes and buttons, replacing ToolTips/MsgBoxes.
- **Window Cycling:** Detects and switches between Roblox windows, with customizable exclusions and process verification.
- **Coordinate Clicking:** Capture and click positions with randomized delays, with GUI feedback.
- **Template Matching:** Uses built-in `ImageSearch`, supporting auto-detected templates from a folder.
- **Function-Specific Automation:** Functions like `autoHatch`, `autoRebirth`, `autoUpgrade`, `autoCollect`, `autoConvert`, `defeatBoss`, and `breakChest`, toggleable via GUI.
- **Dynamic Pixel Search Area:** Define custom search regions via GUI, saved to config.
- **Logging System:** Detailed logs with daily rotation (e.g., `logs/log_YYYYMMDD.txt`), toggleable via GUI, with a “View Log” option.
- **Command Panel:** Test functions directly from the GUI with visual indicators (green dots).
- **Config Management:** Save and load multiple configs from a `configs` folder via GUI dropdown.
- **Anti-AFK Movement:** Simulates WASD-like movement patterns via GUI button.
- **Lightweight:** Minimal dependencies (AutoHotkey v2.0+).

---

## Installation

### Python Version (BMAT.py)
- **Prerequisites:**
  - Python 3.8+
  - Install libraries: `pip install pyautogui keyboard pywin32 opencv-python-headless numpy`
- **Download:**
  - Clone or download ZIP: `git clone https://github.com/xXGeminiXx/BeesPS99MasterAutomation.git`
- **Run:**
  - Navigate to folder and execute: `python BMAT.py`
  - `BeeConfig.ini` auto-generates if missing, with `logs` and `configs` folders created as needed.

### AHK Version (BMAT.ahk)
- **Prerequisites:**
  - AutoHotkey v2.0+ (https://www.autohotkey.com/)
- **Download:**
  - Clone or download ZIP: `git clone https://github.com/xXGeminiXx/BeesPS99MasterAutomation.git`
- **Run:**
  - Double-click `BMAT.ahk` or run via: `"C:\Program Files\AutoHotkey\AutoHotkey.exe" BMAT.ahk`
  - `config.ini` auto-generates if missing, with `logs`, `configs`, and `templates` folders created as needed.

---

## Configuration
Both versions use an INI file (`BeeConfig.ini` for Python, `config.ini` for AHK). Key options:
- **click_delay_min/max:** Timing range for clicks.
- **timer_interval/interaction_duration:** Cycle and interaction timing.
- **excluded_titles:** Window titles to skip.
- **pixelsearch_area:** Custom screen region for detection.
- **enable_logging:** Toggle logging.
- **Python-only:** `match_threshold`, `use_greyscale`.
- **AHK-only:** `ENABLED_FUNCTIONS` (comma-separated list), template file names.

Edit the INI file to customize, or use GUI controls to adjust settings live.

---

## License
Open-source under the MIT License. Use it, modify it, share it—keep the buzz alive!

---

## About
A dual-implementation automation tool for Pet Simulator 99 and beyond. The Python version offers advanced GUI controls and template matching, while the AHK version provides a lightweight, script-driven alternative with surprising depth. Perfect for grinding, collecting, or just keeping the game alive while you sip some honey!

---
