# BMAT Function Reference

## Version 2.0.0 (Updated March 30, 2025)

This document provides a comprehensive reference of all functions in BeeBrained's Master Automation Tool (BMAT) for Pet Simulator 99.

## Core Functions

### Automation Control

#### BB_startAutomation()
**Description:** Initializes and starts the automation process.  
**Parameters:** None  
**Returns:** None  
**Notes:** Sets up timers, initializes state variables, and begins the automation loop.

#### BB_stopAutomation()
**Description:** Stops the automation process.  
**Parameters:** None  
**Returns:** None  
**Notes:** Cleans up timers and resets state variables.

#### BB_togglePause()
**Description:** Toggles the pause state of automation.  
**Parameters:** None  
**Returns:** None  
**Notes:** Updates GUI and logging to reflect pause state.

#### BB_setState(state)
**Description:** Updates the current automation state.  
**Parameters:**
- `state`: String - The new state ("Idle", "Interacting", "Processing", "Navigating", "Error")  
**Returns:** None  
**Notes:** Triggers state-specific behaviors and GUI updates.

### Window Management

#### BB_updateActiveWindows()
**Description:** Refreshes the list of active Roblox windows.  
**Parameters:** None  
**Returns:** Number of windows found  
**Notes:** Filters by process name and excluded titles.

#### BB_activateNextWindow()
**Description:** Switches to the next Roblox window in the list.  
**Parameters:** None  
**Returns:** True if successful, False if no windows available  
**Notes:** Implements circular rotation through windows.

### Template Matching

#### BB_smartTemplateMatch(templateName, &FoundX, &FoundY, hwnd, searchArea := "", customTolerance := 0)
**Description:** Advanced template matching with caching and multiple methods.  
**Parameters:**
- `templateName`: String - Name of the template file
- `&FoundX`: Integer (ByRef) - X coordinate of match
- `&FoundY`: Integer (ByRef) - Y coordinate of match
- `hwnd`: Integer - Window handle
- `searchArea`: String (Optional) - "x1,y1,x2,y2" format
- `customTolerance`: Integer (Optional) - Custom match threshold  
**Returns:** True if match found, False otherwise  
**Notes:** Uses AutoHotkey's native ImageSearch with optimized caching.

### User Interface

#### BB_setupGUI()
**Description:** Creates and configures the main GUI.  
**Parameters:** None  
**Returns:** None  
**Notes:** Includes command panel and configuration options.

#### BB_updateGUI()
**Description:** Updates GUI elements with current state.  
**Parameters:** None  
**Returns:** None  
**Notes:** Updates status text, metrics, and indicators.

### Configuration Management

#### BB_loadConfig()
**Description:** Loads settings from configuration file.  
**Parameters:** None  
**Returns:** True if successful, False if error  
**Notes:** Creates default config if none exists.

#### BB_saveConfig(configName := "")
**Description:** Saves current settings to configuration file.  
**Parameters:**
- `configName`: String (Optional) - Name for the config preset  
**Returns:** True if successful, False if error  
**Notes:** Supports multiple configuration presets.

### Error Handling

#### BB_handleError()
**Description:** Manages error recovery with exponential backoff.  
**Parameters:** None  
**Returns:** True if retry should be attempted, False if max retries reached  
**Notes:** 
- Implements exponential backoff with configurable base delay and factor
- Caps maximum delay at 30 seconds
- Resets game state when max retries reached
- Updates GUI and logs recovery attempts

#### BB_resetErrorState()
**Description:** Resets all error tracking variables.  
**Parameters:** None  
**Returns:** None  
**Notes:** Called after successful automation cycle or manual reset.

#### BB_checkForError(hwnd)
**Description:** Detects error conditions in the game.  
**Parameters:**
- `hwnd`: Integer - Window handle  
**Returns:** True if error detected, False otherwise  
**Notes:** Uses both template and pixel-based detection.

### Anti-AFK System

#### BB_antiAfkLoop()
**Description:** Prevents disconnection due to inactivity.  
**Parameters:** None  
**Returns:** None  
**Notes:** Uses configurable movement patterns.

### Performance Monitoring

#### BB_updatePerformanceStats(category, duration)
**Description:** Tracks performance metrics.  
**Parameters:**
- `category`: String - Category of operation
- `duration`: Integer - Duration in milliseconds  
**Returns:** None  
**Notes:** Maintains rolling averages and peak values.

### Logging System

#### BB_log(message, level := 1)
**Description:** Writes to log file with rotation.  
**Parameters:**
- `message`: String - Message to log
- `level`: Integer (Optional) - Debug level (1-5)  
**Returns:** None  
**Notes:** Supports daily log rotation.

## Implementation Details

### State Machine
The script uses a state-based architecture with the following states:
- **Idle**: Initial state, waiting for action
- **Interacting**: Actively interacting with game elements
- **Processing**: Processing game responses
- **Navigating**: Moving between locations
- **Error**: Handling and recovering from errors

### Error Recovery System
The script implements a robust error recovery system with exponential backoff:
- Base delay starts at 1 second (configurable)
- Each retry doubles the delay (configurable factor)
- Maximum delay capped at 30 seconds
- Maximum 5 retry attempts before game reset
- Automatic reset of error state on successful cycle
- Detailed logging of recovery attempts
- GUI updates during recovery process

Example retry sequence:
1. First retry: 1 second delay
2. Second retry: 2 seconds delay
3. Third retry: 4 seconds delay
4. Fourth retry: 8 seconds delay
5. Fifth retry: 16 seconds delay
6. Reset game state if all retries fail

### Performance Optimization
Several optimization techniques are employed:
- Template matching cache
- Window detection optimization
- Color comparison optimization
- State transition optimization

### Debug Features
Comprehensive debugging tools:
- Screenshot capture
- Performance metrics
- State tracking
- Template validation
- Error logging
- GUI status updates

## Best Practices

1. Always use BB_setState for state transitions
2. Implement proper error handling with BB_checkForError
3. Use BB_smartTemplateMatch for reliable detection
4. Monitor performance with BB_updatePerformanceStats
5. Maintain proper logging with BB_log
6. Use configuration presets for different scenarios
7. Regularly check window activation status
8. Implement appropriate delays between actions
9. Use the anti-AFK system appropriately
10. Monitor and rotate logs regularly 