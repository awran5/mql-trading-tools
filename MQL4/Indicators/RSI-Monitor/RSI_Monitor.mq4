//+------------------------------------------------------------------+
//|                                                  RSI Monitor.mq4 |
//|                                      Copyright 2015-2025, Awran5 |
//|                      https://github.com/awran5/mql-trading-tools |
//+------------------------------------------------------------------+
//| Version History                                                   |
//+------------------------------------------------------------------+
// v2.0.0 (2025) - Institutional-Grade Overhaul
//   NEW: Zero-Lag RSI option (reduced lag delagged calculation)
//   NEW: Divergence detection (bullish/bearish with zone validation)
//   NEW: Confluence scoring (aggregate multi-TF bias)
//   NEW: Adaptive Trend detection (percentage-based sensitivity)
//   NEW: Extreme OB/OS levels (separate thresholds for stronger signals)
//   NEW: Standard/Extended panel styles with refined aesthetics
//   NEW: Configurable alert cooldown (prevents alert floods)
//   OPT: Multi-tier RSI caching (live shift-0 update + bar-based historical)
//   OPT: Per-timeframe alert cooldown & state escalation (OB -> Extreme OB)
//   FIX: Robust error handling for RSI calculations
//   FIX: Proper corner positioning for all 4 screen corners
//
// v1.0.0 (2015) - Initial Release (MQL5.com)
//   - Basic multi-timeframe RSI display
//   - Overbought/Oversold zone alerts
//   - Subwindow support
//+------------------------------------------------------------------+
#property copyright "Copyright 2015-2025, Awran5"
#property link      "https://github.com/awran5/mql-trading-tools"
#property version   "2.00"
#property description "Multi-timeframe RSI panel with Standard/Zero-Lag RSI"
#property description "Features: Trend direction, Divergence detection, Confluence score"
#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_RSI_TYPE
{
   RSI_STANDARD = 0,    // Standard RSI
   RSI_ZERO_LAG = 1     // Zero-Lag RSI (Reduced Lag)
};

