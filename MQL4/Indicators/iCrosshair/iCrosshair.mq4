//+------------------------------------------------------------------+
//|                                                   iCrosshair.mq4 |
//|                                     Copyright 2016-2026, Awran5  |
//|                                                 awran5@yahoo.com |
//+------------------------------------------------------------------+

//--- Branding
#define INDICATOR_NAME    "iCrosshair"
#define INDICATOR_VERSION "2.0"

#property copyright   "Copyright 2026, Awran5"
#property link        "https://www.mql5.com/en/users/awran5"
#property version     INDICATOR_VERSION
#property description "Interactive crosshair that displays OHLC, volume, wick sizes, and candle metrics on hover. "
#property description "Press 'T' or click the lines to freeze/unfreeze. Works on Forex, Gold, Indices, and Crypto. "
#property description "MT5 version: https://www.mql5.com/en/code/68324"
#property strict
#property indicator_chart_window

//--- Object Names Prefix
#define OBJ_PREFIX  "iCH_"
#define H_LINE_NAME OBJ_PREFIX"H_Line"
#define V_LINE_NAME OBJ_PREFIX"V_Line"

//+------------------------------------------------------------------+
//| CHANGELOG                                                        |
//| v2.0 (2026-01-17) - Major Update (Complete Rewrite)              |
//| - Original v1.x: https://www.mql5.com/en/code/15515              |
//|                                                                  |
//| NEW FEATURES:                                                    |
//| - Keyboard shortcut 'T' to toggle tracking (faster than click)  |
//| - Compact info bar with all candle analytics in one line        |
//| - Range display (total candle size in pips/points)              |
//| - UW%/LW% (wick percentages of Range, not absolute values)      |
//| - Body% (body as percentage of total Range)                     |
//| - Close Time (full date and time of candle close)               |
//| - Universal symbol support (Forex, Gold, Indices, Crypto)       |
//| - Customizable tooltip fields (OHLC, Volume, Ratios separately) |
//|                                                                  |
//| OPTIMIZATIONS:                                                   |
//| - Two-tier updates: lines immediate, data debounced at 50ms     |
//| - IsForexSymbol detection cached on init (no repeated calls)    |
//| - Namespace-safe object names (iCH_ prefix vs plain "H Line")   |
//|                                                                  |
//| HARDENING:                                                       |
//| - Comprehensive bounds checking before array access             |
//| - Error handling with GetLastError() reporting                  |
//| - Object existence validation before property access            |
//| - Clean deinitialization with reason logging                    |
//|                                                                  |
//| v1.01 (2016) - Added option to remove tooltip                   |
//| v1.00 (2015) - Initial release                                  |
//+------------------------------------------------------------------+

//--- Input Parameters (Display Options)
input bool            ShowTooltip      = true;      // Show Tooltip
input bool            ShowComment      = true;      // Show Comment (top-left info bar)
input bool            Show_OHLC        = true;      // └─ Show OHLC
input bool            Show_Volume      = true;      // └─ Show Volume
input bool            Show_Ratios      = true;      // └─ Show Ratios (Range, Body%, UW%, LW%)

//--- Input Parameters (Visual Settings)
input color           LineColor        = clrSlateGray; // Crosshair Color
input ENUM_LINE_STYLE LineStyle        = STYLE_DOT; // Line Style
input int             LineWidth        = 1;         // Line Width (1-5)

//--- Input Parameters (Performance)
input int             InfoUpdateInterval = 50;      // Info Bar Update Interval (ms) - Min 50

