//+------------------------------------------------------------------+
//| HistoryLogger.mqh                                                 |
//| CSV file logging for history and strategy survey                 |
//| One file per calendar day, saved inside a dedicated subfolder     |
//| (Files\HedgeGrid_History\) so it's easy to find rather than       |
//| scattered loose at the top level of Files\. Rolls over            |
//| automatically even if the EA runs continuously across a midnight  |
//| boundary.                                                          |
//+------------------------------------------------------------------+
#ifndef HISTORY_LOGGER_MQH
#define HISTORY_LOGGER_MQH

#include "../Inputs.mqh"

// File handle — opened once in InitHistoryLogger, closed in DeinitHistoryLogger,
// reopened by LogHistory on a date rollover
int    g_historyFileHandle = INVALID_HANDLE;
string g_historyLogDate    = "";   // which date's file is currently open

// Dedicated subfolder inside Files\ — keeps all history CSVs in one place
string HISTORY_LOG_FOLDER = "HedgeGrid_History";

//+------------------------------------------------------------------+
//| CSV column headers                                                |
//+------------------------------------------------------------------+
string HISTORY_HEADERS = "DateTime,EventType,Symbol,Timeframe,Price,Direction,"
                         "Lot,PassCounter,BlockLot,BasketProfit,SessionActive,"
                         "MarginFree,Notes";

//+------------------------------------------------------------------+
//| Ensures the dedicated log folder exists. FolderCreate returning   |
//| false when the folder already exists is expected, not an error   |
//| (error code 5019) — only warn on anything else.                   |
//+------------------------------------------------------------------+
void EnsureHistoryLogFolder()
  {
   if(!FolderCreate(HISTORY_LOG_FOLDER))
     {
      int err = GetLastError();
      if(err != 0 && err != 5019)
         PrintFormat("[HedgeGrid][HISTORY_LOG] FolderCreate warning: %d", err);
     }
  }

//+------------------------------------------------------------------+
//| Builds today's path, e.g. HedgeGrid_History\2026-08-30.csv       |
//+------------------------------------------------------------------+
string GetHistoryLogFileName()
  {
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(dateStr, ".", "-");
   return HISTORY_LOG_FOLDER + "\\" + dateStr + ".csv";
  }

//+------------------------------------------------------------------+
//| Initialize logger — open today's file and write headers if new   |
//+------------------------------------------------------------------+
bool InitHistoryLogger()
  {
   if(!InpEnableHistoryLog) return true;

   EnsureHistoryLogFolder();

   g_historyLogDate = TimeToString(TimeCurrent(), TIME_DATE);
   string fname = GetHistoryLogFileName();

   // Open file in dedicated subfolder, append mode
   g_historyFileHandle = FileOpen(fname,
                                  FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI,
                                  ',');

   if(g_historyFileHandle == INVALID_HANDLE)
     {
      PrintFormat("[HedgeGrid][HISTORY_LOG] Failed to open log file: %s Error: %d",
                  fname, GetLastError());
      return false;
     }

   // If file is new (size = 0), write headers
   if(FileTell(g_historyFileHandle) == 0)
      FileWrite(g_historyFileHandle, HISTORY_HEADERS);

   // Move to end for appending
   FileSeek(g_historyFileHandle, 0, SEEK_END);

   PrintFormat("[HedgeGrid][HISTORY_LOG] Log file ready: %s", fname);
   return true;
  }

//+------------------------------------------------------------------+
//| Close logger — call in OnDeinit                                   |
//+------------------------------------------------------------------+
void DeinitHistoryLogger()
  {
   if(g_historyFileHandle != INVALID_HANDLE)
     {
      FileClose(g_historyFileHandle);
      g_historyFileHandle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Write one event row to CSV                                        |
//| All parameters passed explicitly — no hidden state access        |
//| Rolls over to a new dated file the moment the calendar date       |
//| changes, so a VPS running for weeks still gets one file per day,  |
//| always inside the same dedicated subfolder.                       |
//+------------------------------------------------------------------+
void LogHistory(string eventType,
                double price,
                string direction,
                double lot,
                int    passCounter,
                double blockLot,
                double basketProfit,
                bool   sessionActive,
                double marginFree,
                string notes = "")
  {
   if(!InpEnableHistoryLog) return;

   string today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today != g_historyLogDate)
     {
      if(g_historyFileHandle != INVALID_HANDLE)
         FileClose(g_historyFileHandle);

      g_historyLogDate = today;

      EnsureHistoryLogFolder();

      string fname = GetHistoryLogFileName();

      g_historyFileHandle = FileOpen(fname,
                                     FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI,
                                     ',');

      if(g_historyFileHandle == INVALID_HANDLE)
        {
         PrintFormat("[HedgeGrid][HISTORY_LOG] Failed to roll over to: %s Error: %d",
                     fname, GetLastError());
         return;
        }

      if(FileTell(g_historyFileHandle) == 0)
         FileWrite(g_historyFileHandle, HISTORY_HEADERS);

      FileSeek(g_historyFileHandle, 0, SEEK_END);

      PrintFormat("[HedgeGrid][HISTORY_LOG] Rolled over to: %s", fname);
     }

   if(g_historyFileHandle == INVALID_HANDLE) return;

   string row = StringFormat("%s,%s,%s,%s,%.2f,%s,%.2f,%d,%.2f,%.2f,%s,%.2f,%s",
                             TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                             eventType,
                             _Symbol,
                             EnumToString((ENUM_TIMEFRAMES)_Period),
                             price,
                             direction,
                             lot,
                             passCounter,
                             blockLot,
                             basketProfit,
                             sessionActive ? "YES" : "NO",
                             marginFree,
                             notes);

   FileWrite(g_historyFileHandle, row);
   FileFlush(g_historyFileHandle); // Flush immediately so data is not lost on crash
  }

#endif