#ifndef TRANSACTION_HANDLER_MQH
#define TRANSACTION_HANDLER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Models/TransactionItem.mqh"
#include "../Utils/TradeBook.mqh"
#include "../Utils/AsyncTrade.mqh"
#include "../Utils/ProfilerUtils.mqh"
#include "StrategyBridge.mqh"
#include "ReconcileEngine.mqh"

TransactionItem g_transactionQueue[];
int             g_transactionHead = 0;

void QueueTransaction(TransactionItem &item)
  {
   int n = ArraySize(g_transactionQueue);
   if(ArrayResize(g_transactionQueue, n + 1, 128) < 0)
     {
      Print("[REV30.04] Transaction queue allocation failed; periodic broker scan remains active.");
      return;
     }
   g_transactionQueue[n] = item;
  }

void CompactTransactionQueue()
  {
   int total = ArraySize(g_transactionQueue);
   if(g_transactionHead <= 0) return;
   if(g_transactionHead < total && g_transactionHead < 16 && g_transactionHead < total / 2) return;
   int remaining = total - g_transactionHead;
   for(int i = 0; i < remaining; i++)
      g_transactionQueue[i] = g_transactionQueue[g_transactionHead + i];
   ArrayResize(g_transactionQueue, remaining);
   g_transactionHead = 0;
  }

// Every handler: true = consumed/irrelevant; false = required facts not ready.
bool HandleRequestTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.requestMagic != state.magicNumber) return true;
   int idx = FindItemByRequestId(state, tx.requestId);
   if(idx < 0) return true;
   TradeItem item = state.items[idx];
   if(item.actionStatus != ACTION_WAIT_RESULT && item.actionStatus != ACTION_WAIT_CONFIRM) return true;

   item.lastRetcode = tx.retcode;
   item.resultTimeMs = GetTickCount64();
   item.reconcilePending = false;
   if(item.action == ACTION_PLACE && tx.resultOrder > 0)
      item.orderTicket = tx.resultOrder;

   // A result's deal ticket is NOT a processed DEAL event. Only the deal
   // handler writes lastDealTicket, after it has consumed that event.
   if(IsAsyncAcceptedRetcode(tx.retcode) || tx.retcode == TRADE_RETCODE_TIMEOUT ||
      tx.retcode == TRADE_RETCODE_CONNECTION)
      item.actionStatus = ACTION_WAIT_CONFIRM;
   else
     {
      item.actionStatus = ACTION_FAILED;
      item.requestId = 0;
     }
   state.items[idx] = item;
   state.needsGridVerification = true;
   return true;
  }

bool HandleOrderTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.orderTicket == 0) return true;
   state.needsGridVerification = true;
   int idx = FindItemByOrderTicket(state, tx.orderTicket);
   if(idx >= 0) state.items[idx].reconcilePending = true;
   // The live scan owns data changes and disappearance. An event never
   // deletes/replaces an item just because ORDER_DELETE arrived first.
   return true;
  }

bool HandlePositionTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.positionTicket == 0) return true;
   state.needsGridVerification = true;
   int idx = FindItemByPositionTicket(state, tx.positionTicket);
   if(idx >= 0) state.items[idx].reconcilePending = true;
   return true;
  }

