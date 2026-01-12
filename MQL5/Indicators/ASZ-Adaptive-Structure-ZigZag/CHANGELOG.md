# Changelog - ASZ (Adaptive Structure ZigZag)

All notable changes to ASZ will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-12 (Public Release)

### Added
- Centralized version variables (INDICATOR_NAME, INDICATOR_VERSION)
- External documentation: README.md, LICENSE, CHANGELOG.md
- Constants for all magic numbers

### Changed
- **Rebranded** from "Adaptive ZigZag" to "ASZ - Adaptive Structure ZigZag"
- Version reset to 1.0.0 for public release
- Unified ATR interface using barIndex

### Removed
- Legacy shift-based ATR functions
- Harmonic pattern labels (X,A,B,C,D) to avoid confusion

---

## Pre-Release Development History

*The following versions were internal development builds before public release.*

### Internal v2.13
- Unified ATR interface to barIndex
- Removed legacy GetATR(shift) functions

### Internal v2.12
- Added constants for magic numbers
- Memory allocation checks for ArrayResize

### Internal v2.11
- Removed harmonic pattern labels

### Internal v2.10
- State Machine pattern for alternation logic
- Unified IsFractal() function (DRY principle)
- Refactored OnCalculate into helper functions

### Internal v2.00
- ATR Cache optimization (50-100x performance)
- Pre-calculated ATR moving average
- PriceEquals() helper for floating-point comparison

### Internal v1.00
- Basic ZigZag implementation
- Three threshold modes
- Dynamic fractal detection
