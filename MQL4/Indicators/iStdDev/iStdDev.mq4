//+------------------------------------------------------------------+
//|                             Smart Adaptive Regression Channel v2 |
//|                                           Copyright 2026, awran5 |
//+------------------------------------------------------------------+

#property copyright   "awran5 2026"
#property description "Professional Adaptive Linear Regression Channel"
#property description "Featuring Market Structure & R² Optimization"
#property description "v2.0: High-Performance & Multi-Mode Alerts"
#property strict
#property indicator_chart_window
#property indicator_buffers 0

//+------------------------------------------------------------------+
//|                         DEFINITIONS                              |
//+------------------------------------------------------------------+
#define INAME "iStdDev Pro"
#define IVER  "2.00"
#property version IVER

// Performance optimization constants
#define MIN_REQUIRED_HISTORY 10
#define SAFE_MARGIN_BARS 5

//+------------------------------------------------------------------+
//|                         ENUMERATIONS                             |
//+------------------------------------------------------------------+
enum ENUM_ANCHOR_MODE
  {
   ANCHOR_STRUCTURE = 0,   // Smart: Market Structure Shift (Confirmed Swing)
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
//|                       INTERNAL CONSTANTS                         |
//+------------------------------------------------------------------+
#define R2_EXIT_THRESHOLD 0.96      
#define ALERT_TOLERANCE_PIPS 1.0    // Standardized to 1.0 true pip

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
double g_r_squared = 0.0;  // Cache R² to avoid recalculation
int g_active_anchor_idx = -1;
int g_window_count = 0;    // Cache window size
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

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ValidateInputs())
      return(INIT_PARAMETERS_INCORRECT);

   // Initialize cached values
   g_pipSize = GetPipSize();
   g_calcSuccess = false;
   g_r_squared = 0.0;

   UpdateShortName();
   CalculateAndDraw();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteObjectsByPrefix(g_prefix);
   Comment("");
  }

