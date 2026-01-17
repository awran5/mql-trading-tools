# Changelog - iCrosshair for MetaTrader 5

All notable changes to **iCrosshair MT5** will be documented in this file.

> **Note:** This is the MT5 version changelog. For the original MQL4 version, see [iCrosshair.mq4](https://www.mql5.com/en/code/15515).

---

## [1.0] - 2026-01-17

### First Public Release for MT5

This is the first official release of iCrosshair for MetaTrader 5, a complete rewrite from the legacy MQL4 version (v1.01, 2015-2016).

---

### New Features

#### Keyboard Shortcut
- Press **'T'** to toggle tracking mode instantly
- Much faster than clicking chart lines

#### Compact Info Bar
New analytical format with all essential candle data:

```
Bar:5 | Pips:12.3 | O:1.0850 H:1.0875 L:1.0820 C:1.0860 | Range:55 | Body:40% | UW:25% LW:35% | Vol:1234 | 2026.01.15 14:00
```

| Metric | Description |
|--------|-------------|
| **Bar** | Bar index from current (0 = current bar) |
| **Pips** | Distance from cursor to bar's close price |
| **O/H/L/C** | OHLC prices (compact format) |
| **Range** | Total candle size in pips/points |
| **Body%** | Body as percentage of Range |
| **UW%/LW%** | Upper/Lower Wick as percentage of Range |
| **Vol** | Tick volume for the bar |
| **Close Time** | Date and time of candle close |

#### Customizable Display
Input parameters to control what's displayed:
- `Show_OHLC` - Toggle O/H/L/C prices
- `Show_Volume` - Toggle volume display
- `Show_Ratios` - Toggle Range, Body%, UW%, LW%

#### Universal Symbol Support
Auto-detects and adapts to:
- Forex pairs (EURUSD, GBPJPY) → displays in **pips**
- Metals (XAUUSD, XAGUSD) → displays in **points**
- Indices (SPX500, NAS100) → displays in **points**
- Crypto (BTCUSD, ETHUSD) → displays in **points**
- Stocks (AAPL, TSLA) → displays in **points**

---

### Performance Optimizations

#### Debounced Rendering
- Limited to 20 FPS (50ms intervals)
- Reduces CPU usage by ~80% compared to unlimited updates
- Essential for multi-chart workstations

#### Smart Caching
- CopyRates called only when bar changes or new candle forms
- Reduces API calls by ~95%

#### Sliding Window
- Uses 200-bar window instead of full history
- Minimizes memory usage when scrolling through charts

#### Cached Symbol Detection
- `IsForexSymbol()` computed once at initialization
- No repeated API calls during mouse movement

---

### Technical Improvements

- MQL5 native architecture (64-bit optimized)
- `OnChartEvent` for responsive mouse tracking
- Namespace-safe object names (`iCH_` prefix)
- Comprehensive input validation
- Clean deinitialization with reason logging
- Comprehensive bounds checking and error handling

---

### Migration from MQL4

**Breaking Changes:**
- File extension: `.mq4` → `.mq5`
- Requires MetaTrader 5 (will not compile on MT4)

**Preserved:**
- Visual appearance
- User workflow

---

## Legacy Version History (MQL4)

### [1.01] - 2016
- Added option to hide tooltip (`ShowTooltip` input)

### [1.00] - 2015
- Initial release
- Interactive crosshair with horizontal/vertical lines
- Tooltip showing OHLC, volume, wick sizes
- Comment showing bar number, pips, price
- Click-to-measure mode
- Customizable line color, style, width

---

## Versioning

This project uses [Semantic Versioning](https://semver.org/):
- **Major (1.x):** New platform or breaking changes
- **Minor (x.1):** New features, backward-compatible
- **Patch (x.x.1):** Bug fixes, minor improvements
