//+------------------------------------------------------------------+
//| HistoryLogger.mqh                                                 |
//| CSV file logging for history and strategy survey                 |
//| Template — column structure defined, data population pending     |
//+------------------------------------------------------------------+
#pragma once

#include "../Inputs.mqh"

// File handle — opened once in InitHistoryLogger, closed in DeinitHistoryLogger
int g_historyFileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| CSV column headers                                                |
//+------------------------------------------------------------------+
string HISTORY_HEADERS = "DateTime,EventType,Symbol,Timeframe,Price,Direction,"
                         "Lot,PassCounter,BlockLot,BasketProfit,SessionActive,"
                         "MarginFree,Notes";

//+------------------------------------------------------------------+
//| Initialize logger — open file and write headers if new file      |
//+------------------------------------------------------------------+
bool InitHistoryLogger()
  {
   if(!InpEnableHistoryLog) return true;

   // Open file in common folder, append mode
   g_historyFileHandle = FileOpen(InpHistoryLogFile,
                                  FILE_WRITE | FILE_READ | FILE_CSV | FILE_COMMON | FILE_ANSI,
                                  ',');

   if(g_historyFileHandle == INVALID_HANDLE)
     {
      PrintFormat("[HedgeGrid][HISTORY_LOG] Failed to open log file: %s Error: %d",
                  InpHistoryLogFile, GetLastError());
      return false;
     }

   // If file is new (size = 0), write headers
   if(FileTell(g_historyFileHandle) == 0)
      FileWrite(g_historyFileHandle, HISTORY_HEADERS);

   // Move to end for appending
   FileSeek(g_historyFileHandle, 0, SEEK_END);

   PrintFormat("[HedgeGrid][HISTORY_LOG] Log file ready: %s", InpHistoryLogFile);
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
