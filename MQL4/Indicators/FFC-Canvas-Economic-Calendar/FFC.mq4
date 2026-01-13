//+------------------------------------------------------------------+
//|                                                          FFC.mq4 |
//|                      Canvas Economic Calendar v2.0                 |
//+------------------------------------------------------------------+
//|                                                                   |
//| ORIGINAL CONTRIBUTORS (v1.0):                                     |
//|   Copyright © 2006-2016 DerkWehler, traderathome, deVries,        |
//|   qFish, atstrader, awran5                                        |
//|                                                                   |
//| ACKNOWLEDGEMENTS:                                                 |
//|   derkwehler - Core FFCal indicator (2006)                        |
//|   deVries    - MT4 Build 600+ compatibility                       |
//|   qFish      - Testing and improvements                           |
//|   atstrader  - Active pair filtering                              |
//|   traderathome - Coordination and integration                     |
//|   awran5     - v1.0 major modifications (2016)                    |
//|                                                                   |
//| v2.0 REWRITE (2025):                                              |
//|   awran5     - Complete Canvas-based UI rewrite                   |
//|                                                                   |
//+------------------------------------------------------------------+
/*
WHAT'S NEW IN v2.0:

  [UI]
  - Canvas-based rendering (smooth, flicker-free)
  - Draggable panel with saved position
  - Real-time filter buttons (H/M/L impact toggles)
  - Modern dark theme with gradient background
  
  [FEATURES]  
  - Symbol Info display (Spread, RSI, Bar countdown, Daily %)
  - Historical event markers on past candles
  - Improved vertical event lines
  - Event countdown with smart formatting (days/hours/minutes)
  
  [DATA]
  - JSON API (replaces XML) for faster parsing
  - Smart caching with auto-refresh
  - Week boundary detection (auto-refresh on new week)
  
  [PRODUCTION]
  - Input validation with safe bounds
  - Timeout protection for parsing
  - Object pooling for performance
  - Proper cleanup on removal

  Based on FFCal indicator: http://www.forexfactory.com/showthread.php?t=114792
  v2.0 source code: https://github.com/awran5/mql-trading-tools
*/
#property copyright "Copyright © 2006-2025, DerkWehler, traderathome, deVries, qFish, atstrader, awran5"
#property link      "https://www.mql5.com/en/code/15931"
#property description "FFC v2.0 - Canvas Economic Calendar"
#property description "Canvas-based UI with JSON API"
#property version   "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define INDICATOR_NAME        "FFC"
#define INDICATOR_VERSION     "2.0"
#define INDICATOR_PREFIX      "FFC_"
#define JSON_URL              "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
#define MAX_EVENTS            100
#define DISPLAY_EVENTS        8
#define CACHE_VALIDITY_SEC    14400
#define CACHE_MAX_AGE_SEC     604800
#define MIN_REQUEST_INTERVAL  60
#define MAX_RETRY_ATTEMPTS    3
#define INITIAL_BACKOFF_SEC   5

// Rendering Constants
#define ROW_HEIGHT            20
#define HEADER_HEIGHT         44
#define PANEL_WIDTH           680
#define PANEL_MARGIN          10
#define COL_DAY_X             10
#define COL_TIME_X            45
#define COL_CCY_X             90
#define COL_IMPACT_X          130
#define COL_EVENT_X           150
#define COL_FCST_X            475
#define COL_PREV_X            545
#define COL_ACT_X             615
#define TITLE_MAX_LEN         34

// Production Limits
#define MAX_JSON_SIZE         10000000
#define JSON_PARSE_TIMEOUT    5000
#define ALERT_COOLDOWN_SEC    300
#define MAX_GRADIENT_HEIGHT   2000
#define MARKER_POOL_SIZE      50
#define MAX_PARSE_DEPTH       10
#define MAX_VLINE_OBJECTS     20
#define MAX_VISIBLE_VLINES    15


//+------------------------------------------------------------------+
//| DLL Import                                                         |
//+------------------------------------------------------------------+
#import "urlmon.dll"
   int URLDownloadToFileW(int pCaller, string szURL, string szFileName, int dwReserved, int lpfnCB);
#import

#import "wininet.dll"
   int DeleteUrlCacheEntryW(string lpszUrlName);
#import

#include <Canvas\Canvas.mqh>

//+------------------------------------------------------------------+
//| Enums and Structures                                              |
//+------------------------------------------------------------------+
enum ENUM_IMPACT_LEVEL {
   IMPACT_HOLIDAY = 0,
   IMPACT_LOW     = 1,
   IMPACT_MEDIUM  = 2,
   IMPACT_HIGH    = 3
};

enum ENUM_CANVAS_STATE {
   CANVAS_UNINITIALIZED,
   CANVAS_INITIALIZING,
   CANVAS_READY,
   CANVAS_FAILED,
   CANVAS_DESTROYED
};

struct CalendarEvent {
   string            title;
   string            country;
   datetime          eventTime;
   ENUM_IMPACT_LEVEL impact;
   string            forecast;
   string            previous;
   string            actual;
   double            forecastNum;
   double            previousNum;
   double            actualNum;
   int               minutesUntil;
   bool              isValid;
};

//+------------------------------------------------------------------+
//| Input Parameters                                                   |
//+------------------------------------------------------------------+
input string   LBL_FILTERS       = "";                // ========== EVENT FILTERS ==========
input bool     ReportActiveOnly  = true;             // - Active chart currencies only
input bool     IncludeHigh       = true;              // - Include HIGH impact
input bool     IncludeMedium     = true;              // - Include MEDIUM impact
input bool     IncludeLow        = true;              // - Include LOW impact
input bool     IncludeSpeaks     = true;              // - Include speeches
input bool     IncludeHolidays   = false;             // - Include holidays
input string   FilterKeyword     = "";                // - Show only events containing
input string   ExcludeKeyword    = "";                // - Hide events containing

input string   LBL_NETWORK       = "";                // ========== NETWORK SETTINGS ==========
input bool     AllowAutoUpdate   = true;              // - Enable auto-update
input int      UpdateIntervalHrs = 4;                 // - Update check interval (hours)
input int      RequestTimeoutMs  = 10000;             // - Request timeout (milliseconds)

input string   LBL_CURRENCIES    = "";                // ========== CURRENCIES ==========
input bool     ReportUSD         = true;              // - USD
input bool     ReportEUR         = true;              // - EUR
input bool     ReportGBP         = true;              // - GBP
input bool     ReportJPY         = true;              // - JPY
input bool     ReportAUD         = true;              // - AUD
input bool     ReportNZD         = true;              // - NZD
input bool     ReportCAD         = true;              // - CAD
input bool     ReportCHF         = true;              // - CHF
input bool     ReportCNY         = false;             // - CNY

input string   LBL_DISPLAY       = "";                // ========== DISPLAY SETTINGS ==========
input bool     ShowPanel         = true;              // - Show event panel
input bool     ShowVerticalLines = true;              // - Show vertical event lines
input bool     ShowSymbolInfo    = true;              // - Show spread/time info
input int      HideAfterMinutes  = 15;                // - Hide event after (minutes)
input int      ChartTimeOffset   = 0;                 // - Chart time offset (hours)

input string   LBL_COLORS        = "";                // ========== COLOR SCHEME ==========
input color    PanelBackground   = C'18,18,24';       // - Panel background
input color    PanelBorder       = C'45,45,60';       // - Panel border
input color    TitleColor        = C'4,88,141';       // - Title/Header Blue
input color    HighImpactColor   = C'229,25,45';      // - High impact
input color    MediumImpactColor = C'247,164,59';     // - Medium impact
input color    LowImpactColor    = C'236,224,49';     // - Low impact
input color    HolidayColor      = C'193,188,188';    // - Holiday
input color    TextColor         = C'240,240,245';    // - Normal text
input color    DimTextColor      = C'165,165,175';    // - Dimmed text
input bool     ShowHistoricalMarkers= true;          // - Map past events on candles
input int      HistoricalLookbackBars= 500;          // - Max bars to search back
input color    PositiveColor     = C'0,230,118';      // - Positive delta
input color    NegativeColor     = C'255,82,82';      // - Negative delta
input color    HighlightColor    = C'40,60,80';       // - Next event highlight

input string   LBL_ALERTS        = "";                // ========== ALERTS ==========
input int      Alert1Minutes     = 30;                // - First alert (minutes before)
input int      Alert2Minutes     = 5;                 // - Second alert (minutes before)
input bool     EnablePopupAlert  = false;             // - Popup alerts
input bool     EnableSoundAlert  = true;              // - Sound alerts
input string   HighImpactSound   = "alert2.wav";      // - High impact sound
input string   MediumImpactSound = "alert.wav";       // - Medium impact sound
input string   LowImpactSound    = "tick.wav";        // - Low impact sound
input bool     EnablePushNotify  = false;             // - Push notifications
input bool     EnableEmailAlert  = false;             // - Email alerts

input string   LBL_ADVANCED      = "";                // ========== ADVANCED ==========
input bool     DeleteCacheOnRemove = false;           // - Delete cache when removed

//+------------------------------------------------------------------+
//| Global Variables - HARDENED WITH STATE GUARDS                     |
//+------------------------------------------------------------------+
CalendarEvent g_events[];
int           g_eventCount = 0;
bool          g_cacheValid = false;
datetime      g_lastUpdate = 0;
datetime      g_lastRequestTime = 0;

int           g_retryCount = 0;
int           g_currentBackoff = INITIAL_BACKOFF_SEC;

string        g_jsonFileName;
string        g_jsonFullPath;

bool          g_firstAlertFired = false;
bool          g_secondAlertFired = false;
datetime      g_lastAlertEventTime = 0;
datetime      g_lastAlertTriggerTime = 0;