//+------------------------------------------------------------------+
//| Performs sanity checks on user input parameters.                 |
//| Multi-condition checks for cross-broker stability.               |
//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   // Basic parameter range checks
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

   // Deviation values validation
   if(InpInnerDev <= 0 || InpOuterDev <= 0 || InpLevel1Dev < 0 || InpLevel2Dev < 0)
     {
      Print(INAME + " Error: Deviation values must be positive");
      return false;
     }

   // Line width validation
   if(InpInnerWidth < 1 || InpOuterWidth < 1 || InpInnerWidth > 5 || InpOuterWidth > 5)
     {
      Print(INAME + " Error: Line widths must be between 1 and 5");
      return false;
     }

   // Fixed mode specific checks
   if(InpAnchorMode == ANCHOR_FIXED)
     {
      if(InpLastBar <= InpFirstBar)
        {
         Print(INAME + " Error: [Fixed Mode] InpLastBar (", InpLastBar, ") must be > InpFirstBar (", InpFirstBar, ")");
         return false;
        }
     }

   // Historical data check
   int availableBars = iBars(NULL, InpTimeframe);
   int requiredBars = InpMaxBars + InpSwingStrength + SAFE_MARGIN_BARS;

   if(availableBars < requiredBars)
     {
      Print(INAME + " Warning: Insufficient history. Available: ", availableBars, ", Required: ", requiredBars);
      Print(INAME + " Info: Indicator will start when more data is loaded");
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Dynamic ShortName update reflecting the active mode.             |
//+------------------------------------------------------------------+
void UpdateShortName()
{
   string mode = (InpAnchorMode==ANCHOR_STRUCTURE) ? "[Struct]" : (InpAnchorMode==ANCHOR_ADAPTIVE ? "[Adapt]" : "[Fixed]");
   IndicatorShortName(INAME + " v" + IVER + " " + mode);
}

//+------------------------------------------------------------------+
//| Main event handler for market data iterations.                   |
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
   // Validate sufficient historical data
   int tfBars = iBars(NULL, InpTimeframe);
   int requiredBars = InpMaxBars + InpSwingStrength + SAFE_MARGIN_BARS;

   if(tfBars < requiredBars)
     {
      Comment(INAME + ": Loading data... (" + IntegerToString(tfBars) + "/" + IntegerToString(requiredBars) + " bars)");
      return rates_total;
     }

   // Get current bar time for new bar detection
   datetime currentBarTime = iTime(NULL, InpTimeframe, 0);
   if(currentBarTime == 0)
     {
      Comment(INAME + " Error: Invalid bar time");
      return rates_total;
     }

   // Full recalculation on new bar or first run
   bool isNewBar = (g_lastBarTime != currentBarTime);
   bool isFirstRun = (prev_calculated == 0);

   if(isNewBar || isFirstRun)
     {
      g_lastBarTime = currentBarTime;
      g_alertSent = false;

      UpdateShortName();
      CalculateAndDraw();
     }

   // Update live levels and info on every tick if calculation succeeded
   if(g_calcSuccess)
     {
      UpdateCurrentLevels();

      if(InpShowInfo)
         ShowInfo();

      if(InpAlertType != ALERT_NONE)
         CheckAlerts();
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| Main execution driver.                                           |
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

   // Combined calculation for performance (single loop pass)
   if(!CalculateRegressionAndStdDev(g_window_count, anchorIdx))
     {
      Comment(INAME + ": Calculation failed");
      return;
     }

   // Calculate current levels immediately after regression
   UpdateCurrentLevels();

   DrawVisuals(g_window_count, anchorIdx);
   DrawAnchorMarker(anchorIdx);

   g_calcSuccess = true;
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Resolves the target anchor bar index based on active mode.      |
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
//| Identifies the last significant Market Structure point.          |
//+------------------------------------------------------------------+
int FindStructureAnchor()
  {
   int searchStart = InpMinBars;
   int searchEnd = MathMin(InpMaxBars, iBars(NULL, InpTimeframe) - (InpSwingStrength + 1));
   
   for(int i = searchStart; i <= searchEnd; i++)
     {
      g_active_anchor_type = GetSwingType(i, InpSwingStrength);
      if(g_active_anchor_type != SWING_NONE)
        {
         return i;
        }
     }
   g_active_anchor_type = SWING_NONE;
   return searchEnd;
  }

//+------------------------------------------------------------------+
//| Detects if a bar is a High or Low swing point (Radius based).    |
//+------------------------------------------------------------------+
ENUM_SWING_TYPE GetSwingType(int idx, int strength)
  {
   int maxBars = iBars(NULL, InpTimeframe);

   // Boundary check
   if(idx - strength < 0 || idx + strength >= maxBars)
      return SWING_NONE;

   double centerHigh = iHigh(NULL, InpTimeframe, idx);
   double centerLow = iLow(NULL, InpTimeframe, idx);

   bool isHigh = true;
   bool isLow = true;

   // Single loop for efficiency
   for(int k = 1; k <= strength; k++)
     {
      if(isHigh)
        {
         if(iHigh(NULL, InpTimeframe, idx + k) > centerHigh ||
            iHigh(NULL, InpTimeframe, idx - k) > centerHigh)
           {
            isHigh = false;
           }
        }

      if(isLow)
        {
         if(iLow(NULL, InpTimeframe, idx + k) < centerLow ||
            iLow(NULL, InpTimeframe, idx - k) < centerLow)
           {
            isLow = false;
           }
        }

      // Early exit if both failed
      if(!isHigh && !isLow)
         return SWING_NONE;
     }

   if(isHigh) return SWING_HIGH;
   if(isLow) return SWING_LOW;

   return SWING_NONE;
  }

//+------------------------------------------------------------------+
//| Statistical Optimization: Maximize Trend Reliability (R^2).     |
//+------------------------------------------------------------------+
int FindOptimalAnchor()
  {
   int searchLimit = MathMin(InpMaxBars, iBars(NULL, InpTimeframe) - 1);
   double bestR2 = -1.0;
   int bestLen = InpMinBars;

   // Optimization: Use step size for large ranges
   int step = (searchLimit - InpMinBars > 100) ? 2 : 1;

   for(int len = InpMinBars; len <= searchLimit; len += step)
     {
      double r2 = GetRSquared(len);
      if(r2 > bestR2)
        {
         bestR2 = r2;
         bestLen = len;
        }

      // Early exit if excellent fit found
      if(bestR2 > R2_EXIT_THRESHOLD && len > searchLimit * 0.7)
         break;
     }

   // Store the best R² found
   g_r_squared = bestR2;

   return (InpFirstBar + bestLen - 1);
  }

//+------------------------------------------------------------------+
//| Calculates R² (coefficient of determination) for a given window  |
//| Used during Adaptive mode optimization                           |
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
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
      sumY2 += y * y;
     }

   double n = (double)count;
   double num = (n * sumXY - sumX * sumY);
   double den = (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY);

   if(den <= 0.0000001) return 0.0;

   double r2 = MathPow(num, 2) / den;

   // Clamp to valid range
   if(r2 < 0) return 0.0;
   if(r2 > 1) return 1.0;

   return r2;
  }

