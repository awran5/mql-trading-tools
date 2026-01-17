//+------------------------------------------------------------------+
//|                                                   iCrosshair.mq5 |
//|                                          Copyright 2026, Awran5  |
//|                                                 awran5@yahoo.com |
//+------------------------------------------------------------------+

//--- Branding
#define INDICATOR_NAME    "iCrosshair"
#define INDICATOR_VERSION "1.0"

#property copyright   "Copyright 2026, Awran5"
#property link        "https://www.mql5.com/en/users/awran5"
#property version     INDICATOR_VERSION
#property description "Interactive crosshair that displays OHLC, volume, wick sizes, and candle metrics on hover. "
#property description "Press 'T' or click the lines to freeze/unfreeze. Works on Forex, Gold, Indices, and Crypto. "
#property description "MT4 version: https://www.mql5.com/en/code/15515"
#property strict
#property indicator_chart_window
#property indicator_plots 0

//--- Object Names Prefix
#define OBJ_PREFIX  "iCH_"
#define H_LINE_NAME OBJ_PREFIX"H_Line"
#define V_LINE_NAME OBJ_PREFIX"V_Line"

//+------------------------------------------------------------------+
//| CHANGELOG                                                        |
//| v1.0 (2026-01-17) - First Public Release for MT5                 |
//| - Complete rewrite from legacy MQL4 version (iCrosshair.mq4)     |
//| - NEW: Keyboard shortcut 'T' to toggle tracking mode             |
//| - NEW: Compact info bar (O: H: L: C: Range Body% UW% LW%)        |
//| - NEW: Range display (total candle size in pips/points)          |
//| - NEW: UW%/LW% (wick percentages of Range)                       |
//| - NEW: Close Time (full date and time of candle)                 |
//| - NEW: Universal symbol support (Forex, Gold, Indices, Crypto)   |
//| - OPTIMIZED: Smart caching with sliding window (200 bars)        |
//| - OPTIMIZED: Debounced rendering at 20 FPS (50ms intervals)      |
//| - OPTIMIZED: IsForexSymbol detection cached on init              |
//| - HARDENED: Comprehensive bounds checking and error handling     |
//+------------------------------------------------------------------+

//--- Input Parameters
input group "=== Display Options ==="
input bool            ShowComment      = true;      // Show Comment (top-left info bar)
input bool            Show_OHLC        = true;      // └─ Show OHLC
input bool            Show_Volume      = true;      // └─ Show Volume
input bool            Show_Ratios      = true;      // └─ Show Ratios (Range, Body%, UW%, LW%)

input group "=== Visual Settings ==="
input color           LineColor        = clrSlateGray; // Crosshair Color
input ENUM_LINE_STYLE LineStyle        = STYLE_DOT; // Line Style
input int             LineWidth        = 1;         // Line Width (1-5)

input group "=== Performance ==="
input int             InfoUpdateInterval = 50;      // Info Bar Update Interval (ms) - Min 50

//--- Global Variables
MqlRates rates[];
ulong    lastRedrawTime   = 0;
bool     trackingEnabled  = true;   // Refactored from isTracking
int      lastCachedBar    = -1;     // Cache optimization
int      lastCachedStart  = -1;     // Cache optimization for window start position
datetime lastCachedTime   = 0;      // Cache optimization for current bar
int      g_effectiveInterval = 50;  // Effective redraw interval (clamped)
bool     g_isForexSymbol  = false;  // Cached IsForexSymbol result (set in OnInit)
bool     g_commentCleared = false;  // Track if comment was cleared (avoid repeated calls)

