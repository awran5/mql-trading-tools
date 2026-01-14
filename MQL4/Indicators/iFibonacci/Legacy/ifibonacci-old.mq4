//+------------------------------------------------------------------+
//|                                                   iFibonacci.mq4 |
//|                                        Copyright © 2015, Awran5. |
//|                                                 awran5@yahoo.com |
//|      Credit:                                                     |
//|       JimDandy: http://www.jimdandyforex.com                     |
//|       WHRoeder: https://www.mql5.com/en/users/WHRoeder           |
//|       RaptorUK: https://www.mql5.com/en/users/RaptorUK           |
//|       deVries : https://www.mql5.com/en/users/deVries            |                
//+------------------------------------------------------------------+
#property copyright   "Copyright © 2015, Awran5."
#property link        "awran5@yahoo.com"
#property version     "1.01"
#property description "This indicator will Draw Fibonacci Tools e.g. Retracement, Arc, Fan, Expansion, TimeZones. Based on zigzag indicator.\n"
#property description "Credit: \n      JimDandy, \n      WHRoeder, \n      RaptorUK, \n      deVries"
#property strict
#property indicator_chart_window

// Retrieves the coordinates of a window's client area, Used for Fibo Arc scale
#import "user32.dll"
int GetClientRect(int hWnd,int &lpRect[]);
#import
//---
enum ArcScale
  {
   Math,       // MathAbs
   ClientRect, // ClientRect
   Manual      // Set Manually
  };
