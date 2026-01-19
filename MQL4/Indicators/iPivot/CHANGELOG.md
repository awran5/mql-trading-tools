# Changelog

## [2.00] - 2026-01-20

### 🚀 Major Improvements
-   **Architecture:** Completely rewritten using Event-Driven Architecture. Calculations now occur on `New Day` events only, resulting in effectively zero CPU usage.
-   **Display Engine:** Replaced `OBJ_TREND` with `OBJ_HLINE` for cleaner full-width levels. Implemented a Persistent Object Manager to eliminate chart flickering.
-   **Labels:** Labels now include the price (e.g., `@ 1.2345`) and automatically update their position to stay effective on the current bar.

### 🐛 Bug Fixes
-   **Woodie Formula:** Corrected the legacy calculation. Now properly weighted as `(H + L + 2*C) / 4`.
-   **Object Thrashing:** Fixed the v1.01 logic that deleted and recreated objects on every tick.
-   **Buffer Empty:** Fixed issue where buffers were not populated, enabling correct values in the Data Window.
-   **Alert Spam:** Implemented "Debounce" logic. Alerts now trigger only once per level per bar.
-   **Memory Leak:** Fixed `ObjectsDeleteAll` ambiguity for newer MT4 builds using explicit loops.

### 🔧 Other Changes
-   **Strict Mode:** Codebase is now 100% compliant with `#property strict`.
-   **Inputs:** Removed redundant custom sound inputs (`InpSoundName`) in favor of standard system alerts.
-   **Compatibility:** Added backward compatibility cleanup to remove old v1.01 objects from charts upon upgrade.

---

## [1.01] - 2015-05-10
-   *Original Release by Awran5.*
-   Basic support for Standard, Fib, Camarilla, Woodie, DeMark.
