# Changelog - RSI Monitor

All notable changes to the RSI Monitor indicator will be documented in this file.

## [2.0.0] - 2025-01-14
### Institutional-Grade Overhaul
This release marks a complete rewrite of the original 2015 indicator, turning it into a high-performance market analysis tool.

### Added
- **Zero-Lag RSI Engine**: Custom delagged RSI calculation for reduced signal lag.
- **Adaptive Trend Analysis**: Trend detection using percentage-based change thresholds.
- **Divergence Engine**: Professional price-RSI divergence detection with zone verification.
- **Confluence Aggregator**: Multi-timeframe bias scoring with visual "Strong Bias" signal.
- **Advanced Alerts**: 
  - Instant tick-by-tick processing (independent of chart timeframe).
  - Per-timeframe cooldown system.
  - State escalation alerts (e.g., alert when OB moves to Extreme OB).
- **Modern UI**: Refined aesthetics with Standard/Extended styles and state-aware coloring.

### Optimized
- **Multi-Tier Caching**: Dramatically reduced CPU overhead by caching RSI values (Live shift-0 + historical).
- **Logic Cleanup**: Removed all legacy prototypes, unused variables, and magic numbers.
- **Robustness**: Implemented comprehensive error handling and input validation.

### Fixed
- Fixed MQL4 struct array compatibility issues.
- Resolved global alert blocking that previously missed independent signals across different timeframes.
- Fixed chart refresh delays using explicit `ChartRedraw`.

---

## [1.0.0] - 2015-06-20
- **Initial Release**: Basic multi-timeframe RSI panel shared on [MQL5 CodeBase](https://www.mql5.com/en/code/15182).
- Standard iRSI calculations and basic OB/OS alerts.