//|--------------------------------------------------------------------------------------------------------------------|
//|                           E X T E R N A L   V A R I A B L E S                                                      |
//|--------------------------------------------------------------------------------------------------------------------|
//---------------------------------------------------------------------------------------------------------------------
input string  lb_0                     = "";                // ----------  Z I G Z A G   S E T T I N G  
extern int    ExtDepth                 = 24;                // ZigZag Depth
extern int    ExtDeviation             = 5;                 // ZigZag Deviation
extern int    ExtBackstep              = 3;                 // ZigZag Backstep
extern int    MaxBars                  = 500;               // Maximum Bars 
extern ENUM_TIMEFRAMES FixedPeriod     = 0;                 // Time Frame to use
//---------------------------------------------------------------------------------------------------------------------
input string  lb_1                     = "";                // --------------------------------------------------------    
input string  lb_2                     = "";                // ----------  F I B O   R E T R A C E M E N T  
extern bool   ShowRetracement          = true;              // Show Retracement
extern ENUM_LINE_STYLE rStyle          = 0;                 // Levels Style
extern color  rColor                   = clrGold;           // Levels Color
extern int    rWidth                   = 1;                 // Levels Width
extern double l0                       = 0.0;               // Level 0
extern double l38                      = 0.382;             // Level 38.2
extern double l50                      = 0.5;               // Level 50  
extern double l61                      = 0.618;             // Level 61.8
extern double l100                     = 1.0;               // Level 100
extern bool   ExtraLevels              = false;             // Extra levels: 14.6, 23.6, 76.4, 88.6, 127.2
extern double l14                      = 0.146;             // Level 14.6
extern double l23                      = 0.236;             // Level 23.6
extern double l74                      = 0.764;             // Level 76.4
extern double l88                      = 0.886;             // Level 88.6
extern double l127                     = 1.272;             // Level 127.2
extern bool   LevelPrice               = false;             // Show Prices
//---------------------------------------------------------------------------------------------------------------------
input string  lb_3                     = "";                // --------------------------------------------------------
input string  lb_4                     = "";                // ----------  F I B O   A R C  
extern bool   ShowArc                  = false;             // Show Arc
extern ArcScale ScaleMethod            = Math;              // Scalling Method
input string  info="If ClientRect, you must allow DLL imports first"; // ----------  NOTE!
extern double ManualScale              = 0;                 // Manual Scale value
extern color  aColor                   = clrTomato;         // Arc Color
extern ENUM_LINE_STYLE aStyle          = 0;                 // Arc Style
extern int    aWidth                   = 1;                 // Arc Width
extern double ARC38                    = 0.382;             // Level 38.2
extern double ARC50                    = 0.500;             // Level 50  
extern double ARC61                    = 0.618;             // Level 61.8
extern bool   ExtraARC                 = false;             // Show extra levels: 14.6, 23.6, 76.4
extern double ARC14                    = 0.146;             // Level 14.6
extern double ARC23                    = 0.236;             // Level 23.6
extern double ARC74                    = 0.764;             // Level 76.4
//---------------------------------------------------------------------------------------------------------------------
input string  lb_5                     = "";                // --------------------------------------------------------
input string  lb_6                     = "";                // ----------  F I B O   F A N  
extern bool   ShowFan                  = true;              // Show Fan
extern color  fColor                   = clrGold;           // Fan Color
extern ENUM_LINE_STYLE fStyle          = 2;                 // Fan Style
extern int    fWidth                   = 1;                 // Fan Width
extern double FAN38                    = 0.382;             // Level 38.2
extern double FAN50                    = 0.5;               // Level 50  
extern double FAN61                    = 0.618;             // Level 61.8
extern bool   ExtraFAN                 = false;             // Show extra levels: 14.6, 23.6, 76.4
extern double FAN14                    = 0.146;             // Level 14.6
extern double FAN23                    = 0.236;             // Level 23.6
extern double FAN74                    = 0.764;             // Level 76.4
//---------------------------------------------------------------------------------------------------------------------
input string  lb_7                     = "";                // --------------------------------------------------------
input string  lb_8                     = "";                // ----------  F I B O   T I M E Z O N E S  
extern bool   ShowZone                 = true;              // Show Time Zones 
extern color  zColor                   = clrDarkGoldenrod;  // Time Color
extern ENUM_LINE_STYLE zStyle          = 2;                 // Time Style
extern int    zWidth                   = 1;                 // Time Width
extern double Zone0                    = 0;                 // Level 0
extern double Zone1                    = 1;                 // Level 100
extern double Zone2                    = 2;                 // Level 200
extern double Zone3                    = 3;                 // Level 300
extern double Zone5                    = 5;                 // Level 500
extern double Zone8                    = 8;                 // Level 800
extern double Zone13                   = 13;                // Level 1300
extern double Zone21                   = 21;                // Level 2100
extern double Zone34                   = 34;                // Level 3400
//---------------------------------------------------------------------------------------------------------------------
input string  lb_9                     = "";                // --------------------------------------------------------
input string  lb_10                    = "";                // ----------  F I B O   E X P A N S I O N  
extern bool   ShowExpansion            = false;             // Show Expansion
extern color  eColor                   = clrBlue;           // Expansion Color
extern ENUM_LINE_STYLE eStyle          = 0;                 // Expansion Style
extern int    eWidth                   = 2;                 // Expansion Width
extern double EXP61                    = 0.618;             // Level 61.8 
extern double EXP100                   = 1;                 // Level 100
extern double EXP161                   = 1.618;             // Level 161.8
extern double EXP261                   = 2.618;             // Level 261.8
extern bool   ExtraEXP                 = false;             // Show extra levels: 78.66, 138.2, 200
extern double EXP78                    = 0.786;             // Level 78.6
extern double EXP138                   = 1.382;             // Level 138.2
extern double EXP200                   = 2;                 // Level 200
//---------------------------------------------------------------------------------------------------------------------
input string  lb_13                    = "";                // --------------------------------------------------------
input string  lb_14                    = "";                // ----------  D R A W   P A T T E R N
extern bool   ShowPattern              = false;             // Show Pattern
extern color  pColor                   = clrFireBrick;      // Pattern Color
//---------------------------------------------------------------------------------------------------------------------
input string  lb_15                    = "";                // --------------------------------------------------------
input string  lb_16                    = "";                // ----------  D A I L Y   H I G H / L O W
extern bool   ShowDaily                = true;              // Show Daily High/Low
extern color  DayColor                 = clrPurple;         // Daily High/Low Color 
extern color  DayWidth                 = 1;                 // Daily High/Low Width
extern ENUM_LINE_STYLE DayStyle        = 0;                 // Daily High/Low Style
extern bool   ShowPivot                = true;              // Show Daily Pivot
extern color  PivotColor               = clrLightGray;      // Pivot Line Color
extern color  PivotWidth               = 1;                 // Pivot Line Width
extern ENUM_LINE_STYLE PivotStyle      = 0;                 // Pivot Line Style    
input string  lb_17                    = "";                // --------------------------------------------------------
input string  lb_18                    = "";                // ----------  W E E K L Y   H I G H / L O W  
extern bool   ShowWeekly               = true;              // Show Weekly High/Low 
extern color  WeekColor                = clrDarkBlue;       // Weekly Lines Color
extern color  WeekWidth                = 1;                 // Weekly Lines Width
extern ENUM_LINE_STYLE WeekStyle       = 0;                 // Weekly Lines Style    
input string  lb_19                    = "";                // --------------------------------------------------------
input string  lb_20                    = "";                // ----------  M O N T H L Y   H I G H / L O W  
extern bool   ShowMonthly              = false;             // Show Monthly High/Low
extern color  MonthColor               = clrFireBrick;      // Monthly Lines Color
extern color  MonthWidth               = 1;                 // Monthly Lines Width
extern ENUM_LINE_STYLE MonthStyle      = 0;                 // Monthly Lines Style        
input string  lb_21                    = "";                // --------------------------------------------------------
input string  lb_22                    = "";                // ----------  C A N D L E    T I M E
extern bool   ShowCanldeTime           = true;              // Show Candle Time
extern color  TimerColor               = clrYellow;         // Time Left Color
extern int    TimerFontSize            = 7;                 // Time Left Font Size
                                                            //|--------------------------------------------------------------------------------------------------------------------|
