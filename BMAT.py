"""
🐝 BeeBrained's MAT (Master Automation Tool) 🐝
Built for PS99 automation and beyond.
Hotkeys, clicks, window switching, and CV2 template matching.
By BeeBrained - https://www.youtube.com/@BeeBrained-PS99
Hive hangout: https://discord.gg/QVncFccwek
"""

import time
import random
import pyautogui
import keyboard
import sys
import configparser
import threading
import tkinter as tk
from tkinter import messagebox
import cv2
import numpy as np
from typing import Dict, List, Optional
import win32gui
import win32con
import os
from datetime import datetime

# ==================== CONFIG LOADING ====================
CONFIGS_DIR = "configs"
LOGS_DIR = "logs"

def load_config(file_path="BeeConfig.ini") -> Dict[str, any]:
    """Load the config or create a default one if missing."""
    config = configparser.ConfigParser()
    if not config.read(file_path):
        print(f"Config '{file_path}' not found. Creating a default one.")
        create_bee_config(file_path)
        config.read(file_path)

    if "BeeSettings" not in config:
        print("Missing 'BeeSettings' section in config. Exiting.")
        sys.exit(1)

    settings = config["BeeSettings"]
    try:
        config_dict = {
            "click_delay_min": max(0.1, float(settings.get("click_delay_min", "0.5"))),
            "click_delay_max": max(0.2, float(settings.get("click_delay_max", "1.5"))),
            "wait_before_click": max(0.1, float(settings.get("wait_before_click", "0.5"))),
            "wait_after_click": max(0.1, float(settings.get("wait_after_click", "0.5"))),
            "offset_range": max(0, int(settings.get("offset_range", "5"))),
            "timer_interval": max(1, int(settings.get("timer_interval", "60"))),
            "interaction_duration": max(1, int(settings.get("interaction_duration", "5"))),
            "match_threshold": min(1.0, max(0.1, float(settings.get("match_threshold", "0.8")))),
            "use_greyscale": bool(int(settings.get("use_greyscale", "1"))),
            "num_templates": max(1, int(settings.get("num_templates", "3"))),
            "max_window_switches": max(1, int(settings.get("max_window_switches", "3"))),
            "window_stability_timeout": max(1.0, float(settings.get("window_stability_timeout", "5.0"))),
            "window_title": settings.get("window_title", "Roblox"),
            "pause_key": settings.get("pause_key", "p"),
            "start_key": settings.get("start_key", "enter"),
            "stop_key": settings.get("stop_key", "esc"),
            "capture_key": settings.get("capture_key", "c"),
            "debounce_delay": max(0.1, float(settings.get("debounce_delay", "0.2"))),
            "poll_interval": max(0.005, float(settings.get("poll_interval", "0.01"))),
            "pause_sleep": max(0.01, float(settings.get("pause_sleep", "0.1"))),
            "retry_attempts": max(1, int(settings.get("retry_attempts", "3"))),
            "retry_delay": max(0.01, float(settings.get("retry_delay", "0.1"))),
            "error_recovery_delay": max(0.1, float(settings.get("error_recovery_delay", "1.0"))),
            "excluded_titles": settings.get("excluded_titles", "Roblox Account Manager").split(","),
            "pixelsearch_area": [int(x) for x in settings.get("pixelsearch_area", f"0,0,{pyautogui.size().width},{pyautogui.size().height}").split(",")],
            "enable_logging": bool(int(settings.get("enable_logging", "1")))
        }
        if config_dict["click_delay_max"] < config_dict["click_delay_min"]:
            config_dict["click_delay_max"] = config_dict["click_delay_min"] + 0.1
        return config_dict
    except ValueError as e:
        print(f"Invalid config value: {e}. Exiting.")
        sys.exit(1)