//+------------------------------------------------------------------+
//| Price Router handling multiple sources.                         |
//+------------------------------------------------------------------+
double GetPrice(int idx)
  {
   // Cache frequently accessed values
   static ENUM_PRICE_SOURCE lastSource = -1;
   static bool useSimpleClose = false;

   if(lastSource != InpPriceSource)
     {
      lastSource = InpPriceSource;
      useSimpleClose = (InpPriceSource == PRICE_CLOSE_);
     }

   // Fast path for most common case
   if(useSimpleClose)
      return iClose(NULL, InpTimeframe, idx);

   // Other price sources
   double h = iHigh(NULL, InpTimeframe, idx);
   double l = iLow(NULL, InpTimeframe, idx);
   double c = iClose(NULL, InpTimeframe, idx);

   switch(InpPriceSource)
     {
      case PRICE_TYPICAL_:
         return (h + l + c) / 3.0;

      case PRICE_MEDIAN_:
         return (h + l) * 0.5;

      case PRICE_WEIGHTED_:
         return (h + l + c + c) * 0.25;

      default:
         return c;
     }
  }

//+------------------------------------------------------------------+
//| Combined: Regression + StdDev + R² in ONE PASS for performance   |
//| Returns false if calculation failed                              |
//+------------------------------------------------------------------+
bool CalculateRegressionAndStdDev(int count, int anchorIdx)
  {
   if(count < 2)
     {
      Print(INAME + " Error: Count too small for regression (", count, ")");
      return false;
     }

   // First pass: Calculate regression coefficients
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;

   for(int i = 0; i < count; i++)
     {
      double price = GetPrice(anchorIdx - i);
      double x = (double)i;

      sumX += x;
      sumY += price;
      sumXY += x * price;
      sumX2 += x * x;
      sumY2 += price * price;
     }

   double n = (double)count;
   double denom = (n * sumX2 - sumX * sumX);

   if(MathAbs(denom) < 0.0000001)
     {
      Print(INAME + " Error: Degenerate regression (zero denominator)");
      g_reg_slope = 0;
      g_reg_intercept = sumY / n;
      g_std_dev = 0;
      g_r_squared = 0;
      return false;
     }

   g_reg_slope = (n * sumXY - sumX * sumY) / denom;
   g_reg_intercept = (sumY - g_reg_slope * sumX) / n;

   // Second pass: Calculate Standard Deviation and R²
   double sumSq = 0;
   double meanY = sumY / n;

   for(int i = 0; i < count; i++)
     {
      double price = GetPrice(anchorIdx - i);
      double pred = g_reg_intercept + g_reg_slope * i;
      sumSq += MathPow(price - pred, 2);
     }

   g_std_dev = MathSqrt(sumSq / n);

   // Calculate R² (coefficient of determination)
   double ssRes = sumSq;  // Sum of squares of residuals
   double ssTot = sumY2 - n * meanY * meanY;  // Total sum of squares

   if(ssTot > 0.0000001)
      g_r_squared = 1.0 - (ssRes / ssTot);
   else
      g_r_squared = 0.0;

   // Clamp R² to [0, 1] range for numerical stability
   if(g_r_squared < 0) g_r_squared = 0;
   if(g_r_squared > 1) g_r_squared = 1;

   // Cache time values
   g_anchor_time = iTime(NULL, InpTimeframe, anchorIdx);
   g_calc_start_time = iTime(NULL, InpTimeframe, InpFirstBar);

   return true;
  }

//+------------------------------------------------------------------+
//| Projects regression levels to current live price (Time[0]).      |
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
//| Displays professional HUD information (uses cached R²)           |
//+------------------------------------------------------------------+
void ShowInfo()
  {
   string modeS = (InpAnchorMode == ANCHOR_STRUCTURE) ? "Structure" :
                  (InpAnchorMode == ANCHOR_ADAPTIVE)  ? "Adaptive"  : "Fixed";

   string swingType = (g_active_anchor_type == SWING_HIGH) ? "High" :
                      (g_active_anchor_type == SWING_LOW)  ? "Low"  : "None";

   string info = StringFormat(
      "%s v%s | Mode: %s\n"
      "Anchor: Bar %d | Type: %s\n"
      "Window: %d bars | R²: %.4f\n"
      "Slope: %.6f | StdDev: %.5f\n"
      "Center: %.5f | Range: %.5f - %.5f",
      INAME, IVER, modeS,
      g_active_anchor_idx, swingType,
      g_window_count, g_r_squared,
      g_reg_slope, g_std_dev,
      g_level_center, g_level_outer_bot, g_level_outer_top
   );

   Comment(info);
  }