//|                           I N T E R N A L   V A R I A B L E S                                                      |
//|--------------------------------------------------------------------------------------------------------------------|
//---
double   zValue[5];  // zigzag swings value. zValue[1] = swing 1, and so on.
datetime zTime[5];   // Time for zigzag swings value
//---
int rect[4];         // defines the coordinates of window.
int hwnd;            // A handle to the window whose client coordinates are to be retrieved. 
int gPixels,vPixels;
//---
double DayLow,DayHigh,DayClose,DayPivot,WeekLow,WeekHigh,MonthLow,MonthHigh;
//----
string Tools[8]  = {"Fibo Retracement", "Fibo Arc", "Fibo Fan", "Fibo TimeZones", "Fibo Expansion", "Pattern1", "Pattern2", "Candle Time"},
Names[7]  = {"Yesterday High", "Yesterday Low", "Weekly High", "Weekly Low", "Monthly High", "Monthly Low", "Pivot"},
Labels[7] = {"YH","YL","WH","WL","MH", "ML", "PVT"}, space = "       ";
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   if(!IsDllsAllowed())
     {
      Print("One of Fibo ARC Methods is requires DLL, Remember to allow DLL imports if you like to use it.");
      return(INIT_SUCCEEDED);
     }
//---
   hwnd=WindowHandle(Symbol(),Period());
   if(hwnd>0)
     {
      GetClientRect(hwnd,rect);
      gPixels = rect[2];
      vPixels = rect[3];
     }
//---- force daily data load
   iBars(NULL,PERIOD_D1);
