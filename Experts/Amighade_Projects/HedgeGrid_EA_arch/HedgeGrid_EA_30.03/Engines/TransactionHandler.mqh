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

//+------------------------------------------------------------------+
//| true  = handled / intentionally ignored                          |
//| false = required broker data is not ready; retry later           |
//+------------------------------------------------------------------+
bool HandleRequestTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.requestMagic != 0 && tx.requestMagic != state.magicNumber)
      return true;

   int idx = FindItemByRequestId(state, tx.requestId);
   if(idx < 0)
      return true;

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
      item.actionStatus = ACTION_FAILED;
     }

   state.items[idx] = item;
   return true;
  }

bool HandleOrderTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.orderTicket == 0)
      return true;

   int idx = FindItemByOrderTicket(state, tx.orderTicket);

   //===============================================================
   // ORDER EXISTS / CHANGED
   //===============================================================
   if(tx.type == TRADE_TRANSACTION_ORDER_ADD ||
      tx.type == TRADE_TRANSACTION_ORDER_UPDATE)
     {
      // This transaction needs the live order record.
      if(!OrderSelect(tx.orderTicket))
         return false;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         return true;

      if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber)
         return true;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      double price = OrderGetDouble(ORDER_PRICE_OPEN);

      // Prefer the existing strategy item before creating a new one.
      if(idx < 0)
         idx = FindPlannedOrder(state, type, price);

      if(idx < 0)
         idx = AddTradeItem(state);

      TradeItem item = state.items[idx];

      item.kind           = ITEM_ORDER;
      item.orderTicket    = tx.orderTicket;
      item.orderType      = type;
      item.side           = (type == ORDER_TYPE_BUY_STOP ||
                             type == ORDER_TYPE_BUY_LIMIT)
                            ? POSITION_TYPE_BUY
                            : POSITION_TYPE_SELL;
      item.targetPrice    = price;
      item.targetLot      = OrderGetDouble(ORDER_VOLUME_CURRENT);
      item.openPrice      = price;
      item.volume         = item.targetLot;
      item.currentSL      = OrderGetDouble(ORDER_SL);
      item.currentTP      = OrderGetDouble(ORDER_TP);
      item.brokerPresent  = true;
      item.reconcilePending = false;
      item.reconcileMisses  = 0;

      if(item.originalLot <= 0.0)
         item.originalLot = item.targetLot;

      // Broker data only confirms reality. It does not create a new
      // command. A completed PLACE therefore returns to NONE / IDLE.
      if(item.action == ACTION_PLACE)
        {
         item.action              = ACTION_NONE;
         item.actionStatus        = ACTION_IDLE;
         item.requestId           = 0;
        }

      state.items[idx] = item;
      return true;
     }

   //===============================================================
   // ORDER DISAPPEARED
   //===============================================================
   if(tx.type == TRADE_TRANSACTION_ORDER_DELETE)
     {
      if(idx < 0)
         return true;

      TradeItem item = state.items[idx];
      item.brokerPresent = false;

      // Explicit DELETE: disappearance is the confirmation we wanted.
      if(item.action == ACTION_DELETE &&
         (item.actionStatus == ACTION_WAIT_CONFIRM ||
          item.actionStatus == ACTION_WAIT_RESULT ||
          state.lifecycle == GRID_CLEANUP))
        {
         ConfirmReplacementOrRemove(state, idx);
         return true;
        }

      // Otherwise this can be a fill transition. Keep the same logical
      // item until reconciliation / DEAL_ADD resolves ORDER -> POSITION.
      item.reconcilePending = true;
      item.reconcileMisses  = 0;
      state.items[idx]      = item;
      return true;
     }

   return true;
  }

