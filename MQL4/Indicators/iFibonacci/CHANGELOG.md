# Changelog

All notable changes to iFibonacci will be documented in this file.

## [2.0.0] - January 2026

### 🚀 Complete Rewrite from v1.0

This is a **major upgrade** with a completely rewritten swing detection engine and modernized codebase.

---

### ⚡ Swing Detection Engine (NEW)

#### Replaced External ZigZag
The old version relied on an external ZigZag indicator via `iCustom()`, which caused **repainting issues**. v2.0 implements a custom "Reverse-Scan" algorithm:

| Feature | v1.0 (Old) | v2.0 (New) |
|---------|------------|------------|
| Swing Source | External ZigZag | Built-in "Reverse-Scan" |
| Repainting | ❌ Yes (ZigZag repaints) | ✅ No (confirmed swings are stable) |
| "Equal Highs" Bug | ❌ Random selection | ✅ Right-Side Priority |
| Performance | Slow (iCustom calls) | Fast (direct memory access) |

#### Peak-Climbing Algorithm
When consecutive swings of the same type occur, the algorithm now keeps the **better extreme** (higher high or lower low) instead of simply alternating.

```
Before: High1 → Low1 → High2 (even if High1 > High2)
After:  High1 (kept if higher) → Low1 → High2 (only if higher than High1)
```

---

### 🛡️ Security Improvements

#### Removed user32.dll Dependency
The old version used **unsafe DLL imports** for Fibo Arc scaling:

```mql4
// OLD (v1.0) - UNSAFE
#import "user32.dll"
   int GetSystemMetrics(int nIndex);
#import
```

v2.0 calculates arc scale using **pure MQL4 functions**, eliminating the security risk.

---

### 🎨 Visual Improvements

#### Smart Label Stacking
Labels for multiple Fibonacci tools no longer overlap. Each tool's labels are positioned to avoid collision.

#### Centered High/Low Labels
Daily/Weekly/Monthly High/Low labels are now centered on the line instead of anchored at the left edge.

#### Pending Swing Visual
A new feature shows unconfirmed extreme points as dimmed markers, giving traders a preview of potential future swings without affecting confirmed Fibonacci drawings.

#### Ray Right for All Lines
All trend lines now extend to the right edge of the chart, ensuring visibility across all timeframes.

---

### 📢 New Features

| Feature | Description |
|---------|-------------|
| **Fibo Touch Alerts** | Sound and popup alerts when price touches Fibonacci levels |
| **Daily/Weekly/Monthly Levels** | Built-in High/Low/Pivot lines |
| **Candle Timer** | Shows time remaining until candle closes |
| **Pending Swing Visual** | Preview of unconfirmed extremes |
| **Auto Swing Depth** | Automatically adjusts depth per timeframe |

---

### ⚙️ Code Quality

#### Modernized Syntax
- Replaced deprecated `ObjectSet()` with `ObjectSetInteger()`/`ObjectSetString()`
- Added `#property strict` for better error detection
- Used `CopyHigh()`/`CopyLow()` instead of `iHigh()`/`iLow()` in loops

#### Performance Optimizations
- Pre-fetched arrays reduce MT4 kernel transitions
- Caching for Arc scale, High/Low calculations
- New bar detection prevents redundant calculations

#### Better Documentation
- Comprehensive header changelog
- Inline comments explaining complex logic
- Debug mode for troubleshooting

---

### 🐛 Bug Fixes

| Bug | Fix |
|-----|-----|
| Double Top/Bottom bug | Strict neighbor comparison (`<=` instead of `<`) |
| "Equal Highs" random selection | Right-Side Priority rule |
| Arc scale inaccurate | Dynamic calculation based on chart dimensions |
| Objects not cleaned up | All objects use prefix and are deleted in OnDeinit |

---

### 📋 Input Parameters (v2.0)

#### New Parameters
- `AutoSwingDepth` - Auto-adjust depth per timeframe
- `ShowPendingSwing` - Show unconfirmed extremes
- `AlertOnFiboTouch` - Fibo level alerts
- `AlertTolerance` - Alert tolerance percentage
- `ShowDaily/Weekly/Monthly` - High/Low level lines

#### Removed Parameters
- External ZigZag settings (no longer needed)
- DLL-related settings (no longer needed)

---

## [1.0.0] - 2015

### Original Release
- Basic Fibonacci tools (Retracement, Arc, Fan, Time Zones, Expansion)
- External ZigZag for swing detection
- user32.dll for arc scaling
