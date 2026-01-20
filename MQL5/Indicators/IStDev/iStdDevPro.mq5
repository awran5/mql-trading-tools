//+------------------------------------------------------------------+
//|                                                  iStdDev Pro.mq5 |
//|                                           Copyright 2026, awran5 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright   "awran5 2026"
#property link        "https://www.mql5.com"
#property description "Professional Adaptive Linear Regression Channel"
#property description "Featuring Market Structure & R² Optimization"
#property description "v2.0: High-Performance & Multi-Mode Alerts"
#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//|                         DEFINITIONS                              |
//+------------------------------------------------------------------+
#define INAME "iStdDev Pro"
#define IVER  "2.00"
#property version IVER

// Performance optimization constants
#define MIN_REQUIRED_HISTORY 10
#define SAFE_MARGIN_BARS 5
#define R2_EXIT_THRESHOLD 0.96      
#define ALERT_TOLERANCE_PIPS 1.0    

//+------------------------------------------------------------------+
//|                         ENUMERATIONS                             |
//+------------------------------------------------------------------+
enum ENUM_ANCHOR_MODE
  {
   ANCHOR_STRUCTURE = 0,   // Smart: Market Structure Shift (Confirmed Pivot)
   ANCHOR_ADAPTIVE  = 1,   // Smart: Trend Fit Optimization (R2)
   ANCHOR_FIXED     = 2    // Manual: Fixed Window
  };

enum ENUM_PRICE_SOURCE
  {
   PRICE_CLOSE_   = 0,     // Close
   PRICE_TYPICAL_ = 1,     // Typical (H+L+C)/3
   PRICE_MEDIAN_  = 2,     // Median (H+L)/2
   PRICE_WEIGHTED_= 3      // Weighted (H+L+C+C)/4
  };

enum ENUM_ALERT_TYPE
  {
   ALERT_NONE       = 0,    // No Alerts
   ALERT_TOUCH      = 1,    // Touch Channel
   ALERT_BREAK      = 2,    // Break Channel
   ALERT_BOTH       = 3     // Both
  };

enum ENUM_SWING_TYPE
  {
   SWING_NONE = 0,
   SWING_HIGH = 1,
   SWING_LOW  = 2
  };

//+------------------------------------------------------------------+
//|                      INPUT PARAMETERS                            |
//+------------------------------------------------------------------+
input string           sep0              = "══════ CORE LOGIC ══════";
input ENUM_ANCHOR_MODE InpAnchorMode     = ANCHOR_STRUCTURE; // Calculation Mode
input ENUM_PRICE_SOURCE InpPriceSource    = PRICE_CLOSE_;     // Price Source
input int              InpSwingStrength  = 5;              // [Structure] Confirm Radius
input int              InpMinBars        = 20;             // [Adaptive] Min Scan Bars
input int              InpMaxBars        = 250;            // [Adaptive] Max Scan Bars

input string           sep0a             = "══════ MANUAL / LEGACY ══════";
input int              InpFirstBar       = 1;              // Start Bar (Shift)
input int              InpLastBar        = 100;            // End Bar (Fixed Mode)
input ENUM_TIMEFRAMES  InpTimeframe      = PERIOD_CURRENT; // Ref Timeframe
input bool             InpRayRight       = true;           // Extend Ray Right

input string           sep1              = "══════ VISUALS ══════";
input bool             InpShowAnchor     = true;           // Show Anchor Marker
input bool             InpShowInner      = true;           // Show Inner Channel (1.0σ)
input double           InpInnerDev       = 1.0;            // Inner Deviation
input color            InpInnerColor     = clrDodgerBlue;  // Inner Color
input int              InpInnerWidth     = 1;              // Inner Width

input string           sep2              = "══════ MAIN CHANNEL ══════";
input bool             InpShowOuter      = true;           // Show Outer Channel (2.0σ)
input double           InpOuterDev       = 2.0;            // Outer Deviation
input color            InpOuterColor     = clrOrangeRed;   // Outer Color
input int              InpOuterWidth     = 2;              // Outer Width

