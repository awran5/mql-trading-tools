# Changelog

All notable changes to the **Adaptive VWAP Institutional** indicator will be documented in this file.

## [1.0.0] - 2026-01-14

### Added
- **Initial Public Release (Gold Master)**.
- **Institutional Timezone Contexts**: Full support for NY, London, Tokyo, and Sydney sessions with automatic DST adjustments.
- **Adaptive Asset Detection**: Built-in intelligence to detect symbol types and apply corresponding reset logic (Forex 5pm NY, Crypto 24/7, stocks, etc.).
- **Volume Spike Filter**: Advanced volatility-aware volume filtering using median sampling to prevent skewed VWAP lines.
- **Persistence Engine**: Disk-based caching system to preserve session state and speed up performance across terminal restarts or timeframe switches.
- **Standard Deviation Bands**: Highly optimized calculation of multiple deviation levels ($\pm\sigma$) with per-tick updates.
- **On-Chart Professional UI**: Diagnostic panel with real-time statistics (current price distance, session volume, bar counts).
- **Architecture Refactor**: Modular, clean code structure optimized for maintainability and low-latency execution.
- **Input Robustness**: Intelligent parameter clamping and validation to prevent visual or calculation anomalies.
