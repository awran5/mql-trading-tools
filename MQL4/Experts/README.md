# FFC Data Feeder EA

**Companion Expert Advisor for the FFC (Canvas Economic Calendar) Indicator**

## Purpose

This EA downloads economic calendar data from Forex Factory's API and saves it locally for the FFC indicator to read. This architecture is required because:

- **MT4 Indicators** cannot use `WebRequest()` (platform limitation)
- **mql5.com Market** prohibits DLL imports for security reasons

## Setup (One-Time)

1. **Enable WebRequest:**
   - Go to `Tools → Options → Expert Advisors`
   - Check `Allow WebRequest for listed URL`
   - Add: `https://nfs.faireconomy.media/`
   - Click OK

2. **Attach the EA:**
   - Open any chart
   - Drag `FFC_Data_Feeder` from Navigator → Expert Advisors
   - Click OK

3. **Done!** The EA will:
   - Download data immediately on attach
   - Auto-update every 4 hours (configurable)
   - Save to `MQL4/Files/FFC_calendar_cache.json`

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| UpdateIntervalHrs | 4 | Hours between updates |
| ShowStatusOnChart | true | Show status in chart comment |

## How It Works

```
[Forex Factory API] → [EA downloads JSON] → [Saves to Files/] → [Indicator reads file]
```

The indicator monitors the file and reloads when updated.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "URL not allowed" error | Add URL to WebRequest whitelist |
| No data in indicator | Check EA is running (smiley face in corner) |
| Stale data | EA updates every 4 hours automatically |

## License

Same as FFC Indicator - see main repository.