input string           sep3              = "══════ Fibonacci Levels ══════";
input bool             InpShowLevel1     = true;           // Show Level 0.618
input double           InpLevel1Dev      = 0.618;          
input color            InpLevel1Color    = clrGold;        
input bool             InpShowLevel2     = true;           // Show Level 1.618
input double           InpLevel2Dev      = 1.618;          
input color            InpLevel2Color    = clrMediumPurple;
input bool             InpShowRegLine    = true;           // Show Regression Line
input color            InpRegLineColor   = clrWhite;       

input string           sep7              = "══════ ALERTS ══════";
input ENUM_ALERT_TYPE  InpAlertType      = ALERT_NONE;     
input bool             InpAlertPopup     = true;           
input bool             InpAlertSound     = true;           
input bool             InpAlertPush      = false;          
input bool             InpShowInfo       = true;           // Show HUD Info (Comment)

//+------------------------------------------------------------------+
//|                      GLOBAL VARIABLES                            |
//+------------------------------------------------------------------+
string g_prefix = INAME + "_";
datetime g_lastBarTime = 0;
datetime g_anchor_time = 0;
datetime g_calc_start_time = 0;

// Regression calculation results (cached)
double g_reg_slope = 0.0;
double g_reg_intercept = 0.0;
double g_std_dev = 0.0;
double g_r_squared = 0.0;  
int g_active_anchor_idx = -1;
int g_window_count = 0;    
ENUM_SWING_TYPE g_active_anchor_type = SWING_NONE;

// Live projection levels (updated per tick)
double g_level_center = 0.0;
double g_level_inner_top = 0.0;
double g_level_inner_bot = 0.0;
double g_level_outer_top = 0.0;
double g_level_outer_bot = 0.0;

// Alert and calculation flags
bool g_alertSent = false;
bool g_calcSuccess = false;

// Performance optimization: Cache pip size
double g_pipSize = 0.0;

// MQL5 specific data buffers
double bufClose[], bufHigh[], bufLow[];
datetime bufTime[];

//+------------------------------------------------------------------+
//| Indicator Initialization                                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ValidateInputs())
      return(INIT_PARAMETERS_INCORRECT);

   // Initialize cached values
   g_pipSize = GetPipSize();
   g_calcSuccess = false;
   g_r_squared = 0.0;

   // Set array indexing style
   ArraySetAsSeries(bufClose, true);
   ArraySetAsSeries(bufHigh, true);
   ArraySetAsSeries(bufLow, true);
   ArraySetAsSeries(bufTime, true);

   UpdateShortName();
   CalculateAndDraw();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Indicator Deinitialization                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteObjectsByPrefix(g_prefix);
   Comment("");
  }

