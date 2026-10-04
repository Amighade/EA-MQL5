#ifndef TRANSACTION_HANDLER_MQH
#define TRANSACTION_HANDLER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Models/TransactionItem.mqh"
#include "../Utils/TradeBook.mqh"
#include "../Utils/AsyncTrade.mqh"
#include "../Utils/ProfilerUtils.mqh"
#include "StrategyBridge.mqh"

//+------------------------------------------------------------------+
//| ONE transaction inbox.                                           |
//| OnTradeTransaction() appends facts. The timer consumes them.     |
//+------------------------------------------------------------------+
TransactionItem g_transactionQueue[];
int             g_transactionHead = 0;

void QueueTransaction(TransactionItem &item)
  {
   ulong profStart = GetMicrosecondCount();
   int n = ArraySize(g_transactionQueue);
   ArrayResize(g_transactionQueue, n + 1);
   g_transactionQueue[n] = item;
   Profiler30Record(PROF30_QUEUE_TRANSACTION, profStart);
  }

void CompactTransactionQueue()
  {
   int total = ArraySize(g_transactionQueue);
   if(g_transactionHead <= 0) return;

   if(g_transactionHead >= total)
     {
      ArrayResize(g_transactionQueue, 0);
      g_transactionHead = 0;
      return;
     }

   if(g_transactionHead < 16 && g_transactionHead < total / 2)
      return;

   int remaining = total - g_transactionHead;
   for(int i = 0; i < remaining; i++)
      g_transactionQueue[i] = g_transactionQueue[g_transactionHead + i];
   ArrayResize(g_transactionQueue, remaining);
   g_transactionHead = 0;
  }

void HandleRequestTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.requestMagic != 0 && tx.requestMagic != state.magicNumber)
      return;

   int idx = FindItemByRequestId(state, tx.requestId);
   if(idx < 0)
      return;

   TradeItem item = state.items[idx];
   item.lastRetcode  = tx.retcode;
   item.resultTimeMs = GetTickCount64();

   if(IsAsyncAcceptedRetcode(tx.retcode))
     {
      if(tx.resultOrder > 0)
         item.orderTicket = tx.resultOrder;
      if(tx.resultDeal > 0)
         item.lastDealTicket = tx.resultDeal;
      item.actionStatus = ACTION_WAIT_CONFIRM;
     }
   else
     {
      // REV 30.01 deliberately records failure only. Retry/cleanup policy is
      // strategy policy and is not hidden inside the transaction handler.
      item.actionStatus = ACTION_FAILED;
     }
   state.items[idx] = item;
  }

void HandleOrderTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.orderTicket == 0) return;

   int idx = FindItemByOrderTicket(state, tx.orderTicket);

   if(tx.type == TRADE_TRANSACTION_ORDER_ADD ||
      tx.type == TRADE_TRANSACTION_ORDER_UPDATE)
     {
      if(!OrderSelect(tx.orderTicket))
         return;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) return;
      if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber) return;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      double price = OrderGetDouble(ORDER_PRICE_OPEN);

      if(idx < 0)
         idx = FindPlannedOrder(state, type, price);
      if(idx < 0)
         idx = AddTradeItem(state);

      TradeItem item = state.items[idx];
      item.kind          = ITEM_ORDER;
      item.orderTicket   = tx.orderTicket;
      item.orderType     = type;
      item.side          = (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT)
                           ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      item.targetPrice   = price;
      item.targetLot     = OrderGetDouble(ORDER_VOLUME_CURRENT);
      if(item.originalLot <= 0.0) item.originalLot = item.targetLot;
      item.openPrice     = price;
      item.volume        = item.targetLot;
      item.currentSL     = OrderGetDouble(ORDER_SL);
      item.currentTP     = OrderGetDouble(ORDER_TP);
      item.brokerPresent = true;

      if(item.action == ACTION_PLACE)
        {
         item.action       = ACTION_NONE;
         item.actionStatus = ACTION_IDLE;
         item.requestId    = 0;
        }

      // If cleanup started while the PLACE request was already in flight,
      // the newly-created order is immediately scheduled for deletion.
      if(state.lifecycle == GRID_CLEANUP && item.cleanupAfterConfirm)
        {
         item.cleanupAfterConfirm = false;
         item.action              = ACTION_DELETE;
         item.actionStatus        = ACTION_READY;
        }
      state.items[idx] = item;
      return;
     }

   if(tx.type == TRADE_TRANSACTION_ORDER_DELETE)
     {
      if(idx < 0) return;

      TradeItem item = state.items[idx];
      item.brokerPresent = false;

      // Explicit delete: deletion is now confirmed.
      if(item.action == ACTION_DELETE &&
         (item.actionStatus == ACTION_WAIT_CONFIRM ||
          item.actionStatus == ACTION_WAIT_RESULT ||
          state.lifecycle == GRID_CLEANUP))
        {
         if(item.replaceAfterDelete && state.lifecycle != GRID_CLEANUP)
           {
            item.orderTicket        = 0;
            item.targetPrice        = item.replacementPrice;
            item.targetLot          = item.replacementLot;
            item.requestedPrice     = item.replacementPrice;
            item.requestedLot       = item.replacementLot;
            item.requestedSL        = item.replacementSL;
            item.requestedTP        = item.replacementTP;
            item.replaceAfterDelete = false;
            item.action             = ACTION_PLACE;
            item.actionStatus       = ACTION_READY;
            item.requestId          = 0;
            state.items[idx]       = item;
           }
         else
            RemoveTradeItem(state, idx);
        }
      else
         state.items[idx] = item;

      // If this order was filled, DEAL_ADD converts the same logical item to
      // ITEM_POSITION. Therefore an unexplained ORDER_DELETE is not removed
      // here; reconciliation can resolve it after the transaction stream settles.
     }
  }

