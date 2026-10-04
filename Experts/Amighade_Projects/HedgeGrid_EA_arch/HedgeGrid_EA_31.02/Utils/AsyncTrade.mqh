#ifndef ASYNC_TRADE_MQH
#define ASYNC_TRADE_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "TradeBook.mqh"
#include "ProfilerUtils.mqh"

ENUM_ORDER_TYPE_FILLING g_asyncFillMode = ORDER_FILLING_IOC;

bool IsAsyncAcceptedRetcode(int retcode)
  {
   return (retcode == TRADE_RETCODE_DONE ||
           retcode == TRADE_RETCODE_PLACED ||
           retcode == TRADE_RETCODE_DONE_PARTIAL ||
           retcode == TRADE_RETCODE_NO_CHANGES);
  }

void InitAsyncTrade()
  {
   long filling = 0;
   if(SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE, filling))
     {
      if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
         g_asyncFillMode = ORDER_FILLING_IOC;
      else if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
         g_asyncFillMode = ORDER_FILLING_FOK;
      else
         g_asyncFillMode = ORDER_FILLING_RETURN;
     }
  }

//+------------------------------------------------------------------+
//| STRATEGY -> TRADE BOOK requests.                                 |
//| These functions DO NOT contact the broker. They only describe    |
//| what the strategy wants on the relevant TradeItem.               |
//+------------------------------------------------------------------+
uint RequestPlacePending(GridState &state,
                         ENUM_ORDER_TYPE orderType,
                         double price,
                         double lot,
                         double sl=0.0,
                         double tp=0.0,
                         int level=-1)
  {
   if(state.lifecycle == GRID_CLEANUP || state.safetyStopPending) return 0;
   if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT &&
      orderType != ORDER_TYPE_BUY_STOP && orderType != ORDER_TYPE_SELL_STOP) return 0;
   int existing = FindPlannedOrder(state, orderType, price);
   if(existing >= 0) return state.items[existing].id;

   int idx = AddTradeItem(state);
   if(idx < 0) return 0;

   state.items[idx].kind           = ITEM_ORDER;
   state.items[idx].orderType      = orderType;
   state.items[idx].side           = (orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
                                     ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   state.items[idx].level          = level;
   state.items[idx].targetPrice    = price;
   state.items[idx].targetLot      = lot;
   state.items[idx].originalLot    = lot;
   state.items[idx].requestedPrice = price;
   state.items[idx].requestedLot   = lot;
   state.items[idx].requestedSL    = sl;
   state.items[idx].requestedTP    = tp;
   state.items[idx].action         = ACTION_PLACE;
   state.items[idx].actionStatus   = ACTION_READY;

   if(state.lifecycle == GRID_IDLE)
      state.lifecycle = GRID_BUILDING;

   return state.items[idx].id;
  }

bool RequestDeleteOrder(GridState &state, ulong orderTicket)
  {
   int idx = FindItemByOrderTicket(state, orderTicket);
   if(idx < 0) return false;
   if(state.items[idx].reconcilePending ||
      state.items[idx].actionStatus == ACTION_WAIT_RESULT ||
      state.items[idx].actionStatus == ACTION_WAIT_CONFIRM) return false;
   state.items[idx].replaceAfterDelete = false;
   state.items[idx].action = ACTION_DELETE;
   state.items[idx].actionStatus = ACTION_READY;
   state.items[idx].requestId = 0;
   state.items[idx].attempts = 0;
   state.items[idx].sentTimeMs = 0;
   state.items[idx].resultTimeMs = 0;
   state.items[idx].resultOrderTicket = 0;
   state.items[idx].resultDealTicket = 0;
   return true;
  }

bool RequestClosePosition(GridState &state, ulong positionTicket)
  {
   int idx = FindItemByPositionTicket(state, positionTicket);
   if(idx < 0) return false;
   if(state.items[idx].reconcilePending ||
      state.items[idx].actionStatus == ACTION_WAIT_RESULT ||
      state.items[idx].actionStatus == ACTION_WAIT_CONFIRM) return false;

   state.items[idx].action = ACTION_CLOSE;
   state.items[idx].actionStatus = ACTION_READY;
   state.items[idx].requestId = 0;
   state.items[idx].attempts = 0;
   state.items[idx].sentTimeMs = 0;
   state.items[idx].resultTimeMs = 0;
   state.items[idx].resultOrderTicket = 0;
   state.items[idx].resultDealTicket = 0;
   return true;
  }