//---- indicator short name
   IndicatorShortName("iFibonacci");
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   for(int i=0; i<9; i++)
     {
      if(ObjectFind(0,Tools[i])        >=0) ObjectDelete(Tools[i]);
      if(ObjectFind(0,Names[i])        >=0) ObjectDelete(Names[i]);
      if(ObjectFind(0,space+Labels[i]) >=0) ObjectDelete(space+Labels[i]);
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
//---
   int limit,counted_bars=prev_calculated;
   if(counted_bars < 0) return(rates_total);
   if(counted_bars>0) counted_bars--;
   limit=rates_total-counted_bars;
   if(limit>MaxBars) limit=MaxBars;
//----      
   int n=0;
// ZigZag
   for(int i=0; i<limit; i++)
     {
      double zz=iCustom(NULL,FixedPeriod,"ZigZag",ExtDepth,ExtDeviation,ExtBackstep,0,i);
      if(zz!=0 && zz!=EMPTY_VALUE)
        {
         zValue[n] = zz;
         zTime[n]  = iTime(NULL, FixedPeriod, i);
         n++;
         if(n>=5) break;
        }
      if(FixedPeriod==0) FixedPeriod=(ENUM_TIMEFRAMES)Period();
     }
//----
   FibonacciTools();
//+------------------------------------------------------------------+
// Pivot, High, Low     
   for(int i=limit -1; i>=0; i--)
     {
      int iYesterday=i+1;
      datetime yesterday=iTime(NULL,PERIOD_D1,iYesterday);
      if(TimeDayOfWeek(yesterday)==0) iYesterday++; // Data from Friday not Sunday
      //--- daily
      DayHigh  = iHigh (NULL, PERIOD_D1, iYesterday);
      DayLow   = iLow  (NULL, PERIOD_D1, iYesterday);
      DayClose = iClose(NULL, PERIOD_D1, iYesterday);
      DayPivot=(DayHigh+DayLow+DayClose)/3;
      //--- weekly
      WeekHigh   = iHigh(NULL, PERIOD_W1, iYesterday);
      WeekLow    = iLow(NULL, PERIOD_W1, iYesterday);
      //--- monthly
      MonthHigh  = iHigh(NULL, PERIOD_MN1, iYesterday);
      MonthLow   = iLow(NULL, PERIOD_MN1, iYesterday);
     }
//----
   HighAndLow();
//+------------------------------------------------------------------+
   if(ShowCanldeTime) CandleTimeLeft();

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//|--------------------------------------------------------------------------------------------------------------------|
//|                           I N T E R N A L   F U N C T I O N S                                                      |
//|--------------------------------------------------------------------------------------------------------------------|
//+------------------------------------------------------------------+
//|  Fibonacci Tools
//+------------------------------------------------------------------+
void FibonacciTools()
  {
//---
   if(ShowRetracement)
     {
      DrawRetracement(Tools[0],"FR ",rColor,rWidth,rStyle,zTime[1],zValue[1],zTime[0],zValue[0]);
     }
   if(ShowArc)
     {
      DrawArc(Tools[1],"FA",aColor,aWidth,aStyle,zTime[1],zValue[1],zTime[0],zValue[0]);
     }
   if(ShowFan)
     {
      DrawFan(Tools[2],"FF ",fColor,fWidth,fStyle,zTime[1],zValue[1],zTime[0],zValue[0]);
     }
   if(ShowZone)
     {
      DrawZone(Tools[3],"FZ ",zColor,zWidth,zStyle,zTime[1],zValue[1],zTime[0],zValue[0]);
     }
   if(ShowExpansion)
     {
      DrawExpansion(Tools[4],"FE ",eColor,eWidth,eStyle,zTime[3],zValue[3],zTime[2],zValue[2],zTime[1],zValue[1]);
     }
   if(ShowPattern)
     {
      ObjectDelete(Tools[5]);
      ObjectCreate(Tools[5],OBJ_TRIANGLE,0,zTime[4],zValue[4],zTime[3],zValue[3],zTime[2],zValue[2]);
      ObjectSet(Tools[5],OBJPROP_COLOR,pColor);
      //---
      ObjectDelete(Tools[6]);
      ObjectCreate(Tools[6],OBJ_TRIANGLE,0,zTime[2],zValue[2],zTime[1],zValue[1],zTime[0],zValue[0]);
      ObjectSet(Tools[6],OBJPROP_COLOR,pColor);
     }
  }
//+------------------------------------------------------------------+
//|  Daily, Weekly, Monthly high and low lines
//+------------------------------------------------------------------+
void HighAndLow()
  {
//---
   if(ShowDaily && Period()<1440)
     {
      DrawTrend(Names[0],space+Labels[0],DayStyle,DayColor,DayWidth,DayHigh);
      DrawTrend(Names[1],space+Labels[1],DayStyle,DayColor,DayWidth,DayLow);
      if(ShowPivot) DrawTrend(Names[6],space+Labels[6],PivotStyle,PivotColor,PivotWidth,DayPivot);
     }
   if(ShowWeekly && Period()<10080)
     {
      DrawTrend(Names[2],space+Labels[2],WeekStyle,WeekColor,WeekWidth,WeekHigh);
      DrawTrend(Names[3],space+Labels[3],WeekStyle,WeekColor,WeekWidth,WeekLow);
      if(WeekLow==DayLow) WeekLow=WeekLow-Time[0]+Period()*50;
      if(WeekHigh==DayHigh) WeekHigh=WeekHigh+Time[0]+Period()*50;
     }
   if(ShowMonthly && Period()<43200)
     {
      DrawTrend(Names[4],space+Labels[4],MonthStyle,MonthColor,MonthWidth,MonthHigh);
      DrawTrend(Names[5],space+Labels[5],MonthStyle,MonthColor,MonthWidth,MonthLow);
      if(MonthLow  == DayLow)  MonthLow  = MonthLow  - Time[0] + Period() * 50;
      if(MonthHigh == DayHigh) MonthHigh = MonthHigh + Time[0] + Period() * 50;
     }
//---
  }
//+------------------------------------------------------------------+
//|  1- Draw Retracement
//+------------------------------------------------------------------+
void DrawRetracement(string name,string label,color clr,int width,int style,datetime t1,double p1,datetime t2,double p2)
  {
//--- 
   ObjectDelete(name);
   ObjectCreate(name,OBJ_FIBO,0,t1,p1,t2,p2);
   if(ExtraLevels) ObjectSet(name,OBJPROP_FIBOLEVELS,10);
   else ObjectSet(name,OBJPROP_FIBOLEVELS,5);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+0,l0);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+1,l38);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+2,l50);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+3,l61);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+4,l100);
