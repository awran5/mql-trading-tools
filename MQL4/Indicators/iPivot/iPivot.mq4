//+------------------------------------------------------------------+
//|                                                       iPivot.mq4 |
//|                                      Copyright © 2015-2026, Awran5 |
//|                                                 awran5@yahoo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2015-2026, Awran5"
#property link      "awran5@yahoo.com"
#property version   "2.00"
#property description "Institutional Grade Pivot Points (v2.00)"
#property description "Features: Zero-Lag, Persistent Objects, Price Labels"
#property strict
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_color1  clrNONE
#property indicator_color2  clrNONE
#property indicator_color3  clrNONE
#property indicator_color4  clrNONE
#property indicator_color5  clrNONE
#property indicator_color6  clrNONE
#property indicator_color7  clrNONE
#property indicator_color8  clrNONE
#property indicator_color9  clrNONE

#define INAME "iPivot"

//--- Enums
enum PivotMethodType
  {
   Standard,   // Standard
   Fibonacci,  // Fibonacci
   Camarilla,  // Camarilla
   Woodie,     // Woodie
   DeMark      // DeMark
  };

//--- Inputs
input string          InpSep1     = "=== Settings ===";      // Settings
input PivotMethodType InpPivotMethod = Fibonacci;            // Pivot Formula
input color           InpPColor      = clrPurple;            // Pivot Color
input bool            InpShowSR      = true;                 // Show S/R Lines
input color           InpRColor      = clrFireBrick;         // Resistance Color
input color           InpSColor      = clrDarkGreen;         // Support Color
input int             InpWidth       = 2;                    // Line Width
input ENUM_LINE_STYLE InpStyle       = STYLE_SOLID;          // Line Style
input color           InpLabelColor  = clrDimGray;           // Label Color
input int             InpLabelSize   = 8;                    // Label Font Size

input string          InpSep2     = "=== Alerts ===";        // Notification
input bool            InpUseAlert    = false;                 // Enable Pop-up Alert
input bool            InpUseEmail    = false;                // Enable Email
input bool            InpUsePush     = false;                // Enable Push Notification

//--- Global Variables
double P,R1,R2,R3,R4,S1,S2,S3,S4;
double PBuffer[],S1Buffer[],S2Buffer[],S3Buffer[],S4Buffer[],R1Buffer[],R2Buffer[],R3Buffer[],R4Buffer[];
datetime ExtLastCalcDay = 0;
string   ExtFormulaName = "";
bool     ExtAlerted[9]; // 0=P, 1-4=R, 5-8=S

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,PBuffer);
   SetIndexBuffer(1,R1Buffer);
   SetIndexBuffer(2,R2Buffer);
   SetIndexBuffer(3,R3Buffer);
   SetIndexBuffer(4,R4Buffer);
   SetIndexBuffer(5,S1Buffer);
   SetIndexBuffer(6,S2Buffer);
   SetIndexBuffer(7,S3Buffer);
   SetIndexBuffer(8,S4Buffer);

//--- Set styles (Hidden buffers for data window only)
   for(int i=0; i<9; i++)
     {
      SetIndexStyle(i,DRAW_NONE);
      SetIndexEmptyValue(i,0.0);
     }