enum ENUM_PANEL_STYLE
{
   STYLE_CLASSIC  = 0,  // Classic (Original)
   STYLE_EXTENDED = 1   // Extended (With Trend & Signals)
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input string              sep0               = "";                  // ══════════ PANEL ══════════
input ENUM_BASE_CORNER    InpCorner          = CORNER_LEFT_UPPER;   // Panel Corner
input ENUM_PANEL_STYLE    InpPanelStyle      = STYLE_CLASSIC;       // Panel Style
input int                 InpXOffset         = 10;                  // X Offset (pixels)
input int                 InpYOffset         = 20;                  // Y Offset (pixels)
input color               InpBgColor         = C'25,25,25';         // Background Color
input color               InpTitleColor      = clrTomato;           // Title Color
input string              InpFontName        = "Consolas";          // Panel Font
input color               InpLabelColor      = clrSilver;           // Label Color
input color               InpValueColor      = clrDodgerBlue;       // Value Color
input color               InpOverboughtClr   = clrLime;             // Overbought Color
input color               InpOversoldClr     = clrRed;              // Oversold Color
input color               InpNeutralClr      = clrGray;             // Neutral Color
input color               InpBullishClr      = clrLime;             // Bullish Trend Color
input color               InpBearishClr      = clrRed;              // Bearish Trend Color
input color               InpBorderColor     = clrDimGray;          // Panel Border Color

input string              sep2               = "";                  // ══════════ RSI ══════════
input ENUM_RSI_TYPE       InpRSIType         = RSI_STANDARD;        // RSI Calculation Type
input int                 InpRSIPeriod       = 14;                  // RSI Period
input ENUM_APPLIED_PRICE  InpRSIPrice        = PRICE_CLOSE;         // Applied Price
input int                 InpZeroLagDepth    = 0;                   // Zero-Lag EMA Depth (0=Auto)
input double              InpOversoldLevel   = 30.0;                // Oversold Level
input double              InpOverboughtLevel = 70.0;                // Overbought Level
input double              InpExtremeOS       = 20.0;                // Extreme Oversold Level
input double              InpExtremeOB       = 80.0;                // Extreme Overbought Level

input string              sep2b              = "";                  // ══════════ FEATURES ══════════
input bool                InpShowTrend       = true;                // Show Trend Direction
input int                 InpTrendBars       = 3;                   // Bars for Trend Detection
input bool                InpShowDivergence  = true;                // Show Divergence Warnings
input double              InpDivPriceTol     = 0.001;               // Divergence Price Tolerance (0.001 = 0.1%)
input bool                InpShowConfluence  = true;                // Show Confluence Score
input bool                InpHighlightCurrTF = true;                // Highlight Current Timeframe

input string              sep3               = "";                  // ══════════ ALERTS ══════════
input bool                InpUseAlert        = false;               // Popup Alert
input bool                InpUseEmail        = false;               // Email Alert
input bool                InpUseNotification = false;               // Push Notification
input bool                InpUseSound        = false;               // Sound Alert
input string              InpSoundFile       = "alert2.wav";        // Sound File
input bool                InpAlertOnExtreme  = true;                // Alert Only on Extreme Levels
input bool                InpAlertOnDivergence = false;             // Alert on Divergence
input int                 InpAlertCooldown   = 60;                  // Alert Cooldown (seconds, 0=disabled)

//+------------------------------------------------------------------+
//| Layout Constants                                                  |
//+------------------------------------------------------------------+
const string INDICATOR_PREFIX = "RSIM_";
const string ICON_FONT        = "Wingdings";
const string ICON_CIRCLE      = "\x6C";
const string ICON_ARROW_UP    = "\xE9";
const string ICON_ARROW_DOWN  = "\xEA";

#define      TIMEFRAME_COUNT  9
const int    COL_WIDTH        = 38;
const int    PANEL_PADDING    = 12;
const int    ROW_HEIGHT       = 16;
const int    ICON_SIZE        = 10;
const int    FONT_SIZE_TITLE  = 9;
const int    FONT_SIZE_LABEL  = 8;
const int    FONT_SIZE_VALUE  = 8;
const int    FONT_SIZE_CONF   = 7;

const int    RSI_PERIOD_MIN   = 2;
const int    RSI_PERIOD_MAX   = 200;
const double RSI_DEFAULT      = 50.0;
const double RSI_MIN          = 0.0;
const double RSI_MAX          = 100.0;
const double TREND_THRESHOLD  = 2.0;        // Absolute threshold (legacy)
const double TREND_PERCENT    = 3.0;        // Percentage threshold for adaptive trend
const double DIV_RSI_DIFF     = 5.0;
const int    DIV_LOOKBACK     = 10;
const int    CONFLUENCE_STRONG= 4;
const int    FOOTER_SPACING   = 4;          // Vertical spacing for confluence footer

#define      RSI_CACHE_SIZE     15       // Cache size for trend/divergence lookback (must be #define for struct array)

//+------------------------------------------------------------------+
//| RSI State Enumeration                                             |
//+------------------------------------------------------------------+
enum ENUM_RSI_STATE
{
   STATE_EXTREME_OS = -2,
   STATE_OVERSOLD   = -1,
   STATE_NEUTRAL    = 0,
   STATE_OVERBOUGHT = 1,
   STATE_EXTREME_OB = 2
};

//+------------------------------------------------------------------+
//| Trend Direction Enumeration                                       |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIR
{
   TREND_FALLING = -1,
   TREND_FLAT    = 0,
   TREND_RISING  = 1
};

//+------------------------------------------------------------------+
//| Divergence Type Enumeration                                       |
//+------------------------------------------------------------------+
enum ENUM_DIV_TYPE
{
   DIV_BEARISH = -1,
   DIV_NONE    = 0,
   DIV_BULLISH = 1
};

//+------------------------------------------------------------------+
//| Timeframe Data Structure                                          |
//+------------------------------------------------------------------+
struct TimeframeData
{
   ENUM_TIMEFRAMES   tf;
   string            label;
   double            rsiValue;
   double            rsiPrev;
   double            rsiCache[RSI_CACHE_SIZE];  // Cached RSI values for lookback
   datetime          lastCacheBar;              // Last bar time when cache was updated
   ENUM_RSI_STATE    state;
   ENUM_TREND_DIR    trend;
   bool              hasDivergence;
   ENUM_DIV_TYPE     divType;
   bool              isCurrentTF;
};

//+------------------------------------------------------------------+
//| Alert Tracking Structure                                          |
//+------------------------------------------------------------------+
struct AlertState
{
   datetime          lastAlertTime;
   datetime          lastCooldownTime;   // Per-timeframe cooldown tracking
   int               lastAlertState;
   bool              lastDivState;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
TimeframeData g_timeframes[TIMEFRAME_COUNT];
AlertState    g_alertStates[TIMEFRAME_COUNT];
int           g_panelWidth;
int           g_panelHeight;
int           g_rsiPeriod;

//+------------------------------------------------------------------+
//| Initialization                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_rsiPeriod = InpRSIPeriod;
   if(g_rsiPeriod < RSI_PERIOD_MIN || g_rsiPeriod > RSI_PERIOD_MAX)
   {
      PrintFormat("RSI Monitor: Period %d invalid. Using default 14.", g_rsiPeriod);
      g_rsiPeriod = 14;
   }