//--- Constants
#define WINDOW_SIZE 200             // Sliding window size for CopyRates performance

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate and clamp inputs
   g_effectiveInterval = MathMax(50, InfoUpdateInterval);
   if(InfoUpdateInterval < 50)
      Print("NOTE: InfoUpdateInterval too low. Clamped to 50ms.");
   
   if(LineWidth < 1 || LineWidth > 5)
   {
      Print("ERROR: LineWidth must be between 1 and 5.");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Configure rates array (series = newest first, matching iBarShift indexing)
   ArraySetAsSeries(rates, true);

   //--- Cache symbol type (called once, used many times)
   g_isForexSymbol = DetectForexSymbol();

   //--- Create initial crosshair objects
   datetime initTime = iTime(_Symbol, _Period, 0);
   double   initPrice = iClose(_Symbol, _Period, 0);
   
   if(initTime == 0 || initPrice == 0)
   {
      Print("ERROR: Failed to initialize chart data. GetLastError: ", GetLastError());
      return INIT_FAILED;
   }
   
   CreateCrosshairLine(H_LINE_NAME, OBJ_HLINE, initTime, initPrice, "Click to toggle tracking");
   CreateCrosshairLine(V_LINE_NAME, OBJ_VLINE, initTime, initPrice, "Click to toggle tracking");
   
   //--- Enable mouse move events
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   
   //--- Enable keyboard events for 'T' shortcut
   ChartSetInteger(0, CHART_BRING_TO_TOP, true);
   ChartSetInteger(0, CHART_KEYBOARD_CONTROL, true);
   
   //--- Set Shortname & Metadata
   string shortName = StringFormat("%s v%s (%s)", INDICATOR_NAME, INDICATOR_VERSION, _Symbol);
   IndicatorSetString(INDICATOR_SHORTNAME, shortName);
   
   Print(StringFormat("%s v%s initialized successfully | Symbol: %s | Track with 'T' key", 
         INDICATOR_NAME, INDICATOR_VERSION, _Symbol));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Cleanup chart objects
   ObjectDelete(0, H_LINE_NAME);
   ObjectDelete(0, V_LINE_NAME);
   Comment("");

   //--- Free dynamic array memory
   ArrayFree(rates);
   
   string reasonText = "";
   switch(reason)
   {
      case REASON_REMOVE:       reasonText = "Indicator removed"; break;
      case REASON_RECOMPILE:    reasonText = "Recompiled"; break;
      case REASON_CHARTCHANGE:  reasonText = "Symbol/Period changed"; break;
      case REASON_PARAMETERS:   reasonText = "Parameters changed"; break;
      default:                  reasonText = "Unknown reason";
   }
   
   Print(INDICATOR_NAME, " v", INDICATOR_VERSION, " deinitialized | Reason: ", reasonText);
}

//+------------------------------------------------------------------+
//| OnCalculate function (required by MQL5, not used for this tool) |
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
   //--- This indicator uses OnChartEvent, not OnCalculate
   //--- Return value required by MQL5
   return rates_total;
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long   &lparam,
                  const double &dparam,
                  const string &sparam)
{
   //--- Clear comment once if disabled (avoid repeated calls)
   if(!ShowComment && !g_commentCleared)
   {
      Comment("");
      g_commentCleared = true;
   }
   
   //--- Handle Keyboard Shortcut ('T' for toggle)
   if(id == CHARTEVENT_KEYDOWN)
   {
      if(lparam == 'T' || lparam == 't')
      {
         trackingEnabled = !trackingEnabled;
         Print("Tracking mode: ", trackingEnabled ? "ENABLED" : "DISABLED (Frozen)");
         return;
      }
   }

   //--- Handle object click (toggle tracking mode)
   //--- Feature: Click to freeze lines as S/R, click again to reactivate
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == H_LINE_NAME || sparam == V_LINE_NAME)
      {
         trackingEnabled = !trackingEnabled;
         
         if(trackingEnabled)
            Print("Tracking mode: ENABLED - Lines follow mouse");
         else
            Print("Tracking mode: DISABLED - Lines frozen (use as S/R)");
      }
   }
   
   //--- Handle mouse move (update crosshair)
   if(id == CHARTEVENT_MOUSE_MOVE && trackingEnabled)
   {
      //--- Convert screen to chart coordinates (Silent fail for edges)
      datetime time   = 0;
      double   price  = 0;
      int      window = 0;
      if(!ScreenToChartCoordinates((int)lparam, (int)dparam, time, price, window))
         return;

      //--- IMMEDIATE: Update line positions (no debouncing for smooth movement)
      ObjectSetDouble(0, H_LINE_NAME, OBJPROP_PRICE, price);
      ObjectSetInteger(0, V_LINE_NAME, OBJPROP_TIME, time);
      ChartRedraw(0);

      //--- DEBOUNCED: Heavy calculations (tooltip, comment, data fetching)
      ulong currentTime = GetTickCount64();
      if(currentTime - lastRedrawTime < (ulong)g_effectiveInterval)
         return;

      lastRedrawTime = currentTime;

      //--- Get bar index
      int bar = iBarShift(_Symbol, _Period, time);
      if(bar < 0)
         return;

      //--- Calculate window position (used for both CopyRates and localBar)
      int startPos = MathMax(bar - (WINDOW_SIZE / 2), 0);
      int localBar = bar - startPos;

      //--- Copy rates data (Sliding Window for radical performance)
      //--- Cache invalidation: refresh when bar, window position, or current bar time changes
      datetime currentBarTime = iTime(_Symbol, _Period, 0);
      if(bar != lastCachedBar || startPos != lastCachedStart || currentBarTime != lastCachedTime)
      {
         if(CopyRates(_Symbol, _Period, startPos, WINDOW_SIZE, rates) <= 0)
            return;

         lastCachedBar = bar;
         lastCachedStart = startPos;
         lastCachedTime = currentBarTime;
      }

      //--- Bounds check for safety
      if(localBar < 0 || localBar >= ArraySize(rates))
         return;

      //--- Update comment with full candle info
      if(ShowComment)
      {
         double pips = CalculateDistance(price, rates[localBar].close);
         string commentText = BuildCommentLine(localBar, bar, pips);
         Comment(commentText);
      }
   }
   
   //--- Handle chart click (measurement mode - future feature)
   if(id == CHARTEVENT_CLICK && ShowComment)
   {
      datetime time   = 0;
      double   price  = 0;
      int      window = 0;

      if(ScreenToChartCoordinates((int)lparam, (int)dparam, time, price, window))
      {
         //--- Validate objects exist before accessing properties
         if(ObjectFind(0, V_LINE_NAME) < 0 || ObjectFind(0, H_LINE_NAME) < 0)
            return;

         datetime lineTime  = (datetime)ObjectGetInteger(0, V_LINE_NAME, OBJPROP_TIME);
         double   linePrice = ObjectGetDouble(0, H_LINE_NAME, OBJPROP_PRICE);

         int    barDiff = iBarShift(_Symbol, _Period, lineTime) - iBarShift(_Symbol, _Period, time);
         double pipDiff = CalculateDistance(price, linePrice);

         Comment(StringFormat("Bars: %d / Pips: %.1f / Price: %s",
                 MathAbs(barDiff),
                 MathAbs(pipDiff),
                 DoubleToString(price, _Digits)));
      }
   }
}

