# Changelog - iCrosshair for MetaTrader 4

All notable changes to **iCrosshair MT4** will be documented in this file.

> **Original Version:** [iCrosshair v1.x on MQL5.com](https://www.mql5.com/en/code/15515) (2015-2016)

---

## [2.0] - 2026-01-17

### Major Update (Complete Rewrite)

Complete rewrite of the original iCrosshair v1.x with modern architecture and new features.

---

### New Features

#### Keyboard Shortcut
- Press **'T'** to toggle tracking mode instantly
- Much faster than clicking chart lines (v1.x click-only)

#### Compact Info Bar
New analytical format with all essential candle data in one line:

```
Bar:5 | Pips:12.3 | O:1.0850 H:1.0875 L:1.0820 C:1.0860 | Range:55 | Body:40% | UW:25% LW:35% | Vol:1234 | 2026.01.15 14:00
```

**vs v1.x format:** `bar / pips / price` (basic)

| Metric | Description |
|--------|-------------|
| **Bar** | Bar index from current (0 = current bar) |
| **Pips** | Distance from cursor to bar's close price |
| **O/H/L/C** | OHLC prices (compact format) |
| **Range** | Total candle size in pips/points ⭐ NEW |
| **Body%** | Body as percentage of Range ⭐ NEW |
| **UW%/LW%** | Upper/Lower Wick as percentage of Range ⭐ NEW |
| **Vol** | Tick volume for the bar |
| **Close Time** | Date and time of candle close ⭐ NEW |

#### Customizable Tooltip Fields
New input parameters to control what's displayed:
- `Show_OHLC` - Toggle O/H/L/C prices
- `Show_Volume` - Toggle volume display
- `Show_Ratios` - Toggle Range, Body%, UW%, LW%

**vs v1.x:** All fields shown or none (no granular control)

#### Universal Symbol Support
Auto-detects and adapts to:
- Forex pairs (EURUSD, GBPJPY) → displays in **pips**
- Metals (XAUUSD, XAGUSD) → displays in **points**
- Indices (SPX500, NAS100) → displays in **points**
- Crypto (BTCUSD, ETHUSD) → displays in **points**

**vs v1.x:** Forex only with simple 4/5 digit detection

---

### Optimizations

#### Two-Tier Update Strategy
- **Lines:** Update immediately (every mouse event) → smooth tracking
- **Data:** Debounced at 20 FPS (50ms) → saves CPU

**vs v1.x:** No debouncing, redraw on every mouse event

#### Cached Symbol Detection
- `IsForexSymbol()` computed once at initialization
- No repeated MarketInfo calls during mouse movement

**vs v1.x:** `pips2double` calculated but no symbol classification

#### Namespace-Safe Object Names
- Objects use `iCH_` prefix (e.g., `iCH_H_Line`)

**vs v1.x:** Plain names (`H Line`, `V Line`) - potential conflicts

---

### Hardening

| Improvement | v1.x | v2.0 |
|-------------|------|------|
| Bounds checking | ❌ None | ✅ Before all array access |
| Error handling | ❌ Basic | ✅ GetLastError() reporting |
| Object validation | ❌ None | ✅ ObjectFind before access |
| Deinit logging | ❌ None | ✅ Reason text logging |
| Input validation | ❌ None | ✅ LineWidth clamped 1-5 |

---

## Legacy Version History

### [1.01] - 2016
- Added option to remove tooltip (`ShowTooltip` input)

### [1.00] - 2015
- Initial release
- Interactive crosshair with horizontal/vertical lines
- Tooltip showing OHLC, volume, wick sizes
- Customizable line color, style, width

---

## Versioning

This project uses [Semantic Versioning](https://semver.org/):
- **Major (2.x):** Breaking changes or complete rewrites
- **Minor (x.1):** New features, backward-compatible
- **Patch (x.x.1):** Bug fixes, minor improvements