//--- Global Variables
uint     lastRedrawTime      = 0;
bool     trackingEnabled     = true;
int      g_effectiveInterval = 50;
bool     g_isForexSymbol     = false;
bool     g_commentCleared    = false;

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

   //--- Cache symbol type (called once, used many times)
   g_isForexSymbol = DetectForexSymbol();

   //--- Create initial crosshair objects
   datetime initTime = Time[0];
   double   initPrice = Close[0];

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

   //--- Set Shortname
   string shortName = StringFormat("%s v%s (%s)", INDICATOR_NAME, INDICATOR_VERSION, Symbol());
   IndicatorShortName(shortName);

   Print(StringFormat("%s v%s initialized successfully | Symbol: %s | Track with 'T' key",
         INDICATOR_NAME, INDICATOR_VERSION, Symbol()));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(H_LINE_NAME);
   ObjectDelete(V_LINE_NAME);
   Comment("");

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
//| OnCalculate function                                              |
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
      //--- Extract coordinates
      int      x      = (int)lparam;
      int      y      = (int)dparam;
      datetime time   = 0;
      double   price  = 0;
      int      window = 0;

      //--- Convert to chart coordinates (Silent fail for edges)
      if(!ChartXYToTimePrice(0, x, y, window, time, price))
         return;

      //--- IMMEDIATE: Update line positions (no debouncing for smooth movement)
      ObjectSet(H_LINE_NAME, OBJPROP_PRICE1, price);
      ObjectSet(V_LINE_NAME, OBJPROP_TIME1, time);
      ChartRedraw(0);

      //--- DEBOUNCED: Heavy calculations (tooltip, comment, data fetching)
      uint currentTime = GetTickCount();
      if(currentTime - lastRedrawTime < (uint)g_effectiveInterval)
         return;

      lastRedrawTime = currentTime;

      //--- Get bar index
      int bar = iBarShift(NULL, 0, time);
      if(bar < 0 || bar >= Bars)
         return;

      //--- Update tooltip
      if(ShowTooltip)
      {
         string tooltip = BuildTooltip(bar);
         ObjectSetString(0, H_LINE_NAME, OBJPROP_TOOLTIP, tooltip);
         ObjectSetString(0, V_LINE_NAME, OBJPROP_TOOLTIP, tooltip);
      }

      //--- Update comment with full candle info
      if(ShowComment)
      {
         double pips = CalculateDistance(price, Close[bar]);
         string commentText = BuildCommentLine(bar, pips);
         Comment(commentText);
      }
   }

   //--- Handle chart click (measurement mode)
   if(id == CHARTEVENT_CLICK && ShowComment)
   {
      int      x      = (int)lparam;
      int      y      = (int)dparam;
      datetime time   = 0;
      double   price  = 0;
      int      window = 0;

      if(ChartXYToTimePrice(0, x, y, window, time, price))
      {
         //--- Validate objects exist before accessing properties
         if(ObjectFind(V_LINE_NAME) < 0 || ObjectFind(H_LINE_NAME) < 0)
            return;

         datetime lineTime  = (datetime)ObjectGet(V_LINE_NAME, OBJPROP_TIME1);
         double   linePrice = ObjectGet(H_LINE_NAME, OBJPROP_PRICE1);

         int    barDiff = iBarShift(NULL, 0, lineTime) - iBarShift(NULL, 0, time);
         double pipDiff = CalculateDistance(price, linePrice);

         Comment(StringFormat("Bars: %d / Pips: %.1f / Price: %s",
                 MathAbs(barDiff),
                 MathAbs(pipDiff),
                 DoubleToStr(price, Digits)));
      }
   }
}

//+------------------------------------------------------------------+
//| Build single-line comment with all candle data                   |
//| Format: Bar:X | Pips:X | O:X H:X L:X C:X | Range:X | Body:X%     |
//|         UW:X% LW:X% | Vol:X | YYYY.MM.DD HH:MM                   |
//+------------------------------------------------------------------+
string BuildCommentLine(int bar, double pips)
{
   if(bar < 0 || bar >= Bars) return "";

   int priceDigits = GetDisplayDigits();
   
   //--- Calculate Range and percentages
   double range = High[bar] - Low[bar];
   double body = MathAbs(Open[bar] - Close[bar]);
   double upperBody = MathMax(Open[bar], Close[bar]);
   double lowerBody = MathMin(Open[bar], Close[bar]);
   double upperWick = High[bar] - upperBody;
   double lowerWick = lowerBody - Low[bar];
   
   //--- Calculate percentages (avoid division by zero)
   double bodyPct = (range > 0) ? (body / range * 100.0) : 0;
   double uwPct = (range > 0) ? (upperWick / range * 100.0) : 0;
   double lwPct = (range > 0) ? (lowerWick / range * 100.0) : 0;
   
   //--- Convert Range to display units (pips/points)
   double rangeDisplay = ConvertToDisplayUnits(range);
   
   //--- Calculate Close Time (Open Time + Period Duration)
   datetime closeTime = Time[bar] + PeriodSeconds();
   
   //--- Build compact comment string
   string result = "";
   
   //--- Bar & Pips (always shown)
   result += StringFormat("Bar:%d | Pips:%.1f", bar, pips);
   
   //--- Compact OHLC
   if(Show_OHLC)
   {
      result += StringFormat(" | O:%s H:%s L:%s C:%s",
         DoubleToStr(Open[bar], priceDigits),
         DoubleToStr(High[bar], priceDigits),
         DoubleToStr(Low[bar], priceDigits),
         DoubleToStr(Close[bar], priceDigits));
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
      result += StringFormat(" | Vol:%d", (int)Volume[bar]);
   }
   
   //--- Close Time (full date)
   result += StringFormat(" | %s", TimeToStr(closeTime, TIME_DATE | TIME_MINUTES));
   
   return result;
}