//--- Extra
   ObjectSet(name,OBJPROP_FIRSTLEVEL+5,l14);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+6,l23);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+7,l74);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+8,l88);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+9,l127);
//---
   ObjectSet(name,OBJPROP_LEVELCOLOR,clr);
   ObjectSet(name,OBJPROP_LEVELWIDTH,width);
   ObjectSet(name,OBJPROP_LEVELSTYLE,style);
   ObjectSet(name,OBJPROP_COLOR,clr);
//---
   string prices="";
   if(LevelPrice) prices=" --> %$  ";
   ObjectSetFiboDescription(name,0,label+"  "+DoubleToStr(l0  *100,1)+"  "+prices);
   ObjectSetFiboDescription(name,1,label+"  "+DoubleToStr(l38 *100,1)+"  "+prices);
   ObjectSetFiboDescription(name,2,label+"  "+DoubleToStr(l50 *100,1)+"  "+prices);
   ObjectSetFiboDescription(name,3,label+"  "+DoubleToStr(l61 *100,1)+"  "+prices);
   ObjectSetFiboDescription(name,4,label+"  "+DoubleToStr(l100*100,1)+"  "+prices);
//--- Extra
   ObjectSetFiboDescription(name,5,label+"  "+DoubleToStr(l14 *100,1)+"  "+prices);
   ObjectSetFiboDescription(name,6,label+"  "+DoubleToStr(l23 *100,1)+"  "+prices);
   ObjectSetFiboDescription(name,7,label+"  "+DoubleToStr(l74 *100,1)+"  "+prices);
   ObjectSetFiboDescription(name,8,label+"  "+DoubleToStr(l88 *100,1)+"  "+prices);
   ObjectSetFiboDescription(name,9,label+"  "+DoubleToStr(l127*100,1)+"  "+prices);
//---     
  }
//+------------------------------------------------------------------+
//|  2- Draw Fibonacci Arc
//+------------------------------------------------------------------+
void DrawArc(string name,string label,color clr,int width,int style,datetime t1,double p1,datetime t2,double p2)
  {
//---
   ObjectDelete(name);
   ObjectCreate(name,OBJ_FIBOARC,0,t1,p1,t2,p2);
   if(ExtraARC) ObjectSet(name,OBJPROP_FIBOLEVELS,6);
   else ObjectSet(name,OBJPROP_FIBOLEVELS,3);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+0,ARC38);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+1,ARC50);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+2,ARC61);
//--- Extra
   ObjectSet(name,OBJPROP_FIRSTLEVEL+3,ARC14);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+4,ARC23);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+5,ARC74);
//---
   ObjectSet(name,OBJPROP_LEVELCOLOR,clr);
   ObjectSet(name,OBJPROP_LEVELWIDTH,width);
   ObjectSet(name,OBJPROP_LEVELSTYLE,style);
   ObjectSet(name,OBJPROP_COLOR,clr);
   ObjectSet(name,OBJPROP_ELLIPSE,false);
   ObjectSet(name,OBJPROP_SCALE,FibArcScale());
//--- 
   ObjectSetFiboDescription(name,0,label+"  "+DoubleToStr(ARC38*100,1));
   ObjectSetFiboDescription(name,1,label+"  "+DoubleToStr(ARC50*100,1));
   ObjectSetFiboDescription(name,2,label+"  "+DoubleToStr(ARC61*100,1));
//--- Extra
   ObjectSetFiboDescription(name,3,label+"  "+DoubleToStr(ARC14*100,1));
   ObjectSetFiboDescription(name,4,label+"  "+DoubleToStr(ARC23*100,1));
   ObjectSetFiboDescription(name,5,label+"  "+DoubleToStr(ARC74*100,1));
//---
  }