//+------------------------------------------------------------------+
//| High-level rendering pipeline for the channel architecture.      |
//+------------------------------------------------------------------+
void DrawVisuals(int count, int anchorIdx)
  {
   double y_left = g_reg_intercept;
   double y_right = g_reg_intercept + g_reg_slope*(count-1);

   double devIn = InpInnerDev * g_std_dev;
   double devOut = InpOuterDev * g_std_dev;

   if(InpShowRegLine)
      DrawTrendLine("RegLine", g_anchor_time, y_left, g_calc_start_time, y_right, InpRegLineColor, STYLE_SOLID, 2);

   if(InpShowInner)
     {
      DrawBand("ITop", y_left+devIn, y_right+devIn, InpInnerColor, STYLE_SOLID, InpInnerWidth);
      DrawBand("IBot", y_left-devIn, y_right-devIn, InpInnerColor, STYLE_SOLID, InpInnerWidth);
     }
   if(InpShowOuter)
     {
      DrawBand("OTop", y_left+devOut, y_right+devOut, InpOuterColor, STYLE_SOLID, InpOuterWidth);
      DrawBand("OBot", y_left-devOut, y_right-devOut, InpOuterColor, STYLE_SOLID, InpOuterWidth);
     }

   DrawLevels(y_left, y_right);
  }

//+------------------------------------------------------------------+
//| Renders the Fibonacci/Ratio levels relative to the current model.|
//+------------------------------------------------------------------+
void DrawLevels(double yl, double yr)
  {
   double d1 = InpLevel1Dev*g_std_dev;
   double d2 = InpLevel2Dev*g_std_dev;
   if(InpShowLevel1)
     {
      DrawBand("L1T", yl+d1, yr+d1, InpLevel1Color, STYLE_DOT, 1);
      DrawBand("L1B", yl-d1, yr-d1, InpLevel1Color, STYLE_DOT, 1);
     }
   if(InpShowLevel2)
     {
      DrawBand("L2T", yl+d2, yr+d2, InpLevel2Color, STYLE_DOT, 1);
      DrawBand("L2B", yl-d2, yr-d2, InpLevel2Color, STYLE_DOT, 1);
     }
  }

//+------------------------------------------------------------------+
//| Draws a visual indicator at the calculated smart anchor point.   |
//+------------------------------------------------------------------+
void DrawAnchorMarker(int anchorIdx)
  {
   if(!InpShowAnchor)
      return;

   string obj = g_prefix + "AnchorMark";
   datetime time = iTime(NULL, InpTimeframe, anchorIdx);
   double price;
   int arrowCode;
   ENUM_ARROW_ANCHOR anchorPos;
   string tooltipText;

   // Determine marker position and style based on anchor type
   if(g_active_anchor_type == SWING_HIGH)
     {
      price = iHigh(NULL, InpTimeframe, anchorIdx);
      arrowCode = 162;  // Down arrow
      anchorPos = ANCHOR_BOTTOM;
      tooltipText = "Swing High Anchor";
     }
   else if(g_active_anchor_type == SWING_LOW)
     {
      price = iLow(NULL, InpTimeframe, anchorIdx);
      arrowCode = 161;  // Up arrow
      anchorPos = ANCHOR_TOP;
      tooltipText = "Swing Low Anchor";
     }
   else
     {
      price = iHigh(NULL, InpTimeframe, anchorIdx);
      arrowCode = 159;  // Circle
      anchorPos = ANCHOR_BOTTOM;
      tooltipText = "Fixed/Adaptive Anchor";
     }

   // Validate time
   if(time == 0)
     {
      Print(INAME + " Error: Invalid time for anchor marker at bar ", anchorIdx);
      return;
     }

   // Create or update arrow object
   if(ObjectFind(0, obj) < 0)
     {
      if(!ObjectCreate(0, obj, OBJ_ARROW, 0, time, price))
        {
         Print(INAME + " Error: Failed to create anchor marker. Error: ", GetLastError());
         return;
        }
     }
   else
     {
      ObjectSetInteger(0, obj, OBJPROP_TIME, time);
      ObjectSetDouble(0, obj, OBJPROP_PRICE, price);
     }

   // Set visual properties
   ObjectSetInteger(0, obj, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, obj, OBJPROP_ANCHOR, anchorPos);
   ObjectSetInteger(0, obj, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_BACK, false);
   ObjectSetString(0, obj, OBJPROP_TOOLTIP, tooltipText + " [Bar " + IntegerToString(anchorIdx) + "]");
  }