string        g_currentSymbol = "";

int           g_chartWidth = 0;
int           g_chartHeight = 0;
datetime      g_lastChartUpdate = 0;
bool          g_chartDimsValid = false;

string        g_filterKeywordLower = "";
string        g_excludeKeywordLower = "";

int           g_panelX = PANEL_MARGIN;
int           g_panelY = 0;
int           g_panelHeight = 0;
int           g_nextEventIndex = -1;
datetime      g_lastRenderTime = 0;
int           g_lastBufferUpdate = 0;

CCanvas              g_canvas;
string               g_canvasName = INDICATOR_PREFIX + "Panel";
int                  g_canvasX = PANEL_MARGIN;
int                  g_canvasY = 100;
ENUM_CANVAS_STATE    g_canvasState = CANVAS_UNINITIALIZED;
bool                 g_renderDirty = true;
bool                 g_isDragging = false;
int                  g_dragMouseX = 0;
int                  g_dragMouseY = 0;
int                  g_dragStartX = 0;
int                  g_dragStartY = 0;

bool          g_filterShowHigh = true;
bool          g_filterShowMed = true;
bool          g_filterShowLow = true;

double        g_pointFactor = 1.0;

double        MinuteBuffer[];
double        ImpactBuffer[];

string        g_markerPool[];
int           g_markerPoolUsed = 0;

uint          g_gradientLUT[];
bool          g_gradientCacheValid = false;

int           g_validUpdateInterval = 4;
int           g_validHideMinutes = 15;
int           g_validTimeOffset = 0;
int           g_validLookbackBars = 500;
int           g_validAlert1Min = 30;
int           g_validAlert2Min = 5;
int           g_validTimeout = 10000;

bool          g_setupAlertShown = false;
bool          g_downloadFailed = false;