//+------------------------------------------------------------------+
//|  3- Draw Fibonacci Fan
//+------------------------------------------------------------------+
void DrawFan(string name,string label,color clr,int width,int style,datetime t1,double p1,datetime t2,double p2)
  {
//---
   ObjectDelete(name);
   ObjectCreate(name,OBJ_FIBOFAN,0,t1,p1,t2,p2);
   if(ExtraFAN) ObjectSet(name,OBJPROP_FIBOLEVELS,6);
   else ObjectSet(name,OBJPROP_FIBOLEVELS,3);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+0,FAN38);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+1,FAN50);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+2,FAN61);
//--- Extra
   ObjectSet(name,OBJPROP_FIRSTLEVEL+3,FAN14);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+4,FAN23);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+5,FAN74);
//---
   ObjectSet(name,OBJPROP_LEVELCOLOR,clr);
   ObjectSet(name,OBJPROP_LEVELWIDTH,width);
   ObjectSet(name,OBJPROP_LEVELSTYLE,style);
   ObjectSet(name,OBJPROP_COLOR,clr);
//--- 
   ObjectSetFiboDescription(name,0,label+"  "+DoubleToStr(FAN38*100,1));
   ObjectSetFiboDescription(name,1,label+"  "+DoubleToStr(FAN50*100,1));
   ObjectSetFiboDescription(name,2,label+"  "+DoubleToStr(FAN61*100,1));
//--- Extra
   ObjectSetFiboDescription(name,3,label+"  "+DoubleToStr(FAN14*100,1));
   ObjectSetFiboDescription(name,4,label+"  "+DoubleToStr(FAN23*100,1));
   ObjectSetFiboDescription(name,5,label+"  "+DoubleToStr(FAN74*100,1));
//---
  }
//+------------------------------------------------------------------+
//|  4- Draw Fibonacci Time Zones
//+------------------------------------------------------------------+
void DrawZone(string name,string label,color clr,int width,int style,datetime t1,double p1,datetime t2,double p2)
  {
//---
   ObjectDelete(name);
   ObjectCreate(name,OBJ_FIBOTIMES,0,t1,p1,t2,p2);
   ObjectSet(name,OBJPROP_FIBOLEVELS,9);
// 1, 2, 3, 5, 8, 13, 21, 34
   ObjectSet(name,OBJPROP_FIRSTLEVEL+0,Zone0);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+1,Zone1);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+2,Zone2);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+3,Zone3);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+4,Zone5);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+5,Zone8);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+6,Zone13);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+7,Zone21);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+8,Zone34);
//---
   ObjectSet(name,OBJPROP_LEVELCOLOR,clr);
   ObjectSet(name,OBJPROP_LEVELWIDTH,width);
   ObjectSet(name,OBJPROP_LEVELSTYLE,style);
   ObjectSet(name,OBJPROP_COLOR,clr);
//---
   ObjectSetFiboDescription(name,0,label+"  "+DoubleToStr(Zone0 *100,1));
   ObjectSetFiboDescription(name,1,label+"  "+DoubleToStr(Zone1 *100,1));
   ObjectSetFiboDescription(name,2,label+"  "+DoubleToStr(Zone2 *100,1));
   ObjectSetFiboDescription(name,3,label+"  "+DoubleToStr(Zone3 *100,1));
   ObjectSetFiboDescription(name,4,label+"  "+DoubleToStr(Zone5 *100,1));
   ObjectSetFiboDescription(name,5,label+"  "+DoubleToStr(Zone8 *100,1));
   ObjectSetFiboDescription(name,6,label+"  "+DoubleToStr(Zone13*100,1));
   ObjectSetFiboDescription(name,7,label+"  "+DoubleToStr(Zone21*100,1));
   ObjectSetFiboDescription(name,8,label+"  "+DoubleToStr(Zone34*100,1));
//---
  }
//+------------------------------------------------------------------+
//|  5- Draw Fibonacci Expansion     
//+------------------------------------------------------------------+
void DrawExpansion(string name,string label,color clr,int width,int style,datetime t1,double p1,datetime t2,double p2,datetime t3,double p3)
  {
//---
   ObjectDelete(name);
   ObjectCreate(name,OBJ_EXPANSION,0,t1,p1,t2,p2,t3,p3);
   ObjectSet(name,OBJPROP_FIBOLEVELS,7);
   if(ExtraEXP) ObjectSet(name,OBJPROP_FIBOLEVELS,7);
   else ObjectSet(name,OBJPROP_FIBOLEVELS,4);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+0,EXP61);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+1,EXP100);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+2,EXP161);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+3,EXP261);