   if(InpOverboughtLevel <= InpOversoldLevel)
   {
      Print("RSI Monitor: Overbought must be greater than Oversold level.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpExtremeOB <= InpOverboughtLevel || InpExtremeOS >= InpOversoldLevel)
   {
      Print("RSI Monitor: Extreme levels must be beyond standard OB/OS levels.");
      return INIT_PARAMETERS_INCORRECT;
   }

   InitTimeframes();
   InitAlertStates();

   //--- Validate InpTrendBars
   if(InpTrendBars < 1)
   {
      Print("RSI Monitor: TrendBars must be >= 1.");
      return INIT_PARAMETERS_INCORRECT;
   }

   //--- Calculate panel dimensions
   CalculatePanelDimensions();

   string rsiType = (InpRSIType == RSI_ZERO_LAG) ? "Zero-Lag" : "Standard";
   IndicatorShortName("RSI Monitor (" + rsiType + ")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Initialize Timeframe Data                                         |
//+------------------------------------------------------------------+
void InitTimeframes()
{
   ENUM_TIMEFRAMES tfs[]    = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
                               PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
   string          labels[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN"};
   ENUM_TIMEFRAMES currentTF = (ENUM_TIMEFRAMES)Period();

   for(int i = 0; i < TIMEFRAME_COUNT; i++)
   {
      g_timeframes[i].tf            = tfs[i];
      g_timeframes[i].label         = labels[i];
      g_timeframes[i].rsiValue      = RSI_DEFAULT;
      g_timeframes[i].rsiPrev       = RSI_DEFAULT;
      g_timeframes[i].state         = STATE_NEUTRAL;
      g_timeframes[i].trend         = TREND_FLAT;
      g_timeframes[i].hasDivergence = false;
      g_timeframes[i].divType       = DIV_NONE;
      g_timeframes[i].isCurrentTF   = (tfs[i] == currentTF);
      g_timeframes[i].lastCacheBar  = 0;
      ArrayInitialize(g_timeframes[i].rsiCache, RSI_DEFAULT);
   }
}

//+------------------------------------------------------------------+
//| Initialize Alert States                                           |
//+------------------------------------------------------------------+
void InitAlertStates()
{
   for(int i = 0; i < TIMEFRAME_COUNT; i++)
   {
      g_alertStates[i].lastAlertTime   = 0;
      g_alertStates[i].lastCooldownTime = 0;  // Per-TF cooldown
      g_alertStates[i].lastAlertState  = 0;
      g_alertStates[i].lastDivState    = false;
   }
}

//+------------------------------------------------------------------+
//| Update RSI Cache for a Timeframe                                  |
//| FIXED: shift=0 updates every tick for live RSI values            |
//| Historical shifts (>=1) update only on new bar formation         |
//+------------------------------------------------------------------+
void UpdateRSICache(int index)
{
   ENUM_TIMEFRAMES tf = g_timeframes[index].tf;
   datetime currentBar = iTime(Symbol(), tf, 0);
   
   // ALWAYS update shift=0 (current bar RSI) for live values
   g_timeframes[index].rsiCache[0] = CalculateRSI(tf, 0);
   
   // Only refresh historical cache (shift>=1) on new bar formation
   if(g_timeframes[index].lastCacheBar == currentBar)
      return;
   
   g_timeframes[index].lastCacheBar = currentBar;
   
   // Populate historical cache (shift 1 to RSI_CACHE_SIZE-1)
   for(int shift = 1; shift < RSI_CACHE_SIZE; shift++)
   {
      g_timeframes[index].rsiCache[shift] = CalculateRSI(tf, shift);
   }
}

//+------------------------------------------------------------------+
//| Get Cached RSI Value                                              |
//| Returns cached value if available, otherwise falls back to calc  |
//+------------------------------------------------------------------+
double GetCachedRSI(int index, int shift)
{
   if(shift >= 0 && shift < RSI_CACHE_SIZE)
      return g_timeframes[index].rsiCache[shift];
   
   // Fallback for shifts beyond cache range
   return CalculateRSI(g_timeframes[index].tf, shift);
}

//+------------------------------------------------------------------+
//| Calculate Panel Dimensions                                        |
//+------------------------------------------------------------------+
void CalculatePanelDimensions()
{
   g_panelWidth = (COL_WIDTH * TIMEFRAME_COUNT) + (PANEL_PADDING * 2);

   int baseHeight = PANEL_PADDING + ROW_HEIGHT + ROW_HEIGHT + ROW_HEIGHT + ROW_HEIGHT + PANEL_PADDING;
   
   if(InpPanelStyle == STYLE_EXTENDED)
   {
      baseHeight += ROW_HEIGHT;
      if(InpShowConfluence)
         baseHeight += ROW_HEIGHT + ROW_HEIGHT + FOOTER_SPACING;
   }

   g_panelHeight = baseHeight;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, INDICATOR_PREFIX);
}

//+------------------------------------------------------------------+
//| Main Calculation                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < g_rsiPeriod + 1)
      return 0;

   UpdateAllTimeframes();
   DrawPanel();
   ProcessAlerts();

   return rates_total;
}


//+------------------------------------------------------------------+
//| Update All Timeframe Data                                         |
//+------------------------------------------------------------------+
void UpdateAllTimeframes()
{
   ENUM_TIMEFRAMES currentTF = (ENUM_TIMEFRAMES)Period();

   for(int i = 0; i < TIMEFRAME_COUNT; i++)
   {
      // Update RSI cache FIRST (populates historical values)
      UpdateRSICache(i);
      
      g_timeframes[i].rsiPrev    = g_timeframes[i].rsiValue;
      g_timeframes[i].rsiValue   = GetCachedRSI(i, 0);  // Use cached value for shift 0
      g_timeframes[i].state      = DetermineRSIState(g_timeframes[i].rsiValue);
      g_timeframes[i].isCurrentTF = (g_timeframes[i].tf == currentTF);

      if(InpShowTrend)
         g_timeframes[i].trend = CalculateTrend(i);

      if(InpShowDivergence)
         DetectDivergence(i);
   }
}

//+------------------------------------------------------------------+
//| Calculate RSI (Standard or Zero-Lag)                              |
//+------------------------------------------------------------------+
double CalculateRSI(ENUM_TIMEFRAMES tf, int shift)
{
   double rsi;
   
   if(InpRSIType == RSI_ZERO_LAG)
      rsi = CalculateZeroLagRSI(tf, shift);
   else
      rsi = iRSI(Symbol(), tf, g_rsiPeriod, InpRSIPrice, shift);
   
   // Validate RSI value - handle errors gracefully
   if(rsi == EMPTY_VALUE || rsi < RSI_MIN || rsi > RSI_MAX)
   {
      int error = GetLastError();
      if(error != 0)
      {
         PrintFormat("RSI calculation error: %d, TF: %s, Shift: %d", 
                     error, EnumToString(tf), shift);
         ResetLastError();
      }
      return RSI_DEFAULT;  // Safe fallback to 50.0
   }
   
   return rsi;
}

//+------------------------------------------------------------------+
//| Calculate Zero-Lag RSI                                            |
//| NOTE: Uses Simple Moving Average (SMA) for gain/loss calculation |
//| instead of Wilder's Exponential Moving Average (EMA).            |
//| This is intentional for reduced lag - results differ from iRSI.  |
//+------------------------------------------------------------------+
double CalculateZeroLagRSI(ENUM_TIMEFRAMES tf, int shift)
{
   int lag = (InpZeroLagDepth > 0) ? InpZeroLagDepth : (g_rsiPeriod + 1) / 2;
   int barsNeeded = g_rsiPeriod + lag + 10;
   int availableBars = iBars(Symbol(), tf);

   if(availableBars < barsNeeded)
      return iRSI(Symbol(), tf, g_rsiPeriod, InpRSIPrice, shift);

   int arraySize = g_rsiPeriod + 2;
   double delaggedPrice[];
   if(ArrayResize(delaggedPrice, arraySize) != arraySize)
      return iRSI(Symbol(), tf, g_rsiPeriod, InpRSIPrice, shift);  // Fallback on failure
   ArraySetAsSeries(delaggedPrice, true);

   for(int i = 0; i < arraySize; i++)
   {
      double price = GetAppliedPrice(tf, shift + i);
      double ema   = iMA(Symbol(), tf, lag, 0, MODE_EMA, InpRSIPrice, shift + i);
      delaggedPrice[i] = price + (price - ema);
   }

   return CalculateRSIFromArray(delaggedPrice);
}

//+------------------------------------------------------------------+
//| Get Applied Price Value                                           |
//+------------------------------------------------------------------+
double GetAppliedPrice(ENUM_TIMEFRAMES tf, int shift)
{
   switch(InpRSIPrice)
   {
      case PRICE_OPEN:     return iOpen(Symbol(), tf, shift);
      case PRICE_HIGH:     return iHigh(Symbol(), tf, shift);
      case PRICE_LOW:      return iLow(Symbol(), tf, shift);
      case PRICE_MEDIAN:   return (iHigh(Symbol(), tf, shift) + iLow(Symbol(), tf, shift)) / 2.0;
      case PRICE_TYPICAL:  return (iHigh(Symbol(), tf, shift) + iLow(Symbol(), tf, shift) + 
                                   iClose(Symbol(), tf, shift)) / 3.0;
      case PRICE_WEIGHTED: return (iHigh(Symbol(), tf, shift) + iLow(Symbol(), tf, shift) + 
                                   iClose(Symbol(), tf, shift) * 2.0) / 4.0;
      default:             return iClose(Symbol(), tf, shift);
   }
}

//+------------------------------------------------------------------+
//| Calculate RSI from Price Array                                    |
//+------------------------------------------------------------------+
double CalculateRSIFromArray(double &price[])
{
   int size = ArraySize(price);
   if(size < g_rsiPeriod + 1)
      return RSI_DEFAULT;

   double gainSum = 0.0;
   double lossSum = 0.0;

   for(int i = 0; i < g_rsiPeriod; i++)
   {
      double change = price[i] - price[i + 1];
      if(change > 0)
         gainSum += change;
      else
         lossSum -= change;
   }

   double avgGain = gainSum / g_rsiPeriod;
   double avgLoss = lossSum / g_rsiPeriod;

   // No price movement at all (flat market)
   if(avgLoss < DBL_EPSILON && avgGain < DBL_EPSILON)
      return RSI_DEFAULT;
   
   // All gains, no losses
   if(avgLoss < DBL_EPSILON)
      return RSI_MAX;
   
   // All losses, no gains
   if(avgGain < DBL_EPSILON)
      return RSI_MIN;

   double rs  = avgGain / avgLoss;
   double rsi = 100.0 - (100.0 / (1.0 + rs));

   return MathMax(RSI_MIN, MathMin(RSI_MAX, rsi));
}

//+------------------------------------------------------------------+
//| Determine RSI State                                               |
//+------------------------------------------------------------------+
ENUM_RSI_STATE DetermineRSIState(double rsi)
{
   if(rsi >= InpExtremeOB)       return STATE_EXTREME_OB;
   if(rsi >= InpOverboughtLevel) return STATE_OVERBOUGHT;
   if(rsi <= InpExtremeOS)       return STATE_EXTREME_OS;
   if(rsi <= InpOversoldLevel)   return STATE_OVERSOLD;
   return STATE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Calculate Trend Direction                                         |
//| Uses percentage-based threshold for adaptive sensitivity          |
//+------------------------------------------------------------------+
ENUM_TREND_DIR CalculateTrend(int index)
{
   double currentRSI = g_timeframes[index].rsiValue;
   double prevRSI    = GetCachedRSI(index, InpTrendBars);
   
   // Use percentage change for adaptive sensitivity
   // A 3% change from RSI 30 is more significant than from RSI 70
   double changePercent = (prevRSI > 1.0) ? 
                          ((currentRSI - prevRSI) / prevRSI) * 100.0 : 0.0;

   if(changePercent > TREND_PERCENT)  return TREND_RISING;
   if(changePercent < -TREND_PERCENT) return TREND_FALLING;
   return TREND_FLAT;
}

//+------------------------------------------------------------------+
//| Detect Price/RSI Divergence                                       |
//+------------------------------------------------------------------+
void DetectDivergence(int index)
{
   g_timeframes[index].hasDivergence = false;
   g_timeframes[index].divType       = DIV_NONE;

   ENUM_TIMEFRAMES tf = g_timeframes[index].tf;
   int barsAvailable  = iBars(Symbol(), tf);

   if(barsAvailable < DIV_LOOKBACK + 5)
      return;

   int highestBar = iHighest(Symbol(), tf, MODE_HIGH, DIV_LOOKBACK, 1);
   int lowestBar  = iLowest(Symbol(), tf, MODE_LOW, DIV_LOOKBACK, 1);

   if(highestBar < 0 || lowestBar < 0)
      return;

   double highNow  = iHigh(Symbol(), tf, 0);
   double lowNow   = iLow(Symbol(), tf, 0);
   double highPrev = iHigh(Symbol(), tf, highestBar);
   double lowPrev  = iLow(Symbol(), tf, lowestBar);

   double rsiNow        = g_timeframes[index].rsiValue;
   double rsiAtHighPrev = GetCachedRSI(index, highestBar);
   double rsiAtLowPrev  = GetCachedRSI(index, lowestBar);

   // Bearish Divergence: Price makes higher high but RSI makes lower high
   // FIXED: Previous RSI must have been in OB zone for valid divergence
   if(highNow >= highPrev * (1.0 - InpDivPriceTol) && 
      rsiNow < rsiAtHighPrev - DIV_RSI_DIFF &&
      rsiAtHighPrev >= InpOverboughtLevel)  // Previous high RSI was in OB
   {
      g_timeframes[index].hasDivergence = true;
      g_timeframes[index].divType       = DIV_BEARISH;
      return;
   }

   // Bullish Divergence: Price makes lower low but RSI makes higher low
   // FIXED: Previous RSI must have been in OS zone for valid divergence
   if(lowNow <= lowPrev * (1.0 + InpDivPriceTol) && 
      rsiNow > rsiAtLowPrev + DIV_RSI_DIFF &&
      rsiAtLowPrev <= InpOversoldLevel)  // Previous low RSI was in OS
   {
      g_timeframes[index].hasDivergence = true;
      g_timeframes[index].divType       = DIV_BULLISH;
   }
}

//+------------------------------------------------------------------+
//| Calculate Confluence Scores                                       |
//+------------------------------------------------------------------+
void CalculateConfluence(int &bullish, int &bearish, int &neutral)
{
   bullish = bearish = neutral = 0;

   for(int i = 0; i < TIMEFRAME_COUNT; i++)
   {
      if(g_timeframes[i].state <= STATE_OVERSOLD)
         bullish++;
      else if(g_timeframes[i].state >= STATE_OVERBOUGHT)
         bearish++;
      else
         neutral++;
   }
}

//+------------------------------------------------------------------+
//| Draw Panel                                                        |
//+------------------------------------------------------------------+
void DrawPanel()
{
   int xBase, yBase;
   CalculateBasePosition(xBase, yBase);

   DrawBackground(xBase, yBase);
   DrawTitle(xBase, yBase);
   DrawTimeframeColumns(xBase, yBase);

   if(InpShowConfluence && InpPanelStyle == STYLE_EXTENDED)
      DrawConfluenceFooter(xBase, yBase);
   
   ChartRedraw(0);  // Force chart refresh
}

//+------------------------------------------------------------------+
//| Calculate Base Position                                           |
//+------------------------------------------------------------------+
void CalculateBasePosition(int &x, int &y)
{
   // For static positioning, the base position is simply the input offsets.
   // The corner logic handles the actual screen placement.
   x = InpXOffset;
   y = InpYOffset;
}

//+------------------------------------------------------------------+
//| Helper: Is Right Corner                                            |
//+------------------------------------------------------------------+
bool IsRightCorner()
{
   return (InpCorner == CORNER_RIGHT_UPPER || InpCorner == CORNER_RIGHT_LOWER);
}

//+------------------------------------------------------------------+
//| Helper: Is Bottom Corner                                           |
//+------------------------------------------------------------------+
bool IsBottomCorner()
{
   return (InpCorner == CORNER_LEFT_LOWER || InpCorner == CORNER_RIGHT_LOWER);
}

//+------------------------------------------------------------------+
//| Get X Position Adjusted for Corner                                |
//+------------------------------------------------------------------+
int GetAdjustedX(int xBase, int localX)
{
   // If anchored to Right, X grows to the left.
   // localX 0 (left of panel) should be furthest from right corner (xBase + width)
   if(IsRightCorner())
      return xBase + (g_panelWidth - localX);
   return xBase + localX;
}

//+------------------------------------------------------------------+
//| Get Y Position Adjusted for Corner                                |
//+------------------------------------------------------------------+
int GetAdjustedY(int yBase, int localY)
{
   // If anchored to Bottom, Y grows upwards.
   // localY 0 (top of panel) should be furthest from bottom corner (yBase + height)
   if(IsBottomCorner())
      return yBase + (g_panelHeight - localY);
   return yBase + localY;
}

//+------------------------------------------------------------------+
//| Draw Background Rectangle                                         |
//+------------------------------------------------------------------+
void DrawBackground(int xBase, int yBase)
{
   // Use GetAdjusted to find the 'Top-Left' visual coordinate for the background
   // even if anchored to Right/Bottom.
   int bgX = GetAdjustedX(xBase, 0);
   int bgY = GetAdjustedY(yBase, 0);
   
   CreateRectangle("BG", bgX, bgY, g_panelWidth, g_panelHeight, InpBgColor, InpBorderColor);
}

//+------------------------------------------------------------------+
//| Draw Panel Title                                                  |
//+------------------------------------------------------------------+
void DrawTitle(int xBase, int yBase)
{
   string rsiTypeStr = (InpRSIType == RSI_ZERO_LAG) ? " [ZL]" : "";
   string titleText  = "RSI MONITOR" + rsiTypeStr;
   int    localX     = PANEL_PADDING;
   int    localY     = PANEL_PADDING;

   CreateLabel("Title", titleText, GetAdjustedX(xBase, localX), GetAdjustedY(yBase, localY),
               InpTitleColor, FONT_SIZE_TITLE, true);
}

//+------------------------------------------------------------------+
//| Draw All Timeframe Columns                                        |
//+------------------------------------------------------------------+
void DrawTimeframeColumns(int xBase, int yBase)
{
   for(int i = 0; i < TIMEFRAME_COUNT; i++)
   {
      int localX = PANEL_PADDING + (i * COL_WIDTH);
      DrawSingleColumn(i, xBase, yBase, localX);
   }
}

//+------------------------------------------------------------------+
//| Draw Single Timeframe Column                                      |
//+------------------------------------------------------------------+
void DrawSingleColumn(int index, int xBase, int yBase, int localX)
{
   int rowTF    = PANEL_PADDING + ROW_HEIGHT;
   int rowVal   = rowTF + ROW_HEIGHT;
   int rowIcon  = rowVal + ROW_HEIGHT;
   int rowTrend = rowIcon + ROW_HEIGHT;

   string idxStr = IntegerToString(index);
   
   // Center offset for text elements (approximate text width: 3 chars * 5px = 15px)
   int textCenterOffset = (COL_WIDTH - 15) / 2;
   // Center offset for icons (icon size 10px)
   int iconCenterOffset = (COL_WIDTH - ICON_SIZE) / 2;

   color labelColor = InpLabelColor;
   if(InpHighlightCurrTF && g_timeframes[index].isCurrentTF)
      labelColor = clrYellow;

   // TF Label - centered
   CreateLabel("TF_" + idxStr, g_timeframes[index].label,
               GetAdjustedX(xBase, localX + textCenterOffset), GetAdjustedY(yBase, rowTF),
               labelColor, FONT_SIZE_LABEL, g_timeframes[index].isCurrentTF);

   // RSI Value - centered (value is ~4 chars like "65.3")
   color  valueColor = GetStateColor(g_timeframes[index].state, true);
   string valueStr   = DoubleToString(g_timeframes[index].rsiValue, 1);
   int    valueCenterOffset = (COL_WIDTH - 20) / 2;  // ~4 chars * 5px
   CreateLabel("Val_" + idxStr, valueStr,
               GetAdjustedX(xBase, localX + valueCenterOffset), GetAdjustedY(yBase, rowVal),
               valueColor, FONT_SIZE_VALUE, false);

   // State Icon - centered
   color iconColor = GetStateColor(g_timeframes[index].state, false);
   CreateIcon("Icon_" + idxStr, ICON_CIRCLE, 
              GetAdjustedX(xBase, localX + iconCenterOffset), GetAdjustedY(yBase, rowIcon), 
              iconColor, ICON_SIZE);

   if(InpPanelStyle == STYLE_EXTENDED)
   {
      // Trend Arrow - centered (aligned with icon, +1px adjustment)
      if(InpShowTrend)
      {
         DrawTrendIndicator(index, GetAdjustedX(xBase, localX + iconCenterOffset + 1), 
                           GetAdjustedY(yBase, rowTrend));
      }

      // Divergence Warning - positioned to right side of column
      if(InpShowDivergence && g_timeframes[index].hasDivergence)
      {
         color divColor = (g_timeframes[index].divType == DIV_BULLISH) ? InpBullishClr : InpBearishClr;
         int   divX     = GetAdjustedX(xBase, localX + COL_WIDTH - 8);
         CreateLabel("Div_" + idxStr, "!", divX, GetAdjustedY(yBase, rowIcon), divColor, FONT_SIZE_LABEL, true);
      }
      else
      {
         DeleteObject("Div_" + idxStr);
      }
   }
}

//+------------------------------------------------------------------+
//| Get State-Based Color                                             |
//+------------------------------------------------------------------+
color GetStateColor(ENUM_RSI_STATE state, bool forValue)
{
   switch(state)
   {
      case STATE_EXTREME_OB: return InpOverboughtClr;
      case STATE_OVERBOUGHT: return InpOverboughtClr;
      case STATE_EXTREME_OS: return InpOversoldClr;
      case STATE_OVERSOLD:   return InpOversoldClr;
      default:               return forValue ? InpValueColor : InpNeutralClr;
   }
}

//+------------------------------------------------------------------+
//| Draw Trend Indicator                                              |
//+------------------------------------------------------------------+
void DrawTrendIndicator(int index, int x, int y)
{
   string idxStr    = IntegerToString(index);
   string objName   = "Trend_" + idxStr;
   string text;
   color  clr;
   string font;
   int    fontSize;

   switch(g_timeframes[index].trend)
   {
      case TREND_RISING:
         text     = ICON_ARROW_UP;
         clr      = InpBullishClr;
         font     = ICON_FONT;
         fontSize = FONT_SIZE_VALUE;
         break;
      case TREND_FALLING:
         text     = ICON_ARROW_DOWN;
         clr      = InpBearishClr;
         font     = ICON_FONT;
         fontSize = FONT_SIZE_VALUE;
         break;
      default:
         text     = "-";
         clr      = InpNeutralClr;
         font     = InpFontName;
         fontSize = FONT_SIZE_VALUE;
         break;
   }

   int yOffset = 0;
   if(g_timeframes[index].trend == TREND_FALLING)
      yOffset = 3; // Shift down arrow down to center it

   // Invert offset for bottom corners because Y grows upwards (distance from bottom)
   if(InpCorner == CORNER_LEFT_LOWER || InpCorner == CORNER_RIGHT_LOWER)
      yOffset = -yOffset;
      
   CreateLabelEx(objName, text, x, y + yOffset, clr, fontSize, font, false);
}

//+------------------------------------------------------------------+
//| Draw Confluence Footer                                            |
//+------------------------------------------------------------------+
void DrawConfluenceFooter(int xBase, int yBase)
{
   int bullish, bearish, neutral;
   CalculateConfluence(bullish, bearish, neutral);

   int footerY  = g_panelHeight - PANEL_PADDING - ROW_HEIGHT - ROW_HEIGHT + 4;
   int signalY  = footerY + ROW_HEIGHT;  // Signal on row below
   int sepY     = footerY - 4;

   CreateRectangle("Sep", GetAdjustedX(xBase, PANEL_PADDING),
                   GetAdjustedY(yBase, sepY), g_panelWidth - (PANEL_PADDING * 2), 1, InpBorderColor, InpBorderColor);

   // Clearer labels: Oversold/Neutral/Overbought with counts
   string confText = StringFormat("TF Bias: %d Oversold | %d Neutral | %d Overbought", 
                                  bullish, neutral, bearish);
   CreateLabel("Conf", confText, GetAdjustedX(xBase, PANEL_PADDING),
               GetAdjustedY(yBase, footerY), InpLabelColor, FONT_SIZE_CONF, false);

   // Show strong bias signal on new row when 5+ TFs agree
   if(bullish >= CONFLUENCE_STRONG)
   {
      string signalText = StringFormat(">>> BUY BIAS (%d/9 TFs)", bullish);
      CreateLabel("Signal", signalText, GetAdjustedX(xBase, PANEL_PADDING),
                  GetAdjustedY(yBase, signalY), InpBullishClr, FONT_SIZE_CONF, true);
   }
   else if(bearish >= CONFLUENCE_STRONG)
   {
      string signalText = StringFormat(">>> SELL BIAS (%d/9 TFs)", bearish);
      CreateLabel("Signal", signalText, GetAdjustedX(xBase, PANEL_PADDING),
                  GetAdjustedY(yBase, signalY), InpBearishClr, FONT_SIZE_CONF, true);
   }
   else
   {
      // No strong bias - show placeholder
      CreateLabel("Signal", "... Awaiting strong signal ...", GetAdjustedX(xBase, PANEL_PADDING),
                  GetAdjustedY(yBase, signalY), InpNeutralClr, FONT_SIZE_CONF, false);
   }
}

//+------------------------------------------------------------------+
//| Helper: Create Rectangle                                          |
//+------------------------------------------------------------------+
void CreateRectangle(string name, int x, int y, int w, int h, color bgColor, color borderColor)
{
   string objName = INDICATOR_PREFIX + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, objName, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
}

//+------------------------------------------------------------------+
//| Helper: Create Label                                              |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize, bool isBold=false)
{
   CreateLabelEx(name, text, x, y, clr, fontSize, InpFontName, isBold);
}

//+------------------------------------------------------------------+
//| Helper: Create Label Extended                                     |
//+------------------------------------------------------------------+
void CreateLabelEx(string name, string text, int x, int y, color clr, int fontSize, string font, bool isBold=false)
{
   string objName = INDICATOR_PREFIX + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);

   // Apply bold font weight if requested
   string fontName = isBold ? (font + " Bold") : font;

   ObjectSetInteger(0, objName, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetString(0, objName, OBJPROP_FONT, fontName);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 10);
}
//+------------------------------------------------------------------+
//| Create Icon Object                                                |
//+------------------------------------------------------------------+
void CreateIcon(const string name, const string icon, int x, int y, color clr, int size)
{
   CreateLabelEx(name, icon, x, y, clr, size, ICON_FONT, false);
}

//+------------------------------------------------------------------+
//| Delete Object                                                     |
//+------------------------------------------------------------------+
void DeleteObject(const string name)
{
   string objName = INDICATOR_PREFIX + name;
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
}

//+------------------------------------------------------------------+
//| Process Alerts                                                    |
//+------------------------------------------------------------------+
void ProcessAlerts()
{
   if(!InpUseAlert && !InpUseEmail && !InpUseNotification && !InpUseSound)
      return;

   for(int i = 0; i < TIMEFRAME_COUNT; i++)
   {
      ProcessStateAlert(i);
      ProcessDivergenceAlert(i);
   }
}

//+------------------------------------------------------------------+
//| Process OB/OS State Alert                                         |
//| FIXED: Only updates state when alert is actually sent            |
//+------------------------------------------------------------------+
void ProcessStateAlert(int index)
{
   int currentState = (int)g_timeframes[index].state;

   bool shouldAlert = InpAlertOnExtreme ? 
                      (MathAbs(currentState) == 2) : 
                      (currentState != 0);

   // Logic: 
   // 1. First entry into a zone (LastState was 0)
   // 2. Escalation (e.g., OB -> Extreme OB)
   // 3. New bar formation while still in a zone (and not the same state we last alerted)
   
   datetime currentBarTime = iTime(Symbol(), g_timeframes[index].tf, 0);
   bool isNewBar = (currentBarTime != g_alertStates[index].lastAlertTime);
   bool isEscalation = (MathAbs(currentState) > MathAbs(g_alertStates[index].lastAlertState));
   
   bool shouldTrigger = false;
   if(isEscalation) shouldTrigger = true;
   else if(isNewBar && currentState != 0 && currentState != g_alertStates[index].lastAlertState) shouldTrigger = true;
   else if(g_alertStates[index].lastAlertState == 0 && currentState != 0) shouldTrigger = true;

   if(!shouldTrigger)
      return;

   string zone = GetStateName(g_timeframes[index].state);
   string rsiType = (InpRSIType == RSI_ZERO_LAG) ? "ZL-RSI" : "RSI";
   string message = StringFormat("%s %s on %s %s | Value: %.1f",
                                 rsiType, zone, Symbol(), g_timeframes[index].label,
                                 g_timeframes[index].rsiValue);

   // FIXED: Only update state if alert was actually sent
   if(SendAlert(index, message))
   {
      g_alertStates[index].lastAlertTime  = currentBarTime;
      g_alertStates[index].lastAlertState = currentState;
   }
}

//+------------------------------------------------------------------+
//| Process Divergence Alert                                          |
//| FIXED: Only updates state when alert is actually sent            |
//+------------------------------------------------------------------+
void ProcessDivergenceAlert(int index)
{
   if(!InpAlertOnDivergence)
      return;

   if(g_timeframes[index].hasDivergence && !g_alertStates[index].lastDivState)
   {
      string divType = (g_timeframes[index].divType == DIV_BULLISH) ? "BULLISH" : "BEARISH";
      string message = StringFormat("%s DIVERGENCE on %s %s", divType, Symbol(), g_timeframes[index].label);
      
      // FIXED: Only update state if alert was actually sent
      if(SendAlert(index, message))
         g_alertStates[index].lastDivState = true;
   }

   if(!g_timeframes[index].hasDivergence)
      g_alertStates[index].lastDivState = false;
}

//+------------------------------------------------------------------+
//| Get State Name String                                             |
//+------------------------------------------------------------------+
string GetStateName(ENUM_RSI_STATE state)
{
   switch(state)
   {
      case STATE_EXTREME_OB: return "EXTREME OVERBOUGHT";
      case STATE_OVERBOUGHT: return "OVERBOUGHT";
      case STATE_EXTREME_OS: return "EXTREME OVERSOLD";
      case STATE_OVERSOLD:   return "OVERSOLD";
      default:               return "NEUTRAL";
   }
}

//+------------------------------------------------------------------+
//| Send Alert via All Enabled Methods                                |
//| FIXED: Per-timeframe cooldown instead of global                   |
//+------------------------------------------------------------------+
bool SendAlert(int index, const string message)
{
   // Per-timeframe rate limiting - prevent alert floods per TF
   if(InpAlertCooldown > 0)
   {
      datetime now = TimeCurrent();
      if(now - g_alertStates[index].lastCooldownTime < InpAlertCooldown)
         return false;  // Alert blocked by cooldown for this TF
      g_alertStates[index].lastCooldownTime = now;
   }
   
   if(InpUseAlert)        Alert(message);
   if(InpUseSound)        PlaySound(InpSoundFile);
   if(InpUseEmail)        SendMail("RSI Monitor Alert", message);
   if(InpUseNotification) SendNotification(message);
   
   return true;  // Alert was sent
}

//+------------------------------------------------------------------+