bool HandleDealTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.dealTicket == 0) return true;
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) return false;
   if(!HistoryDealSelect(tx.dealTicket)) return false;
   if(HistoryDealGetString(tx.dealTicket, DEAL_SYMBOL) != _Symbol) return true;
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tx.dealTicket, DEAL_ENTRY);
   ulong positionId = (ulong)HistoryDealGetInteger(tx.dealTicket, DEAL_POSITION_ID);
   long magic = HistoryDealGetInteger(tx.dealTicket, DEAL_MAGIC);
   tx.orderTicket = (ulong)HistoryDealGetInteger(tx.dealTicket, DEAL_ORDER);
   tx.dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(tx.dealTicket, DEAL_TYPE);
   tx.price = HistoryDealGetDouble(tx.dealTicket, DEAL_PRICE);
   tx.volume = HistoryDealGetDouble(tx.dealTicket, DEAL_VOLUME);
   int idx = FindItemByPositionTicket(state, tx.positionTicket);
   if(idx < 0)
      for(int j = 0; j < ArraySize(state.items); j++)
         if(state.items[j].kind == ITEM_POSITION && state.items[j].orderTicket == positionId)
           {
            idx = j;
            break;
           }
   if(magic != state.magicNumber && idx < 0) return true;

   // Use the same synchronization as periodic recovery; this also handles
   // DEAL-before-ORDER, partial fills and broker position-ticket changes.
   if(entry == DEAL_ENTRY_IN)
      ReconcileTradeItems(state);
   else if(!RebuildTradeBookFromTerminal(state))
      return false;
   idx = FindItemByPositionTicket(state, tx.positionTicket);
   if(idx < 0)
      for(int j = 0; j < ArraySize(state.items); j++)
         if(state.items[j].kind == ITEM_POSITION && state.items[j].orderTicket == positionId)
           {
            idx = j;
            break;
           }
   if(idx < 0) return (entry != DEAL_ENTRY_IN);
   if(state.items[idx].lastDealTicket == tx.dealTicket) return true;

   tx.positionTicket = state.items[idx].positionTicket;
   state.items[idx].lastDealTicket = tx.dealTicket;
   state.items[idx].reconcilePending = true;
   state.needsGridVerification = true;

   if(state.lifecycle == GRID_CLEANUP || state.safetyStopPending) return true;
   if(entry == DEAL_ENTRY_IN && state.items[idx].brokerPresent)
     {
      state.lifecycle = GRID_ACTIVE;
      Strategy_OnEntryFill(state, idx, tx);
     }
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      Strategy_OnExitDeal(state, idx, tx);
   return true;
  }

bool HandleTransaction(GridState &state, TransactionItem &tx)
  {
   if(tx.symbol != "" && tx.symbol != _Symbol) return true;
   switch(tx.type)
     {
      case TRADE_TRANSACTION_REQUEST:
         return HandleRequestTransaction(state, tx);
      case TRADE_TRANSACTION_ORDER_ADD:
      case TRADE_TRANSACTION_ORDER_UPDATE:
      case TRADE_TRANSACTION_ORDER_DELETE:
         return HandleOrderTransaction(state, tx);
      case TRADE_TRANSACTION_DEAL_ADD:
         return HandleDealTransaction(state, tx);
      case TRADE_TRANSACTION_POSITION:
         return HandlePositionTransaction(state, tx);
      default:
         return true;
     }
  }

void ProcessTransactionQueue(GridState &state, ulong frameStartUs, ulong budgetUs)
  {
   ulong profStart = GetMicrosecondCount();
   int processed = 0;
   int frameTotal = ArraySize(g_transactionQueue); // Retried facts wait until the next frame.
   while(g_transactionHead < frameTotal && processed < InpSchedulerMaxTransactionsPerFrame)
     {
      if(GetMicrosecondCount() - frameStartUs >= budgetUs) break;
      TransactionItem tx = g_transactionQueue[g_transactionHead];
      if(!HandleTransaction(state, tx))
        {
         tx.handlerRetries++;
         if(tx.handlerRetries < MathMax(1, InpSafetyRetryAttempts))
            QueueTransaction(tx);
         else
           {
            int idx = FindItemByPositionTicket(state, tx.positionTicket);
            if(idx < 0) idx = FindItemByOrderTicket(state, tx.orderTicket);
            if(idx >= 0) state.items[idx].reconcilePending = true;
            state.needsGridVerification = true;
            // Recover broker reality; never invent identity or start cycle cleanup.
           }
        }
      g_transactionHead++;
      processed++;
     }
   CompactTransactionQueue();
   Profiler30Record(PROF30_PROCESS_TRANSACTION_QUEUE, profStart);
  }

void ResetTransactionQueue()
  {
   ArrayResize(g_transactionQueue, 0);
   g_transactionHead = 0;
  }

#endif
