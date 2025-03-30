# 🐝 BeeBrained's Master Automation Tool (BMAT) 🐝

A versatile automation powerhouse built for efficiency and flexibility, perfect for repetitive tasks in games like Pet Simulator 99 (PS99) and beyond. This is the AHK implementation focused on simplicity and reliability.

**Created by:** BeeBrained  
- 📺 YouTube: [@BeeBrained-PS99](https://www.youtube.com/@BeeBrained-PS99)  
- 💬 Discord: [Hive Hangout](https://discord.gg/QVncFccwek)

## 🚀 Key Features

- **State-based Automation**: Robust workflow management with automatic error recovery
- **Advanced Image Recognition**: Multi-method template matching with transparency support
- **Multi-Window Support**: Automatically handles multiple Roblox instances
- **Human-like Interaction**: Randomized delays and movements to avoid detection
- **Comprehensive Error Handling**: Automatic detection and recovery from common issues
- **Extensive Configuration**: Easily customize all aspects of the automation
- **Powerful Debugging Tools**: Screenshot capture, performance tracking, and detailed logging
- **Anti-AFK System**: Intelligent anti-idle system with configurable patterns
- **Command Panel**: Test individual functions directly from the GUI
- **Performance Monitoring**: Track metrics and optimize automation

## 📋 Requirements

- Windows 10 or newer
- [AutoHotkey v2.0+](https://www.autohotkey.com/)
- Roblox running in windowed mode (not fullscreen)

## 🛠️ Setup Instructions

1. **Install AutoHotkey v2** if you haven't already
2. **Clone or download** this repository
3. **Place the script** in a folder with write permissions (e.g., C:\Apps\BMAT)
4. **Configure settings** in `config.ini` (or use the defaults)
5. **Run `BMAT.ahk`** as administrator

## ⚙️ Configuration

BMAT is highly configurable through the `config.ini` file. Key settings include:

```ini
[Timing]
CLICK_DELAY_MIN=500          ; Minimum delay between clicks (ms)
CLICK_DELAY_MAX=1500         ; Maximum delay between clicks (ms)
INTERACTION_DURATION=5000     ; Duration of interactions (ms)
ANTI_AFK_INTERVAL=300000     ; Anti-AFK check interval (ms)

[Window]
WINDOW_TITLE=Roblox          ; Window title to match
EXCLUDED_TITLES=Roblox Account Manager  ; Windows to exclude

[Features]
SAFE_MODE=true               ; Enable additional safety checks
ENABLE_AUTO_RECONNECT=true   ; Auto reconnect on disconnection

[Templates]
MATCH_THRESHOLD=0.7          ; Minimum confidence for template matches
USE_TRANSPARENT=true         ; Use transparent templates when available
```

## 🎮 Usage

- Press **F1** to start automation
- Press **F2** to toggle automation
- Press **P** to pause/resume
- Press **T** for teleport menu
- Press **F** for inventory
- Press **Esc** to exit

## 🔍 Debug Mode

Run with debug parameter to enable advanced debugging:
```
.\BMAT.ahk debug
```

Debug hotkeys:
- **F6**: Capture screenshot
- **F7**: Test template detection
- **F8**: Check automation state
- **F9**: Display current status
- **F10**: Show performance metrics
- **F11**: Cycle debug levels
- **F12**: Toggle debug mode

## 📂 Project Structure

```
BMAT/
├── BMAT.ahk                # Main script file
├── config.ini             # Configuration file
├── config.example.ini     # Example configuration
├── templates/             # Template images
├── logs/                  # Log files
├── configs/               # Configuration presets
├── docs/                  # Documentation
│   ├── BMAT_FunctionReference.md
│   └── CHANGELOG.md
└── README.md             # This file
```

## 📚 Documentation

- [Function Reference](docs/BMAT_FunctionReference.md) - Detailed function documentation
- [Changelog](docs/CHANGELOG.md) - Version history and changes

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📝 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgements

- The AutoHotkey community for their invaluable resources
- Pet Simulator 99 players for testing and feedback 