bool RequestModifySL(GridState &state, ulong positionTicket, double newSL)
  {
   if(state.lifecycle == GRID_CLEANUP || state.safetyStopPending) return false;
   int idx = FindItemByPositionTicket(state, positionTicket);
   if(idx < 0) return false;
   if(state.items[idx].reconcilePending ||
      state.items[idx].actionStatus == ACTION_WAIT_RESULT ||
      state.items[idx].actionStatus == ACTION_WAIT_CONFIRM) return false;
   state.items[idx].requestedSL = newSL;
   state.items[idx].action = ACTION_MODIFY_SL;
   state.items[idx].actionStatus = ACTION_READY;
   state.items[idx].requestId = 0;
   state.items[idx].attempts = 0;
   state.items[idx].sentTimeMs = 0;
   state.items[idx].resultTimeMs = 0;
   state.items[idx].resultOrderTicket = 0;
   state.items[idx].resultDealTicket = 0;
   return true;
  }

bool RequestReplaceOrder(GridState &state,
                         ulong orderTicket,
                         double replacementPrice,
                         double replacementLot,
                         double replacementSL=0.0,
                         double replacementTP=0.0)
  {
   if(state.lifecycle == GRID_CLEANUP || state.safetyStopPending) return false;
   // Reuse the same guard and DELETE initialization. No second command path.
   if(!RequestDeleteOrder(state, orderTicket)) return false;
   int idx = FindItemByOrderTicket(state, orderTicket);
   state.items[idx].replaceAfterDelete = true;
   state.items[idx].replacementPrice = replacementPrice;
   state.items[idx].replacementLot = replacementLot;
   state.items[idx].replacementSL = replacementSL;
   state.items[idx].replacementTP = replacementTP;
   return true;
  }