bool HandleDealTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.dealTicket == 0) return true;

   ulong profHistoryStart = GetMicrosecondCount();
   bool historySelected = HistoryDealSelect(tx.dealTicket);
   Profiler30Record(PROF30_HISTORY_DEAL_SELECT, profHistoryStart);
   if(!historySelected)
      return false;

   long magic = HistoryDealGetInteger(tx.dealTicket, DEAL_MAGIC);
   if(magic != state.magicNumber)
      return true;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tx.dealTicket, DEAL_ENTRY);

   if(entry == DEAL_ENTRY_IN)
     {
      int idx = FindItemByOrderTicket(state, tx.orderTicket);
      if(idx < 0)
         idx = FindItemByPositionTicket(state, tx.positionTicket);
      if(idx < 0)
         idx = AddTradeItem(state);

      TradeItem item = state.items[idx];
      item.kind           = ITEM_POSITION;
      item.orderTicket    = tx.orderTicket;
      item.positionTicket = tx.positionTicket;
      item.lastDealTicket = tx.dealTicket;
      item.side           = (tx.dealType == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      item.openPrice      = tx.price;
      item.volume         = tx.volume;
      item.targetLot      = tx.volume;
      if(item.originalLot <= 0.0) item.originalLot = tx.volume;
      item.brokerPresent  = true;
      item.action         = ACTION_NONE;
      item.actionStatus   = ACTION_IDLE;
      item.requestId      = 0;
      state.items[idx]    = item;

      if(state.lifecycle == GRID_CLEANUP)
        {
         state.items[idx].action       = ACTION_CLOSE;
         state.items[idx].actionStatus = ACTION_READY;
        }
      else
        {
         state.lifecycle = GRID_ACTIVE;
         ulong profStrategyStart = GetMicrosecondCount();
         Strategy_OnEntryFill(state, idx, tx);
         Profiler30Record(PROF30_STRATEGY_ON_ENTRY_FILL, profStrategyStart);
        }
      return true;
     }

   if(entry == DEAL_ENTRY_OUT ||
      entry == DEAL_ENTRY_OUT_BY ||
      entry == DEAL_ENTRY_INOUT)
     {
      int idx = FindItemByPositionTicket(state, tx.positionTicket);
      if(idx >= 0)
        {
         ulong profStrategyStart = GetMicrosecondCount();
         Strategy_OnExitDeal(state, idx, tx);
         Profiler30Record(PROF30_STRATEGY_ON_EXIT_DEAL, profStrategyStart);

         if(PositionSelectByTicket(tx.positionTicket))
           {
            state.items[idx].volume        = PositionGetDouble(POSITION_VOLUME);
            state.items[idx].openPrice     = PositionGetDouble(POSITION_PRICE_OPEN);
            state.items[idx].currentSL     = PositionGetDouble(POSITION_SL);
            state.items[idx].currentTP     = PositionGetDouble(POSITION_TP);
            state.items[idx].brokerPresent = true;
           }
         else
            RemoveTradeItem(state, idx);
        }
      return true;
     }

   return true;
  }

void HandlePositionTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.positionTicket == 0) return;
   int idx = FindItemByPositionTicket(state, tx.positionTicket);
   if(idx < 0) return;

   if(!PositionSelectByTicket(tx.positionTicket))
     {
      state.items[idx].brokerPresent = false;
      return;
     }

   state.items[idx].kind          = ITEM_POSITION;
   state.items[idx].side          = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   state.items[idx].openPrice     = PositionGetDouble(POSITION_PRICE_OPEN);
   state.items[idx].volume        = PositionGetDouble(POSITION_VOLUME);
   state.items[idx].currentSL     = PositionGetDouble(POSITION_SL);
   state.items[idx].currentTP     = PositionGetDouble(POSITION_TP);
   state.items[idx].brokerPresent = true;
  }

//+------------------------------------------------------------------+
//| ONE readable dispatcher -- this is the black box made explicit.  |
//+------------------------------------------------------------------+
bool HandleTransaction(GridState &state, TransactionItem &tx)
  {
   ulong profStart = GetMicrosecondCount();

   if(tx.type == TRADE_TRANSACTION_REQUEST)
     {
      ulong profChild = GetMicrosecondCount();
      HandleRequestTransaction(state, tx);
      Profiler30Record(PROF30_HANDLE_REQUEST_TRANSACTION, profChild);
      Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
      return true;
     }

   // Non-request transaction types can be filtered by symbol immediately.
   if(tx.symbol != "" && tx.symbol != _Symbol)
     {
      Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
      return true;
     }

   if(tx.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong profChild = GetMicrosecondCount();
      bool handled = HandleDealTransaction(state, tx);
      Profiler30Record(PROF30_HANDLE_DEAL_TRANSACTION, profChild);
      Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
      return handled;
     }

   if(tx.type == TRADE_TRANSACTION_ORDER_ADD ||
      tx.type == TRADE_TRANSACTION_ORDER_UPDATE ||
      tx.type == TRADE_TRANSACTION_ORDER_DELETE)
     {
      ulong profChild = GetMicrosecondCount();
      HandleOrderTransaction(state, tx);
      Profiler30Record(PROF30_HANDLE_ORDER_TRANSACTION, profChild);
      Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
      return true;
     }

   if(tx.type == TRADE_TRANSACTION_POSITION)
     {
      ulong profChild = GetMicrosecondCount();
      HandlePositionTransaction(state, tx);
      Profiler30Record(PROF30_HANDLE_POSITION_TRANSACTION, profChild);
      Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
      return true;
     }

   Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
   return true;
  }

void ProcessTransactionQueue(GridState &state, ulong frameStartUs, ulong budgetUs)
  {
   ulong profStart = GetMicrosecondCount();
   int processed = 0;
   int frameTotal = ArraySize(g_transactionQueue);

   while(g_transactionHead < frameTotal)
     {
      if((GetMicrosecondCount() - frameStartUs) >= budgetUs)
         break;
      if(processed >= InpSchedulerMaxTransactionsPerFrame)
         break;

      TransactionItem tx = g_transactionQueue[g_transactionHead];

      if(!HandleTransaction(state, tx))
        {
         // History not locally available yet. Re-append the same immutable
         // fact so unrelated later events are not blocked behind it.
         tx.historyRetries++;
         if(tx.historyRetries < 3)
            QueueTransaction(tx);
         else
           {
            state.lifecycle = GRID_FAULT;
            state.safetyStopReason = "DEAL_HISTORY_UNAVAILABLE";
           }
        }

      g_transactionHead++;
      processed++;
     }

   ulong profCompactStart = GetMicrosecondCount();
   CompactTransactionQueue();
   Profiler30Record(PROF30_COMPACT_TRANSACTION_QUEUE, profCompactStart);
   Profiler30Record(PROF30_PROCESS_TRANSACTION_QUEUE, profStart);
  }

void ResetTransactionQueue()
  {
   ArrayResize(g_transactionQueue, 0);
   g_transactionHead = 0;
  }

#endif
