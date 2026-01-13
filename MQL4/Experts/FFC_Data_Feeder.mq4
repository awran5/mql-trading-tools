//+------------------------------------------------------------------+
//|                                              FFC_Data_Feeder.mq4 |
//|                                         Copyright © 2025, awran5 |
//|                             https://www.mql5.com/en/users/awran5 |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, awran5"
#property link      "https://github.com/awran5/mql-trading-tools"
#property version   "1.00"
#property strict
#property description "FFC Data Feeder v1.0"
#property description "Companion EA for FFC Canvas Economic Calendar"
#property description " "
#property description "Downloads Forex Factory calendar data using native WebRequest."
#property description "No DLL required. MQL5 Market compliant. Set and Forget."
#property description " "
#property description "Setup: Enable WebRequest for https://nfs.faireconomy.media/"

//--- Input Parameters
input int      UpdateIntervalHrs  = 4;       // Update Interval (Hours)
input bool     ShowStatusOnChart  = true;    // Show Download Status on Chart

//--- Constants
#define JSON_URL              "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
#define CACHE_NAME            "FFC_calendar_cache.json"
#define LOG_PREFIX            "[FFC-Feeder] "
#define REQUEST_TIMEOUT_MS    10000

//--- Global Variables
datetime g_lastUpdate = 0;
string   g_statusMessage = "Initializing...";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   Print(LOG_PREFIX, "Data Feeder v1.0 Initializing...");
   
   // Initial download attempt
   PerformDownload();
   
   // Set timer for periodic updates
   EventSetTimer(UpdateIntervalHrs * 3600);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
   Comment("");
   Print(LOG_PREFIX, "Data Feeder stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer() {
   PerformDownload();
}

//+------------------------------------------------------------------+
//| Expert tick function (required for tester)                       |
//+------------------------------------------------------------------+
void OnTick() {
   // This EA is a utility - it does not trade
   // OnTick is here only to satisfy the Strategy Tester requirement
}

//+------------------------------------------------------------------+
//| Tester function - returns success for MQL5 Market validation     |
//+------------------------------------------------------------------+
double OnTester() {
   // Return a positive value to indicate successful test
   // This is a utility EA, not a trading EA
   return(1.0);
}

//+------------------------------------------------------------------+
//| Downloads JSON using WebRequest and saves to file                |
//| NOTE: Simple implementation - no retry logic needed.             |
//| On failure, it will retry on the next timer interval.            |
//+------------------------------------------------------------------+
void PerformDownload() {
   uchar data[], result[];
   string headers;
   int res;
   
   Print(LOG_PREFIX, "Downloading calendar data...");
   
   res = WebRequest("GET", JSON_URL, NULL, NULL, REQUEST_TIMEOUT_MS, data, 0, result, headers);
   
   if(res == -1) {
      int err = GetLastError();
      if(err == 4060) {
         g_statusMessage = "ERROR: URL not allowed!";
         SendWebAlert();
      } else {
         g_statusMessage = "ERROR: Download failed (" + IntegerToString(err) + ")";
         Print(LOG_PREFIX, "Download failed. Will retry in ", UpdateIntervalHrs, " hours.");
      }
   }
   else if(res == 200) {
      string responseString = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      if(SaveToFile(responseString)) {
         g_lastUpdate = TimeCurrent();
         g_statusMessage = "OK: " + TimeToString(g_lastUpdate, TIME_DATE|TIME_MINUTES);
         Print(LOG_PREFIX, "Success! Saved to ", CACHE_NAME);
      } else {
         g_statusMessage = "ERROR: File write failed";
         Print(LOG_PREFIX, "Failed to write file!");
      }
   }
   else {
      g_statusMessage = "ERROR: HTTP " + IntegerToString(res);
      Print(LOG_PREFIX, "Server error: ", res);
   }
   
   if(ShowStatusOnChart) UpdateChartComment();
}

//+------------------------------------------------------------------+
//| Saves string data to local MQL4/Files folder                     |
//+------------------------------------------------------------------+
bool SaveToFile(const string &content) {
   int handle = FileOpen(CACHE_NAME, FILE_WRITE|FILE_BIN);
   if(handle != INVALID_HANDLE) {
      uchar buffer[];
      StringToCharArray(content, buffer, 0, -1, CP_UTF8);
      FileWriteArray(handle, buffer, 0, ArraySize(buffer) - 1);
      FileClose(handle);
      return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Sends a formatted alert for setup instructions                   |
//+------------------------------------------------------------------+
void SendWebAlert() {
   string msg = "FFC DATA FEEDER SETUP REQUIRED:\n\n" +
                "1. Go to Tools -> Options -> Expert Advisors\n" +
                "2. Check 'Allow WebRequest for listed URL'\n" +
                "3. Add: https://nfs.faireconomy.media/\n\n" +
                "The EA cannot download data until this is done.";
                
   Alert(msg);
   Print(LOG_PREFIX, msg);
}

//+------------------------------------------------------------------+
//| Updates the chart comment for visibility                         |
//+------------------------------------------------------------------+
void UpdateChartComment() {
   string comment = "FFC Data Feeder | " + g_statusMessage;
   Comment(comment);
}