//--- Set labels
   SetIndexLabel(0,"Pivot");
   SetIndexLabel(1,"Res 1");
   SetIndexLabel(2,"Res 2");
   SetIndexLabel(3,"Res 3");
   SetIndexLabel(4,"Res 4");
   SetIndexLabel(5,"Sup 1");
   SetIndexLabel(6,"Sup 2");
   SetIndexLabel(7,"Sup 3");
   SetIndexLabel(8,"Sup 4");

   IndicatorShortName(INAME);

   ArrayInitialize(ExtAlerted, false);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Clear Comment
   Comment("");

   // Use explicit loop for MQL4 compatibility and safety
   // Note: Using (0, -1, -1) selects the overload for ChartID=0, All Windows, All Types
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      // Check if name implies it belongs to this indicator (StartsWith check)
      if(StringFind(name, INAME) == 0) 
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   if(rates_total < 2) return(0);

   //--- Detect New Day (Math Calculation)
   datetime currentDay = iTime(NULL, PERIOD_D1, 0);
   bool isNewDay = (currentDay != ExtLastCalcDay);
   
   if(isNewDay || prev_calculated == 0)
     {
      if(CalculateLevels()) {
        ExtLastCalcDay = currentDay;
        // Reset Alerts for the new day
        ArrayInitialize(ExtAlerted, false);
      }
     }
     
   //--- Detect New Bar (Visual Update)
   // We update visuals every bar to keep labels near the hard right edge
   static datetime lastBar = 0;
   if(Time[0] != lastBar)
     {
      UpdateVisuals();
      lastBar = Time[0];
     }

   //--- Fill Data Window Buffers logic
   int limit = rates_total - prev_calculated;
   if(limit > 1) limit = rates_total - 1; 

   // Standard loop to populate the buffers for the Data Window
   // This allows validation and "Mouse Hover" values
   for(int i = limit; i >= 0; i--)
     {
      PBuffer[i]  = P;
      R1Buffer[i] = R1;
      R2Buffer[i] = R2;
      R3Buffer[i] = R3;
      R4Buffer[i] = R4;
      S1Buffer[i] = S1;
      S2Buffer[i] = S2;
      S3Buffer[i] = S3;
      S4Buffer[i] = S4;
     }

   //--- Check Alerts
   CheckAlerts();

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Calculate Pivot Levels                                           |
//+------------------------------------------------------------------+
bool CalculateLevels()
  {
   // Get Yesterday's Data
   int yShift = 1;
   datetime yTime = iTime(NULL, PERIOD_D1, yShift);
   
   if(yTime == 0) return(false); // Validating data availability
   
   // Adjust for Sunday Data if broker has it (Skip Sunday)
   if(TimeDayOfWeek(yTime) == 0) yShift = 2;

   double dayHigh  = iHigh(NULL, PERIOD_D1, yShift);
   double dayLow   = iLow(NULL, PERIOD_D1, yShift);
   double dayClose = iClose(NULL, PERIOD_D1, yShift);
   double dayOpen  = iOpen(NULL, PERIOD_D1, yShift);
   
   // Safety Check for Data Validity
   if(dayHigh <= 0 || dayLow <= 0 || dayClose <= 0) 
     {
      Print("iPivot: Invalid Daily Data for calculation.");
      return(false);
     }
     
   double range    = dayHigh - dayLow;

   // Reset
   R1=0; R2=0; R3=0; R4=0;
   S1=0; S2=0; S3=0; S4=0;

   switch(InpPivotMethod)
     {
      case Standard:
         P = (dayHigh + dayLow + dayClose) / 3.0;
         R1 = (2 * P) - dayLow;
         R2 = P + range;
         R3 = R2 + range;
         R4 = R3 + range;
         S1 = (2 * P) - dayHigh;
         S2 = P - range;
         S3 = S2 - range;
         S4 = S3 - range;
         ExtFormulaName = "Standard";
         break;

      case Fibonacci:
         P = (dayHigh + dayLow + dayClose) / 3.0;
         R1 = P + (range * 0.382);
         R2 = P + (range * 0.618);
         R3 = P + (range * 1.000);
         R4 = P + (range * 1.618);
         S1 = P - (range * 0.382);
         S2 = P - (range * 0.618);
         S3 = P - (range * 1.000);
         S4 = P - (range * 1.618);
         ExtFormulaName = "Fibonacci";
         break;

      case Camarilla:
         R1 = dayClose + (range * 1.1 / 12.0);
         R2 = dayClose + (range * 1.1 / 6.0);
         R3 = dayClose + (range * 1.1 / 4.0);
         R4 = dayClose + (range * 1.1 / 2.0);
         S1 = dayClose - (range * 1.1 / 12.0);
         S2 = dayClose - (range * 1.1 / 6.0);
         S3 = dayClose - (range * 1.1 / 4.0);
         S4 = dayClose - (range * 1.1 / 2.0);
         P  = (R1 + S1) / 2.0;
         ExtFormulaName = "Camarilla";
         break;

      case Woodie:
         // Woodie uses weighting on Close: (H + L + 2 * C) / 4
         P = (dayHigh + dayLow + (2 * dayClose)) / 4.0;
         R1 = (2 * P) - dayLow;
         R2 = P + range;
         R3 = dayHigh + 2 * (P - dayLow); 
         R4 = R3 + range;
         S1 = (2 * P) - dayHigh;
         S2 = P - range;
         S3 = dayLow - 2 * (dayHigh - P);
         S4 = S3 - range;
         ExtFormulaName = "Woodie";
         break;

      case DeMark:
         {
         double x;
         if(dayClose < dayOpen) x = dayHigh + (2 * dayLow) + dayClose;
         else if(dayClose > dayOpen) x = (2 * dayHigh) + dayLow + dayClose;
         else x = dayHigh + dayLow + (2 * dayClose);
         
         P = x / 4.0;
         R1 = x / 2.0 - dayLow;
         S1 = x / 2.0 - dayHigh;
         // DeMark only has 1 level typically, zeroing others
         R2=0; R3=0; R4=0;
         S2=0; S3=0; S4=0;
         ExtFormulaName = "DeMark";
         }
         break;
     }
     
   return(true);
  }

