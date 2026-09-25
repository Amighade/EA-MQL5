#ifndef SCHEDULER_30_MQH
#define SCHEDULER_30_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "TransactionHandler.mqh"
#include "ReconcileEngine.mqh"
#include "CleanupEngine.mqh"
#include "StrategyBridge.mqh"
#include "../Utils/AsyncTrade.mqh"

ulong g_lastFastMs       = 0;
ulong g_lastMediumMs     = 0;
ulong g_lastBackgroundMs = 0;

ulong g_profileStartUs   = 0;
ulong g_profileWorkUs    = 0;
ulong g_lastFrameUs      = 0;
ulong g_maxFrameUs       = 0;
ulong g_lastProfileMs    = 0;

bool TierDue(ulong nowMs, ulong &lastMs, ulong intervalMs)
  {
   if(nowMs - lastMs < intervalMs) return false;
   lastMs = nowMs;
   return true;
  }

bool FrameBudgetAvailable(ulong frameStartUs, ulong budgetUs)
  {
   return (GetMicrosecondCount() - frameStartUs) < budgetUs;
  }

bool TradeBookNeedsReconcile(GridState &state)
  {
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      if(state.items[i].actionStatus == ACTION_WAIT_RESULT ||
         state.items[i].actionStatus == ACTION_WAIT_CONFIRM)
         return true;
      if(!state.items[i].brokerPresent && state.items[i].orderTicket > 0)
         return true;
     }
   return false;
  }

void InitScheduler()
  {
   ulong now = GetTickCount64();
   g_lastFastMs       = 0;
   g_lastMediumMs     = 0;
   g_lastBackgroundMs = now;
   g_profileStartUs   = GetMicrosecondCount();
   g_profileWorkUs    = 0;
   g_lastFrameUs      = 0;
   g_maxFrameUs       = 0;
   g_lastProfileMs    = now;
   ResetTransactionQueue();
  }

void PrintSchedulerProfile30(ulong nowMs, GridState &state)
  {
   if(!InpEnableDebugLog) return;
   if(nowMs - g_lastProfileMs < 10000) return;

   ulong elapsedUs = GetMicrosecondCount() - g_profileStartUs;
   double duty = (elapsedUs > 0)
                 ? 100.0 * (double)g_profileWorkUs / (double)elapsedUs
                 : 0.0;

   PrintFormat("[REV30.01 PROFILE] Duty=%.3f%% LastFrame=%I64u us MaxFrame=%I64u us Items=%d TxQueued=%d",
               duty,
               g_lastFrameUs,
               g_maxFrameUs,
               ArraySize(state.items),
               ArraySize(g_transactionQueue) - g_transactionHead);

   g_lastProfileMs = nowMs;
  }

//+------------------------------------------------------------------+
//| Record frame timing before any early return.                     |
//+------------------------------------------------------------------+
void FinishSchedulerFrame30(ulong frameStartUs, ulong nowMs, GridState &state)
  {
   g_lastFrameUs = GetMicrosecondCount() - frameStartUs;
   g_profileWorkUs += g_lastFrameUs;
   if(g_lastFrameUs > g_maxFrameUs) g_maxFrameUs = g_lastFrameUs;
   PrintSchedulerProfile30(nowMs, state);
  }

//+------------------------------------------------------------------+
//| One obvious scheduler order:                                     |
//|   1 transaction inbox                                            |
//|   2 safety/cleanup decision                                      |
//|   3 async actions                                                 |
//|   4 live confirmation                                            |
//|   5 strategy                                                     |
//+------------------------------------------------------------------+
void RunScheduler30(GridState &state)
  {
   ulong frameStartUs = GetMicrosecondCount();
   ulong nowMs        = GetTickCount64();
   ulong budgetUs     = (ulong)MathMax(0, InpSchedulerBudgetMs) * 1000;

   if(budgetUs == 0)
     {
      FinishSchedulerFrame30(frameStartUs, nowMs, state);
      return;
     }

   // 1) Facts from MT5 -> GridState / TradeItem[]
   ProcessTransactionQueue(state, frameStartUs, budgetUs);
   if(!FrameBudgetAvailable(frameStartUs, budgetUs))
     {
      FinishSchedulerFrame30(frameStartUs, nowMs, state);
      return;
     }

   // 2) Whole-cycle safety request -> cleanup lifecycle.
   if(state.safetyStopPending && state.lifecycle != GRID_CLEANUP)
     {
      StartCleanup(state, state.safetyStopReason);
      state.safetyStopPending = false;
     }

   // 3) Strategy/item actions -> OrderSendAsync().
   ProcessPendingActions(state, frameStartUs, budgetUs);
   if(!FrameBudgetAvailable(frameStartUs, budgetUs))
     {
      FinishSchedulerFrame30(frameStartUs, nowMs, state);
      return;
     }

   // 4) Broker state is final confirmation.
   if(TradeBookNeedsReconcile(state) || state.lifecycle == GRID_CLEANUP)
      ReconcileTradeItems(state);

   if(state.lifecycle == GRID_CLEANUP)
     {
      ProcessCleanupState(state);
      // Cleanup owns the cycle; strategy is not called while it is active.
      if(state.lifecycle == GRID_CLEANUP)
        {
         FinishSchedulerFrame30(frameStartUs, nowMs, state);
         return;
        }
     }

   if(!FrameBudgetAvailable(frameStartUs, budgetUs))
     {
      FinishSchedulerFrame30(frameStartUs, nowMs, state);
      return;
     }

   // 5) Strategy. Rev 30.01 hooks are intentionally empty until reviewed.
   if(state.lifecycle != GRID_FAULT)
     {
      if(TierDue(nowMs, g_lastFastMs, (ulong)InpFastTierIntervalMs))
         Strategy_Fast(state);

      if(FrameBudgetAvailable(frameStartUs, budgetUs) &&
         TierDue(nowMs, g_lastMediumMs, (ulong)InpMediumTierIntervalMs))
         Strategy_Medium(state);

      if(FrameBudgetAvailable(frameStartUs, budgetUs) &&
         TierDue(nowMs, g_lastBackgroundMs, (ulong)InpBackgroundTierIntervalMs))
         Strategy_Background(state);
     }

   FinishSchedulerFrame30(frameStartUs, nowMs, state);
  }

#endif
