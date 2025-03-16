🐝 BeeBrained’s MAT (Master Automation Tool) 🐝
A versatile automation tool designed for efficiency and flexibility, perfect for repetitive tasks in games like Pet Simulator 99 (PS99) and beyond. Featuring hotkeys, GUI controls, coordinate clicking, WASD movement, and OpenCV template matching, this script is your go-to for automating window-based interactions.

Created by BeeBrained

📺 YouTube: @BeeBrained-PS99

💬 Discord: QVncFccwek

Features
Configurable Settings: Loads from BeeConfig.ini with sensible defaults and validation.
Hotkeys & GUI: Full control via hotkeys (Enter, Esc, P, C, Shift+C, WASD) and matching GUI buttons.
Window Cycling: Automatically finds and switches between target windows (e.g., Roblox), with customizable exclusions.
Coordinate Clicking: Capture and click specific screen positions with randomization for natural behavior.
Template Matching: Uses OpenCV to detect and interact with on-screen images (e.g., buttons, items).
Anti-AFK Movement: Simulates WASD key presses to keep sessions active.
Robust Error Handling: Retries failed actions and prevents crashes with clean shutdowns.
Installation
Prerequisites:
Python 3.8+
Install required libraries:
pip install pyautogui keyboard pywin32 opencv-python numpy
Download:
Clone this repository or download the ZIP:
git clone https://github.com/BeeBrained/MAT.git
Run:
Navigate to the folder and execute:
python BeeMAT.py
If BeeConfig.ini is missing, it’ll be created with default settings.
Usage
Launch: Run the script to open the GUI.
Capture Targets:
Coords: Press C or click “Capture Coords” to record mouse positions.
Templates: Press Shift+C or click “Capture Templates” to select ROIs for image matching (ESC to cancel).
Control:
Start: Press Enter or click “Start” to begin automation.
Pause/Resume: Press P or click “Pause/Resume” to toggle.
Stop: Press Esc or click “Stop” to end.
Move: Use W, A, S, D or their buttons for manual movement (when running and not paused).
Monitor: The GUI shows the current state (Idle/Running/Paused), coord count, and template count.
Configuration
The script uses BeeConfig.ini for settings. Key options include:
click_delay_min/max: Timing range for clicks.
match_threshold: Confidence level for template matching (0.0-1.0).
timer_interval: Seconds between window cycles.
excluded_titles: Window titles to skip (comma-separated).
Edit the file to customize behavior, or let the script generate defaults on first run.

How It Works
Core Components
Config Loading
Loads settings from BeeConfig.ini, creating defaults if absent. Validates values to ensure stability.
Hotkeys
Binds keys for start (Enter), stop (Esc), pause (P), capture (C/Shift+C), and movement (WASD). Most respect the paused state; stop is always available.
GUI
A 400x400 window with buttons for every action, plus a real-time status display (state, coords, templates).
Automation Loop
Finds target windows (e.g., Roblox) using find_roblox_windows.
Activates each with bring_to_front.
Clicks captured coords and matches templates for interaction_duration.
Tracks window switches to prevent glitches, waiting timer_interval between cycles.
Template Matching
Uses OpenCV to screenshot the screen, match templates, and click them if confidence exceeds match_threshold. Retries on failure up to retry_attempts.
Clicking
Randomizes mouse movement and timing in click_at to mimic human input.
Movement
Simulates WASD presses for 0.5s each, keeping sessions active when running.
Threading
Runs the main loop in a daemon thread, ensuring clean shutdowns with no orphaned processes.
Shutdown
Closing the GUI stops the automation and cleans up resources.
Technical Details
Config: Comprehensive with validation for min/max constraints.
Hotkeys: Respect paused state (except stop_automation).
GUI: Updates every 100ms; all buttons match hotkey functionality.
Loop: Robust with window management, interaction logic, and safety checks.
Templates: Reliable OpenCV matching with retry logic.
Clicking: Randomized for natural behavior.
Threading: Clean and efficient daemon thread management.
Potential Enhancement: Add a “Clear Coords/Templates” button (optional, not critical).

Contributing
Feel free to fork, tweak, and submit pull requests! Ideas:

Add new features (e.g., save/load profiles).
Improve GUI responsiveness (e.g., button state toggling).
Share your custom BeeConfig.ini setups in the Discussions tab.
License
This project is open-source under the MIT License. Use it, modify it, share it—just keep the buzz alive!

Shoutouts
Big thanks to the PS99 community for inspiring this tool. Join the hive on Discord and check out my YouTube for more automation goodness!

🐝 Happy automating, hive! 🐝