bool HandleDealTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.dealTicket == 0)
      return true;

   ulong profHistoryStart = GetMicrosecondCount();
   bool historySelected = HistoryDealSelect(tx.dealTicket);
   Profiler30Record(PROF30_HISTORY_DEAL_SELECT, profHistoryStart);

   if(!historySelected)
      return false;

   long magic = HistoryDealGetInteger(tx.dealTicket, DEAL_MAGIC);
   if(magic != state.magicNumber)
      return true;

   ENUM_DEAL_ENTRY entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tx.dealTicket, DEAL_ENTRY);

   //===============================================================
   // OPEN / ENTRY DEAL
   //===============================================================
   if(entry == DEAL_ENTRY_IN)
     {
      // DEAL_ORDER is authoritative when the transaction itself did not
      // carry the source order ticket.
      if(tx.orderTicket == 0)
         tx.orderTicket = (ulong)HistoryDealGetInteger(tx.dealTicket, DEAL_ORDER);

      int idx = FindItemByOrderTicket(state, tx.orderTicket);

      if(idx < 0)
         idx = FindItemByPositionTicket(state, tx.positionTicket);

      // The DEAL may arrive before ORDER_ADD / REQUEST has attached the
      // broker ticket to the planned PLACE item. Use the source order's
      // original type + price to recover that existing strategy item.
      if(idx < 0 && tx.orderTicket > 0)
        {
         if(!HistoryOrderSelect(tx.orderTicket))
            return false;

         if(HistoryOrderGetInteger(tx.orderTicket, ORDER_MAGIC) == state.magicNumber)
           {
            ENUM_ORDER_TYPE sourceType =
               (ENUM_ORDER_TYPE)HistoryOrderGetInteger(tx.orderTicket, ORDER_TYPE);
            double sourcePrice =
               HistoryOrderGetDouble(tx.orderTicket, ORDER_PRICE_OPEN);

            idx = FindPlannedOrder(state, sourceType, sourcePrice);
           }
        }

      if(idx < 0)
         idx = AddTradeItem(state);

      TradeItem item = state.items[idx];

      item.kind             = ITEM_POSITION;
      item.orderTicket      = tx.orderTicket;
      item.positionTicket   = tx.positionTicket;
      item.lastDealTicket   = tx.dealTicket;
      item.side             = (tx.dealType == DEAL_TYPE_BUY)
                              ? POSITION_TYPE_BUY
                              : POSITION_TYPE_SELL;
      item.openPrice        = tx.price;
      item.volume           = tx.volume;
      item.targetLot        = tx.volume;
      item.brokerPresent    = true;
      item.reconcilePending = false;
      item.reconcileMisses  = 0;

      if(item.originalLot <= 0.0)
         item.originalLot = tx.volume;

      // Broker fill = broker state only. No command is created here.
      item.action              = ACTION_NONE;
      item.actionStatus        = ACTION_IDLE;
      item.requestId           = 0;

      state.items[idx] = item;

      // Cleanup owns the cycle while active. The cleanup engine will
      // convert this live POSITION into ACTION_CLOSE.
      if(state.lifecycle != GRID_CLEANUP)
        {
         state.lifecycle = GRID_ACTIVE;

         ulong profStrategyStart = GetMicrosecondCount();
         Strategy_OnEntryFill(state, idx, tx);
         Profiler30Record(PROF30_STRATEGY_ON_ENTRY_FILL, profStrategyStart);
        }

      return true;
     }

   //===============================================================
   // EXIT DEAL
   //===============================================================
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
           {
            RemoveTradeItem(state, idx);
           }
        }

      return true;
     }

   return true;
  }

bool HandlePositionTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.positionTicket == 0)
      return true;

   int idx = FindItemByPositionTicket(state, tx.positionTicket);
   if(idx < 0)
      return true;

   if(!PositionSelectByTicket(tx.positionTicket))
     {
      state.items[idx].brokerPresent    = false;
      state.items[idx].reconcilePending = true;
      state.items[idx].reconcileMisses  = 0;
      return true;
     }

   state.items[idx].kind             = ITEM_POSITION;
   state.items[idx].side             = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   state.items[idx].openPrice        = PositionGetDouble(POSITION_PRICE_OPEN);
   state.items[idx].volume           = PositionGetDouble(POSITION_VOLUME);
   state.items[idx].currentSL        = PositionGetDouble(POSITION_SL);
   state.items[idx].currentTP        = PositionGetDouble(POSITION_TP);
   state.items[idx].brokerPresent    = true;
   state.items[idx].reconcilePending = false;
   state.items[idx].reconcileMisses  = 0;

   return true;
  }

//+------------------------------------------------------------------+
//| One readable dispatcher.                                         |
//+------------------------------------------------------------------+
bool HandleTransaction(GridState &state, TransactionItem &tx)
  {
   ulong profStart = GetMicrosecondCount();

   if(tx.type == TRADE_TRANSACTION_REQUEST)
     {
      ulong profChild = GetMicrosecondCount();
      bool handled = HandleRequestTransaction(state, tx);
      Profiler30Record(PROF30_HANDLE_REQUEST_TRANSACTION, profChild);
      Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
      return handled;
     }

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
      bool handled = HandleOrderTransaction(state, tx);
      Profiler30Record(PROF30_HANDLE_ORDER_TRANSACTION, profChild);
      Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
      return handled;
     }

   if(tx.type == TRADE_TRANSACTION_POSITION)
     {
      ulong profChild = GetMicrosecondCount();
      bool handled = HandlePositionTransaction(state, tx);
      Profiler30Record(PROF30_HANDLE_POSITION_TRANSACTION, profChild);
      Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
      return handled;
     }

   Profiler30Record(PROF30_HANDLE_TRANSACTION, profStart);
   return true;
  }

void ProcessTransactionQueue(GridState &state, ulong frameStartUs, ulong budgetUs)
  {
   ulong profStart = GetMicrosecondCount();
   int processed = 0;

   // Freeze this frame's tail. A retried transaction appended below is
   // therefore not retried again until a later heartbeat.
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
         tx.handlerRetries++;

         if(tx.handlerRetries < 3)
           {
            QueueTransaction(tx);
           }
         else
           {
            // Handler retries are exhausted. Mark only the already-known
            // logical TradeItem so the normal reconciler resolves live state.
            int idx = FindItemByOrderTicket(state, tx.orderTicket);

            if(idx < 0)
               idx = FindItemByPositionTicket(state, tx.positionTicket);

            if(idx >= 0)
              {
               if(tx.orderTicket > 0)
                  state.items[idx].orderTicket = tx.orderTicket;

               if(tx.positionTicket > 0)
                  state.items[idx].positionTicket = tx.positionTicket;

               if(tx.dealTicket > 0)
                  state.items[idx].lastDealTicket = tx.dealTicket;

               state.items[idx].reconcilePending = true;
               state.items[idx].reconcileMisses  = 0;
              }
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