//+------------------------------------------------------------------+
//| Sanity checks on user input parameters                           |
//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   if(InpMinBars < MIN_REQUIRED_HISTORY)
     {
      Print(INAME + " Error: InpMinBars too small (min ", MIN_REQUIRED_HISTORY, ")");
      return false;
     }

   if(InpMaxBars < InpMinBars)
     {
      Print(INAME + " Error: InpMaxBars (", InpMaxBars, ") must be >= InpMinBars (", InpMinBars, ")");
      return false;
     }

   if(InpMinBars <= InpSwingStrength + 1)
     {
      Print(INAME + " Error: InpMinBars (", InpMinBars, ") must be > InpSwingStrength+1 (", InpSwingStrength+1, ")");
      return false;
     }

   if(InpFirstBar < 0)
     {
      Print(INAME + " Error: InpFirstBar cannot be negative (", InpFirstBar, ")");
      return false;
     }

   if(InpInnerDev <= 0 || InpOuterDev <= 0)
     {
      Print(INAME + " Error: Deviation values must be positive");
      return false;
     }

   if(InpAnchorMode == ANCHOR_FIXED)
     {
      if(InpLastBar <= InpFirstBar)
        {
         Print(INAME + " Error: [Fixed Mode] InpLastBar (", InpLastBar, ") must be > InpFirstBar (", InpFirstBar, ")");
         return false;
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Dynamic ShortName update                                         |
//+------------------------------------------------------------------+
void UpdateShortName()
  {
   string mode = (InpAnchorMode == ANCHOR_STRUCTURE) ? "[Struct]" : (InpAnchorMode == ANCHOR_ADAPTIVE ? "[Adapt]" : "[Fixed]");
   IndicatorSetString(INDICATOR_SHORTNAME, INAME + " v" + IVER + " " + mode);
  }

//+------------------------------------------------------------------+
//| Main Calculation Event                                           |
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
   // Refresh local buffers from specified timeframe
   int required = InpMaxBars + InpSwingStrength + SAFE_MARGIN_BARS;
   if(CopyClose(Symbol(), InpTimeframe, 0, required, bufClose) < required ||
      CopyHigh(Symbol(), InpTimeframe, 0, required, bufHigh) < required  ||
      CopyLow(Symbol(), InpTimeframe, 0, required, bufLow) < required    ||
      CopyTime(Symbol(), InpTimeframe, 0, required, bufTime) < required)
     {
      Comment(INAME + ": Loading data...");
      return 0;
     }

   datetime currentBarTime = bufTime[0];
   bool isNewBar = (g_lastBarTime != currentBarTime);
   bool isFirstRun = (prev_calculated == 0);

   if(isNewBar || isFirstRun)
     {
      g_lastBarTime = currentBarTime;
      g_alertSent = false;
      UpdateShortName();
      CalculateAndDraw();
     }

   if(g_calcSuccess)
     {
      UpdateCurrentLevels();
      if(InpShowInfo) ShowInfo();
      if(InpAlertType != ALERT_NONE) CheckAlerts();
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Main execution driver                                            |
//+------------------------------------------------------------------+
void CalculateAndDraw()
  {
   g_calcSuccess = false;
   int anchorIdx = GetAnchorIndex();

   if(anchorIdx < InpFirstBar + 2)
     {
      Comment(INAME + ": Invalid anchor index");
      return;
     }

   g_active_anchor_idx = anchorIdx;
   g_window_count = anchorIdx - InpFirstBar + 1;

   if(!CalculateRegressionAndStdDev(g_window_count, anchorIdx))
     {
      Comment(INAME + ": Calculation failed");
      return;
     }

   UpdateCurrentLevels();
   DrawVisuals(g_window_count, anchorIdx);
   DrawAnchorMarker(anchorIdx);

   g_calcSuccess = true;
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Resolves target anchor bar index                                 |
//+------------------------------------------------------------------+
int GetAnchorIndex()
  {
   switch(InpAnchorMode)
     {
      case ANCHOR_FIXED:     
         g_active_anchor_type = SWING_NONE;
         return InpLastBar;
      case ANCHOR_STRUCTURE: 
         return FindStructureAnchor();
      case ANCHOR_ADAPTIVE:  
         g_active_anchor_type = SWING_NONE;
         return FindOptimalAnchor();
      default:               
         return InpLastBar;
     }
  }

//+------------------------------------------------------------------+
//| Identifies Market Structure pivot                                |
//+------------------------------------------------------------------+
int FindStructureAnchor()
  {
   int searchStart = InpMinBars;
   int searchEnd = MathMin(InpMaxBars, ArraySize(bufClose) - (InpSwingStrength + 1));

   for(int i = searchStart; i <= searchEnd; i++)
     {
      g_active_anchor_type = GetSwingType(i, InpSwingStrength);
      if(g_active_anchor_type != SWING_NONE)
         return i;
     }
   g_active_anchor_type = SWING_NONE;
   return searchEnd;
  }

//+------------------------------------------------------------------+
//| Detects Swing High/Low (Radius based)                            |
//+------------------------------------------------------------------+
ENUM_SWING_TYPE GetSwingType(int idx, int strength)
  {
   int maxBars = ArraySize(bufClose);
   if(idx - strength < 0 || idx + strength >= maxBars) return SWING_NONE;

   double centerHigh = bufHigh[idx];
   double centerLow = bufLow[idx];
   bool isHigh = true;
   bool isLow = true;

   for(int k = 1; k <= strength; k++)
     {
      if(isHigh && (bufHigh[idx + k] > centerHigh || bufHigh[idx - k] > centerHigh)) isHigh = false;
      if(isLow && (bufLow[idx + k] < centerLow || bufLow[idx - k] < centerLow)) isLow = false;
      if(!isHigh && !isLow) return SWING_NONE;
     }

   if(isHigh) return SWING_HIGH;
   if(isLow) return SWING_LOW;
   return SWING_NONE;
  }

//+------------------------------------------------------------------+
//| Adaptive Optimization (Maximize R^2)                             |
//+------------------------------------------------------------------+
int FindOptimalAnchor()
  {
   int searchLimit = MathMin(InpMaxBars, ArraySize(bufClose) - 1);
   double bestR2 = -1.0;
   int bestLen = InpMinBars;
   int step = (searchLimit - InpMinBars > 100) ? 2 : 1;

   for(int len = InpMinBars; len <= searchLimit; len += step)
     {
      double r2 = GetRSquared(len);
      if(r2 > bestR2)
        {
         bestR2 = r2;
         bestLen = len;
        }
      if(bestR2 > R2_EXIT_THRESHOLD && len > searchLimit * 0.7) break;
     }
   g_r_squared = bestR2;
   return (InpFirstBar + bestLen - 1);
  }

//+------------------------------------------------------------------+
//| R-Squared (Statistical Correlation)                              |
//+------------------------------------------------------------------+
double GetRSquared(int count)
  {
   if(count < 2) return 0.0;
   int anchorBar = InpFirstBar + count - 1;
   double sumY = 0, sumX = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;

   for(int i = 0; i < count; i++)
     {
      double y = GetPrice(anchorBar - i);
      double x = (double)i;
      sumX += x; sumY += y; sumXY += x * y; sumX2 += x * x; sumY2 += y * y;
     }

   double n = (double)count;
   double num = (n * sumXY - sumX * sumY);
   double den = (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY);

   if(den <= 0.0000001) return 0.0;
   double r2 = MathPow(num, 2) / den;
   return MathMin(MathMax(r2, 0.0), 1.0);
  }

//+------------------------------------------------------------------+
//| Price Router handling multiple sources                           |
//+------------------------------------------------------------------+
double GetPrice(int idx)
  {
   if(InpPriceSource == PRICE_CLOSE_) return bufClose[idx];
   double h = bufHigh[idx], l = bufLow[idx], c = bufClose[idx];

   switch(InpPriceSource)
     {
      case PRICE_TYPICAL_:  return (h + l + c) / 3.0;
      case PRICE_MEDIAN_:   return (h + l) * 0.5;
      case PRICE_WEIGHTED_: return (h + l + c + c) * 0.25;
      default:              return c;
     }
  }

//+------------------------------------------------------------------+
//| Combined Regression + StdDev logic                               |
//+------------------------------------------------------------------+
bool CalculateRegressionAndStdDev(int count, int anchorIdx)
  {
   if(count < 2) return false;
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;

   for(int i = 0; i < count; i++)
     {
      double price = GetPrice(anchorIdx - i);
      double x = (double)i;
      sumX += x; sumY += price; sumXY += x * price; sumX2 += x * x; sumY2 += price * price;
     }

   double n = (double)count;
   double denom = (n * sumX2 - sumX * sumX);
   if(MathAbs(denom) < 0.0000001) return false;

   g_reg_slope = (n * sumXY - sumX * sumY) / denom;
   g_reg_intercept = (sumY - g_reg_slope * sumX) / n;

   double sumSq = 0;
   double meanY = sumY / n;
   for(int i = 0; i < count; i++)
     {
      double price = GetPrice(anchorIdx - i);
      double pred = g_reg_intercept + g_reg_slope * i;
      sumSq += MathPow(price - pred, 2);
     }

   g_std_dev = MathSqrt(sumSq / n);
   double ssRes = sumSq;
   double ssTot = sumY2 - n * meanY * meanY;
   g_r_squared = (ssTot > 0.0000001) ? MathMin(MathMax(1.0 - (ssRes / ssTot), 0.0), 1.0) : 0.0;

   g_anchor_time = bufTime[anchorIdx];
   g_calc_start_time = bufTime[InpFirstBar];
   return true;
  }

//+------------------------------------------------------------------+
//| Projection logic to live levels                                   |
//+------------------------------------------------------------------+
void UpdateCurrentLevels()
  {
   double x_proj = (double)g_active_anchor_idx;
   g_level_center = g_reg_intercept + g_reg_slope * x_proj;
   g_level_inner_top = g_level_center + (InpInnerDev * g_std_dev);
   g_level_inner_bot = g_level_center - (InpInnerDev * g_std_dev);
   g_level_outer_top = g_level_center + (InpOuterDev * g_std_dev);
   g_level_outer_bot = g_level_center - (InpOuterDev * g_std_dev);
  }

//+------------------------------------------------------------------+
//| Professional HUD Display                                         |
//+------------------------------------------------------------------+
void ShowInfo()
  {
   string modeS = (InpAnchorMode == ANCHOR_STRUCTURE) ? "Structure" : (InpAnchorMode == ANCHOR_ADAPTIVE ? "Adaptive" : "Fixed");
   string swingS = (g_active_anchor_type == SWING_HIGH) ? "High" : (g_active_anchor_type == SWING_LOW ? "Low" : "None");

   string info = StringFormat(
      "%s v%s | Mode: %s\n"
      "Anchor: Bar %d | Type: %s\n"
      "Window: %d bars | R²: %.4f\n"
      "Slope: %.6f | StdDev: %.5f\n"
      "Center: %.5f | Range: %.5f - %.5f",
      INAME, IVER, modeS, g_active_anchor_idx, swingS,
      g_window_count, g_r_squared, g_reg_slope, g_std_dev,
      g_level_center, g_level_outer_bot, g_level_outer_top
   );
   Comment(info);
  }

//+------------------------------------------------------------------+
//| Rendering Pipeline                                               |
//+------------------------------------------------------------------+
void DrawVisuals(int count, int anchorIdx)
  {
   double y_left = g_reg_intercept;
   double y_right = g_reg_intercept + g_reg_slope * (count - 1);
   double devIn = InpInnerDev * g_std_dev;
   double devOut = InpOuterDev * g_std_dev;

   if(InpShowRegLine) DrawTrendLine("RegLine", g_anchor_time, y_left, g_calc_start_time, y_right, InpRegLineColor, STYLE_SOLID, 2);
   if(InpShowInner) { DrawBand("ITop", y_left+devIn, y_right+devIn, InpInnerColor, STYLE_SOLID, InpInnerWidth); DrawBand("IBot", y_left-devIn, y_right-devIn, InpInnerColor, STYLE_SOLID, InpInnerWidth); }
   if(InpShowOuter) { DrawBand("OTop", y_left+devOut, y_right+devOut, InpOuterColor, STYLE_SOLID, InpOuterWidth); DrawBand("OBot", y_left-devOut, y_right-devOut, InpOuterColor, STYLE_SOLID, InpOuterWidth); }

   DrawLevels(y_left, y_right);
  }

//+------------------------------------------------------------------+
//| Renders Fibonacci Bands                                          |
//+------------------------------------------------------------------+
void DrawLevels(double yl, double yr)
  {
   double d1 = InpLevel1Dev * g_std_dev;
   double d2 = InpLevel2Dev * g_std_dev;
   if(InpShowLevel1) { DrawBand("L1T", yl+d1, yr+d1, InpLevel1Color, STYLE_DOT, 1); DrawBand("L1B", yl-d1, yr-d1, InpLevel1Color, STYLE_DOT, 1); }
   if(InpShowLevel2) { DrawBand("L2T", yl+d2, yr+d2, InpLevel2Color, STYLE_DOT, 1); DrawBand("L2B", yl-d2, yr-d2, InpLevel2Color, STYLE_DOT, 1); }
  }

//+------------------------------------------------------------------+
//| Visual Marker for Anchor point                                   |
//+------------------------------------------------------------------+
void DrawAnchorMarker(int anchorIdx)
  {
   if(!InpShowAnchor) return;
   string obj = g_prefix + "AnchorMark";
   datetime time = bufTime[anchorIdx];
   double p; int arrow; ENUM_ARROW_ANCHOR ap; string tt;

   if(g_active_anchor_type == SWING_HIGH) { p = bufHigh[anchorIdx]; arrow = 162; ap = ANCHOR_BOTTOM; tt = "Swing High Anchor"; }
   else if(g_active_anchor_type == SWING_LOW) { p = bufLow[anchorIdx]; arrow = 161; ap = ANCHOR_TOP; tt = "Swing Low Anchor"; }
   else { p = bufHigh[anchorIdx]; arrow = 159; ap = ANCHOR_BOTTOM; tt = "Fixed/Adaptive Anchor"; }

   if(ObjectFind(0, obj) < 0) ObjectCreate(0, obj, OBJ_ARROW, 0, time, p);
   else { ObjectMove(0, obj, 0, time, p); }

   ObjectSetInteger(0, obj, OBJPROP_ARROWCODE, arrow);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, obj, OBJPROP_ANCHOR, ap);
   ObjectSetInteger(0, obj, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, obj, OBJPROP_TOOLTIP, tt + " [Bar " + IntegerToString(anchorIdx) + "]");
  }

//+------------------------------------------------------------------+
//| Trendline Object Wrapper                                         |
//+------------------------------------------------------------------+
void DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, ENUM_LINE_STYLE style, int width)
  {
   string objName = g_prefix + name;
   if(ObjectFind(0, objName) < 0) ObjectCreate(0, objName, OBJ_TREND, 0, t1, p1, t2, p2);
   else { ObjectMove(0, objName, 0, t1, p1); ObjectMove(0, objName, 1, t2, p2); }
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, InpRayRight);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetString(0, objName, OBJPROP_TOOLTIP, INAME + " " + name);
  }

void DrawBand(string name, double p1, double p2, color clr, ENUM_LINE_STYLE style, int width)
  {
   DrawTrendLine(name, g_anchor_time, p1, g_calc_start_time, p2, clr, style, width);
  }

//+------------------------------------------------------------------+
//| Tick-by-tick Alert Monitoring                                    |
//+------------------------------------------------------------------+
void CheckAlerts()
  {
   if(g_alertSent) return;
   double cp = bufClose[0];
   string msg = ""; bool s = false;
   double tol = ALERT_TOLERANCE_PIPS * g_pipSize;

   if(InpAlertType == ALERT_TOUCH || InpAlertType == ALERT_BOTH)
     {
      if(MathAbs(cp - g_level_inner_top) < tol) { msg = "Touch Inner Top @ " + DoubleToString(cp, _Digits); s = true; }
      else if(MathAbs(cp - g_level_inner_bot) < tol) { msg = "Touch Inner Bot @ " + DoubleToString(cp, _Digits); s = true; }
     }
   if(!s && (InpAlertType == ALERT_BREAK || InpAlertType == ALERT_BOTH))
     {
      if(cp > g_level_outer_top) { msg = "Break Outer Top @ " + DoubleToString(cp, _Digits); s = true; }
      else if(cp < g_level_outer_bot) { msg = "Break Outer Bot @ " + DoubleToString(cp, _Digits); s = true; }
     }

   if(s)
     {
      string fullMsg = Symbol() + " " + EnumToString(_Period) + ": " + msg;
      if(InpAlertPopup) Alert(fullMsg);
      if(InpAlertSound) PlaySound("alert.wav");
      if(InpAlertPush) SendNotification(fullMsg);
      g_alertSent = true;
     }
  }

//+------------------------------------------------------------------+
//| Broker-Independent PipSize Handling                              |
//+------------------------------------------------------------------+
double GetPipSize()
  {
   int d = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   return (d == 3 || d == 5) ? 10.0 * _Point : _Point;
  }

//+------------------------------------------------------------------+
//| Batch Object Deletion                                            |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
  {
   ObjectsDeleteAll(0, prefix);
  }
//+------------------------------------------------------------------+
