# Changelog

All notable changes to Canvas Economic Calendar (FFC) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] - 2025-01-13

### 🎉 Complete Rewrite
This version is a **complete architectural rewrite** of the indicator, replacing the legacy 2016 codebase with modern, production-grade implementation.

### Added

#### User Interface
- **Canvas-based rendering** using MQL4's `CCanvas` library for smooth, flicker-free display
- **Draggable panel** - Click and drag to reposition; position saved via `GlobalVariables`
- **Real-time filter buttons** (H/M/L) in panel header to toggle impact levels without reopening settings
- **Gradient background** with optimized LUT caching for performance
- **Modern dark theme** with carefully selected color palette

#### New Features
- **Symbol Info Bar** - Displays:
  - Number of high-impact events today
  - Next event countdown
  - Current spread
  - Bar countdown timer
- **Historical Event Markers** - Visual markers on past candles where events occurred
- **Actual Value Column** - Shows released economic data with color-coded comparison:
  - 🟢 Green = Better than forecast
  - 🔴 Red = Worse than forecast
- **Week Date Range** - Shows current week range in panel header (e.g., "Jan 11 - Jan 17")
- **Timezone Display** - Shows server timezone offset (e.g., "GMT+2") in panel header
- **Smart Countdown Format** - Days/hours/minutes format (e.g., "2d 5h", "45m", "In Progress")

#### Data Handling
- **JSON API** - Migrated from XML to JSON data source (`nfs.faireconomy.media`)
- **Custom JSON Parser** with:
  - Timeout protection (`JSON_PARSE_TIMEOUT`)
  - Maximum depth limiting (`MAX_PARSE_DEPTH`)
- **Smart Caching System**:
  - 4-hour cache validity check
  - Automatic week boundary detection
  - Force refresh on new week
- **Windows Cache Clearing** - Uses `wininet.dll` to clear IE cache before downloads

#### Production Hardening
- **Input Validation** - `ValidateInputs()` function clamps all parameters to safe ranges with warnings
- **Canvas State Management** - `ENUM_CANVAS_STATE` for safe initialization/destruction
- **Retry Logic** - Download retries with exponential backoff
- **Object Pooling** - Reuses chart objects (markers, lines) instead of delete/create cycles
- **Alert Cooldown** - `ALERT_COOLDOWN_SEC` prevents spam alerts
- **Settings Persistence** - Panel position and filter states saved across sessions

#### Code Architecture
- **Structured Event Storage** - `CalendarEvent` struct replaces `string Event[200][7]` array
- **Impact Level Enum** - `ENUM_IMPACT_LEVEL` for type-safe impact handling
- **Named Constants** - `#define` for all UI dimensions and limits
- **QuickSort Algorithm** - Efficient event sorting by time
- **Modular Functions** - Code split into focused, single-responsibility functions

### Changed

#### Data Source
| v1.0 | v2.0 |
|------|------|
| XML from `forexfactory.com/ff_calendar_thisweek.xml` | JSON from `nfs.faireconomy.media/ff_calendar_thisweek.json` |
| `StringFind`-based parsing | Custom JSON parser with safety limits |

#### Rendering Engine
| v1.0 | v2.0 |
|------|------|
| `OBJ_LABEL` chart objects | `CCanvas` bitmap rendering |
| 5 events displayed | 8 events displayed |
| Fixed 4-corner positioning | Free-drag positioning |
| Object deletion/recreation | Object pooling |

#### Currency Filtering
| v1.0 | v2.0 |
|------|------|
| `StringFind()` substring matching | Exact base/quote currency matching |
| "US30" matched "USD" (incorrect) | Only exact "USD" pairs match |

#### Cleanup Behavior
| v1.0 | v2.0 |
|------|------|
| Deleted `GlobalVariables` on any deinit | Only deletes on `REASON_REMOVE` |
| Lost settings on timeframe change | Preserves settings across TF changes |

### Removed
- Legacy `Draw()` function for `OBJ_LABEL` creation
- Simple 2D string array for event storage
- XML parsing code
- Fixed corner positioning system

### Fixed
- **ReportActiveOnly Logic** - Now correctly matches exact currency codes instead of substrings
- **Object Cleanup** - No more orphaned objects when removing indicator
- **Memory Leaks** - Proper canvas destruction and object cleanup
- **Alert Spam** - Cooldown prevents repeated alerts for same event

---

## [1.0.0] - 2016-08-15

### Initial Release
Original version by awran5, based on FFCal indicator contributions from:
- derkwehler (Core FFCal code, 2006)
- deVries (MT4 Build 600+ compatibility)
- qFish (Testing and improvements)
- atstrader (Active pair filtering)
- traderathome (Coordination and integration)

### Features
- XML-based data from Forex Factory
- Object-based UI rendering (`OBJ_LABEL`)
- 4-corner panel positioning
- Vertical event lines
- Basic alert system (popup, sound, push, email)
- Currency pair filtering
- Impact level filtering (High/Medium/Low)
- Event countdown display

---

## Migration Guide (v1.0 → v2.0)

### Breaking Changes
1. **Settings Reset** - All saved positions will be reset due to updated `GlobalVariable` naming (`FFC_` prefix)

### New Input Parameters
The following inputs are new in v2.0:
- `ShowSymbolInfo` - Toggle the bottom info bar
- `ShowHistoricalMarkers` - Toggle historical event markers

### Removed Input Parameters
None - all v1.0 inputs are still available.

### Recommended Actions
1. Remove the old indicator from all charts
2. Delete any compiled `.ex4` files
3. Add the new v2.0 indicator
4. Reconfigure your preferred settings

---

[2.0.0]: https://github.com/awran5/mql-trading-tools/releases/tag/FFC-v2.0.0
[1.0.0]: https://github.com/awran5/mql-trading-tools/releases/tag/FFC-v1.0.0
