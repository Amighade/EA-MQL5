//+------------------------------------------------------------------+
//| HedgeGrid.mq5                                                    |
//| REV 30.04 - SIMPLE ASYNC DATA-FLOW REFERENCE                    |
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
//| Strategy hooks are intentionally empty in Rev 30.04.             |
//+------------------------------------------------------------------+
#property copyright "HedgeGrid EA"
#property version   "30.04"
#property strict

#include "Inputs.mqh"
#include "Models/GridState.mqh"
#include "Models/TransactionItem.mqh"
#include "Utils/Identity.mqh"
#include "Utils/TradeBook.mqh"
#include "Utils/ProfilerUtils.mqh"
#include "Utils/AsyncTrade.mqh"
#include "Engines/StrategyBridge.mqh"
#include "Engines/TransactionHandler.mqh"
#include "Engines/ReconcileEngine.mqh"
#include "Engines/CleanupEngine.mqh"
#include "Engines/Scheduler.mqh"

GridState g_state;

int OnInit()
  {
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING ||
      AccountInfoInteger(ACCOUNT_FIFO_CLOSE))
     {
      Print("[REV30.04] Requires a hedging account without FIFO close restrictions.");
      return INIT_FAILED;
     }
   if(InpSchedulerHeartbeatMs < 1 || InpSchedulerBudgetMs < 1 ||
      InpFastTierIntervalMs < 1 || InpMediumTierIntervalMs < 1 ||
      InpBackgroundTierIntervalMs < 1 || InpSchedulerMaxTransactionsPerFrame < 1 ||
      InpCleanupAsyncBatch < 1 || InpSafetyRetryAttempts < 1 ||
      InpSafetyRetryDelayMs < 0 || InpAsyncConfirmGraceMs < 0 ||
      InpAsyncResultTimeoutMs < 1 || InpAsyncLiveConfirmTimeoutMs < 1)
      return INIT_PARAMETERS_INCORRECT;

   ResetGridState(g_state);
   g_state.magicNumber = (InpMagicNumber == 0) ? GenerateMagicNumber30() : InpMagicNumber;

   InitAsyncTrade();
   InitScheduler30();
   g_state.needsGridVerification = true;
   ReconcileTradeItems(g_state);

   if(!EventSetMillisecondTimer(InpSchedulerHeartbeatMs))
     {
      PrintFormat("[REV30.04] EventSetMillisecondTimer(%d) failed. err=%d",
                  InpSchedulerHeartbeatMs, GetLastError());
      return INIT_FAILED;
     }

   PrintFormat("[REV30.04] started. Magic=%d Lifecycle=%d Items=%d",
               g_state.magicNumber,
               (int)g_state.lifecycle,
               ArraySize(g_state.items));

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   PrintFormat("[REV30.04] stopped. Reason=%d", reason);

   // Deliberately NO hidden synchronous close/delete here.
   // Deinitialization policy will be added only after this architecture is reviewed.
  }

//+------------------------------------------------------------------+
//| OnTradeTransaction = recorder only.                              |
//| Every callback creates ONE TransactionItem and appends it to the |
//| inbox. No strategy, scan, history lookup or broker action here.  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   TransactionItem item;
   ResetTransactionItem(item);
   item.type = trans.type;
   if(trans.type == TRADE_TRANSACTION_REQUEST)
     {
      item.symbol = request.symbol;
      item.requestMagic = (long)request.magic;
      item.requestId = result.request_id;
      item.retcode = (int)result.retcode;
      item.resultOrder = result.order;
     }
   else
     {
      item.symbol = trans.symbol;
      item.orderTicket = trans.order;
      item.positionTicket = trans.position;
      item.dealTicket = trans.deal;
      item.dealType = trans.deal_type;
      item.price = trans.price;
      item.volume = trans.volume;
     }
   QueueTransaction(item);
  }

void OnTimer()
  {
   RunScheduler30(g_state);
  }