//+------------------------------------------------------------------+
//| Update Visual Objects                                            |
//+------------------------------------------------------------------+
void UpdateVisuals()
  {
   // Draw Pivot
   DrawLevel("Pvt", "Pivot", InpPColor, P);

   if(InpShowSR)
     {
      DrawLevel("R1", "Res 1", InpRColor, R1);
      DrawLevel("R2", "Res 2", InpRColor, R2);
      DrawLevel("R3", "Res 3", InpRColor, R3);
      DrawLevel("R4", "Res 4", InpRColor, R4);

      DrawLevel("S1", "Sup 1", InpSColor, S1);
      DrawLevel("S2", "Sup 2", InpSColor, S2);
      DrawLevel("S3", "Sup 3", InpSColor, S3);
      DrawLevel("S4", "Sup 4", InpSColor, S4);
     }
     
   // Info Label -> Converted to Comment
   Comment("Pivot Formula: ", ExtFormulaName);
   
   // Cleanup potential old label object if it exists (for seamless update)
   string infoName = INAME + "_Info";
   if(ObjectFind(0, infoName) >= 0) ObjectDelete(0, infoName);
  }

//+------------------------------------------------------------------+
//| Helper: Draw Level (Line + Label)                                |
//+------------------------------------------------------------------+
void DrawLevel(string suffix, string title, color clr, double price)
  {
   if(price <= 0) return;

   string lineName  = INAME + "_" + suffix;
   string labelName = INAME + "_Txt_" + suffix;
   
   // DateTime for Label positioning
   // Using a small offset (1 bar) ensures visibility even at high zoom
   datetime tEnd = Time[0] + PeriodSeconds();
   
   //--- 1. Manage Line (Simplified to HLINE)
   if(ObjectFind(0, lineName) < 0)
     {
      ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, InpStyle);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, InpWidth);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true); // Put lines behind price
      ObjectSetString(0, lineName, OBJPROP_TOOLTIP, title + " " + DoubleToString(price, _Digits));
     }
   else
     {
      // Move Anchor Points (Only Price needed for HLINE)
      ObjectMove(0, lineName, 0, 0, price);
     }

   //--- 2. Manage Label
   if(ObjectFind(0, labelName) < 0)
     {
      ObjectCreate(0, labelName, OBJ_TEXT, 0, tEnd, price);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, InpLabelColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, InpLabelSize);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
     }
   else
     {
      // Keep label just after current time or at start? 
      // User asked for "Above the line aligned with label". Standard place is right side.
      // Let's stick to the right side of the chart relative to time[0].
      ObjectMove(0, labelName, 0, Time[0] + PeriodSeconds()*2, price);
     }
   
   string priceStr = DoubleToString(price, _Digits);
   // Format: "Res 1   @ 1.23456" for clear separation
   ObjectSetString(0, labelName, OBJPROP_TEXT, title + "   @ " + priceStr);
  }

//+------------------------------------------------------------------+
//| Check Alerts                                                     |
//+------------------------------------------------------------------+
void CheckAlerts()
  {
   if(!InpUseAlert && !InpUseEmail && !InpUsePush) return;

   double H = High[0];
   double L = Low[0];
   
   // Helper Macro for checking touch with Index tracking for debounce
   // 0=Pivot, 1-4=R, 5-8=S
   CheckTouch(H, L, P, "Pivot", 0);
   
   CheckTouch(H, L, R1, "Resistance 1", 1);
   CheckTouch(H, L, R2, "Resistance 2", 2);
   CheckTouch(H, L, R3, "Resistance 3", 3);
   CheckTouch(H, L, R4, "Resistance 4", 4);
   
   CheckTouch(H, L, S1, "Support 1", 5);
   CheckTouch(H, L, S2, "Support 2", 6);
   CheckTouch(H, L, S3, "Support 3", 7);
   CheckTouch(H, L, S4, "Support 4", 8);
  }

void CheckTouch(double h, double l, double level, string levelName, int idx)
  {
   if(level <= 0) return;
   
   // If already alerted for this level on this bar, return
   if(ExtAlerted[idx]) return;
   
   if(l <= level && h >= level)
     {
      ExtAlerted[idx] = true; // Mark as alerted
      
      string msg = INAME + ": Touched " + levelName + " @" + DoubleToString(level, _Digits);
      if(InpUseAlert) Alert(msg);
      if(InpUsePush)  SendNotification(msg);
      if(InpUseEmail) SendMail(INAME + " Alert", msg);
     }
  }
