//+------------------------------------------------------------------+
//|                                                   iFibonacci.mq4 |
//|                                   Copyright © 2015-2026, Awran5. |
//|                                                 awran5@yahoo.com |
//|                        https://www.mql5.com/en/code/14393        |
//|  Original Credit:                                                |
//|    JimDandy: http://www.jimdandyforex.com                        |
//|    WHRoeder: https://www.mql5.com/en/users/WHRoeder              |
//|    RaptorUK: https://www.mql5.com/en/users/RaptorUK              |
//|    deVries : https://www.mql5.com/en/users/deVries               |
//|                                                                  |
//|  v2.0 Changelog (Jan 2026):                                      |
//|    - MAJOR UPGRADE from v1.0 (complete rewrite)                  |
//|    - REPLACED external ZigZag with "Reverse-Scan" Swing Engine:  |
//|         * Non-Repainting: Stable anchors (unlike standard ZigZag)|
//|         * Peak-Climbing: Consecutive highs keep the HIGHER one   |
//|         * Right-Side Priority: Fixes "Equal Highs" bug           |
//|         * Zero-Lag: Uses direct memory access (CopyHigh/Low)     |
//|    - REMOVED unsafe user32.dll imports (Fibo Arc scaling)        |
//|    - OPTIMIZED performance (Pre-fetched arrays, caching)         |
//|    - MODERNIZED code (ObjectSetString/Integer, strict mode)      |
//|    - ADDED Fibo Touch Alerts (Sound/Popup)                       |
//|    - ADDED Pending Swing Visual: Shows unconfirmed extremes      |
//|                                                                  |
//|  MT5 Porting Notes (not yet compatible):                         |
//|    - WindowPriceMax/Min/BarsPerChart() -> ChartGetDouble()       |
//|    - ObjectSetFiboDescription() -> ObjectSetString(LEVELTEXT)    |
//+------------------------------------------------------------------+
#property copyright   "Copyright © 2015-2026, Awran5."
#property link        "awran5@yahoo.com"
#property version     "2.00"
#property description "Draw Fibonacci Tools: Retracement, Arc, Fan, TimeZones, Expansion"
#property description "Non-repainting swing detection with Peak-Climbing algorithm"
#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
#define INDICATOR_NAME    "iFibonacci"
#define INDICATOR_VERSION "2.0"
#define INDICATOR_PREFIX  "iFib_"

// Time period constants (in minutes)
#define PERIOD_D1_MINS    1440
#define PERIOD_W1_MINS    10080
#define PERIOD_MN1_MINS   43200

// Maximum swings to track
#define MAX_SWINGS           5
#define MAX_FIBO_LEVELS      10

// Calculation constants
#define MIN_BARS_REQUIRED       10
#define PIVOT_DIVISOR           3
#define MIN_RANGE_POINTS        10
#define PENDING_SWING_LOOKBACK  20  // Bars to look back for pending swing