def create_bee_config(file_path="BeeConfig.ini"):
    """Create a default config file."""
    config = configparser.ConfigParser()
    config["BeeSettings"] = {
        "click_delay_min": "0.5", "click_delay_max": "1.5", "wait_before_click": "0.5",
        "wait_after_click": "0.5", "offset_range": "5", "timer_interval": "60",
        "interaction_duration": "5", "match_threshold": "0.8", "use_greyscale": "1",
        "num_templates": "3", "max_window_switches": "3", "window_stability_timeout": "5.0",
        "window_title": "Roblox", "pause_key": "p", "start_key": "enter",
        "stop_key": "esc", "capture_key": "c", "debounce_delay": "0.2", "poll_interval": "0.01",
        "pause_sleep": "0.1", "retry_attempts": "3", "retry_delay": "0.1",
        "error_recovery_delay": "1.0", "excluded_titles": "Roblox Account Manager",
        "pixelsearch_area": f"0,0,{pyautogui.size().width},{pyautogui.size().height}",
        "enable_logging": "1"
    }
    with open(file_path, "w") as config_file:
        config.write(config_file)

# ==================== AUTOMATION CORE ====================
class BeeAutomationCore:
    def __init__(self, config: Dict[str, any]):
        self.config = config
        self.running = False
        self.paused = False
        self.coords = []
        self.templates = {}
        self.window_switch_count = 0
        self.last_window = None
        self.enable_logging = config["enable_logging"]
        self.log_file = os.path.join(LOGS_DIR, f"log_{datetime.now().strftime('%Y%m%d')}.txt")
        self.setup_hotkeys()
        pyautogui.FAILSAFE = True
        self.enabled_functions = ["autoHatch", "autoRebirth"]  # Default enabled functions
        os.makedirs(LOGS_DIR, exist_ok=True)
        os.makedirs(CONFIGS_DIR, exist_ok=True)

    def setup_hotkeys(self):
        """Set up hotkeys with corresponding functions."""
        keyboard.add_hotkey(self.config["stop_key"], self.stop_automation)
        keyboard.add_hotkey(self.config["start_key"], self.start_automation)
        keyboard.add_hotkey(self.config["pause_key"], self.toggle_pause)
        keyboard.add_hotkey(self.config["capture_key"], self.capture_coords)
        keyboard.add_hotkey(f"shift+{self.config['capture_key']}", self.capture_templates)

    def start_automation(self):
        """Start the automation loop."""
        if not self.running:
            self.running = True
            self.paused = False
            self.log_action(f"Automation started. Use '{self.config['stop_key']}' to stop, '{self.config['pause_key']}' to pause.")
            threading.Thread(target=self.main_loop, daemon=True).start()

    def stop_automation(self):
        """Stop the automation loop."""
        self.running = False
        self.paused = False
        self.log_action("Automation stopped.")
        cv2.destroyAllWindows()

    def toggle_pause(self):
        """Toggle pause state."""
        if self.running:
            self.paused = not self.paused
            self.log_action("Paused." if self.paused else "Resumed.")
            time.sleep(self.config["debounce_delay"])

    def capture_coords(self):
        """Capture mouse coordinates."""
        time.sleep(0.5)
        x, y = pyautogui.position()
        self.coords.append((x, y))
        self.log_action(f"Captured coords: x={x}, y={y} (Total: {len(self.coords)})")

    def capture_templates(self):
        """Capture templates via ROI."""
        self.select_templates()

    def capture_template(self, index: int, total: int) -> Optional[np.ndarray]:
        """Capture a single template."""
        window_title = self.config["window_title"]
        full_shot = pyautogui.screenshot()
        base_img = cv2.cvtColor(np.array(full_shot), cv2.COLOR_RGB2BGR)

        cv2.namedWindow(window_title, cv2.WND_PROP_FULLSCREEN)
        cv2.setWindowProperty(window_title, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
        cv2.setWindowProperty(window_title, cv2.WND_PROP_TOPMOST, 1)
        cv2.imshow(window_title, base_img)
        if not self.bring_to_front(window_title):
            cv2.destroyWindow(window_title)
            return None
        cv2.waitKey(1)

        print(f"Capturing template {index + 1}/{total} (ESC to cancel)...")
        x, y, w, h = cv2.selectROI(window_title, base_img, showCrosshair=True)
        cv2.destroyWindow(window_title)

        if keyboard.is_pressed("esc"):
            self.log_action("Template capture canceled.")
            return None
        if w == 0 or h == 0:
            self.log_action("ROI selection canceled.")
            return False

        template = base_img[int(y):int(y + h), int(x):int(x + w)]
        return cv2.cvtColor(template, cv2.COLOR_BGR2GRAY) if self.config["use_greyscale"] else template

    def select_templates(self):
        """Capture multiple templates."""
        self.templates.clear()
        self.log_action(f"Select {self.config['num_templates']} templates (ESC to cancel all).")
        for i in range(self.config["num_templates"]):
            template = self.capture_template(i, self.config["num_templates"])
            if template is None:
                self.templates.clear()
                self.log_action("Template selection aborted.")
                return False
            if template is False:
                continue
            name = f"template_{len(self.templates) + 1}"
            self.templates[name] = template
            self.log_action(f"Template {len(self.templates)} captured.")
        if not self.templates:
            self.log_action("No templates captured.")
            return False
        self.log_action(f"Captured {len(self.templates)} templates. Press '{self.config['start_key']}' to start.")
        return True

    def click_at(self, x: int, y: int):
        """Click at coordinates with randomized timing."""
        time.sleep(self.config["wait_before_click"])
        offset_x = random.randint(-self.config["offset_range"], self.config["offset_range"])
        offset_y = random.randint(-self.config["offset_range"], self.config["offset_range"])
        pyautogui.moveTo(x + offset_x, y + offset_y, duration=0.1)
        delay = random.uniform(self.config["click_delay_min"], self.config["click_delay_max"])
        time.sleep(delay)
        pyautogui.click()
        time.sleep(self.config["wait_after_click"])
        self.log_action(f"Clicked at x={x + offset_x}, y={y + offset_y}.")

    def find_roblox_windows(self) -> List[int]:
        """Find all Roblox windows."""
        def window_callback(hwnd, windows):
            if win32gui.IsWindowVisible(hwnd):
                title = win32gui.GetWindowText(hwnd)
                if "Roblox" in title and not any(excluded in title for excluded in self.config["excluded_titles"]):
                    windows.append(hwnd)
        windows = []
        win32gui.EnumWindows(window_callback, windows)
        return windows

    def bring_to_front(self, window_title: str) -> bool:
        """Bring a window to the foreground."""
        try:
            time.sleep(0.05)
            windows = [hwnd for hwnd in self.find_roblox_windows() if window_title in win32gui.GetWindowText(hwnd)]
            if not windows:
                l = []
                win32gui.EnumWindows(lambda hwnd, extra: extra.append(hwnd) if window_title in win32gui.GetWindowText(hwnd) else None, l)
                windows = l
            if not windows:
                self.log_action(f"Window '{window_title}' not found.")
                return False
            hwnd = windows[0]
            win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
            win32gui.SetForegroundWindow(hwnd)
            self.log_action(f"Activated window: {window_title}")
            return True
        except Exception as e:
            self.log_action(f"Error activating '{window_title}': {e}")
            return False

    def search_and_click_templates(self, template_name: str):
        """Search for a specific template and click it."""
        retry_count = 0
        while retry_count < self.config["retry_attempts"]:
            try:
                frame = np.array(pyautogui.screenshot(region=self.config["pixelsearch_area"]))
                frame = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY) if self.config["use_greyscale"] else cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

                template = self.templates.get(template_name)
                if not template:
                    self.log_action(f"Template '{template_name}' not found.")
                    return False

                result = cv2.matchTemplate(frame, template, cv2.TM_CCOEFF_NORMED)
                _, max_val, _, max_loc = cv2.minMaxLoc(result)
                if max_val >= self.config["match_threshold"]:
                    x, y = max_loc
                    h, w = template.shape[:2]
                    target_x = x + w // 2 + self.config["pixelsearch_area"][0]
                    target_y = y + h // 2 + self.config["pixelsearch_area"][1]
                    self.click_at(target_x, target_y)
                    self.log_action(f"Template '{template_name}' match found (confidence: {max_val:.2f}).")
                    return True
                else:
                    self.log_action(f"Template '{template_name}' match failed (confidence: {max_val:.2f}).")
                    return False
            except Exception as e:
                retry_count += 1
                if retry_count == self.config["retry_attempts"]:
                    self.log_action(f"Failed after {retry_count} retries for '{template_name}': {e}. Pausing.")
                    time.sleep(self.config["error_recovery_delay"])
                    return False
                self.log_action(f"Retry {retry_count}/{self.config['retry_attempts']} for '{template_name}': {e}")
                time.sleep(self.config["retry_delay"])
        return False

    def autoHatch(self):
        return self.search_and_click_templates("hatch_button")

    def autoRebirth(self):
        return self.search_and_click_templates("rebirth_ready")

    def autoUpgrade(self):
        return self.search_and_click_templates("upgrade_button")

    def autoCollect(self):
        frame = np.array(pyautogui.screenshot(region=self.config["pixelsearch_area"]))
        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY) if self.config["use_greyscale"] else frame
        # Simplified pixel search (no direct color match in Python, using template-like logic or threshold)
        # For now, we'll assume a template-based approach or skip unless pixel color is added
        self.log_action("autoCollect not fully implemented with pixel search yet.")
        return False

    def autoConvert(self):
        return self.search_and_click_templates("convert_button")

    def main_loop(self):
        """Main automation loop."""
        self.last_window = win32gui.GetWindowText(win32gui.GetForegroundWindow())
        last_switch_time = time.time()

        while self.running:
            if self.paused:
                time.sleep(self.config["pause_sleep"])
                continue

            roblox_windows = self.find_roblox_windows()
            if not roblox_windows:
                self.log_action("No Roblox windows found. Waiting 10s...")
                time.sleep(10)
                continue

            self.log_action(f"Found {len(roblox_windows)} Roblox window(s).")
            for hwnd in roblox_windows:
                if not self.running:
                    break
                window_title = win32gui.GetWindowText(hwnd)
                if self.bring_to_front(window_title):
                    start_time = time.time()
                    while time.time() - start_time < self.config["interaction_duration"]:
                        if not self.running or self.paused:
                            break
                        if self.coords:
                            for x, y in self.coords:
                                self.click_at(x, y)
                        for func in self.enabled_functions:
                            if func == "autoHatch":
                                self.autoHatch()
                            elif func == "autoRebirth":
                                self.autoRebirth()
                            elif func == "autoUpgrade":
                                self.autoUpgrade()
                            elif func == "autoCollect":
                                self.autoCollect()
                            elif func == "autoConvert":
                                self.autoConvert()
                        time.sleep(random.uniform(0.8, 1.2))

                current_window = win32gui.GetWindowText(win32gui.GetForegroundWindow())
                if current_window != self.last_window:
                    self.window_switch_count += 1
                    self.last_window = current_window
                    last_switch_time = time.time()
                    if self.window_switch_count >= self.config["max_window_switches"]:
                        self.log_action("Too many window switches. Stopping.")
                        self.stop_automation()
                        break
                elif time.time() - last_switch_time > self.config["window_stability_timeout"]:
                    self.window_switch_count = max(0, self.window_switch_count - 1)

            self.log_action(f"Cycle done. Waiting {self.config['timer_interval']}s.")
            time.sleep(self.config["timer_interval"])

    def log_action(self, action: str):
        """Log actions to a daily file if enabled."""
        if self.enable_logging:
            self.log_file = os.path.join(LOGS_DIR, f"log_{datetime.now().strftime('%Y%m%d')}.txt")
            with open(self.log_file, "a") as f:
                f.write(f"{datetime.now().isoformat()}: {action}\n")
        print(action)

