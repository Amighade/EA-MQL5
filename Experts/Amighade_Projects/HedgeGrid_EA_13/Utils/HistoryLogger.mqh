//+------------------------------------------------------------------+
//| HistoryLogger.mqh                                                 |
//| CSV file logging for history and strategy survey                 |
//| One file per calendar day — named by date so old files are easy  |
//| to find and delete manually; rolls over automatically even if    |
//| the EA runs continuously across a midnight boundary.              |
//+------------------------------------------------------------------+
#ifndef HISTORY_LOGGER_MQH
#define HISTORY_LOGGER_MQH

#include "../Inputs.mqh"

// File handle — opened once in InitHistoryLogger, closed in DeinitHistoryLogger,
// reopened by LogHistory on a date rollover
int    g_historyFileHandle = INVALID_HANDLE;
string g_historyLogDate    = "";   // which date's file is currently open

//+------------------------------------------------------------------+
//| CSV column headers                                                |
//+------------------------------------------------------------------+
string HISTORY_HEADERS = "DateTime,EventType,Symbol,Timeframe,Price,Direction,"
                         "Lot,PassCounter,BlockLot,BasketProfit,SessionActive,"
                         "MarginFree,Notes";

//+------------------------------------------------------------------+
//| Builds today's filename, e.g. HedgeGrid_History_2026-08-30.csv   |
//+------------------------------------------------------------------+
string GetHistoryLogFileName()
  {
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(dateStr, ".", "-");
   return "HedgeGrid_History_" + dateStr + ".csv";
  }

//+------------------------------------------------------------------+
//| Initialize logger — open today's file and write headers if new   |
//+------------------------------------------------------------------+
bool InitHistoryLogger()
  {
   if(!InpEnableHistoryLog) return true;

   g_historyLogDate = TimeToString(TimeCurrent(), TIME_DATE);
   string fname = GetHistoryLogFileName();

   // Open file in common folder, append mode
   g_historyFileHandle = FileOpen(fname,
                                  FILE_WRITE | FILE_READ | FILE_CSV | FILE_COMMON | FILE_ANSI,
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
//| changes, so a VPS running for weeks still gets one file per day.  |
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
      string fname = GetHistoryLogFileName();

      g_historyFileHandle = FileOpen(fname,
                                     FILE_WRITE | FILE_READ | FILE_CSV | FILE_COMMON | FILE_ANSI,
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