//---Extra
   ObjectSet(name,OBJPROP_FIRSTLEVEL+4,EXP78);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+5,EXP138);
   ObjectSet(name,OBJPROP_FIRSTLEVEL+6,EXP200);
//---
   ObjectSet(name,OBJPROP_LEVELCOLOR,clr);
   ObjectSet(name,OBJPROP_LEVELWIDTH,width);
   ObjectSet(name,OBJPROP_LEVELSTYLE,style);
   ObjectSet(name,OBJPROP_COLOR,clr);
//---
   ObjectSetFiboDescription(name,0,label+"  "+DoubleToStr(EXP61 *100,1)+"  ");
   ObjectSetFiboDescription(name,1,label+"  "+DoubleToStr(EXP100*100,1)+"  ");
   ObjectSetFiboDescription(name,2,label+"  "+DoubleToStr(EXP161*100,1)+"  ");
   ObjectSetFiboDescription(name,3,label+"  "+DoubleToStr(EXP261*100,1)+"  ");
//---Extra
   ObjectSetFiboDescription(name,4,label+"  "+DoubleToStr(EXP78 *100,1)+"  ");
   ObjectSetFiboDescription(name,5,label+"  "+DoubleToStr(EXP138*100,1)+"  ");
   ObjectSetFiboDescription(name,6,label+"  "+DoubleToStr(EXP200*100,1)+"  ");
//---
  }
//+------------------------------------------------------------------+
//|  Draw High/Low lines
//+------------------------------------------------------------------+
void DrawTrend(string name,string label,int style,color clr,int width,double price)
  {
//--- 
   datetime startline = iTime(NULL, 1440, 0) - 3600;
   datetime stopline  = iTime(NULL, 240, 0) + 43200;
//---
   ObjectDelete(name);
   ObjectCreate(name,OBJ_TREND,0,startline,price,stopline,price);
   ObjectSet(name,OBJPROP_COLOR,clr);
   ObjectSet(name,OBJPROP_STYLE,style);
   ObjectSet(name,OBJPROP_WIDTH,width);
   ObjectSet(name,OBJPROP_RAY,false);
   if(ObjectFind(label)!=0)
     {
      ObjectDelete(label);
      ObjectCreate(label,OBJ_TEXT,0,startline,price,stopline,price);
      ObjectSetText(label,label,7,"Verdana",clrDarkGray);
     }
   else
     {
      ObjectMove(label,0,startline,price);
     }
//---     
  }
//+------------------------------------------------------------------+
//|  determine Scale for Fibo Arc 
//+------------------------------------------------------------------+
double FibArcScale()
  {
//---
//--- Scale Calculation
   double AutoScale=0;
//---
   if(ScaleMethod==ClientRect)
     {
      double chartScale = 0.0;
      double priceRange = fabs(WindowPriceMax() - WindowPriceMin()) / Point;
      int barsCount=WindowBarsPerChart();
      chartScale=(priceRange)/barsCount;
      if(!IsDllsAllowed())
        {
         Alert("DLL imports is not allowed! Please Allow DLL imports in Common tab of indicator properties and try again.");
         return(0);
        }
      AutoScale=chartScale*gPixels/vPixels;
     }
   else if(ScaleMethod==Math)
     {
      double ScaleValue = fabs(zValue[2] - zValue[1]) / Point,
      ScaleTime  = iBarShift(Symbol(), Period(), zTime[2]) - iBarShift(Symbol(), Period(), zTime[1]);
      AutoScale=ScaleValue/ScaleTime;
     }
   else if(ScaleMethod==Manual && ManualScale>0) AutoScale=ManualScale;

   return(AutoScale);
//---
  }
//+------------------------------------------------------------------+
//| Show Candle Time Left  
//+------------------------------------------------------------------+
void CandleTimeLeft()
  {
//---
   string TimeLeft;
   int offset;
   TimeLeft=TimeToStr(Time[0]+Period()*60-TimeCurrent(),TIME_MINUTES|TIME_SECONDS);
   offset=Period()*200;
   ObjectDelete(Tools[7]);
   ObjectCreate(Tools[7],OBJ_TEXT,0,Time[0]+offset,Close[0]);
   ObjectSetText(Tools[7],TimeLeft,TimerFontSize,"Calibri",TimerColor);
//---
  }
//|--------------------------------------------------------------------------------------------------------------------|
//|                                                      E N D                                                         |
//|--------------------------------------------------------------------------------------------------------------------|
