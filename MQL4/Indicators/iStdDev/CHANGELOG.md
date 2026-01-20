# Changelog

All notable changes to the **iStdDev Pro** project.

## [2.00] - 2026-01-20
### 🎯 Ground-Up Reconstruction
- **Full Rewrite**: Migrated entire codebase from legacy MT4 `OBJ_STDDEVCHANNEL` dependencies to a custom-engineered statistical engine.
- **Performance Engine**: Implemented "Single-Pass" math loops, resulting in a 40-60% efficiency boost in real-time calculations.
- **Enhanced Accuracy**: Replaced binary point-checks with Epsilon-based comparisons for deep numerical stability.

### ✨ New Institutional Features
- **Smart Anchoring**: Three advanced modes (Structure-based, Trend-Adaptive R², and Manual Fixed).
- **R² Optimization**: Integrated Trend Quality metrics to automatically find the most statistically significant window.
- **Multi-Source Price Routing**: Support for Close, Typical, Median, and Weighted price arrays.
- **Fibonacci Targets**: New visual layers for 0.618 and 1.618 standard deviation increments.
- **Dynamic HUD**: Real-time chart statistics showing Slope, R², and precise range levels.
- **Smart Alerts**: Precise Touch/Break alert logic with automatic broker-pip scaling.

### 🎨 Visual & UI Improved
- **High/Low Markers**: Intelligent anchor markers that visually differentiate between High and Low pivots.
- **Refined Drawing**: Optimized object layering (Z-Order) to ensure lines are drawn behind price action for better visibility.
- **Tooltips**: Descriptive tooltips for all chart objects including bar index information.

### 🛡️ Robustness & Validation
- **Deep Input Validation**: Integrated 10+ core sanity checks to prevent runtime errors and invalid window configurations.
- **Safety Guards**: Implemented `g_calcSuccess` guards to prevent erroneous alerts during history loading or calculation failures.
- **Data Sufficiency Logic**: Smarter handling of historical data loading with informative on-screen status.

---
**Maintained by:** awran5  
**Version:** 2.00 (Major Release)