//+------------------------------------------------------------------+
//| Build tooltip string with candle analytics                       |
//+------------------------------------------------------------------+
string BuildTooltip(int bar)
{
   if(bar < 0 || bar >= Bars) return "";

   int priceDigits = GetDisplayDigits();
   
   //--- Calculate Range and percentages
   double range = High[bar] - Low[bar];
   double body = MathAbs(Open[bar] - Close[bar]);
   double upperBody = MathMax(Open[bar], Close[bar]);
   double lowerBody = MathMin(Open[bar], Close[bar]);
   double upperWick = High[bar] - upperBody;
   double lowerWick = lowerBody - Low[bar];
   
   //--- Calculate percentages
   double bodyPct = (range > 0) ? (body / range * 100.0) : 0;
   double uwPct = (range > 0) ? (upperWick / range * 100.0) : 0;
   double lwPct = (range > 0) ? (lowerWick / range * 100.0) : 0;
   
   //--- Convert Range to display units
   double rangeDisplay = ConvertToDisplayUnits(range);
   
   //--- Calculate Close Time
   datetime closeTime = Time[bar] + PeriodSeconds();
   
   string tip = StringFormat("Bar: %d", bar);

   //--- Grouped OHLC (2 lines for compactness)
   if(Show_OHLC)
   {
      tip += StringFormat("\nO: %s  H: %s",
             DoubleToStr(Open[bar], priceDigits),
             DoubleToStr(High[bar], priceDigits));
      tip += StringFormat("\nL: %s  C: %s",
             DoubleToStr(Low[bar], priceDigits),
             DoubleToStr(Close[bar], priceDigits));
   }

   //--- Volume
   if(Show_Volume)
      tip += StringFormat("\nVolume: %.0f", (double)Volume[bar]);

   //--- Metrics with percentages
   if(Show_Ratios)
   {
      tip += "\n----";
      tip += StringFormat("\nRange: %.1f", rangeDisplay);
      tip += StringFormat("\nBody: %.0f%%", bodyPct);
      tip += StringFormat("\nUW: %.0f%% | LW: %.0f%%", uwPct, lwPct);
   }
   
   //--- Close Time
   tip += StringFormat("\n%s", TimeToStr(closeTime, TIME_DATE | TIME_MINUTES));

   return tip;
}

//+------------------------------------------------------------------+
//| Get adaptive digits for display                                  |
//+------------------------------------------------------------------+
int GetDisplayDigits()
{
   if(IsForexSymbol()) return Digits;

   //--- For Gold/Crypto/Indices: typically 2 or 1 digits are cleaner
   if(Digits > 2) return 2;
   return Digits;
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
   return priceDistance / Point;
}

//+------------------------------------------------------------------+
//| Get pip value based on symbol type                               |
//+------------------------------------------------------------------+
double GetPipValue()
{
   //--- 5-digit or 3-digit brokers (modern)
   if(Digits == 5 || Digits == 3)
      return Point * 10.0;

   //--- 4-digit or 2-digit brokers (legacy)
   if(Digits == 4 || Digits == 2)
      return Point;

   //--- Default: use Point
   return Point;
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
   //--- Use MarketInfo for symbol classification in MQ4
   int calcMode = (int)MarketInfo(Symbol(), MODE_PROFITCALCMODE);

   //--- 0 = Forex mode in MQ4
   if(calcMode != 0)
      return false;

   //--- Exclude metals and commodities that some brokers classify as Forex
   string symbol = Symbol();
   if(StringFind(symbol, "XAU") >= 0 || // Gold
      StringFind(symbol, "XAG") >= 0 || // Silver
      StringFind(symbol, "XPD") >= 0 || // Palladium
      StringFind(symbol, "XPT") >= 0 || // Platinum
      StringFind(symbol, "OIL") >= 0 || // Oil
      StringFind(symbol, "WTI") >= 0 || // Oil
      StringFind(symbol, "BRN") >= 0)   // Brent
      return false;

   //--- Passed all checks: it's a Forex pair
   return true;
}

//+------------------------------------------------------------------+
//| Create crosshair line object                                     |
//+------------------------------------------------------------------+
void CreateCrosshairLine(string name, int type, datetime time, double price, string tooltip)
{
   //--- Delete existing object
   ObjectDelete(name);

   //--- Create new object
   if(!ObjectCreate(name, type, 0, time, price))
   {
      Print("ERROR: Failed to create object ", name, " | Error: ", GetLastError());
      return;
   }

   //--- Set properties
   ObjectSet(name, OBJPROP_COLOR, LineColor);
   ObjectSet(name, OBJPROP_STYLE, LineStyle);
   ObjectSet(name, OBJPROP_WIDTH, LineWidth);
   ObjectSet(name, OBJPROP_BACK, false);
   ObjectSet(name, OBJPROP_SELECTABLE, true);
   ObjectSet(name, OBJPROP_SELECTED, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| OPTIMIZATION NOTE:                                               |
//| Two-tier update strategy for optimal UX + performance:           |
//| 1. LINE MOVEMENT: Immediate (every mouse event) - smooth tracking|
//| 2. DATA UPDATES: Debounced at 20 FPS (50ms) - saves CPU          |
//| This achieves native-like smoothness while keeping CPU low.      |
//+------------------------------------------------------------------+