//+------------------------------------------------------------------+
//| OnInit - PRODUCTION HARDENED WITH VALIDATION GATES                 |
//+------------------------------------------------------------------+
int OnInit() {
   Print(INDICATOR_NAME, " v", INDICATOR_VERSION, ": Production initialization...");
   
   if(!ValidateInputs()) {
      Print(INDICATOR_NAME, ": FATAL - Input validation failed!");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   SetIndexBuffer(0, MinuteBuffer);
   SetIndexBuffer(1, ImpactBuffer);
   SetIndexStyle(0, DRAW_NONE);
   SetIndexStyle(1, DRAW_NONE);
   SetIndexEmptyValue(0, EMPTY_VALUE);
   SetIndexEmptyValue(1, EMPTY_VALUE);
   
   g_pointFactor = (Digits == 3 || Digits == 5) ? 10.0 : 1.0;
   
   g_jsonFileName = INDICATOR_PREFIX + "calendar_cache.json";
   g_jsonFullPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL4\\Files\\" + g_jsonFileName;
   
   ArrayResize(g_events, MAX_EVENTS, MAX_EVENTS);
   
   if(StringLen(FilterKeyword) > 0) {
      g_filterKeywordLower = FilterKeyword;
      StringToLower(g_filterKeywordLower);
   }
   if(StringLen(ExcludeKeyword) > 0) {
      g_excludeKeywordLower = ExcludeKeyword;
      StringToLower(g_excludeKeywordLower);
   }
   
   if(!InitializeChartDimensions()) {
      Print(INDICATOR_NAME, ": WARNING - Chart dimensions unavailable, using defaults");
      g_chartWidth = 800;
      g_chartHeight = 600;
   }
   
   LoadSettings();
   
   ArrayResize(g_markerPool, MARKER_POOL_SIZE);
   for(int i = 0; i < MARKER_POOL_SIZE; i++) {
      g_markerPool[i] = INDICATOR_PREFIX + "HM_" + IntegerToString(i);
   }
   
   string jsonData = "";
   bool cacheLoaded = LoadCachedJSON(jsonData);
   
   if(!cacheLoaded) {
      Print(INDICATOR_NAME, ": No valid cache. Attempting download...");
      if(DownloadCalendarJSON(jsonData)) {
         Print(INDICATOR_NAME, ": Download successful. Length = ", StringLen(jsonData));
      }
   }
   
   if(StringLen(jsonData) > 10) {
      if(!ParseJSONEventsWithTimeout(jsonData, JSON_PARSE_TIMEOUT)) {
         Print(INDICATOR_NAME, ": WARNING - JSON parse timeout or error");
      } else {
         Print(INDICATOR_NAME, ": Parse complete. Events: ", g_eventCount);
      }
   } else {
      g_downloadFailed = true;
      PrintDownloadHelp();
   }
   
   if(AllowAutoUpdate && g_validUpdateInterval > 0) {
      EventSetTimer(g_validUpdateInterval * 3600);
   }
   
   IndicatorShortName(INDICATOR_NAME + " v" + INDICATOR_VERSION);
   
   if(!InitializeCanvas()) {
      Print(INDICATOR_NAME, ": Canvas initialization FAILED - using fallback rendering");
      g_canvasState = CANVAS_FAILED;
   } else {
      g_canvasState = CANVAS_READY;
      Print(INDICATOR_NAME, ": Canvas initialized successfully");
   }
   
   if(g_canvasState == CANVAS_READY) {
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   }
   
   ChartRedraw();
   
   Print(INDICATOR_NAME, " v", INDICATOR_VERSION, " initialized. Events: ", g_eventCount, 
         ", Canvas: ", EnumToString(g_canvasState));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| PRODUCTION: Validate all inputs                                   |
//+------------------------------------------------------------------+
bool ValidateInputs() {
   //--- Clamp inputs to safe ranges. Clamping is a recovery, not failure.
   //--- Only return false for truly unrecoverable/invalid configurations.
   
   g_validUpdateInterval = (int)MathMax(1, MathMin(24, UpdateIntervalHrs));
   if(g_validUpdateInterval != UpdateIntervalHrs) {
      Print(INDICATOR_NAME, ": WARNING - UpdateIntervalHrs clamped to ", g_validUpdateInterval);
   }
   
   g_validHideMinutes = (int)MathMax(0, MathMin(120, HideAfterMinutes));
   if(g_validHideMinutes != HideAfterMinutes) {
      Print(INDICATOR_NAME, ": WARNING - HideAfterMinutes clamped to ", g_validHideMinutes);
   }
   
   g_validTimeOffset = (int)MathMax(-12, MathMin(12, ChartTimeOffset));
   if(g_validTimeOffset != ChartTimeOffset) {
      Print(INDICATOR_NAME, ": WARNING - ChartTimeOffset clamped to ", g_validTimeOffset);
   }
   
   g_validLookbackBars = (int)MathMax(10, MathMin(1000, HistoricalLookbackBars));
   if(g_validLookbackBars != HistoricalLookbackBars) {
      Print(INDICATOR_NAME, ": WARNING - HistoricalLookbackBars clamped to ", g_validLookbackBars);
   }
   
   g_validAlert1Min = (int)MathMax(0, MathMin(1440, Alert1Minutes));
   g_validAlert2Min = (int)MathMax(0, MathMin(1440, Alert2Minutes));
   
   g_validTimeout = (int)MathMax(5000, MathMin(30000, RequestTimeoutMs));
   if(g_validTimeout != RequestTimeoutMs) {
      Print(INDICATOR_NAME, ": WARNING - RequestTimeoutMs clamped to ", g_validTimeout);
   }
   
   //--- All values successfully clamped to valid ranges
   return(true);
}

//+------------------------------------------------------------------+
//| PRODUCTION: Initialize canvas with full error handling            |
//+------------------------------------------------------------------+
bool InitializeCanvas() {
   ResetLastError();
   g_canvasState = CANVAS_INITIALIZING;
   
   if(g_canvasX < 0 || g_canvasY < 0 || PANEL_WIDTH <= 0) {
      Print(INDICATOR_NAME, ": Invalid canvas dimensions!");
      return(false);
   }
   
   if(!g_canvas.CreateBitmapLabel(g_canvasName, g_canvasX, g_canvasY, 
                                   PANEL_WIDTH, 500, COLOR_FORMAT_ARGB_NORMALIZE)) {
      int err = GetLastError();
      Print(INDICATOR_NAME, ": Canvas creation FAILED! Error: ", err);
      return(false);
   }
   
   if(ObjectFind(0, g_canvasName) < 0) {
      Print(INDICATOR_NAME, ": Canvas object not found after creation!");
      return(false);
   }
   
   return(true);
}

//+------------------------------------------------------------------+
//| PRODUCTION: Chart dimension initialization with validation        |
//+------------------------------------------------------------------+
bool InitializeChartDimensions() {
   ResetLastError();
   
   long width = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   if(width <= 0 || height <= 0) {
      int err = GetLastError();
      Print(INDICATOR_NAME, ": Failed to get chart dimensions. Error: ", err);
      g_chartDimsValid = false;
      return(false);
   }
   
   g_chartWidth = (int)width;
   g_chartHeight = (int)height;
   g_chartDimsValid = true;
   g_lastChartUpdate = TimeCurrent();
   
   return(true);
}

//+------------------------------------------------------------------+
//| OnDeinit - PRODUCTION: Safe cleanup                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //--- Safe Canvas destruction
   if(g_canvasState == CANVAS_READY || g_canvasState == CANVAS_INITIALIZING) {
      g_canvas.Destroy();
      g_canvasState = CANVAS_DESTROYED;
   }
   
   //--- Remove all chart objects with our prefix
   for(int i = ObjectsTotal() - 1; i >= 0; i--) {
      string name = ObjectName(i);
      if(StringFind(name, INDICATOR_PREFIX) >= 0) {
         ObjectDelete(0, name);
      }
   }
   
   //--- Only clean GlobalVariables when indicator is explicitly removed
   //--- NOT on timeframe changes (REASON_CHARTCHANGE) or recompile
   if(reason == REASON_REMOVE) {
      string id = Symbol();
      GlobalVariableDel(INDICATOR_PREFIX + "X_" + id);
      GlobalVariableDel(INDICATOR_PREFIX + "Y_" + id);
      GlobalVariableDel(INDICATOR_PREFIX + "FILTER_H_" + id);
      GlobalVariableDel(INDICATOR_PREFIX + "FILTER_M_" + id);
      GlobalVariableDel(INDICATOR_PREFIX + "FILTER_L_" + id);
   }
   
   //--- Optional: Delete cache file if user enabled cleanup
   if(DeleteCacheOnRemove) {
      if(FileIsExist(g_jsonFileName)) {
         FileDelete(g_jsonFileName);
         Print(INDICATOR_NAME, ": Cache file deleted.");
      }
   }
   
   EventKillTimer();
   ChartRedraw();
   
   Print(INDICATOR_NAME, ": Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| OnChartEvent - PRODUCTION: Hardened event handling                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   //--- Handle chart resize BEFORE canvas state check (dimensions needed regardless of canvas)
   if(id == CHARTEVENT_CHART_CHANGE) {
      InitializeChartDimensions();
      g_renderDirty = true;
      return;  // Resize handled, exit early
   }
   
   //--- All other events require canvas to be ready
   if(g_canvasState != CANVAS_READY) return;
   
   if(id == CHARTEVENT_MOUSE_MOVE) {
      int x = (int)lparam;
      int y = (int)dparam;
      uint buttons = (uint)sparam;
      
      bool leftButton = ((buttons & 1) == 1);
      
      if(leftButton) {
         if(!g_isDragging) {
            if(x >= g_canvasX && x <= g_canvasX + PANEL_WIDTH &&
               y >= g_canvasY && y <= g_canvasY + HEADER_HEIGHT) {
               
               g_isDragging = true;
               g_dragStartX = x - g_canvasX;
               g_dragStartY = y - g_canvasY;
               
               ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
            }
         } else {
            g_canvasX = x - g_dragStartX;
            g_canvasY = y - g_dragStartY;
            
            if(g_chartDimsValid) {
               if(g_canvasX < 0) g_canvasX = 0;
               if(g_canvasY < 0) g_canvasY = 0;
               if(g_canvasX + PANEL_WIDTH > g_chartWidth) 
                  g_canvasX = g_chartWidth - PANEL_WIDTH;
               if(g_canvasY + g_panelHeight > g_chartHeight) 
                  g_canvasY = g_chartHeight - g_panelHeight;
            }
            
            ObjectSetInteger(0, g_canvasName, OBJPROP_XDISTANCE, g_canvasX);
            ObjectSetInteger(0, g_canvasName, OBJPROP_YDISTANCE, g_canvasY);
            
            // SaveSettings(); // Moved to drag-end
            g_renderDirty = true;
         }
      } else {
         if(g_isDragging) {
            ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
            g_isDragging = false;
            SaveSettings();
         }
      }
      return;
   }
   
   if(id == CHARTEVENT_CLICK) {
      int x = (int)lparam;
      int y = (int)dparam;
      
      if(x >= g_canvasX && x <= g_canvasX + PANEL_WIDTH &&
         y >= g_canvasY && y <= g_canvasY + g_panelHeight) {
         
         int relX = x - g_canvasX;
         int relY = y - g_canvasY;
         
         int fx = PANEL_WIDTH - 75;
         if(relY >= 5 && relY <= 25) {
            if(relX >= fx && relX < fx + 25) {
               g_filterShowHigh = !g_filterShowHigh;
               SaveSettings();
               g_renderDirty = true;
               RenderPanelCanvasSafe();
            }
            else if(relX >= fx + 25 && relX < fx + 50) {
               g_filterShowMed = !g_filterShowMed;
               SaveSettings();
               g_renderDirty = true;
               RenderPanelCanvasSafe();
            }
            else if(relX >= fx + 50 && relX < fx + 75) {
               g_filterShowLow = !g_filterShowLow;
               SaveSettings();
               g_renderDirty = true;
               RenderPanelCanvasSafe();
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTimer - PRODUCTION: Safe timer with rate limiting               |
//+------------------------------------------------------------------+
void OnTimer() {
   //--- Periodic boundary check to handle resize/init stability
   //--- We do this here instead of OnChartEvent to avoid clamping on transient init dimensions
   if(g_canvasState == CANVAS_READY) {
      InitializeChartDimensions();
      if(g_chartDimsValid && g_chartWidth > PANEL_WIDTH) { // Sanity check
         bool changed = false;
         if(g_canvasX + PANEL_WIDTH > g_chartWidth) {
            g_canvasX = MathMax(0, g_chartWidth - PANEL_WIDTH);
            changed = true;
         }
         if(g_canvasY + g_panelHeight > g_chartHeight) {
            g_canvasY = MathMax(0, g_chartHeight - g_panelHeight);
            changed = true;
         }
         
         if(changed) {
            ObjectSetInteger(0, g_canvasName, OBJPROP_XDISTANCE, g_canvasX);
            ObjectSetInteger(0, g_canvasName, OBJPROP_YDISTANCE, g_canvasY);
         }
      }
   }

   datetime fileAge = GetCacheFileAge();
   
   //--- Trigger download if: no cache exists OR cache is stale
   bool needsUpdate = (fileAge == 0) || (TimeCurrent() - fileAge > CACHE_VALIDITY_SEC);
   
   if(needsUpdate) {
      int dayOfWeek = TimeDayOfWeek(TimeCurrent());
      if(dayOfWeek == 0 || dayOfWeek == 6) return;
      
      if(TimeCurrent() - g_lastRequestTime < MIN_REQUEST_INTERVAL) return;
      
      string jsonData = "";
      if(DownloadCalendarJSON(jsonData)) {
         ParseJSONEventsWithTimeout(jsonData, JSON_PARSE_TIMEOUT);
         g_renderDirty = true;
      }
   }
}

//+------------------------------------------------------------------+
//| OnCalculate - PRODUCTION: Optimized calculation loop              |
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
                
   if(g_currentSymbol != Symbol()) {
      g_currentSymbol = Symbol();
      string jsonData = "";
      if(LoadCachedJSON(jsonData) && StringLen(jsonData) > 10) {
         ParseJSONEventsWithTimeout(jsonData, JSON_PARSE_TIMEOUT);
      }
      g_renderDirty = true;
   }
   
   if(!g_cacheValid || g_eventCount == 0) {
      DrawNoEventsMessage();
      return(rates_total);
   }
   
   UpdateEventTiming();
   
   if(prev_calculated == 0 || g_lastBufferUpdate != rates_total) {
      PopulateBuffers(rates_total, prev_calculated);
      g_lastBufferUpdate = rates_total;
   }
   
   bool needsRender = (TimeCurrent() != g_lastRenderTime) || g_renderDirty;
   if(ShowPanel && (needsRender || g_isDragging)) {
      RenderPanelCanvasSafe();
      g_lastRenderTime = TimeCurrent();
      g_renderDirty = false;
   }
   
   if(ShowVerticalLines) DrawVerticalLines();
   if(ShowSymbolInfo) DrawSymbolInfo(time);
   
   ProcessAlertsWithCooldown();
   
   if(ShowHistoricalMarkers) DrawHistoricalMarkersPooled();
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Load cached JSON from file                                        |
//+------------------------------------------------------------------+
bool LoadCachedJSON(string &jsonData) {
   ResetLastError();
   jsonData = "";
   
   if(!FileIsExist(g_jsonFileName)) {
      Print(INDICATOR_NAME, ": No cache file found.");
      return(false);
   }
   
   datetime fileModTime = GetCacheFileAge();
   if(fileModTime > 0 && TimeCurrent() - fileModTime > CACHE_MAX_AGE_SEC) {
      Print(INDICATOR_NAME, ": Cache file expired (>1 week). Fresh download required.");
      FileDelete(g_jsonFileName);
      return(false);
   }
   
   if(IsCacheFromPreviousWeek()) {
      Print(INDICATOR_NAME, ": New week detected! Deleting old cache for fresh data.");
      FileDelete(g_jsonFileName);
      return(false);
   }
   
   int handle = FileOpen(g_jsonFileName, FILE_READ|FILE_BIN);
   if(handle == INVALID_HANDLE) {
      int err = GetLastError();
      Print(INDICATOR_NAME, ": Failed to open cache. Error: ", err);
      return(false);
   }
   
   ulong fileSize = FileSize(handle);
   if(fileSize == 0 || fileSize > MAX_JSON_SIZE) {
      FileClose(handle);
      Print(INDICATOR_NAME, ": Invalid file size: ", fileSize);
      return(false);
   }
   
   uchar buffer[];
   ArrayResize(buffer, (int)fileSize);
   uint bytesRead = FileReadArray(handle, buffer, 0, (int)fileSize);
   FileClose(handle);
   
   if(bytesRead != fileSize) {
      Print(INDICATOR_NAME, ": Read mismatch. Expected ", fileSize, ", got ", bytesRead);
      return(false);
   }
   
   jsonData = CharArrayToString(buffer, 0, (int)bytesRead, CP_UTF8);
   
   int cacheAgeHours = (int)((TimeCurrent() - fileModTime) / 3600);
   Print(INDICATOR_NAME, ": Loaded ", StringLen(jsonData), " bytes from cache. Age: ", cacheAgeHours, " hours");
   
   g_lastUpdate = fileModTime;
   return(StringLen(jsonData) > 10);
}

//+------------------------------------------------------------------+
//| Download calendar JSON with retry logic                           |
//+------------------------------------------------------------------+
bool DownloadCalendarJSON(string &jsonData) {
   ResetLastError();
   g_lastRequestTime = TimeCurrent();
   
   Print(INDICATOR_NAME, ": Attempting to download calendar data...");
   
   if(TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) {
      Print(INDICATOR_NAME, ": Using Windows API download method...");
      if(DownloadViaWinAPI(jsonData)) {
         g_retryCount = 0;
         g_currentBackoff = INITIAL_BACKOFF_SEC;
         return(true);
      }
   }
   
   g_retryCount++;
   if(g_retryCount < MAX_RETRY_ATTEMPTS) {
      g_currentBackoff *= 2;
      Print(INDICATOR_NAME, ": Download failed. Retry ", g_retryCount, "/", MAX_RETRY_ATTEMPTS,
            " in ", g_currentBackoff, " seconds");
   } else {
      Print(INDICATOR_NAME, ": All download attempts failed. Will retry on next timer interval.");
      g_retryCount = 0;
      g_currentBackoff = INITIAL_BACKOFF_SEC;
   }
   
   return(false);
}

//+------------------------------------------------------------------+
//| Download using Windows API                                        |
//+------------------------------------------------------------------+
bool DownloadViaWinAPI(string &jsonData) {
   ResetLastError();
   
   Print(INDICATOR_NAME, ": Downloading to: ", g_jsonFullPath);
   
   //--- Clear Windows cache for this URL before downloading
   DeleteUrlCacheEntryW(JSON_URL);
   
   int downloadResult = URLDownloadToFileW(0, JSON_URL, g_jsonFullPath, 0, 0);
   
   if(downloadResult != 0) {
      Print(INDICATOR_NAME, ": URLDownloadToFileW failed. Result: ", downloadResult);
      return(false);
   }
   
   Print(INDICATOR_NAME, ": File downloaded successfully!");
   
   return(ReadDownloadedFile(jsonData));
}

//+------------------------------------------------------------------+
//| Save JSON data to cache file                                      |
//------------------------------------------------------------------+
void SaveToCache(const string &jsonData) {
   int handle = FileOpen(g_jsonFileName, FILE_WRITE|FILE_BIN);
   if(handle != INVALID_HANDLE) {
      uchar buffer[];
      StringToCharArray(jsonData, buffer, 0, -1, CP_UTF8);
      FileWriteArray(handle, buffer, 0, ArraySize(buffer) - 1);
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| Read downloaded file                                              |
//+------------------------------------------------------------------+
bool ReadDownloadedFile(string &jsonData) {
   ResetLastError();
   
   if(!FileIsExist(g_jsonFileName)) {
      Print(INDICATOR_NAME, ": Downloaded file not found!");
      return(false);
   }
   
   bool success = LoadCachedJSON(jsonData);
   
   if(success) {
      Print(INDICATOR_NAME, ": JSON preview: ", StringSubstr(jsonData, 0, 100), "...");
   }
   
   return(success);
}

//+------------------------------------------------------------------+
//| Get cache file modification time                                  |
//+------------------------------------------------------------------+
datetime GetCacheFileAge() {
   if(!FileIsExist(g_jsonFileName)) return(0);
   return((datetime)FileGetInteger(g_jsonFileName, FILE_MODIFY_DATE));
}

//+------------------------------------------------------------------+
//| Get the Saturday that starts the current FF week                  |
//+------------------------------------------------------------------+
datetime GetWeekStartDate(datetime fromTime) {
   MqlDateTime dt;
   TimeToStruct(fromTime, dt);
   int dayOfWeek = dt.day_of_week;
   
   int daysToSaturday;
   if(dayOfWeek == 6) daysToSaturday = 0;
   else if(dayOfWeek == 0) daysToSaturday = 1;
   else daysToSaturday = dayOfWeek + 1;
   
   datetime saturday = fromTime - daysToSaturday * 86400;
   MqlDateTime satDt;
   TimeToStruct(saturday, satDt);
   satDt.hour = 0;
   satDt.min = 0;
   satDt.sec = 0;
   return(StructToTime(satDt));
}

//+------------------------------------------------------------------+
//| Check if cache is from a previous week                            |
//+------------------------------------------------------------------+
bool IsCacheFromPreviousWeek() {
   datetime cacheTime = GetCacheFileAge();
   if(cacheTime == 0) return(false);
   
   datetime currentWeekStart = GetWeekStartDate(TimeCurrent());
   datetime cacheWeekStart = GetWeekStartDate(cacheTime);
   
   if(cacheWeekStart < currentWeekStart) {
      Print(INDICATOR_NAME, ": Cache is from previous week. Current week: ", 
            TimeToString(currentWeekStart, TIME_DATE), 
            ", Cache week: ", TimeToString(cacheWeekStart, TIME_DATE));
      return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| PRODUCTION: JSON parser with timeout and depth limiting           |
//+------------------------------------------------------------------+
bool ParseJSONEventsWithTimeout(const string &jsonData, const int timeoutMs) {
   uint startTime = GetTickCount();
   g_eventCount = 0;
   g_cacheValid = false;
   
   if(StringLen(jsonData) < 10 || StringLen(jsonData) > MAX_JSON_SIZE) {
      Print(INDICATOR_NAME, ": JSON size invalid: ", StringLen(jsonData));
      return(false);
   }
   
   string baseCurrency = StringSubstr(Symbol(), 0, 3);
   string quoteCurrency = StringSubstr(Symbol(), 3, 3);
   
   int pos = 0;
   int len = StringLen(jsonData);
   
   while(pos < len && g_eventCount < MAX_EVENTS) {
      if(g_eventCount % 10 == 0) {
         if(GetTickCount() - startTime > (uint)timeoutMs) {
            Print(INDICATOR_NAME, ": TIMEOUT parsing JSON at event ", g_eventCount);
            return(false);
         }
      }
      
      int objStart = StringFind(jsonData, "{", pos);
      if(objStart == -1) break;
      
      int objEnd = FindMatchingBraceWithDepthLimit(jsonData, objStart, MAX_PARSE_DEPTH);
      if(objEnd == -1) {
         Print(INDICATOR_NAME, ": Malformed JSON at position ", objStart);
         break;
      }
      
      string eventObj = StringSubstr(jsonData, objStart, objEnd - objStart + 1);
      pos = objEnd + 1;
      
      string title = ExtractJSONString(eventObj, "title");
      string country = ExtractJSONString(eventObj, "country");
      string dateStr = ExtractJSONString(eventObj, "date");
      string impactStr = ExtractJSONString(eventObj, "impact");
      string forecast = ExtractJSONValue(eventObj, "forecast");
      string previous = ExtractJSONValue(eventObj, "previous");
      string actual = ExtractJSONValue(eventObj, "actual");
      
      if(!PassesFilters(title, country, impactStr, baseCurrency, quoteCurrency))
         continue;
      
      datetime eventTime = ParseISO8601(dateStr);
      if(eventTime == 0) continue;
      
      int minutesUntil = (int)((eventTime - TimeGMT()) / 60);
      
      if(minutesUntil + g_validHideMinutes < 0) continue;
      
      CalendarEvent evt;
      evt.title = title;
      evt.country = country;
      evt.eventTime = eventTime;
      evt.impact = StringToImpact(impactStr);
      evt.forecast = (StringLen(forecast) > 0) ? forecast : "—";
      evt.previous = (StringLen(previous) > 0) ? previous : "—";
      evt.actual = (StringLen(actual) > 0) ? actual : "";
      evt.forecastNum = ParseNumericValue(forecast);
      evt.previousNum = ParseNumericValue(previous);
      evt.actualNum = ParseNumericValue(actual);
      evt.minutesUntil = minutesUntil;
      evt.isValid = true;
      
      g_events[g_eventCount] = evt;
      g_eventCount++;
   }
   
   if(g_eventCount > 1) {
      QuickSortEvents(0, g_eventCount - 1);
   }
   
   g_cacheValid = (g_eventCount > 0);
   
   uint endTime = GetTickCount();
   Print(INDICATOR_NAME, ": Parsed ", g_eventCount, " events in ", (endTime - startTime), " ms");
   
   return(true);
}

//+------------------------------------------------------------------+
//| PRODUCTION: Find matching brace with depth limit                  |
//+------------------------------------------------------------------+
int FindMatchingBraceWithDepthLimit(const string &json, const int startPos, const int maxDepth) {
   int depth = 0;
   int len = StringLen(json);
   bool inString = false;
   
   for(int i = startPos; i < len; i++) {
      ushort ch = StringGetCharacter(json, i);
      
      if(ch == '"' && (i == 0 || StringGetCharacter(json, i-1) != '\\')) {
         inString = !inString;
         continue;
      }
      
      if(inString) continue;
      
      if(ch == '{') {
         depth++;
         if(depth > maxDepth) {
            Print(INDICATOR_NAME, ": JSON depth limit exceeded!");
            return(-1);
         }
      }
      else if(ch == '}') {
         depth--;
         if(depth == 0) return(i);
      }
   }
   
   return(-1);
}

//+------------------------------------------------------------------+
//| QuickSort for events by time                                      |
//+------------------------------------------------------------------+
void QuickSortEvents(const int left, const int right) {
   if(left >= right) return;
   
   int i = left, j = right;
   datetime pivot = g_events[(left + right) / 2].eventTime;
   
   while(i <= j) {
      while(g_events[i].eventTime < pivot) i++;
      while(g_events[j].eventTime > pivot) j--;
      
      if(i <= j) {
         CalendarEvent temp = g_events[i];
         g_events[i] = g_events[j];
         g_events[j] = temp;
         i++;
         j--;
      }
   }
   
   if(left < j)  QuickSortEvents(left, j);
   if(i < right) QuickSortEvents(i, right);
}

//+------------------------------------------------------------------+
//| Extract string value from JSON key                                |
//+------------------------------------------------------------------+
string ExtractJSONString(const string &json, const string key) {
   string searchKey = "\"" + key + "\":\"";
   int keyPos = StringFind(json, searchKey);
   
   if(keyPos == -1) return("");
   
   int valueStart = keyPos + StringLen(searchKey);
   int len = StringLen(json);
   
   int valueEnd = valueStart;
   while(valueEnd < len) {
      ushort ch = StringGetCharacter(json, valueEnd);
      if(ch == '"') {
         if(valueEnd > 0 && StringGetCharacter(json, valueEnd - 1) == '\\')
            valueEnd++;
         else
            break;
      } else {
         valueEnd++;
      }
   }
   
   if(valueEnd <= valueStart) return("");
   
   return(StringSubstr(json, valueStart, valueEnd - valueStart));
}

//+------------------------------------------------------------------+
//| Extract any value from JSON                                       |
//+------------------------------------------------------------------+
string ExtractJSONValue(const string &json, const string key) {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   
   if(keyPos == -1) return("");
   
   int valueStart = keyPos + StringLen(searchKey);
   int len = StringLen(json);
   
   while(valueStart < len) {
      ushort ch = StringGetCharacter(json, valueStart);
      if(ch != ' ' && ch != '\t' && ch != '\n' && ch != '\r')
         break;
      valueStart++;
   }
   
   if(valueStart >= len) return("");
   
   ushort firstChar = StringGetCharacter(json, valueStart);
   
   if(firstChar == '"') {
      valueStart++;
      int valueEnd = valueStart;
      while(valueEnd < len) {
         ushort ch = StringGetCharacter(json, valueEnd);
         if(ch == '"' && (valueEnd == 0 || StringGetCharacter(json, valueEnd - 1) != '\\'))
            break;
         valueEnd++;
      }
      return(valueEnd > valueStart ? StringSubstr(json, valueStart, valueEnd - valueStart) : "");
   }
   
   if(StringSubstr(json, valueStart, 4) == "null") return("");
   
   int valueEnd = valueStart;
   while(valueEnd < len) {
      ushort ch = StringGetCharacter(json, valueEnd);
      if(ch == ',' || ch == '}' || ch == ']' || ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r')
         break;
      valueEnd++;
   }
   
   return(valueEnd > valueStart ? StringSubstr(json, valueStart, valueEnd - valueStart) : "");
}

//+------------------------------------------------------------------+
//| Parse ISO 8601 datetime string                                    |
//+------------------------------------------------------------------+
datetime ParseISO8601(const string &isoDate) {
   if(StringLen(isoDate) < 19) return(0);
   
   string datePart = StringSubstr(isoDate, 0, 10);
   string timePart = StringSubstr(isoDate, 11, 8);
   
   //--- MQL4 StringToTime requires yyyy.mm.dd format (dots, not hyphens)
   StringReplace(datePart, "-", ".");
   
   int tzOffset = 0;
   if(StringLen(isoDate) >= 25) {
      string tzStr = StringSubstr(isoDate, 19, 6);
      int tzSign = (StringGetCharacter(tzStr, 0) == '-') ? -1 : 1;
      int tzHours = (int)StringToInteger(StringSubstr(tzStr, 1, 2));
      int tzMins = (int)StringToInteger(StringSubstr(tzStr, 4, 2));
      tzOffset = tzSign * (tzHours * 3600 + tzMins * 60);
   }
   
   datetime result = StringToTime(datePart + " " + timePart);
   result -= tzOffset;
   
   return(result);
}

//+------------------------------------------------------------------+
//| Parse numeric value from string                                   |
//+------------------------------------------------------------------+
double ParseNumericValue(const string &value) {
   if(StringLen(value) == 0 || value == "—" || value == "null") return(EMPTY_VALUE);
   
   string cleaned = value;
   double multiplier = 1.0;
   
   StringReplace(cleaned, "%", "");
   StringReplace(cleaned, ",", "");
   
   if(StringFind(cleaned, "K") >= 0) { multiplier = 1000; StringReplace(cleaned, "K", ""); }
   else if(StringFind(cleaned, "M") >= 0) { multiplier = 1000000; StringReplace(cleaned, "M", ""); }
   else if(StringFind(cleaned, "B") >= 0) { multiplier = 1000000000; StringReplace(cleaned, "B", ""); }
   
   StringTrimLeft(cleaned);
   StringTrimRight(cleaned);
   
   double result = StringToDouble(cleaned);
   if(result == 0 && StringLen(cleaned) > 0 && StringGetCharacter(cleaned, 0) != '0') {
      return(EMPTY_VALUE);
   }
   
   return(result * multiplier);
}

//+------------------------------------------------------------------+
//| Convert impact string to enum                                     |
//+------------------------------------------------------------------+
ENUM_IMPACT_LEVEL StringToImpact(const string &impact) {
   if(impact == "High")    return(IMPACT_HIGH);
   if(impact == "Medium")  return(IMPACT_MEDIUM);
   if(impact == "Low")     return(IMPACT_LOW);
   if(impact == "Holiday") return(IMPACT_HOLIDAY);
   return(IMPACT_LOW);
}

//+------------------------------------------------------------------+
//| Check if event passes filters                                     |
//+------------------------------------------------------------------+
bool PassesFilters(const string &title, const string &country, const string &impact,
                   const string &baseCcy, const string &quoteCcy) {
   
   if(ReportActiveOnly) {
      if(country != baseCcy && country != quoteCcy)
         return(false);
   } else {
      if(!IsCurrencyEnabled(country))
         return(false);
   }
   
   if(impact == "High" && !IncludeHigh) return(false);
   if(impact == "Medium" && !IncludeMedium) return(false);
   if(impact == "Low" && !IncludeLow) return(false);
   if(impact == "Holiday" && !IncludeHolidays) return(false);
   
   if(!IncludeSpeaks && StringFind(title, "Speaks") != -1) return(false);
   
   if(StringLen(g_filterKeywordLower) > 0) {
      string titleLower = title;
      StringToLower(titleLower);
      if(StringFind(titleLower, g_filterKeywordLower) == -1) return(false);
   }
   
   if(StringLen(g_excludeKeywordLower) > 0) {
      string titleLower = title;
      StringToLower(titleLower);
      if(StringFind(titleLower, g_excludeKeywordLower) != -1) return(false);
   }
   
   return(true);
}

//+------------------------------------------------------------------+
//| Check if currency is enabled in inputs                            |
//+------------------------------------------------------------------+
bool IsCurrencyEnabled(const string &country) {
   if(country == "USD") return(ReportUSD);
   if(country == "EUR") return(ReportEUR);
   if(country == "GBP") return(ReportGBP);
   if(country == "JPY") return(ReportJPY);
   if(country == "AUD") return(ReportAUD);
   if(country == "NZD") return(ReportNZD);
   if(country == "CAD") return(ReportCAD);
   if(country == "CHF") return(ReportCHF);
   if(country == "CNY") return(ReportCNY);
   return(false);
}

//+------------------------------------------------------------------+
//| Update timing for all events                                      |
//+------------------------------------------------------------------+
void UpdateEventTiming() {
   datetime now = TimeGMT();
   g_nextEventIndex = -1;
   
   for(int i = 0; i < g_eventCount; i++) {
      g_events[i].minutesUntil = (int)((g_events[i].eventTime - now) / 60);
      
      //--- Identify the next upcoming event for highlighting
      if(g_events[i].minutesUntil >= 0 && g_nextEventIndex == -1) {
         g_nextEventIndex = i;
      }
   }
}

//+------------------------------------------------------------------+
//| Populate indicator buffers                                        |
//+------------------------------------------------------------------+
void PopulateBuffers(const int rates_total, const int prev_calculated) {
   MinuteBuffer[0] = EMPTY_VALUE;
   ImpactBuffer[0] = EMPTY_VALUE;
   if(g_eventCount > 0) {
      for(int i = 0; i < g_eventCount; i++) {
         if(g_events[i].minutesUntil >= 0) {
            MinuteBuffer[0] = (double)g_events[i].minutesUntil;
            ImpactBuffer[0] = (double)g_events[i].impact;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get week date range string                                        |
//+------------------------------------------------------------------+
string GetWeekDateRange() {
   datetime now = TimeCurrent();
   
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int dayOfWeek = dt.day_of_week;
   
   int daysToSaturday;
   if(dayOfWeek == 6) daysToSaturday = 0;
   else if(dayOfWeek == 0) daysToSaturday = 1;
   else daysToSaturday = dayOfWeek + 1;
   
   datetime saturday = now - daysToSaturday * 86400;
   datetime friday = saturday + 6 * 86400;
   
   MqlDateTime satDt, friDt;
   TimeToStruct(saturday, satDt);
   TimeToStruct(friday, friDt);
   
   string months[] = {"", "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
   
   return StringFormat("%s %d - %s %d", 
                       months[satDt.mon], satDt.day,
                       months[friDt.mon], friDt.day);
}

//+------------------------------------------------------------------+
//| Helper to convert MT4 color to ARGB uint                          |
//+------------------------------------------------------------------+
uint ToARGB(color mqlColor, uchar alpha) {
   uint r = (uint)(mqlColor & 0xFF);
   uint g = (uint)((mqlColor >> 8) & 0xFF);
   uint b = (uint)((mqlColor >> 16) & 0xFF);
   return ((uint)alpha << 24) | (r << 16) | (g << 8) | b;
}

//+------------------------------------------------------------------+
//| PRODUCTION: Safe canvas rendering with validation                 |
//+------------------------------------------------------------------+
void RenderPanelCanvasSafe() {
   if(!ShowPanel || g_canvasState != CANVAS_READY) return;
   
   ResetLastError();
   
   //--- Count how many events will actually be displayed after filtering
   int filteredCount = 0;
   for(int i = 0; i < g_eventCount && filteredCount < DISPLAY_EVENTS; i++) {
      if(g_events[i].minutesUntil + g_validHideMinutes >= 0) {
         if(PassesRuntimeFilter(g_events[i].impact)) {
            filteredCount++;
         }
      }
   }
   
   int visibleEvents = (filteredCount > 0) ? filteredCount : 1;
   
   int h = HEADER_HEIGHT + (visibleEvents * ROW_HEIGHT) + 10;  // Extra bottom padding
   h = MathMin(h, MAX_GRADIENT_HEIGHT);
   g_panelHeight = h;
   
   g_canvas.Erase(0);
   
   if(!DrawBackgroundWithCachedGradient(h)) {
      Print(INDICATOR_NAME, ": Gradient rendering failed");
      return;
   }
   
   uint borderColor = ToARGB(PanelBorder, 255);
   g_canvas.Rectangle(0, 0, PANEL_WIDTH - 1, h - 1, borderColor);
   
   uint accentColor = ToARGB(TitleColor, 255);
   g_canvas.FillRectangle(0, 0, PANEL_WIDTH - 1, 3, accentColor);
   
   string weekDate = GetWeekDateRange();
   
   //--- Build timezone string (e.g., "GMT+2" or "GMT-5")
   int gmtOffsetHours = (int)(GetServerGMTOffset() / 3600) + g_validTimeOffset;
   string tzStr = (gmtOffsetHours >= 0) ? "GMT+" + IntegerToString(gmtOffsetHours) 
                                        : "GMT" + IntegerToString(gmtOffsetHours);
   
   string fullTitle = "CANVAS ECONOMIC CALENDAR (" + weekDate + ") " + tzStr;
   
   g_canvas.FontSet("Arial Bold", -90);
   g_canvas.TextOut(10, 11, fullTitle, ToARGB(TextColor, 255));
   
   int fx = PANEL_WIDTH - 75;
   g_canvas.FontSet("Arial Bold", -90);
   g_canvas.TextOut(fx, 11, "H", ToARGB(g_filterShowHigh ? HighImpactColor : DimTextColor, 255));
   g_canvas.TextOut(fx + 25, 11, "M", ToARGB(g_filterShowMed ? MediumImpactColor : DimTextColor, 255));
   g_canvas.TextOut(fx + 50, 11, "L", ToARGB(g_filterShowLow ? LowImpactColor : DimTextColor, 255));
   
   int headerY = 32;
   g_canvas.FontSet("Arial", -85);
   uint headColor = ToARGB(DimTextColor, 200);
   g_canvas.TextOut(COL_DAY_X, headerY, "DAY", headColor);
   g_canvas.TextOut(COL_TIME_X, headerY, "TIME", headColor);
   g_canvas.TextOut(COL_CCY_X, headerY, "CCY", headColor);
   g_canvas.TextOut(COL_EVENT_X, headerY, "EVENT", headColor);
   g_canvas.TextOut(COL_FCST_X, headerY, "FCST", headColor);
   g_canvas.TextOut(COL_PREV_X, headerY, "PREV", headColor);
   g_canvas.TextOut(COL_ACT_X, headerY, "ACT", headColor);
   
   g_canvas.LineHorizontal(5, PANEL_WIDTH - 10, headerY + 13, ToARGB(PanelBorder, 100));
   
   DrawEventRowsOptimized();
   
   g_canvas.Update();
}

//+------------------------------------------------------------------+
//| PRODUCTION: Optimized gradient with LUT caching                   |
//+------------------------------------------------------------------+
bool DrawBackgroundWithCachedGradient(const int h) {
   //--- Guard against division by zero
   if(h <= 0) return(false);
   
   if(!g_gradientCacheValid || ArraySize(g_gradientLUT) != h) {
      ArrayResize(g_gradientLUT, h);
      
      int r1 = (int)(PanelBackground & 0xFF);
      int g1 = (int)((PanelBackground >> 8) & 0xFF);
      int b1 = (int)((PanelBackground >> 16) & 0xFF);
      int r2 = 10, g2 = 10, b2 = 15;
      
      for(int i = 0; i < h; i++) {
         uint rV = (uint)((r1 * (h - i) + r2 * i) / h);
         uint gV = (uint)((g1 * (h - i) + g2 * i) / h);
         uint bV = (uint)((b1 * (h - i) + b2 * i) / h);
         g_gradientLUT[i] = ((uint)245 << 24) | (rV << 16) | (gV << 8) | bV;
      }
      
      g_gradientCacheValid = true;
   }
   
   for(int i = 0; i < h; i++) {
      g_canvas.LineHorizontal(0, PANEL_WIDTH - 1, i, g_gradientLUT[i]);
   }
   
   return(true);
}

//+------------------------------------------------------------------+
//| PRODUCTION: Optimized event row drawing                           |
//+------------------------------------------------------------------+
void DrawEventRowsOptimized() {
   int rowY = HEADER_HEIGHT + 5;
   int eventsDrawn = 0;
   
   g_canvas.FontSet("Arial", -90);
   
   for(int i = 0; i < g_eventCount && eventsDrawn < DISPLAY_EVENTS; i++) {
      if(g_events[i].minutesUntil + g_validHideMinutes >= 0) {
         if(!PassesRuntimeFilter(g_events[i].impact)) continue;
         
         if(i == g_nextEventIndex) {
            g_canvas.FillRectangle(2, rowY, PANEL_WIDTH - 3, rowY + ROW_HEIGHT, 
                                   ToARGB(HighlightColor, 255));
         }
         
         uint rowTextColor = ToARGB(g_events[i].minutesUntil < 0 ? DimTextColor : TextColor, 255);
         uint rowImpColor = ToARGB(GetImpactColor(g_events[i].impact), 255);
         
         datetime eventLocalTime = g_events[i].eventTime + GetServerGMTOffset();
         uint timeColor = (g_events[i].minutesUntil < 0 ? rowTextColor : rowImpColor);
         
         //--- Get day name from event time
         MqlDateTime evtDt;
         TimeToStruct(eventLocalTime, evtDt);
         string dayNames[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
         string dayName = dayNames[evtDt.day_of_week];
         
         g_canvas.TextOut(COL_DAY_X, rowY + 3, dayName, timeColor);
         g_canvas.TextOut(COL_TIME_X, rowY + 3, TimeToString(eventLocalTime, TIME_MINUTES), timeColor);
         g_canvas.TextOut(COL_CCY_X, rowY + 3, g_events[i].country, timeColor);
         
         g_canvas.FontSet("Wingdings", -90);
         g_canvas.TextOut(COL_IMPACT_X, rowY + 4, "n", rowImpColor);
         
         g_canvas.FontSet("Arial", -90);
         string titleStr = g_events[i].title;
         if(StringLen(titleStr) > TITLE_MAX_LEN) 
            titleStr = StringSubstr(titleStr, 0, TITLE_MAX_LEN - 2) + "..";
         g_canvas.TextOut(COL_EVENT_X, rowY + 3, titleStr, rowTextColor);
         
         uint fcstColor = timeColor;
         if(g_events[i].minutesUntil >= 0 && g_events[i].forecast != "—") {
            if(g_events[i].forecastNum != EMPTY_VALUE && g_events[i].previousNum != EMPTY_VALUE) {
               if(g_events[i].forecastNum > g_events[i].previousNum) 
                  fcstColor = ToARGB(PositiveColor, 255);
               else if(g_events[i].forecastNum < g_events[i].previousNum) 
                  fcstColor = ToARGB(NegativeColor, 255);
               else 
                  fcstColor = ToARGB(TextColor, 255);
            }
         }
         
         g_canvas.TextOut(COL_FCST_X, rowY + 3, g_events[i].forecast, fcstColor);
         g_canvas.TextOut(COL_PREV_X, rowY + 3, g_events[i].previous, timeColor);
         
         string actStr = (StringLen(g_events[i].actual) > 0) ? g_events[i].actual : "—";
         uint rowActColor = rowTextColor;
         if(StringLen(g_events[i].actual) > 0 && g_events[i].actualNum != EMPTY_VALUE && 
            g_events[i].forecastNum != EMPTY_VALUE) {
            if(g_events[i].actualNum > g_events[i].forecastNum) 
               rowActColor = ToARGB(PositiveColor, 255);
            else if(g_events[i].actualNum < g_events[i].forecastNum) 
               rowActColor = ToARGB(NegativeColor, 255);
         }
         
         g_canvas.TextOut(COL_ACT_X, rowY + 3, actStr, rowActColor);
         
         rowY += ROW_HEIGHT;
         eventsDrawn++;
      }
   }
   
   if(eventsDrawn == 0) {
      g_canvas.FontSet("Arial", -90);
      if(g_downloadFailed || g_eventCount == 0) {
         // Show setup instructions on canvas
         g_canvas.TextOut(20, HEADER_HEIGHT + 5, "SETUP REQUIRED", ToARGB(HighImpactColor, 255));
         g_canvas.TextOut(20, HEADER_HEIGHT + 22, "Please enable DLL imports in MT4 Options.", ToARGB(TextColor, 200));
         g_canvas.TextOut(20, HEADER_HEIGHT + 39, "Check Experts tab for instructions.", ToARGB(DimTextColor, 180));
      } else {
         g_canvas.TextOut(20, HEADER_HEIGHT + 10, "No upcoming events", ToARGB(DimTextColor, 200));
      }
   }
}

//+------------------------------------------------------------------+
//| Check whether event passes runtime filter buttons                 |
//+------------------------------------------------------------------+
bool PassesRuntimeFilter(const ENUM_IMPACT_LEVEL impact) {
   if(impact == IMPACT_HIGH && !g_filterShowHigh) return(false);
   if(impact == IMPACT_MEDIUM && !g_filterShowMed) return(false);
   if(impact == IMPACT_LOW && !g_filterShowLow) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| Draw vertical event lines on chart                                |
//+------------------------------------------------------------------+
void DrawVerticalLines() {
   if(!ShowVerticalLines) return;
   
   int linesDrawn = 0;
   
   //--- First pass: Hide all pooled lines (efficient - no delete/recreate)
   for(int i = 0; i < MAX_VLINE_OBJECTS; i++) {
      string lineName = INDICATOR_PREFIX + "VL" + IntegerToString(i);
      if(ObjectFind(0, lineName) >= 0) {
         ObjectSetInteger(0, lineName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      } else {
         //--- Create pooled object once if it doesn't exist
         if(ObjectCreate(0, lineName, OBJ_VLINE, 0, 0, 0)) {
            ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
            ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lineName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
         }
      }
   }
   
   //--- Second pass: Move and show valid lines
   for(int i = 0; i < g_eventCount && linesDrawn < MAX_VISIBLE_VLINES; i++) {
      if(g_events[i].minutesUntil < -g_validHideMinutes) continue;
      if(!PassesRuntimeFilter(g_events[i].impact)) continue;
      
      //--- Corrected ActiveOnly: Exact base/quote match (not StringFind which matches US30 to USD)
      if(ReportActiveOnly) {
         string base = StringSubstr(Symbol(), 0, 3);
         string quote = StringSubstr(Symbol(), 3, 3);
         if(g_events[i].country != base && g_events[i].country != quote) continue;
      } else {
         if(!IsCurrencyEnabled(g_events[i].country)) continue;
      }
      
      string lineName = INDICATOR_PREFIX + "VL" + IntegerToString(linesDrawn);
      datetime lineTime = g_events[i].eventTime + GetServerGMTOffset() + (g_validTimeOffset * 3600);
      color lineColor = g_events[i].minutesUntil < 0 ? DimTextColor : GetImpactColor(g_events[i].impact);
      
      //--- Move existing pooled object and make visible
      ObjectMove(0, lineName, 0, lineTime, 0);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, lineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetString(0, lineName, OBJPROP_TOOLTIP, g_events[i].title + " (" + g_events[i].country + ")");
      
      linesDrawn++;
   }
}

//+------------------------------------------------------------------+
//| Draw info bar - Calendar-focused Symbol Info                      |
//+------------------------------------------------------------------+
void DrawSymbolInfo(const datetime &time[]) {
   g_chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   g_chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   //--- Trading essentials
   double spreadPips = MarketInfo(Symbol(), MODE_SPREAD) / g_pointFactor;
   
   datetime currentBarTime = iTime(Symbol(), Period(), 0);
   datetime candleEnd = currentBarTime + PeriodSeconds();
   int secsRemaining = (int)(candleEnd - TimeCurrent());
   if(secsRemaining < 0 || secsRemaining > PeriodSeconds()) secsRemaining = 0;
   string candleTime = StringFormat("%02d:%02d", secsRemaining / 60, secsRemaining % 60);
   
   //--- Count TODAY's events by impact
   int todayHigh = 0;
   int todayMed = 0;
   int todayLow = 0;
   string nextEventStr = "—";
   color nextColor = TextColor;
   ENUM_IMPACT_LEVEL nextImpact = IMPACT_LOW;
   
   datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   datetime todayEnd = todayStart + 86400;
   
   for(int i = 0; i < g_eventCount; i++) {
      datetime evtLocal = g_events[i].eventTime + GetServerGMTOffset();
      
      //--- Count today's events
      if(evtLocal >= todayStart && evtLocal < todayEnd) {
         if(g_events[i].impact == IMPACT_HIGH) todayHigh++;
         else if(g_events[i].impact == IMPACT_MEDIUM) todayMed++;
         else if(g_events[i].impact == IMPACT_LOW) todayLow++;
      }
      
      //--- Find next upcoming event
      if(g_events[i].minutesUntil >= 0 && nextEventStr == "—") {
         int mins = g_events[i].minutesUntil;
         int hours = mins / 60;
         if(hours >= 24) nextEventStr = StringFormat("%dd %dh", hours / 24, hours % 24);
         else if(hours > 0) nextEventStr = StringFormat("%dh %dm", hours, mins % 60);
         else nextEventStr = StringFormat("%dm", mins);
         nextColor = GetImpactColor(g_events[i].impact);
         nextImpact = g_events[i].impact;
      }
   }
   
   //--- Position for right-bottom corner
   int yRow1 = 25;
   int yRow2 = 5;
   
   //--- Clean up all old SI labels
   ObjectDelete(0, INDICATOR_PREFIX + "SI_TodayLabel");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_HighCount");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_MedCount");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_NoEvents");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_Sep1");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_Sep2");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_NextLabel");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_NextTime");
   ObjectDelete(0, INDICATOR_PREFIX + "InfoRow1");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_RSI");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_Day");
   ObjectDelete(0, INDICATOR_PREFIX + "SI_ATR");
   
   //--- Row 1: Today's Summary
   string row1 = "TODAY:  ";
   
   if(todayHigh > 0) {
      row1 += IntegerToString(todayHigh) + " High";
      if(todayMed > 0) row1 += "  |  ";
   }
   
   if(todayMed > 0) {
      row1 += IntegerToString(todayMed) + " Med";
   }
   
   if(todayHigh == 0 && todayMed == 0) {
      row1 += "No major events";
   }
   
   row1 += "  |  Next: " + nextEventStr;
   
   //--- Draw Row 1 with impact-based color
   color row1Color = TextColor;
   if(todayHigh > 0) row1Color = HighImpactColor;
   else if(todayMed > 0) row1Color = MediumImpactColor;
   
   DrawLabelSI("InfoRow1", row1, 15, yRow1, row1Color);
   
   //--- Row 2: Trading essentials
   string row2 = StringFormat("Bar: %s  |  Spread: %.1f pips", candleTime, spreadPips);
   DrawLabelSI("InfoRow2", row2, 15, yRow2, TextColor);
}

//+------------------------------------------------------------------+
//| Helper for Symbol Info Labels                                     |
//+------------------------------------------------------------------+
void DrawLabelSI(string subName, string text, int x, int y, color clr) {
   string name = INDICATOR_PREFIX + subName;
   if(ObjectFind(0, name) < 0) {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return;
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Extended helper for Symbol Info Labels with anchor                |
//+------------------------------------------------------------------+
void DrawLabelSIEx(string subName, string text, int x, int y, color clr, ENUM_ANCHOR_POINT anchor) {
   string name = INDICATOR_PREFIX + subName;
   if(ObjectFind(0, name) < 0) {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return;
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Draw "No Events" message                                          |
//+------------------------------------------------------------------+
void DrawNoEventsMessage() {
   string msg = g_cacheValid ? "NO ECONOMIC EVENTS" : "LOADING CALENDAR DATA...";
   
   string name = INDICATOR_PREFIX + "NoData";
   if(ObjectFind(0, name) < 0) {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return;
   }
   
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_panelX + 20);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, g_chartHeight - 50);
   ObjectSetInteger(0, name, OBJPROP_COLOR, DimTextColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 11);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, name, OBJPROP_TEXT, msg);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| PRODUCTION: Historical markers with object pooling                |
//+------------------------------------------------------------------+
void DrawHistoricalMarkersPooled() {
   if(g_eventCount == 0) return;
   
   long chartOffset = g_validTimeOffset * 3600;
   long gmtOffset = (long)GetServerGMTOffset();
   datetime lookbackLimit = iTime(NULL, 0, MathMin(g_validLookbackBars, Bars - 1));
   
   g_markerPoolUsed = 0;
   
   for(int i = 0; i < g_eventCount && g_markerPoolUsed < MARKER_POOL_SIZE; i++) {
      if(g_events[i].minutesUntil >= 0) continue;
      if(g_events[i].eventTime < lookbackLimit) continue;
      
      if(!PassesRuntimeFilter(g_events[i].impact)) continue;
      
      //--- Corrected ActiveOnly: Exact base/quote match (not StringFind which matches US30 to USD)
      if(ReportActiveOnly) {
         string base = StringSubstr(Symbol(), 0, 3);
         string quote = StringSubstr(Symbol(), 3, 3);
         if(g_events[i].country != base && g_events[i].country != quote) continue;
      } else {
         if(!IsCurrencyEnabled(g_events[i].country)) continue;
      }
      
      datetime eventChartTime = (datetime)((long)g_events[i].eventTime + gmtOffset + chartOffset);
      int barIdx = iBarShift(NULL, 0, eventChartTime, true);
      
      if(barIdx < 0) continue;
      
      string markerName = g_markerPool[g_markerPoolUsed];
      color markerColor = GetImpactColor(g_events[i].impact);
      
      double price = iHigh(NULL, 0, barIdx) + (15 * Point * g_pointFactor);
      
      if(ObjectFind(0, markerName) < 0) {
         if(!ObjectCreate(0, markerName, OBJ_TEXT, 0, eventChartTime, price)) continue;
      } else {
         ObjectMove(0, markerName, 0, eventChartTime, price);
      }
      
      ObjectSetInteger(0, markerName, OBJPROP_COLOR, markerColor);
      ObjectSetInteger(0, markerName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, markerName, OBJPROP_FONT, "Wingdings 3");
      ObjectSetString(0, markerName, OBJPROP_TEXT, "n");
      ObjectSetInteger(0, markerName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, markerName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetString(0, markerName, OBJPROP_TOOLTIP, 
                      StringFormat("%s (%s)\nOutcome: %s (vs %s)", 
                                 g_events[i].title, g_events[i].country,
                                 (StringLen(g_events[i].actual) > 0 ? g_events[i].actual : "n/a"),
                                 g_events[i].forecast));
      
      g_markerPoolUsed++;
   }
   
   for(int i = g_markerPoolUsed; i < MARKER_POOL_SIZE; i++) {
      if(ObjectFind(0, g_markerPool[i]) >= 0) {
         ObjectSetInteger(0, g_markerPool[i], OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
   }
}

//+------------------------------------------------------------------+
//| PRODUCTION: Alert system with cooldown and spam prevention        |
//+------------------------------------------------------------------+
void ProcessAlertsWithCooldown() {
   if(!EnablePopupAlert && !EnableSoundAlert && !EnablePushNotify && !EnableEmailAlert)
      return;
   
   datetime now = TimeCurrent();
   
   if(now - g_lastAlertTriggerTime < ALERT_COOLDOWN_SEC) {
      return;
   }
   
   for(int i = 0; i < g_eventCount; i++) {
      if(g_events[i].impact < IMPACT_MEDIUM) continue;
      
      if(g_events[i].eventTime != g_lastAlertEventTime && g_events[i].minutesUntil > 0 && 
         g_events[i].minutesUntil < MathMax(g_validAlert1Min, g_validAlert2Min) + 5) {
         g_firstAlertFired = false;
         g_secondAlertFired = false;
         g_lastAlertEventTime = g_events[i].eventTime;
      }
      
      if(g_validAlert1Min > 0 && !g_firstAlertFired && 
         g_events[i].minutesUntil == g_validAlert1Min) {
         TriggerAlertSafe("FIRST ALERT", g_events[i]);
         g_firstAlertFired = true;
         g_lastAlertTriggerTime = now;
      }
      
      if(g_validAlert2Min > 0 && !g_secondAlertFired && 
         g_events[i].minutesUntil == g_validAlert2Min) {
         TriggerAlertSafe("FINAL ALERT", g_events[i]);
         g_secondAlertFired = true;
         g_lastAlertTriggerTime = now;
      }
      
      if(g_events[i].minutesUntil >= 0) break;
   }
}

//+------------------------------------------------------------------+
//| PRODUCTION: Safe alert trigger with error handling                |
//+------------------------------------------------------------------+
void TriggerAlertSafe(const string alertType, const CalendarEvent &evt) {
   string message = StringFormat("%s | %s in %d min | %s [%s] | Forecast: %s | Previous: %s",
                                 alertType, ImpactToString(evt.impact), evt.minutesUntil,
                                 evt.title, evt.country, evt.forecast, evt.previous);
   
   Print(INDICATOR_NAME, ": ", message);
   
   if(EnablePopupAlert) {
      ResetLastError();
      Alert(message);
      if(GetLastError() != 0) {
         Print(INDICATOR_NAME, ": Popup alert failed. Error: ", GetLastError());
      }
   }
   
   if(EnableSoundAlert) {
      string soundFile = GetImpactSound(evt.impact);
      if(!PlaySound(soundFile)) {
         Print(INDICATOR_NAME, ": Sound alert failed for ", soundFile);
      }
   }
   
   if(EnablePushNotify) {
      if(!SendNotification(message)) {
         Print(INDICATOR_NAME, ": Push notification failed. Error: ", GetLastError());
      }
   }
   
   if(EnableEmailAlert) {
      if(!SendMail(INDICATOR_NAME + " - " + alertType, message)) {
         Print(INDICATOR_NAME, ": Email alert failed. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Get sound file for impact level                                   |
//+------------------------------------------------------------------+
string GetImpactSound(const ENUM_IMPACT_LEVEL impact) {
   switch(impact) {
      case IMPACT_HIGH:    return(HighImpactSound);
      case IMPACT_MEDIUM:  return(MediumImpactSound);
      case IMPACT_LOW:     return(LowImpactSound);
      default:             return(LowImpactSound);
   }
}

//+------------------------------------------------------------------+
//| Get color for impact level                                        |
//+------------------------------------------------------------------+
color GetImpactColor(const ENUM_IMPACT_LEVEL impact) {
   switch(impact) {
      case IMPACT_HIGH:    return(HighImpactColor);
      case IMPACT_MEDIUM:  return(MediumImpactColor);
      case IMPACT_LOW:     return(LowImpactColor);
      case IMPACT_HOLIDAY: return(HolidayColor);
      default:             return(TextColor);
   }
}

//+------------------------------------------------------------------+
//| Convert impact level to string                                    |
//+------------------------------------------------------------------+
string ImpactToString(const ENUM_IMPACT_LEVEL impact) {
   switch(impact) {
      case IMPACT_HIGH:    return("HIGH");
      case IMPACT_MEDIUM:  return("MEDIUM");
      case IMPACT_LOW:     return("LOW");
      case IMPACT_HOLIDAY: return("HOLIDAY");
      default:             return("UNKNOWN");
   }
}

//+------------------------------------------------------------------+
//| Load runtime settings from GlobalVariables                        |
//+------------------------------------------------------------------+
void LoadSettings() {
   //--- Use Symbol name for persistence across timeframe changes
   //--- ChartID changes when timeframe changes, but Symbol stays the same
   string id = Symbol();
   
   if(GlobalVariableCheck(INDICATOR_PREFIX + "X_" + id))
      g_canvasX = (int)GlobalVariableGet(INDICATOR_PREFIX + "X_" + id);
      
   if(GlobalVariableCheck(INDICATOR_PREFIX + "Y_" + id))
      g_canvasY = (int)GlobalVariableGet(INDICATOR_PREFIX + "Y_" + id);
   
   if(GlobalVariableCheck(INDICATOR_PREFIX + "FILTER_H_" + id))
      g_filterShowHigh = (GlobalVariableGet(INDICATOR_PREFIX + "FILTER_H_" + id) > 0.5);
      
   if(GlobalVariableCheck(INDICATOR_PREFIX + "FILTER_M_" + id))
      g_filterShowMed = (GlobalVariableGet(INDICATOR_PREFIX + "FILTER_M_" + id) > 0.5);
      
   if(GlobalVariableCheck(INDICATOR_PREFIX + "FILTER_L_" + id))
      g_filterShowLow = (GlobalVariableGet(INDICATOR_PREFIX + "FILTER_L_" + id) > 0.5);
}

//+------------------------------------------------------------------+
//| Save runtime settings to GlobalVariables                          |
//+------------------------------------------------------------------+
void SaveSettings() {
   string id = Symbol();
   GlobalVariableSet(INDICATOR_PREFIX + "X_" + id, g_canvasX);
   GlobalVariableSet(INDICATOR_PREFIX + "Y_" + id, g_canvasY);
   GlobalVariableSet(INDICATOR_PREFIX + "FILTER_H_" + id, g_filterShowHigh ? 1.0 : 0.0);
   GlobalVariableSet(INDICATOR_PREFIX + "FILTER_M_" + id, g_filterShowMed ? 1.0 : 0.0);
   GlobalVariableSet(INDICATOR_PREFIX + "FILTER_L_" + id, g_filterShowLow ? 1.0 : 0.0);
}

//+------------------------------------------------------------------+
//| Print download troubleshooting help                               |
//+------------------------------------------------------------------+
void PrintDownloadHelp() {
   //--- Show Alert popup once to get user's attention
   if(!g_setupAlertShown) {
      string msg = "";
      
      //--- Check if DLLs are actually disabled
      if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) {
         msg = INDICATOR_NAME + " v" + INDICATOR_VERSION + ": Setup Required!\n\n" +
               "Please enable DLL imports to allow calendar data download.\n\n" +
               "Go to: Tools -> Options -> Expert Advisors\n" +
               "Check: 'Allow DLL imports'\n" +
               "Then restart MetaTrader.";
      } else {
         msg = INDICATOR_NAME + " v" + INDICATOR_VERSION + ": Download Failed!\n\n" +
               "Could not download calendar data.\n" +
               "Check your internet connection and try again.";
      }
      
      Alert(msg);
      g_setupAlertShown = true;
   }
   
   //--- Print detailed instructions to Experts tab
   Print(INDICATOR_NAME, ": ============= SETUP REQUIRED =============");
   Print(INDICATOR_NAME, ": No calendar data available.\n");
   Print(INDICATOR_NAME, ": DLL imports are required for data download.\n");
   Print(INDICATOR_NAME, ": HOW TO ENABLE:");
   Print("   1. Go to Tools -> Options -> Expert Advisors");
   Print("   2. Check 'Allow DLL imports'");
   Print("   3. Click OK");
   Print("   4. Restart MetaTrader\n");
   Print(INDICATOR_NAME, ": The indicator uses urlmon.dll (Windows built-in)");
   Print(INDICATOR_NAME, ": to download economic calendar data.\n");
   Print(INDICATOR_NAME, ": ===========================================");
}

//+------------------------------------------------------------------+
//| Calculate Server GMT Offset                                       |
//+------------------------------------------------------------------+
int GetServerGMTOffset() {
   static int offset = 0;
   static datetime lastCheck = 0;
   
   datetime server = TimeCurrent();
   if(server == 0) return(offset); // Guard against uninitialized time
   
   if(server - lastCheck > 60) { // Check once per minute
      datetime gmt = TimeGMT();
      if(gmt > 0) {
         offset = (int)(server - gmt);
         lastCheck = server;
      }
   }
   
   return(offset);
}

//+------------------------------------------------------------------+
//| END OF FFC v2.0 - Production Ready                               |
//+------------------------------------------------------------------+
 