//+------------------------------------------------------------------+
//| Convert one READY TradeItem into one OrderSendAsync() request.   |
//| Only this layer knows broker request syntax. Strategy code does   |
//| not know request_id, WAIT_RESULT, or WAIT_CONFIRM.                |
//+------------------------------------------------------------------+
bool SendTradeItemAction(GridState &state, int index)
  {
   if(index < 0 || index >= ArraySize(state.items)) return false;

   TradeItem item = state.items[index];
   if(item.actionStatus != ACTION_READY || item.action == ACTION_NONE)
      return false;

   if(item.reconcilePending || !TerminalInfoInteger(TERMINAL_CONNECTED) ||
      !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
   if(state.lifecycle == GRID_CLEANUP && item.action != ACTION_CLOSE && item.action != ACTION_DELETE) return false;
   if(item.sentTimeMs > 0 && GetTickCount64() - item.sentTimeMs <
      (ulong)MathMax(InpSafetyRetryDelayMs, InpAsyncConfirmGraceMs)) return false;
   if((item.action == ACTION_PLACE || item.action == ACTION_DELETE) && item.kind != ITEM_ORDER) return false;
   if((item.action == ACTION_CLOSE || item.action == ACTION_MODIFY_SL) && item.kind != ITEM_POSITION) return false;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};

   req.symbol = _Symbol;
   req.magic  = (ulong)state.magicNumber;

   if(item.action == ACTION_PLACE)
     {
      req.action       = TRADE_ACTION_PENDING;
      req.type         = item.orderType;
      req.volume       = item.requestedLot;
      req.price        = item.requestedPrice;
      req.sl           = item.requestedSL;
      req.tp           = item.requestedTP;
      req.type_time    = ORDER_TIME_GTC;
      req.type_filling = ORDER_FILLING_RETURN;
     }
   else if(item.action == ACTION_DELETE)
     {
      // The order is already gone: DELETE is already satisfied.
      // Keep replacement sequencing on the same TradeItem when required.
      if(item.orderTicket == 0 || !OrderSelect(item.orderTicket))
        {
         ConfirmReplacementOrRemove(state, index);
         return true;
        }

      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         OrderGetInteger(ORDER_MAGIC) != state.magicNumber) return false;
      req.action = TRADE_ACTION_REMOVE;
      req.order  = item.orderTicket;
     }
   else if(item.action == ACTION_CLOSE)
     {
      // The position is already gone: CLOSE is already satisfied.
      if(item.positionTicket == 0 || !PositionSelectByTicket(item.positionTicket))
        {
         RemoveTradeItem(state, index);
         return true;
        }

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != state.magicNumber) return false;
      item.requestedLot = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE side = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      req.action       = TRADE_ACTION_DEAL;
      req.position     = item.positionTicket;
      req.volume       = PositionGetDouble(POSITION_VOLUME);
      req.type         = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      req.price        = (side == POSITION_TYPE_BUY)
                         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.deviation    = 20;
      req.type_filling = g_asyncFillMode;
      req.type_time    = ORDER_TIME_GTC;
     }
   else if(item.action == ACTION_MODIFY_SL)
     {
      if(item.positionTicket == 0 || !PositionSelectByTicket(item.positionTicket))
        {
         RemoveTradeItem(state, index);
         return true;
        }

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != state.magicNumber) return false;
      req.action   = TRADE_ACTION_SLTP;
      req.position = item.positionTicket;
      req.sl       = item.requestedSL;
      req.tp       = PositionGetDouble(POSITION_TP);
     }
   else
      return false;

   ResetLastError();
   ulong profSendStart = GetMicrosecondCount();
   bool sent = OrderSendAsync(req, res);

   if(item.action == ACTION_PLACE)
      Profiler30Record(PROF30_ORDERSEND_ASYNC_PLACE, profSendStart);
   else if(item.action == ACTION_DELETE)
      Profiler30Record(PROF30_ORDERSEND_ASYNC_DELETE, profSendStart);
   else if(item.action == ACTION_CLOSE)
      Profiler30Record(PROF30_ORDERSEND_ASYNC_CLOSE, profSendStart);
   else if(item.action == ACTION_MODIFY_SL)
      Profiler30Record(PROF30_ORDERSEND_ASYNC_MODIFY_SL, profSendStart);

   item.attempts++;
   item.sentTimeMs  = GetTickCount64();
   item.resultTimeMs = 0;
   item.resultOrderTicket = 0;
   item.resultDealTicket = 0;
   item.lastRetcode = (int)res.retcode;
   item.lastError   = GetLastError();

   if(!sent)
     {
      item.actionStatus  = ACTION_FAILED;
      item.requestId     = 0;
      state.items[index] = item;
      ResetLastError();
      return false;
     }

   item.requestId       = res.request_id;
   item.actionStatus    = ACTION_WAIT_RESULT;
   state.items[index]   = item;
   return true;
  }

void ProcessPendingActions(GridState &state, ulong frameStartUs, ulong budgetUs)
  {
   ulong profStart = GetMicrosecondCount();
   int inFlight = 0;
   for(int i = 0; i < ArraySize(state.items); i++)
      if(state.items[i].actionStatus == ACTION_WAIT_RESULT ||
         state.items[i].actionStatus == ACTION_WAIT_CONFIRM) inFlight++;

   // Limit outstanding requests so a slow terminal/server does not receive
   // the entire grid at once. Reconciliation frees a slot on live confirmation
   // or a definitive failure.
   for(int i = ArraySize(state.items) - 1; i >= 0; i--)
     {
      if(GetMicrosecondCount() - frameStartUs >= budgetUs) break;
      if(inFlight >= MathMax(1, InpCleanupAsyncBatch)) break;
      if(state.items[i].actionStatus != ACTION_READY) continue;
      uint id = state.items[i].id;
      SendTradeItemAction(state, i);
      int idx = FindItemById(state, id);
      if(idx >= 0 && state.items[idx].actionStatus == ACTION_WAIT_RESULT) inFlight++;
     }
   Profiler30Record(PROF30_PROCESS_PENDING_ACTIONS, profStart);
  }

#endif