# ==================== GUI ====================
class BeeGUI(tk.Tk):
    def __init__(self, core: BeeAutomationCore):
        super().__init__()
        self.core = core
        self.title("🐝 BeeBrained’s MAT 🐝")
        self.geometry("400x500")
        self.attributes("-topmost", True)

        # Status Label
        self.status_label = tk.Label(self, text="Status: Idle", font=("Arial", 12))
        self.status_label.pack(pady=10)

        # Control Buttons
        self.start_btn = tk.Button(self, text=f"Start ({self.core.config['start_key']})", command=self.core.start_automation)
        self.start_btn.pack(pady=5)

        self.stop_btn = tk.Button(self, text=f"Stop ({self.core.config['stop_key']})", command=self.core.stop_automation)
        self.stop_btn.pack(pady=5)

        self.pause_btn = tk.Button(self, text=f"Pause/Resume ({self.core.config['pause_key']})", command=self.core.toggle_pause)
        self.pause_btn.pack(pady=5)

        self.capture_coords_btn = tk.Button(self, text=f"Capture Coords ({self.core.config['capture_key']})", command=self.core.capture_coords)
        self.capture_coords_btn.pack(pady=5)

        self.capture_templates_btn = tk.Button(self, text=f"Capture Templates (Shift+{self.core.config['capture_key']})", command=self.core.capture_templates)
        self.capture_templates_btn.pack(pady=5)

        self.set_area_btn = tk.Button(self, text="Set Search Area", command=self.set_search_area)
        self.set_area_btn.pack(pady=5)

        # Logging Controls
        self.log_toggle_var = tk.BooleanVar(value=self.core.enable_logging)
        self.log_toggle = tk.Checkbutton(self, text="Enable Logging", variable=self.log_toggle_var, command=self.toggle_logging)
        self.log_toggle.pack(pady=5)

        self.view_log_btn = tk.Button(self, text="View Log", command=self.view_log)
        self.view_log_btn.pack(pady=5)

        # Function Controls
        self.function_frame = tk.Frame(self)
        self.function_frame.pack(pady=10)
        self.function_vars = {}
        self.function_indicators = {}
        functions = ["autoHatch", "autoRebirth", "autoUpgrade", "autoCollect", "autoConvert"]
        for i, func in enumerate(functions):
            var = tk.BooleanVar(value=func in self.core.enabled_functions)
            self.function_vars[func] = var
            chk = tk.Checkbutton(self.function_frame, text=func, variable=var, command=lambda f=func: self.toggle_function(f))
            chk.grid(row=i, column=0, padx=5, pady=2)
            indicator = tk.Label(self.function_frame, text="", width=2)
            indicator.grid(row=i, column=1, padx=5)
            self.function_indicators[func] = indicator
            btn = tk.Button(self.function_frame, text=f"Test {func}", command=lambda f=func: self.test_function(f))
            btn.grid(row=i, column=2, padx=5, pady=2)

        # Config Save/Load
        self.config_frame = tk.Frame(self)
        self.config_frame.pack(pady=10)
        tk.Label(self.config_frame, text="Config Name:").pack(side=tk.LEFT, padx=5)
        self.config_name = tk.Entry(self.config_frame, width=15)
        self.config_name.insert(0, "default")
        self.config_name.pack(side=tk.LEFT, padx=5)
        self.save_config_btn = tk.Button(self.config_frame, text="Save Config", command=self.save_config)
        self.save_config_btn.pack(side=tk.LEFT, padx=5)
        self.config_list = tk.OptionMenu(self.config_frame, tk.StringVar(value="default"), *self.get_config_list(), command=self.load_config)
        self.config_list.pack(side=tk.LEFT, padx=5)

        # Info Label
        self.info_label = tk.Label(self, text="By BeeBrained | YouTube: @BeeBrained-PS99 | Discord: QVncFccwek", font=("Arial", 8))
        self.info_label.pack(pady=10)

        self.protocol("WM_DELETE_WINDOW", self.on_closing)
        self.update_status()

    def update_status(self):
        """Update GUI status."""
        status = "Running" if self.core.running else "Paused" if self.core.paused else "Idle"
        self.status_label.config(text=f"Status: {status}\nCoords: {len(self.core.coords)} | Templates: {len(self.core.templates)}")
        for func in self.function_indicators:
            self.function_indicators[func].config(bg="SystemButtonFace")  # Reset indicators
        self.after(100, self.update_status)

    def set_search_area(self):
        """Set pixel search area dynamically."""
        messagebox.showinfo("Set Search Area", "Click top-left corner of search area.")
        while not keyboard.is_pressed("left"):
            time.sleep(0.1)
        x1, y1 = pyautogui.position()
        messagebox.showinfo("Set Search Area", "Click bottom-right corner of search area.")
        while not keyboard.is_pressed("left"):
            time.sleep(0.1)
        x2, y2 = pyautogui.position()
        self.core.config["pixelsearch_area"] = [x1, y1, x2, y2]
        self.core.log_action(f"Updated pixelsearch_area to {x1},{y1}-{x2},{y2}")
        config = configparser.ConfigParser()
        config.read("BeeConfig.ini")
        config["BeeSettings"]["pixelsearch_area"] = f"{x1},{y1},{x2},{y2}"
        with open("BeeConfig.ini", "w") as f:
            config.write(f)

    def toggle_logging(self):
        """Toggle logging state."""
        self.core.enable_logging = self.log_toggle_var.get()
        config = configparser.ConfigParser()
        config.read("BeeConfig.ini")
        config["BeeSettings"]["enable_logging"] = "1" if self.core.enable_logging else "0"
        with open("BeeConfig.ini", "w") as f:
            config.write(f)

    def view_log(self):
        """Open the current log file."""
        os.startfile(self.core.log_file)

    def toggle_function(self, func: str):
        """Toggle a function’s enabled state."""
        if self.function_vars[func].get():
            if func not in self.core.enabled_functions:
                self.core.enabled_functions.append(func)
        else:
            if func in self.core.enabled_functions:
                self.core.enabled_functions.remove(func)

    def test_function(self, func: str):
        """Test a specific function."""
        if func == "autoHatch":
            self.core.autoHatch()
        elif func == "autoRebirth":
            self.core.autoRebirth()
        elif func == "autoUpgrade":
            self.core.autoUpgrade()
        elif func == "autoCollect":
            self.core.autoCollect()
        elif func == "autoConvert":
            self.core.autoConvert()
        self.function_indicators[func].config(bg="green")
        self.after(100, lambda: self.function_indicators[func].config(bg="SystemButtonFace"))

    def save_config(self):
        """Save the current config to a file."""
        config_name = self.config_name.get()
        if not config_name:
            messagebox.showerror("Error", "Enter a config name!")
            return
        config_path = os.path.join(CONFIGS_DIR, f"{config_name}.ini")
        os.makedirs(CONFIGS_DIR, exist_ok=True)
        with open("BeeConfig.ini", "r") as src, open(config_path, "w") as dst:
            dst.write(src.read())
        self.core.log_action(f"Saved config as {config_name}.ini")
        self.update_config_list()

    def load_config(self, config_name: str):
        """Load a saved config."""
        config_path = os.path.join(CONFIGS_DIR, f"{config_name}.ini")
        if os.path.exists(config_path):
            with open(config_path, "r") as src, open("BeeConfig.ini", "w") as dst:
                dst.write(src.read())
            self.core.config = load_config()
            self.core.enable_logging = self.core.config["enable_logging"]
            self.log_toggle_var.set(self.core.enable_logging)
            self.core.log_action(f"Loaded config: {config_name}")
            self.update_config_list()

    def get_config_list(self) -> List[str]:
        """Get list of saved configs."""
        return [f.replace(".ini", "") for f in os.listdir(CONFIGS_DIR) if f.endswith(".ini")]

    def update_config_list(self):
        """Update the config dropdown."""
        menu = self.config_list["menu"]
        menu.delete(0, "end")
        for config in self.get_config_list():
            menu.add_command(label=config, command=lambda c=config: self.load_config(c))

    def on_closing(self):
        """Handle window close."""
        self.core.stop_automation()
        self.destroy()

# ==================== MAIN EXECUTION ====================
if __name__ == "__main__":
    print("🐝 BeeBrained’s MAT booting up! 🐝")
    config = load_config()
    core = BeeAutomationCore(config)
    gui = BeeGUI(core)
    gui.mainloop()
    print("🐝 MAT shut down. Catch you later! 🐝")