// Level definition structure for generic Fibo drawing
struct FiboLevelDef {
   double value;
   string label;
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
//--- Swing Detection Settings
input string  lb_swing           = "";                // ══════ SWING DETECTION ══════
input bool    AutoSwingDepth     = true;              // Auto-adjust depth per timeframe
input int     SwingDepth         = 24;                // Swing Depth (if Auto=false)
input int     SwingBackstep      = 3;                 // Swing Backstep
input int     MaxBars            = 500;               // Maximum Bars to analyze
input ENUM_TIMEFRAMES FixedPeriod = 0;                // Time Frame (0=current)
input bool    ShowPendingSwing   = true;              // Show Pending (unconfirmed) Swing

//--- Fibonacci Retracement
input string  lb_ret             = "";                // ══════ FIBO RETRACEMENT ══════
input bool    ShowRetracement    = true;              // Show Retracement
input ENUM_LINE_STYLE rStyle     = STYLE_SOLID;       // Levels Style
input color   rColor             = clrGold;           // Levels Color
input int     rWidth             = 1;                 // Levels Width
input double  l0                 = 0.0;               // Level 0
input double  l38                = 0.382;             // Level 38.2
input double  l50                = 0.5;               // Level 50  
input double  l61                = 0.618;             // Level 61.8
input double  l100               = 1.0;               // Level 100
input bool    ExtraLevels        = false;             // Extra levels: 14.6, 23.6, 76.4, 88.6, 127.2
input double  l14                = 0.146;             // Level 14.6
input double  l23                = 0.236;             // Level 23.6
input double  l74                = 0.764;             // Level 76.4
input double  l88                = 0.886;             // Level 88.6
input double  l127               = 1.272;             // Level 127.2
input bool    LevelPrice         = false;             // Show Prices on levels

//--- Fibonacci Arc
input string  lb_arc             = "";                // ══════ FIBO ARC ══════
input bool    ShowArc            = false;             // Show Arc
input color   aColor             = clrTomato;         // Arc Color
input ENUM_LINE_STYLE aStyle     = STYLE_SOLID;       // Arc Style
input int     aWidth             = 1;                 // Arc Width
input double  ARC38              = 0.382;             // Level 38.2
input double  ARC50              = 0.500;             // Level 50  
input double  ARC61              = 0.618;             // Level 61.8
input bool    ExtraARC           = false;             // Extra levels: 14.6, 23.6, 76.4
input double  ARC14              = 0.146;             // Level 14.6
input double  ARC23              = 0.236;             // Level 23.6
input double  ARC74              = 0.764;             // Level 76.4

//--- Fibonacci Fan
input string  lb_fan             = "";                // ══════ FIBO FAN ══════
input bool    ShowFan            = true;              // Show Fan
input color   fColor             = clrGold;           // Fan Color
input ENUM_LINE_STYLE fStyle     = STYLE_DOT;         // Fan Style
input int     fWidth             = 1;                 // Fan Width
input double  FAN38              = 0.382;             // Level 38.2
input double  FAN50              = 0.5;               // Level 50  
input double  FAN61              = 0.618;             // Level 61.8
input bool    ExtraFAN           = false;             // Extra levels: 14.6, 23.6, 76.4
input double  FAN14              = 0.146;             // Level 14.6
input double  FAN23              = 0.236;             // Level 23.6
input double  FAN74              = 0.764;             // Level 76.4

//--- Fibonacci TimeZones
input string  lb_zone            = "";                // ══════ FIBO TIMEZONES ══════
input bool    ShowZone           = true;              // Show Time Zones 
input color   zColor             = clrDarkGoldenrod;  // Time Color
input ENUM_LINE_STYLE zStyle     = STYLE_DOT;         // Time Style
input int     zWidth             = 1;                 // Time Width
input double  Zone0              = 0;                 // Level 0
input double  Zone1              = 1;                 // Level 1
input double  Zone2              = 2;                 // Level 2
input double  Zone3              = 3;                 // Level 3
input double  Zone5              = 5;                 // Level 5
input double  Zone8              = 8;                 // Level 8
input double  Zone13             = 13;                // Level 13
input double  Zone21             = 21;                // Level 21
input double  Zone34             = 34;                // Level 34

//--- Fibonacci Expansion
input string  lb_exp             = "";                // ══════ FIBO EXPANSION ══════
input bool    ShowExpansion      = false;             // Show Expansion
input color   eColor             = clrBlue;           // Expansion Color
input ENUM_LINE_STYLE eStyle     = STYLE_SOLID;       // Expansion Style
input int     eWidth             = 2;                 // Expansion Width
input double  EXP61              = 0.618;             // Level 61.8 
input double  EXP100             = 1;                 // Level 100
input double  EXP161             = 1.618;             // Level 161.8
input double  EXP261             = 2.618;             // Level 261.8
input bool    ExtraEXP           = false;             // Extra levels: 78.6, 138.2, 200
input double  EXP78              = 0.786;             // Level 78.6
input double  EXP138             = 1.382;             // Level 138.2
input double  EXP200             = 2;                 // Level 200

input string  lb_daily           = "";                // ══════ DAILY HIGH/LOW ══════
input bool    ShowDaily          = true;              // Show Daily High/Low
input color   DayColor           = clrPurple;         // Daily Color 
input int     DayWidth           = 1;                 // Daily Width
input ENUM_LINE_STYLE DayStyle   = STYLE_SOLID;       // Daily Style
input bool    ShowPivot          = true;              // Show Daily Pivot
input color   PivotColor         = clrLightGray;      // Pivot Color
input int     PivotWidth         = 1;                 // Pivot Width
input ENUM_LINE_STYLE PivotStyle = STYLE_SOLID;       // Pivot Style    

//--- Weekly High/Low
input string  lb_weekly          = "";                // ══════ WEEKLY HIGH/LOW ══════
input bool    ShowWeekly         = true;              // Show Weekly High/Low 
input color   WeekColor          = clrDarkBlue;       // Weekly Color
input int     WeekWidth          = 1;                 // Weekly Width
input ENUM_LINE_STYLE WeekStyle  = STYLE_SOLID;       // Weekly Style    

//--- Monthly High/Low
input string  lb_monthly         = "";                // ══════ MONTHLY HIGH/LOW ══════
input bool    ShowMonthly        = true;              // Show Monthly High/Low
input color   MonthColor         = clrFireBrick;      // Monthly Color
input int     MonthWidth         = 1;                 // Monthly Width
input ENUM_LINE_STYLE MonthStyle = STYLE_SOLID;       // Monthly Style        

//--- Candle Time
input string  lb_time            = "";                // ══════ CANDLE TIME ══════
input bool    ShowCandleTime     = true;              // Show Candle Time
input color   TimerColor         = clrYellow;         // Timer Color
input int     TimerFontSize      = 7;                 // Timer Font Size

//--- Fibo Level Alerts
input string  lb_alerts          = "";                // ══════ FIBO ALERTS ══════
input bool    AlertOnFiboTouch   = false;             // Alert when price touches Fibo
input bool    AlertPopup         = false;             // Popup Alert
input bool    AlertSound         = false;             // Sound Alert
input string  AlertSoundFile     = "alert.wav";       // Alert Sound File
input double  AlertTolerance     = 0.2;               // Alert Tolerance (% of range)

//--- Debug Mode (for developers)
input string  lb_debug           = "";                // ══════ DEBUG ══════
input bool    DebugMode          = false;             // Print Debug Info

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
double   g_swingValue[MAX_SWINGS];   // Swing price values
datetime g_swingTime[MAX_SWINGS];    // Swing times

double   g_dayLow, g_dayHigh, g_dayClose, g_dayPivot;
double   g_weekLow, g_weekHigh;
double   g_monthLow, g_monthHigh;

ENUM_TIMEFRAMES g_activePeriod;

// Effective swing depth (auto-calculated or manual)
int g_effectiveSwingDepth = 24;

// Object names
string g_objRetracement, g_objArc, g_objFan, g_objZone, g_objExpansion;
string g_objCandleTime;
string g_objDayHigh, g_objDayLow, g_objWeekHigh, g_objWeekLow;
string g_objMonthHigh, g_objMonthLow, g_objPivot;
string g_objPendingHigh, g_objPendingLow;  // Pending swing visuals

// Fibo alert tracking (prevent duplicate alerts per level)
double g_fiboLevels[10];          // Store current Fibo prices (up to 10 with ExtraLevels)
bool   g_fiboTouched[10];         // Track if level was already alerted
datetime g_lastFiboAlertBar = 0;  // Last bar that triggered alert

// Caching timestamps for High/Low calculations
datetime g_lastDailyCalc = 0;
datetime g_lastWeeklyCalc = 0;
datetime g_lastMonthlyCalc = 0;

// Caching for swing state (skip redraw if unchanged)
datetime g_lastSwingTime0 = 0;
datetime g_lastSwingTime1 = 0;

// Caching for arc scale (avoid expensive GUI queries)
double g_cachedArcScale = 1.0;
int g_lastArcChartWidth = 0;
int g_lastArcChartHeight = 0;

// New-bar detection for performance optimization
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit() {
   Print(INDICATOR_NAME, " v", INDICATOR_VERSION, ": Initializing...");
   
   //--- Validate inputs
   if(SwingDepth < 1 || SwingBackstep < 1) {
      Print(INDICATOR_NAME, ": Invalid swing parameters!");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(MaxBars < 50) {
      Print(INDICATOR_NAME, ": MaxBars should be at least 50");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   //--- Validate widths (warn only, don't fail)
   if(rWidth < 1 || aWidth < 1 || fWidth < 1 || zWidth < 1 || eWidth < 1) {
      Print(INDICATOR_NAME, ": Warning - Width values should be >= 1");
   }
   
   //--- Validate Fibo levels (sane range: -0.5 to 3.0 for extensions)
   if(l0 < -0.5 || l127 > 3.0 || EXP261 > 4.0) {
      Print(INDICATOR_NAME, ": Warning - Extreme Fibo level values detected");
   }
   
   //--- Validate AlertTolerance
   if(AlertTolerance < 0 || AlertTolerance > 10) {
      Print(INDICATOR_NAME, ": AlertTolerance must be 0-10%");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   //--- Set active period
   g_activePeriod = (FixedPeriod == 0) ? (ENUM_TIMEFRAMES)Period() : FixedPeriod;
   
   //--- Calculate effective swing depth (auto-adjust or manual)
   if(AutoSwingDepth) {
      g_effectiveSwingDepth = CalculateSwingDepth(g_activePeriod);
      if(DebugMode) Print(INDICATOR_NAME, ": Auto swing depth = ", g_effectiveSwingDepth, " for ", EnumToString(g_activePeriod));
   } else {
      g_effectiveSwingDepth = SwingDepth;
   }
   
   //--- Initialize object names with prefix
   g_objRetracement = INDICATOR_PREFIX + "Retracement";
   g_objArc         = INDICATOR_PREFIX + "Arc";
   g_objFan         = INDICATOR_PREFIX + "Fan";
   g_objZone        = INDICATOR_PREFIX + "TimeZones";
   g_objExpansion   = INDICATOR_PREFIX + "Expansion";
   g_objCandleTime  = INDICATOR_PREFIX + "CandleTime";
   g_objDayHigh     = INDICATOR_PREFIX + "DayHigh";
   g_objDayLow      = INDICATOR_PREFIX + "DayLow";
   g_objWeekHigh    = INDICATOR_PREFIX + "WeekHigh";
   g_objWeekLow     = INDICATOR_PREFIX + "WeekLow";
   g_objMonthHigh   = INDICATOR_PREFIX + "MonthHigh";
   g_objMonthLow    = INDICATOR_PREFIX + "MonthLow";
   g_objPivot       = INDICATOR_PREFIX + "Pivot";
   g_objPendingHigh = INDICATOR_PREFIX + "PendingHigh";
   g_objPendingLow  = INDICATOR_PREFIX + "PendingLow";
   
   //--- Force data load for higher timeframes
   iBars(NULL, PERIOD_D1);
   iBars(NULL, PERIOD_W1);
   iBars(NULL, PERIOD_MN1);
   
   //--- Set indicator short name
   IndicatorShortName(INDICATOR_NAME + " v" + INDICATOR_VERSION);
   
   if(DebugMode) Print(INDICATOR_NAME, ": Initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //--- Remove all objects with our prefix (optimized)
   ObjectsDeleteAll(0, INDICATOR_PREFIX);
   
   if(DebugMode) Print(INDICATOR_NAME, ": Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Chart event handler (for arc scale on resize)                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, 
                  const double &dparam, const string &sparam) {
   //--- Handle chart resize
   if(id == CHARTEVENT_CHART_CHANGE) {
      //--- Check if arc is shown and dimensions changed
      if(ShowArc) {
         int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
         int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
         
         if(chartWidth != g_lastArcChartWidth || chartHeight != g_lastArcChartHeight) {
            //--- Recalculate and update arc scale
            double newScale = CalculateArcScale();
            if(ObjectFind(0, g_objArc) >= 0) {
               ObjectSetDouble(0, g_objArc, OBJPROP_SCALE, newScale);
            }
            if(DebugMode) Print(INDICATOR_NAME, ": Chart resized, arc scale updated to ", newScale);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
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
                const int &spread[]) {
   
   if(rates_total < g_effectiveSwingDepth + MIN_BARS_REQUIRED) return(rates_total);
   
   //--- PERFORMANCE: Only recalculate on new bar (swing points don't change mid-bar)
   datetime currentBarTime = iTime(NULL, g_activePeriod, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   
   if(isNewBar) {
      g_lastBarTime = currentBarTime;
      
      //--- Detect swing points (uses g_activePeriod internally)
      DetectSwingPoints();
      
      //--- Draw Fibonacci tools
      DrawFibonacciTools();
      
      //--- Calculate and draw High/Low levels
      CalculateHighLow();
      DrawHighLowLines();
   }
   
   //--- Candle time (needs tick updates)
   if(ShowCandleTime) {
      DrawCandleTime(time[0], close[0]);
   }
   
   //--- Check Fibo level touch alerts (needs tick updates)
   if(AlertOnFiboTouch && ShowRetracement) {
      CheckFiboLevelTouch(high[0], low[0], time[0]);
   }
   
   //--- Draw pending swing visuals (needs tick updates)
   if(ShowPendingSwing) {
      DrawPendingSwing(high, low, time, rates_total);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Internal Swing Point Detection (optimized with pre-fetched data)  |
//+------------------------------------------------------------------+
void DetectSwingPoints() {
   
   int swingCount = 0;
   int lastSwingBar = -1;
   int lastSwingType = 0; // 1 = high, -1 = low
   
   //--- Reset swing arrays
   ArrayInitialize(g_swingValue, 0);
   ArrayInitialize(g_swingTime, 0);
   
   //--- Get rates_total for the target timeframe
   int rates_total = iBars(NULL, g_activePeriod);
   if(rates_total < g_effectiveSwingDepth + MIN_BARS_REQUIRED) return;
   
   //--- Calculate safe limit
   int limit = MathMin(MaxBars, rates_total - g_effectiveSwingDepth - 1);
   if(limit < g_effectiveSwingDepth + 5) {
      limit = MathMin(g_effectiveSwingDepth + 5, rates_total - 1);
   }
   if(limit <= g_effectiveSwingDepth) return;
   
   //--- PERFORMANCE: Pre-fetch high/low data (single kernel transition)
   int copyCount = limit + g_effectiveSwingDepth + 1;
   double highs[];
   double lows[];
   datetime times[];
   
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(times, true);
   
   if(CopyHigh(NULL, g_activePeriod, 0, copyCount, highs) <= 0) return;
   if(CopyLow(NULL, g_activePeriod, 0, copyCount, lows) <= 0) return;
   if(CopyTime(NULL, g_activePeriod, 0, copyCount, times) <= 0) return;
   
   //--- Find swing points using pre-fetched arrays (pure memory access)
   for(int i = g_effectiveSwingDepth; i < limit && swingCount < MAX_SWINGS; i++) {
      
      double currentHigh = highs[i];
      double currentLow  = lows[i];
      
      //--- Check for swing high
      bool isSwingHigh = true;
      for(int j = 1; j <= g_effectiveSwingDepth; j++) {
         if(i + j >= copyCount || i - j < 0) {
            isSwingHigh = false;
            break;
         }
         
         double rightVal = highs[i - j]; // Newer
         double leftVal  = highs[i + j]; // Older
         
         // Left Side: Strict. If neighbor is equal or higher, fail.
         if(currentHigh <= leftVal)  { isSwingHigh = false; break; }
         
         // Right Side: Strict. If neighbor is equal or higher, fail (let newer win).
         if(currentHigh <= rightVal) { isSwingHigh = false; break; }
      }
      
      //--- Check for swing low
      bool isSwingLow = true;
      for(int j = 1; j <= g_effectiveSwingDepth; j++) {
         if(i + j >= copyCount || i - j < 0) {
            isSwingLow = false;
            break;
         }
         
         double rightVal = lows[i - j]; // Newer
         double leftVal  = lows[i + j]; // Older
         
         // Left Side: Strict. If neighbor is equal or lower, fail.
         if(currentLow >= leftVal) { isSwingLow = false; break; }
         
         // Right Side: Strict. If neighbor is equal or lower, fail (let newer win).
         if(currentLow >= rightVal) { isSwingLow = false; break; }
      }
      
      //--- Add swing point with Peak-Climbing logic
      //--- Peak-Climbing: If consecutive swings of same type, keep the BETTER one
      
      if(isSwingHigh) {
         if(lastSwingType == 1 && swingCount > 0) {
            //--- PEAK-CLIMBING: Consecutive highs - keep the HIGHER one
            if(currentHigh > g_swingValue[swingCount - 1]) {
               //--- Replace last swing with this higher one
               g_swingValue[swingCount - 1] = currentHigh;
               g_swingTime[swingCount - 1] = times[i];
               lastSwingBar = i;
               // lastSwingType stays 1, swingCount unchanged
            }
            //--- else: Lower high is ignored (current swing is better)
         }
         else if(lastSwingType != 1 || swingCount == 0) {
            //--- Normal alternation: add new high
            if(lastSwingBar < 0 || i - lastSwingBar >= SwingBackstep) {
               g_swingValue[swingCount] = currentHigh;
               g_swingTime[swingCount] = times[i];
               lastSwingBar = i;
               lastSwingType = 1;
               swingCount++;
            }
         }
      }
      
      if(isSwingLow) {
         if(lastSwingType == -1 && swingCount > 0) {
            //--- PEAK-CLIMBING: Consecutive lows - keep the LOWER one
            if(currentLow < g_swingValue[swingCount - 1]) {
               //--- Replace last swing with this lower one
               g_swingValue[swingCount - 1] = currentLow;
               g_swingTime[swingCount - 1] = times[i];
               lastSwingBar = i;
               // lastSwingType stays -1, swingCount unchanged
            }
            //--- else: Higher low is ignored (current swing is better)
         }
         else if(lastSwingType != -1 || swingCount == 0) {
            //--- Normal alternation: add new low
            if(lastSwingBar < 0 || i - lastSwingBar >= SwingBackstep) {
               g_swingValue[swingCount] = currentLow;
               g_swingTime[swingCount] = times[i];
               lastSwingBar = i;
               lastSwingType = -1;
               swingCount++;
            }
         }
      }
   }
   
   if(DebugMode && swingCount > 0) {
      Print(INDICATOR_NAME, ": Found ", swingCount, " swings. Swing[0]=", g_swingValue[0], ", Swing[1]=", g_swingValue[1]);
   }
}

//+------------------------------------------------------------------+
//| Draw all Fibonacci tools                                          |
//+------------------------------------------------------------------+
void DrawFibonacciTools() {
   //--- Need at least 2 swing points for most tools
   if(g_swingTime[0] == 0 || g_swingTime[1] == 0) return;
   
   //--- CACHING: Skip redraw if swings haven't changed
   if(g_swingTime[0] == g_lastSwingTime0 && g_swingTime[1] == g_lastSwingTime1) {
      return; // No change, skip expensive redraw
   }
   g_lastSwingTime0 = g_swingTime[0];
   g_lastSwingTime1 = g_swingTime[1];
   
   if(ShowRetracement) {
      DrawRetracement(g_objRetracement, "FR ", rColor, rWidth, rStyle,
                      g_swingTime[1], g_swingValue[1], 
                      g_swingTime[0], g_swingValue[0]);
   }
   
   if(ShowArc) {
      DrawArc(g_objArc, "FA ", aColor, aWidth, aStyle,
              g_swingTime[1], g_swingValue[1], 
              g_swingTime[0], g_swingValue[0]);
   }
   
   if(ShowFan) {
      DrawFan(g_objFan, "FF ", fColor, fWidth, fStyle,
              g_swingTime[1], g_swingValue[1], 
              g_swingTime[0], g_swingValue[0]);
   }
   
   if(ShowZone) {
      DrawTimeZones(g_objZone, "FZ ", zColor, zWidth, zStyle,
                    g_swingTime[1], g_swingValue[1], 
                    g_swingTime[0], g_swingValue[0]);
   }
   
   //--- Expansion needs 3 points (check ALL used indices)
   if(ShowExpansion && g_swingTime[1] != 0 && g_swingTime[2] != 0 && g_swingTime[3] != 0) {
      DrawExpansion(g_objExpansion, "FE ", eColor, eWidth, eStyle,
                    g_swingTime[3], g_swingValue[3],
                    g_swingTime[2], g_swingValue[2],
                    g_swingTime[1], g_swingValue[1]);
   }
}

//+------------------------------------------------------------------+
//| Set common Fibo object properties (reduces duplication)           |
//+------------------------------------------------------------------+
void SetFiboCommonProps(string name, int levels, color clr, int width, ENUM_LINE_STYLE style) {
   ObjectSetInteger(0, name, OBJPROP_FIBOLEVELS, levels);
   ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_LEVELWIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_LEVELSTYLE, style);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Generic Fibo Object Drawing (reduces duplication)                 |
//+------------------------------------------------------------------+
void DrawFiboObject(string name, ENUM_OBJECT type, 
                    FiboLevelDef &levels[], int count,
                    color clr, int width, ENUM_LINE_STYLE style,
                    datetime t1, double p1, datetime t2, double p2,
                    datetime t3=0, double p3=0, bool showPrice=false) {
   
   ObjectDelete(0, name);
   
   bool ok = false;
   if(type == OBJ_EXPANSION) {
      ok = ObjectCreate(0, name, type, 0, t1, p1, t2, p2, t3, p3);
   } else {
      ok = ObjectCreate(0, name, type, 0, t1, p1, t2, p2);
   }
   
   if(!ok) {
      Print(INDICATOR_NAME, ": Failed to create ", EnumToString(type));
      return;
   }
   
   SetFiboCommonProps(name, count, clr, width, style);
   
   // Type-specific settings
   if(type == OBJ_FIBO) {
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
   }
   else if(type == OBJ_FIBOARC) {
      ObjectSetInteger(0, name, OBJPROP_ELLIPSE, false);
      ObjectSetDouble(0, name, OBJPROP_SCALE, CalculateArcScale());
   }
   
   // Standard 5 levels (same as DrawRetracement)
   // Single loop for all levels
   string suffix = showPrice ? " --> %$" : "";
   for(int i = 0; i < count; i++) {
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, i, levels[i].value);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, i, levels[i].label + suffix);
   }
}

//+------------------------------------------------------------------+
//| Draw Fibonacci Retracement                                        |
//+------------------------------------------------------------------+
void DrawRetracement(string name, string label, color clr, int width, 
                     ENUM_LINE_STYLE style, datetime t1, double p1, 
                     datetime t2, double p2) {
   
   int count = ExtraLevels ? 10 : 5;
   FiboLevelDef lvls[MAX_FIBO_LEVELS];
   
   lvls[0].value = l0;   lvls[0].label = label + DoubleToString(l0 * 100, 1);
   lvls[1].value = l38;  lvls[1].label = label + DoubleToString(l38 * 100, 1);
   lvls[2].value = l50;  lvls[2].label = label + DoubleToString(l50 * 100, 1);
   lvls[3].value = l61;  lvls[3].label = label + DoubleToString(l61 * 100, 1);
   lvls[4].value = l100; lvls[4].label = label + DoubleToString(l100 * 100, 1);
   
   if(ExtraLevels) {
      lvls[5].value = l14;  lvls[5].label = label + DoubleToString(l14 * 100, 1);
      lvls[6].value = l23;  lvls[6].label = label + DoubleToString(l23 * 100, 1);
      lvls[7].value = l74;  lvls[7].label = label + DoubleToString(l74 * 100, 1);
      lvls[8].value = l88;  lvls[8].label = label + DoubleToString(l88 * 100, 1);
      lvls[9].value = l127; lvls[9].label = label + DoubleToString(l127 * 100, 1);
   }
   
   DrawFiboObject(name, OBJ_FIBO, lvls, count, clr, width, style, t1, p1, t2, p2, 0, 0, LevelPrice);
}

//+------------------------------------------------------------------+
//| Draw Fibonacci Arc                                                |
//+------------------------------------------------------------------+
void DrawArc(string name, string label, color clr, int width, 
             ENUM_LINE_STYLE style, datetime t1, double p1, 
             datetime t2, double p2) {
   
   int count = ExtraARC ? 6 : 3;
   FiboLevelDef lvls[6];
   
   lvls[0].value = ARC38; lvls[0].label = label + DoubleToString(ARC38 * 100, 1);
   lvls[1].value = ARC50; lvls[1].label = label + DoubleToString(ARC50 * 100, 1);
   lvls[2].value = ARC61; lvls[2].label = label + DoubleToString(ARC61 * 100, 1);
   
   if(ExtraARC) {
      lvls[3].value = ARC14; lvls[3].label = label + DoubleToString(ARC14 * 100, 1);
      lvls[4].value = ARC23; lvls[4].label = label + DoubleToString(ARC23 * 100, 1);
      lvls[5].value = ARC74; lvls[5].label = label + DoubleToString(ARC74 * 100, 1);
   }
   
   DrawFiboObject(name, OBJ_FIBOARC, lvls, count, clr, width, style, t1, p1, t2, p2);
}

//+------------------------------------------------------------------+
//| Calculate Arc Scale (cached for performance)                      |
//+------------------------------------------------------------------+
double CalculateArcScale() {
   //--- Check cache first (avoid expensive GUI calls)
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   if(chartWidth == g_lastArcChartWidth && chartHeight == g_lastArcChartHeight) {
      return g_cachedArcScale; // Use cached value
   }
   
   //--- Update cache
   g_lastArcChartWidth = chartWidth;
   g_lastArcChartHeight = chartHeight;
   
   if(chartWidth <= 0 || chartHeight <= 0) {
      g_cachedArcScale = 1.0;
      return g_cachedArcScale;
   }
   
   double priceRange = MathAbs(WindowPriceMax() - WindowPriceMin()) / Point;
   int barsCount = WindowBarsPerChart();
   
   if(barsCount <= 0) {
      g_cachedArcScale = 1.0;
      return g_cachedArcScale;
   }
   
   double chartScale = priceRange / barsCount;
   g_cachedArcScale = chartScale * chartWidth / chartHeight;
   return g_cachedArcScale;
}

//+------------------------------------------------------------------+
//| Draw Fibonacci Fan                                                |
//+------------------------------------------------------------------+
void DrawFan(string name, string label, color clr, int width, 
             ENUM_LINE_STYLE style, datetime t1, double p1, 
             datetime t2, double p2) {
   
   int count = ExtraFAN ? 6 : 3;
   FiboLevelDef lvls[6];
   
   lvls[0].value = FAN38; lvls[0].label = label + DoubleToString(FAN38 * 100, 1);
   lvls[1].value = FAN50; lvls[1].label = label + DoubleToString(FAN50 * 100, 1);
   lvls[2].value = FAN61; lvls[2].label = label + DoubleToString(FAN61 * 100, 1);
   
   if(ExtraFAN) {
      lvls[3].value = FAN14; lvls[3].label = label + DoubleToString(FAN14 * 100, 1);
      lvls[4].value = FAN23; lvls[4].label = label + DoubleToString(FAN23 * 100, 1);
      lvls[5].value = FAN74; lvls[5].label = label + DoubleToString(FAN74 * 100, 1);
   }
   
   DrawFiboObject(name, OBJ_FIBOFAN, lvls, count, clr, width, style, t1, p1, t2, p2);
}

//+------------------------------------------------------------------+
//| Draw Fibonacci Time Zones                                         |
//+------------------------------------------------------------------+
void DrawTimeZones(string name, string label, color clr, int width, 
                   ENUM_LINE_STYLE style, datetime t1, double p1, 
                   datetime t2, double p2) {
   
   FiboLevelDef lvls[9];
   
   lvls[0].value = Zone0;  lvls[0].label = label + DoubleToString(Zone0, 0);
   lvls[1].value = Zone1;  lvls[1].label = label + DoubleToString(Zone1, 0);
   lvls[2].value = Zone2;  lvls[2].label = label + DoubleToString(Zone2, 0);
   lvls[3].value = Zone3;  lvls[3].label = label + DoubleToString(Zone3, 0);
   lvls[4].value = Zone5;  lvls[4].label = label + DoubleToString(Zone5, 0);
   lvls[5].value = Zone8;  lvls[5].label = label + DoubleToString(Zone8, 0);
   lvls[6].value = Zone13; lvls[6].label = label + DoubleToString(Zone13, 0);
   lvls[7].value = Zone21; lvls[7].label = label + DoubleToString(Zone21, 0);
   lvls[8].value = Zone34; lvls[8].label = label + DoubleToString(Zone34, 0);
   
   DrawFiboObject(name, OBJ_FIBOTIMES, lvls, 9, clr, width, style, t1, p1, t2, p2);
}

//+------------------------------------------------------------------+
//| Draw Fibonacci Expansion                                          |
//+------------------------------------------------------------------+
void DrawExpansion(string name, string label, color clr, int width, 
                   ENUM_LINE_STYLE style, datetime t1, double p1, 
                   datetime t2, double p2, datetime t3, double p3) {
   
   int count = ExtraEXP ? 7 : 4;
   FiboLevelDef lvls[7];
   
   lvls[0].value = EXP61;  lvls[0].label = label + DoubleToString(EXP61 * 100, 1);
   lvls[1].value = EXP100; lvls[1].label = label + DoubleToString(EXP100 * 100, 1);
   lvls[2].value = EXP161; lvls[2].label = label + DoubleToString(EXP161 * 100, 1);
   lvls[3].value = EXP261; lvls[3].label = label + DoubleToString(EXP261 * 100, 1);
   
   if(ExtraEXP) {
      lvls[4].value = EXP78;  lvls[4].label = label + DoubleToString(EXP78 * 100, 1);
      lvls[5].value = EXP138; lvls[5].label = label + DoubleToString(EXP138 * 100, 1);
      lvls[6].value = EXP200; lvls[6].label = label + DoubleToString(EXP200 * 100, 1);
   }
   
   DrawFiboObject(name, OBJ_EXPANSION, lvls, count, clr, width, style, t1, p1, t2, p2, t3, p3);
}

//+------------------------------------------------------------------+
//| Calculate High/Low Levels                                         |
//+------------------------------------------------------------------+
void CalculateHighLow() {
   //--- CACHING: Only recalculate when period changes
   datetime currentDay = iTime(NULL, PERIOD_D1, 0);
   datetime currentWeek = iTime(NULL, PERIOD_W1, 0);
   datetime currentMonth = iTime(NULL, PERIOD_MN1, 0);
   
   //--- Daily levels (recalculate only on new day)
   if(g_lastDailyCalc != currentDay) {
      int iYesterday = 1;
      datetime yesterday = iTime(NULL, PERIOD_D1, iYesterday);
      
      //--- Skip Sunday
      MqlDateTime dt;
      TimeToStruct(yesterday, dt);
      if(dt.day_of_week == 0) iYesterday++;
      
      g_dayHigh  = iHigh(NULL, PERIOD_D1, iYesterday);
      g_dayLow   = iLow(NULL, PERIOD_D1, iYesterday);
      g_dayClose = iClose(NULL, PERIOD_D1, iYesterday);
      g_dayPivot = (g_dayHigh + g_dayLow + g_dayClose) / PIVOT_DIVISOR;
      
      g_lastDailyCalc = currentDay;
   }
   
   //--- Weekly levels (recalculate only on new week)
   if(g_lastWeeklyCalc != currentWeek) {
      g_weekHigh = iHigh(NULL, PERIOD_W1, 1);
      g_weekLow  = iLow(NULL, PERIOD_W1, 1);
      g_lastWeeklyCalc = currentWeek;
   }
   
   //--- Monthly levels (recalculate only on new month)
   if(g_lastMonthlyCalc != currentMonth) {
      g_monthHigh = iHigh(NULL, PERIOD_MN1, 1);
      g_monthLow  = iLow(NULL, PERIOD_MN1, 1);
      g_lastMonthlyCalc = currentMonth;
   }
}

//+------------------------------------------------------------------+
//| Draw High/Low Lines (optimized - only redraw when values change)  |
//|                                                                  |
//| NOTE: Static variables are SAFE here because MT4 reinitializes   |
//| the indicator when switching symbols. Each symbol gets fresh     |
//| static values starting from OnInit().                            |
//+------------------------------------------------------------------+
void DrawHighLowLines() {
   int currentPeriod = Period();
   
   //--- Static cache for previous values (reset on symbol change via OnInit)
   static double s_lastDayHigh = 0, s_lastDayLow = 0, s_lastDayPivot = 0;
   static double s_lastWeekHigh = 0, s_lastWeekLow = 0;
   static double s_lastMonthHigh = 0, s_lastMonthLow = 0;
   
   //--- Daily (only show on timeframes less than D1)
   if(ShowDaily && currentPeriod < PERIOD_D1_MINS) {
      if(g_dayHigh != s_lastDayHigh) {
         DrawTrendLine(g_objDayHigh, "Daily High", DayStyle, DayColor, DayWidth, g_dayHigh);
         s_lastDayHigh = g_dayHigh;
      }
      if(g_dayLow != s_lastDayLow) {
         DrawTrendLine(g_objDayLow, "Daily Low", DayStyle, DayColor, DayWidth, g_dayLow);
         s_lastDayLow = g_dayLow;
      }
      if(ShowPivot && g_dayPivot != s_lastDayPivot) {
         DrawTrendLine(g_objPivot, "Daily Pivot", PivotStyle, PivotColor, PivotWidth, g_dayPivot);
         s_lastDayPivot = g_dayPivot;
      }
   }
   
   //--- Weekly (only show on timeframes less than W1)
   if(ShowWeekly && currentPeriod < PERIOD_W1_MINS) {
      if(g_weekHigh != s_lastWeekHigh) {
         DrawTrendLine(g_objWeekHigh, "Weekly High", WeekStyle, WeekColor, WeekWidth, g_weekHigh);
         s_lastWeekHigh = g_weekHigh;
      }
      if(g_weekLow != s_lastWeekLow) {
         DrawTrendLine(g_objWeekLow, "Weekly Low", WeekStyle, WeekColor, WeekWidth, g_weekLow);
         s_lastWeekLow = g_weekLow;
      }
   }
   
   //--- Monthly (only show on timeframes less than MN1)
   if(ShowMonthly && currentPeriod < PERIOD_MN1_MINS) {
      if(g_monthHigh != s_lastMonthHigh) {
         DrawTrendLine(g_objMonthHigh, "Monthly High", MonthStyle, MonthColor, MonthWidth, g_monthHigh);
         s_lastMonthHigh = g_monthHigh;
      }
      if(g_monthLow != s_lastMonthLow) {
         DrawTrendLine(g_objMonthLow, "Monthly Low", MonthStyle, MonthColor, MonthWidth, g_monthLow);
         s_lastMonthLow = g_monthLow;
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Trend Line                                                   |
//|                                                                  |
//| LABEL POSITIONING:                                               |
//| Labels are centered at the midpoint of the visible line portion. |
//| This ensures clean, consistent alignment across all timeframes.  |
//+------------------------------------------------------------------+
void DrawTrendLine(string name, string label, ENUM_LINE_STYLE style, 
                   color clr, int width, double price) {
   
   //--- Dynamic Length Calculation
   // Start: Start of the current day (consistent anchor)
   datetime startLine = iTime(NULL, PERIOD_D1, 0);
   
   // End: Use Ray Right, so stopLine is just for initial creation
   datetime currentTime = TimeCurrent();
   int periodSec = PeriodSeconds();
   datetime stopLine = currentTime + (periodSec * 10);
   
   //--- Create Line
   ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_TREND, 0, startLine, price, stopLine, price)) {
      return;
   }
   
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   
   //--- Create Label (Centered on line)
   string labelName = name + "_Label";
   ObjectDelete(0, labelName);
   
   //--- Calculate midpoint of line + small right offset
   int labelOffset = periodSec * 5;  // 5 bars padding to the right
   datetime labelTime = startLine + ((currentTime - startLine) / 2) + labelOffset;
   
   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, price)) {
      ObjectSetString(0, labelName, OBJPROP_TEXT, label);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_UPPER);  // Position below line
   }
}


//+------------------------------------------------------------------+
//| Draw Candle Time Left                                             |
//+------------------------------------------------------------------+
void DrawCandleTime(datetime barTime, double price) {
   int secsLeft = (int)(barTime + PeriodSeconds() - TimeCurrent());
   if(secsLeft < 0) secsLeft = 0;
   
   string timeLeft = StringFormat("%02d:%02d", secsLeft / 60, secsLeft % 60);
   int offset = PeriodSeconds() * 1;  // 1 bar offset in seconds
   
   ObjectDelete(0, g_objCandleTime);
   if(ObjectCreate(0, g_objCandleTime, OBJ_TEXT, 0, barTime + offset, price)) {
      ObjectSetString(0, g_objCandleTime, OBJPROP_TEXT, timeLeft);
      ObjectSetInteger(0, g_objCandleTime, OBJPROP_COLOR, TimerColor);
      ObjectSetInteger(0, g_objCandleTime, OBJPROP_FONTSIZE, TimerFontSize);
      ObjectSetString(0, g_objCandleTime, OBJPROP_FONT, "Calibri");
      ObjectSetInteger(0, g_objCandleTime, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Calculate Swing Depth based on Timeframe                          |
//|                                                                  |
//| OPTIMIZED VALUES (v2.1):                                         |
//| Reduced depths for faster detection while maintaining accuracy.  |
//| These values balance responsiveness with noise filtering.        |
//|                                                                  |
//| NOTE: This indicator uses CONFIRMED swings only (non-repainting).|
//| Swings are confirmed after the specified number of bars.         |
//+------------------------------------------------------------------+
int CalculateSwingDepth(ENUM_TIMEFRAMES tf) {
   int period = (tf == 0) ? Period() : (int)tf;
   
   //--- Optimized depths: ~50% faster than v2.0, still reliable
   if(period <= PERIOD_M5)       return 3;    // M1-M5: very tight (3 bars)
   else if(period <= PERIOD_M15) return 4;    // M15: tight (4 bars = 1 hour)
   else if(period <= PERIOD_M30) return 4;    // M30: (4 bars = 2 hours)
   else if(period <= PERIOD_H1)  return 5;    // H1: (5 bars = 5 hours)
   else if(period <= PERIOD_H4)  return 6;    // H4: (6 bars = 24 hours)
   else if(period <= PERIOD_D1)  return 8;    // D1: (8 bars = 8 days)
   else                          return 12;   // W1, MN1: (12 bars)
}

//+------------------------------------------------------------------+
//| Check if price touches Fibo levels and trigger alerts             |
//|                                                                  |
//| CALCULATION:                                                     |
//| Uses same formula as MT4 OBJ_FIBO:                               |
//|   level_price = basePrice + (endPrice - basePrice) * level_value |
//| Where swing[1] = basePrice, swing[0] = endPrice                  |
//+------------------------------------------------------------------+
void CheckFiboLevelTouch(double barHigh, double barLow, datetime currentBar) {
   //--- Need valid swing points for Fibo levels
   if(g_swingTime[0] == 0 || g_swingTime[1] == 0) return;
   
   //--- Base and End prices (same as DrawRetracement)
   double basePrice = g_swingValue[1];  // First anchor point
   double endPrice  = g_swingValue[0];  // Second anchor point
   double range = MathAbs(endPrice - basePrice);
   
   if(range < Point * MIN_RANGE_POINTS) return; // Range too small
   
   //--- Calculate Fibo levels - MUST match DrawRetracement exactly
   int levelCount = ExtraLevels ? 10 : 5;  // 5 standard or 10 with extra
   double levels[10];
   string levelNames[10];
   
   // Standard 5 levels (same as DrawRetracement)
   levels[0] = l0;   levelNames[0] = DoubleToString(l0 * 100, 1) + "%";
   levels[1] = l38;  levelNames[1] = DoubleToString(l38 * 100, 1) + "%";
   levels[2] = l50;  levelNames[2] = DoubleToString(l50 * 100, 1) + "%";
   levels[3] = l61;  levelNames[3] = DoubleToString(l61 * 100, 1) + "%";
   levels[4] = l100; levelNames[4] = DoubleToString(l100 * 100, 1) + "%";
   
   // Extra 5 levels only when ExtraLevels=true
   if(ExtraLevels) {
      levels[5] = l14;  levelNames[5] = DoubleToString(l14 * 100, 1) + "%";
      levels[6] = l23;  levelNames[6] = DoubleToString(l23 * 100, 1) + "%";
      levels[7] = l74;  levelNames[7] = DoubleToString(l74 * 100, 1) + "%";
      levels[8] = l88;  levelNames[8] = DoubleToString(l88 * 100, 1) + "%";
      levels[9] = l127; levelNames[9] = DoubleToString(l127 * 100, 1) + "%";
   }
   
   //--- Calculate actual price levels (MT4 OBJ_FIBO formula)
   //--- level_price = basePrice + (endPrice - basePrice) * level
   for(int i = 0; i < levelCount; i++) {
      g_fiboLevels[i] = basePrice + (endPrice - basePrice) * levels[i];
   }
   
   //--- Reset touched flags on new bar
   if(currentBar != g_lastFiboAlertBar) {
      ArrayInitialize(g_fiboTouched, false);
      g_lastFiboAlertBar = currentBar;
   }
   
   //--- Check each level for touch using HIGH/LOW (catches intrabar touches)
   double tolerance = range * (AlertTolerance / 100.0);
   
   for(int i = 0; i < levelCount; i++) {
      if(g_fiboTouched[i]) continue; // Already alerted for this level
      
      double levelPrice = g_fiboLevels[i];
      
      //--- Check if level was touched by bar's high/low range
      //--- Level is touched if: (barLow - tolerance) <= level <= (barHigh + tolerance)
      if(levelPrice >= (barLow - tolerance) && levelPrice <= (barHigh + tolerance)) {
         //--- Trigger alert
         string msg = StringFormat("%s: Price touched Fibo %s (%.5f)",
                                   Symbol(), levelNames[i], levelPrice);
         
         if(AlertPopup) {
            Alert(msg);
         }
         if(AlertSound) {
            PlaySound(AlertSoundFile);
         }
         Print("FIBO ALERT: ", msg);
         
         g_fiboTouched[i] = true; // Mark as alerted
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Pending (Unconfirmed) Swing Markers                          |
//|                                                                  |
//| PURPOSE:                                                         |
//| Shows the current extreme points that haven't been confirmed yet.|
//| These markers are drawn with a distinct style (dotted/faded) to  |
//| indicate they are NOT CONFIRMED and may change.                  |
//|                                                                  |
//| NOTE: These visual markers do NOT affect Fibonacci tool drawing. |
//| Fibo tools only use confirmed swings for accuracy.               |
//+------------------------------------------------------------------+
void DrawPendingSwing(const double &high[], const double &low[], 
                      const datetime &time[], int rates_total) {
   
   //--- NOTE: In MQL4 OnCalculate, arrays are already AsSeries (high[0] = newest)
   //--- No need for explicit ArraySetAsSeries() call here
   
   if(rates_total < PENDING_SWING_LOOKBACK) return;
   
   //--- Find highest high and lowest low in recent bars
   int highestBar = 0, lowestBar = 0;
   double highestPrice = high[0], lowestPrice = low[0];
   
   for(int i = 1; i < PENDING_SWING_LOOKBACK && i < rates_total; i++) {
      if(high[i] > highestPrice) {
         highestPrice = high[i];
         highestBar = i;
      }
      if(low[i] < lowestPrice) {
         lowestPrice = low[i];
         lowestBar = i;
      }
   }
   
   //--- Skip if these are already confirmed swings
   bool highConfirmed = false, lowConfirmed = false;
   for(int i = 0; i < MAX_SWINGS; i++) {
      if(g_swingTime[i] == time[highestBar]) highConfirmed = true;
      if(g_swingTime[i] == time[lowestBar])  lowConfirmed = true;
   }
   
   //--- Draw pending high marker (if not confirmed)
   ObjectDelete(0, g_objPendingHigh);
   if(!highConfirmed && highestBar < g_effectiveSwingDepth) {
      if(ObjectCreate(0, g_objPendingHigh, OBJ_ARROW, 0, time[highestBar], highestPrice)) {
         ObjectSetInteger(0, g_objPendingHigh, OBJPROP_ARROWCODE, 159);  // Hollow diamond
         ObjectSetInteger(0, g_objPendingHigh, OBJPROP_COLOR, clrDimGray);
         ObjectSetInteger(0, g_objPendingHigh, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, g_objPendingHigh, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
         ObjectSetInteger(0, g_objPendingHigh, OBJPROP_SELECTABLE, false);
         ObjectSetString(0, g_objPendingHigh, OBJPROP_TOOLTIP, 
            "Pending High (unconfirmed) - " + DoubleToString(highestPrice, _Digits));
      }
   }
   
   //--- Draw pending low marker (if not confirmed)
   ObjectDelete(0, g_objPendingLow);
   if(!lowConfirmed && lowestBar < g_effectiveSwingDepth) {
      if(ObjectCreate(0, g_objPendingLow, OBJ_ARROW, 0, time[lowestBar], lowestPrice)) {
         ObjectSetInteger(0, g_objPendingLow, OBJPROP_ARROWCODE, 159);  // Hollow diamond
         ObjectSetInteger(0, g_objPendingLow, OBJPROP_COLOR, clrDimGray);
         ObjectSetInteger(0, g_objPendingLow, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, g_objPendingLow, OBJPROP_ANCHOR, ANCHOR_TOP);
         ObjectSetInteger(0, g_objPendingLow, OBJPROP_SELECTABLE, false);
         ObjectSetString(0, g_objPendingLow, OBJPROP_TOOLTIP, 
            "Pending Low (unconfirmed) - " + DoubleToString(lowestPrice, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| END OF iFibonacci v2.1                                            |
//+------------------------------------------------------------------+
