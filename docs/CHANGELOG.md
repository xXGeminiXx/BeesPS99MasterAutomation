# Changelog

All notable changes to BMAT will be documented in this file.

## [2.0.0] - 2025-03-30

### Added
- Complete rewrite of core automation system
- New state-based architecture with improved error handling
- Advanced template matching with native AHK ImageSearch
- Multi-window support with automatic rotation
- Comprehensive GUI with command panel
- Configuration preset system
- Performance monitoring and metrics
- Daily log rotation
- Anti-AFK system with configurable patterns
- Debug mode with extensive tools
- Template caching for improved performance
- Enhanced error recovery with exponential backoff:
  - Configurable base delay and backoff factor
  - Maximum delay cap of 30 seconds
  - Automatic game reset after max retries
  - Detailed recovery attempt logging
  - GUI updates during recovery process

### Changed
- Updated to match repository at https://github.com/xXGeminiXx/BeesPS99MasterAutomation
- Improved error recovery with exponential backoff
- Enhanced window detection logic
- Reorganized project structure
- Updated all documentation
- Streamlined configuration system
- Removed GDI+ dependency in favor of native AHK image handling
- Refactored error handling into dedicated functions
- Added configurable error recovery settings

### Fixed
- Window activation issues
- Template matching reliability
- Performance bottlenecks
- Log file handling
- Error detection accuracy
- Error recovery reliability with smart backoff

## [1.0.0] - 2025-03-15

### Initial Release
- Basic automation framework
- Simple GUI
- Basic error handling
- Window detection
- Template matching
- Configuration system
- Logging system 