//+------------------------------------------------------------------+
//| Primitive Trendline wrapper with existence checking.             |
//+------------------------------------------------------------------+
void DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, ENUM_LINE_STYLE style, int width)
  {
   string objName = g_prefix + name;

   // Validate inputs
   if(t1 == 0 || t2 == 0 || p1 <= 0 || p2 <= 0)
     {
      Print(INAME + " Error: Invalid trendline parameters for ", objName);
      return;
     }

   // Create or update object
   if(ObjectFind(0, objName) < 0)
     {
      if(!ObjectCreate(0, objName, OBJ_TREND, 0, t1, p1, t2, p2))
        {
         Print(INAME + " Error: Failed to create trendline ", objName, " Error: ", GetLastError());
         return;
        }
     }
   else
     {
      ObjectSetInteger(0, objName, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, p2);
     }

   // Set visual properties
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, InpRayRight);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);  // Draw behind price
   ObjectSetString(0, objName, OBJPROP_TOOLTIP, INAME + " " + name);
  }

//+------------------------------------------------------------------+
//| Helper to draw parallel bands offset by standard deviation.      |
//+------------------------------------------------------------------+
void DrawBand(string name, double p1, double p2, color clr, ENUM_LINE_STYLE style, int width)
  {
   DrawTrendLine(name, g_anchor_time, p1, g_calc_start_time, p2, clr, style, width);
  }

//+------------------------------------------------------------------+
//| Alert monitoring system. Performs tick-by-tick proximity checks. |
//+------------------------------------------------------------------+
void CheckAlerts()
  {
   if(g_alertSent)
      return;

   double currentPrice = iClose(NULL, InpTimeframe, 0);
   string alertMsg = "";
   bool shouldAlert = false;
   double tolerance = ALERT_TOLERANCE_PIPS * g_pipSize;  // Use cached pip size

   // Check touch alerts
   if(InpAlertType == ALERT_TOUCH || InpAlertType == ALERT_BOTH)
     {
      if(MathAbs(currentPrice - g_level_inner_top) < tolerance)
        {
         alertMsg = "Touch Inner Top @ " + DoubleToString(currentPrice, _Digits);
         shouldAlert = true;
        }
      else if(MathAbs(currentPrice - g_level_inner_bot) < tolerance)
        {
         alertMsg = "Touch Inner Bot @ " + DoubleToString(currentPrice, _Digits);
         shouldAlert = true;
        }
     }

   // Check break alerts (only if no touch triggered)
   if(!shouldAlert && (InpAlertType == ALERT_BREAK || InpAlertType == ALERT_BOTH))
     {
      if(currentPrice > g_level_outer_top)
        {
         alertMsg = "Break Outer Top @ " + DoubleToString(currentPrice, _Digits);
         shouldAlert = true;
        }
      else if(currentPrice < g_level_outer_bot)
        {
         alertMsg = "Break Outer Bot @ " + DoubleToString(currentPrice, _Digits);
         shouldAlert = true;
        }
     }

   // Trigger alerts
   if(shouldAlert)
     {
      string fullMsg = Symbol() + " " + EnumToString(InpTimeframe) + ": " + alertMsg;

      if(InpAlertPopup)
         Alert(fullMsg);

      if(InpAlertSound)
         PlaySound("alert.wav");

      if(InpAlertPush)
         SendNotification(fullMsg);

      g_alertSent = true;
     }
  }

//+------------------------------------------------------------------+
//| Calculates the true pip size for broker-independent scaling      |
//| Call once during init and cache the result                       |
//+------------------------------------------------------------------+
double GetPipSize()
  {
   int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

   // Handle fractional pip brokers (5 and 3 digit quotes)
   if(digits == 3 || digits == 5)
      return 10.0 * _Point;

   // Standard pip size for 2 and 4 digit quotes
   return _Point;
  }

//+------------------------------------------------------------------+
//| Batch object cleanup algorithm.                                  |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
  {
   int total = ObjectsTotal();

   // Iterate backwards for safe deletion
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);

      // Check if object name starts with our prefix
      if(StringFind(name, prefix) == 0)
        {
         if(!ObjectDelete(0, name))
           {
            Print(INAME + " Warning: Failed to delete object: ", name);
           }
        }
     }
  }
//+------------------------------------------------------------------+