//+------------------------------------------------------------------+
//| Build single-line comment with all candle data                   |
//| Format: Bar:X | Pips:X | O:X H:X L:X C:X | Range:X | Body:X%     |
//|         UW:X% LW:X% | Vol:X | YYYY.MM.DD HH:MM                   |
//+------------------------------------------------------------------+
string BuildCommentLine(int localBar, int bar, double pips)
{
   if(localBar < 0 || localBar >= ArraySize(rates)) return "";

   int priceDigits = GetDisplayDigits();
   
   //--- Calculate Range and percentages
   double range = rates[localBar].high - rates[localBar].low;
   double body = MathAbs(rates[localBar].open - rates[localBar].close);
   double upperBody = MathMax(rates[localBar].open, rates[localBar].close);
   double lowerBody = MathMin(rates[localBar].open, rates[localBar].close);
   double upperWick = rates[localBar].high - upperBody;
   double lowerWick = lowerBody - rates[localBar].low;
   
   //--- Calculate percentages (avoid division by zero)
   double bodyPct = (range > 0) ? (body / range * 100.0) : 0;
   double uwPct = (range > 0) ? (upperWick / range * 100.0) : 0;
   double lwPct = (range > 0) ? (lowerWick / range * 100.0) : 0;
   
   //--- Convert Range to display units (pips/points)
   double rangeDisplay = ConvertToDisplayUnits(range);
   
   //--- Calculate Close Time (Open Time + Period Duration)
   datetime closeTime = rates[localBar].time + PeriodSeconds(_Period);
   
   //--- Build compact comment string
   string result = "";
   
   //--- Bar & Pips (always shown)
   result += StringFormat("Bar:%d | Pips:%.1f", bar, pips);
   
   //--- Compact OHLC
   if(Show_OHLC)
   {
      result += StringFormat(" | O:%s H:%s L:%s C:%s",
         DoubleToString(rates[localBar].open, priceDigits),
         DoubleToString(rates[localBar].high, priceDigits),
         DoubleToString(rates[localBar].low, priceDigits),
         DoubleToString(rates[localBar].close, priceDigits));
   }
   
   //--- Range & Ratios
   if(Show_Ratios)
   {
      result += StringFormat(" | Range:%.1f | Body:%.0f%% | UW:%.0f%% LW:%.0f%%",
         rangeDisplay, bodyPct, uwPct, lwPct);
   }
   
   //--- Volume
   if(Show_Volume)
   {
      result += StringFormat(" | Vol:%lld", rates[localBar].tick_volume);
   }
   
   //--- Close Time (full date)
   result += StringFormat(" | %s", TimeToString(closeTime, TIME_DATE | TIME_MINUTES));
   
   return result;
}

