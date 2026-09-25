//+------------------------------------------------------------------+
//| HedgeGrid.mq5                                                    |
//| REV 30.01 - SIMPLE ASYNC DATA-FLOW REFERENCE                    |
//|                                                                  |
//| Purpose of this revision:                                       |
//|   - make the broker/event path readable before strategy is added |
//|   - one GridState                                               |
//|   - one GridState.items[] array for orders + positions           |
//|   - one separate transactionQueue[] inbox                        |
//|   - one HandleTransaction() dispatcher                           |
//|   - all broker actions use OrderSendAsync()                      |
//|                                                                  |
//| Rev 22.2 strategy source is included under Reference_Rev22_2/.   |
//| Strategy hooks are intentionally empty in Rev 30.01.             |
//+------------------------------------------------------------------+
#property copyright "HedgeGrid EA"
#property version   "30.01"
#property strict

#include "Inputs.mqh"
#include "Models/GridState.mqh"
#include "Models/TransactionItem.mqh"
#include "Utils/Identity.mqh"
#include "Utils/TradeBook.mqh"
#include "Utils/AsyncTrade.mqh"
#include "Engines/StrategyBridge.mqh"
#include "Engines/TransactionHandler.mqh"
#include "Engines/ReconcileEngine.mqh"
#include "Engines/CleanupEngine.mqh"
#include "Engines/Scheduler.mqh"

GridState g_state;

int OnInit()
  {
   ResetGridState(g_state);
   g_state.magicNumber = (InpMagicNumber == 0) ? GenerateMagicNumber() : InpMagicNumber;

   InitAsyncTrade();
   RebuildTradeBookFromTerminal(g_state);
   InitScheduler();

   if(!EventSetMillisecondTimer(InpSchedulerHeartbeatMs))
     {
      PrintFormat("[REV30.01] EventSetMillisecondTimer(%d) failed. err=%d",
                  InpSchedulerHeartbeatMs, GetLastError());
      return INIT_FAILED;
     }

   PrintFormat("[REV30.01] started. Magic=%d Lifecycle=%d Items=%d",
               g_state.magicNumber,
               (int)g_state.lifecycle,
               ArraySize(g_state.items));

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   PrintFormat("[REV30.01] stopped. Reason=%d", reason);

   // Deliberately NO hidden synchronous close/delete here.
   // Deinitialization policy will be added only after this architecture is reviewed.
  }

//+------------------------------------------------------------------+
//| OnTradeTransaction = recorder only.                              |
//| Every callback creates ONE TransactionItem and appends it to the |
//| inbox. No strategy, scan, history lookup or broker action here.  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   TransactionItem item;
   ResetTransactionItem(item);

   item.type           = trans.type;
   item.symbol         = (trans.symbol != "") ? trans.symbol : request.symbol;
   item.orderTicket    = trans.order;
   item.positionTicket = trans.position;
   item.dealTicket     = trans.deal;
   item.orderType      = trans.order_type;
   item.dealType       = trans.deal_type;
   item.price          = trans.price;
   item.volume         = trans.volume;

   item.requestId      = result.request_id;
   item.retcode        = (int)result.retcode;
   item.resultOrder    = result.order;
   item.resultDeal     = result.deal;

   item.requestAction   = request.action;
   item.requestMagic    = (long)request.magic;
   item.requestOrder    = request.order;
   item.requestPosition = request.position;
   item.requestType     = request.type;
   item.requestPrice    = request.price;
   item.requestVolume   = request.volume;
   item.requestSL       = request.sl;
   item.requestTP       = request.tp;
   item.historyRetries  = 0;

   QueueTransaction(item);
  }

void OnTimer()
  {
   RunScheduler30(g_state);
  }