//+------------------------------------------------------------------+
//| Get adaptive digits for display                                  |
//+------------------------------------------------------------------+
int GetDisplayDigits()
{
   if(IsForexSymbol()) return _Digits;

   //--- For Gold/Crypto/Indices: typically 2 or 1 digits are cleaner
   //--- But we respect broker's _Digits if they are already low (e.g. BTC with 0 or 2)
   //--- Why 2 digits? Industry standard for commodities (XAUUSD: 1234.56)
   //--- and cleaner display for indices (US30: 34567.89) without excessive precision
   if(_Digits > 2) return 2;
   return _Digits;
}

//+------------------------------------------------------------------+
//| Calculate distance between two prices                            |
//+------------------------------------------------------------------+
double CalculateDistance(double price1, double price2)
{
   double distance = MathAbs(price1 - price2);
   return ConvertToDisplayUnits(distance);
}

//+------------------------------------------------------------------+
//| Convert price distance to display units (pips/points)            |
//+------------------------------------------------------------------+
double ConvertToDisplayUnits(double priceDistance)
{
   //--- For Forex: convert to pips
   if(IsForexSymbol())
   {
      double pipValue = GetPipValue();
      return priceDistance / pipValue;
   }
   
   //--- For other assets: return points
   return priceDistance / _Point;
}

//+------------------------------------------------------------------+
//| Get pip value based on symbol type                               |
//+------------------------------------------------------------------+
double GetPipValue()
{
   //--- 5-digit or 3-digit brokers (modern)
   if(_Digits == 5 || _Digits == 3)
      return _Point * 10.0;
   
   //--- 4-digit or 2-digit brokers (legacy)
   if(_Digits == 4 || _Digits == 2)
      return _Point;
   
   //--- Default: use Point
   return _Point;
}

//+------------------------------------------------------------------+
//| Check if symbol is Forex pair (returns cached value)             |
//+------------------------------------------------------------------+
bool IsForexSymbol()
{
   return g_isForexSymbol;
}

//+------------------------------------------------------------------+
//| Detect if symbol is Forex pair (called once in OnInit)           |
//+------------------------------------------------------------------+
bool DetectForexSymbol()
{
   //--- Use MQL5 symbol info for accurate classification
   ENUM_SYMBOL_CALC_MODE calcMode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE);

   //--- Not Forex mode = not Forex
   if(calcMode != SYMBOL_CALC_MODE_FOREX)
      return false;

   //--- Exclude metals and commodities that some brokers classify as Forex
   string symbol = _Symbol;
   if(StringFind(symbol, "XAU") >= 0 || // Gold
      StringFind(symbol, "XAG") >= 0 || // Silver
      StringFind(symbol, "XPD") >= 0 || // Palladium
      StringFind(symbol, "XPT") >= 0 || // Platinum
      StringFind(symbol, "OIL") >= 0 || // Oil
      StringFind(symbol, "WTI") >= 0 || // Oil
      StringFind(symbol, "BRN") >= 0)   // Brent
      return false;

   //--- Passed all checks: trust SYMBOL_CALC_MODE_FOREX classification
   return true;
}

//+------------------------------------------------------------------+
//| Create crosshair line object                                     |
//+------------------------------------------------------------------+
void CreateCrosshairLine(string name, ENUM_OBJECT type, datetime time, double price, string tooltip)
{
   //--- Delete existing object
   ObjectDelete(0, name);
   
   //--- Create new object
   if(!ObjectCreate(0, name, type, 0, time, price))
   {
      Print("ERROR: Failed to create object ", name, " | Error: ", GetLastError());
      return;
   }
   
   //--- Set properties
   ObjectSetInteger(0, name, OBJPROP_COLOR, LineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| Convert screen coordinates to chart coordinates                  |
//| Returns true on success, fills time/price/window by reference    |
//+------------------------------------------------------------------+
bool ScreenToChartCoordinates(int x, int y, datetime &time, double &price, int &window)
{
   time   = 0;
   price  = 0;
   window = 0;
   return ChartXYToTimePrice(0, x, y, window, time, price);
}

//+------------------------------------------------------------------+
//| OPTIMIZATION NOTE:                                               |
//| Two-tier update strategy for optimal UX + performance:           |
//| 1. LINE MOVEMENT: Immediate (every mouse event) - smooth tracking|
//| 2. DATA UPDATES: Debounced at 20 FPS (50ms) - saves CPU          |
//| This achieves native-like smoothness while keeping CPU low.      |
//+------------------------------------------------------------------+
