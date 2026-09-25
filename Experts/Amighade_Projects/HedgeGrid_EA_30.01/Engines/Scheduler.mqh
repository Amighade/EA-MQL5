#ifndef SCHEDULER_30_MQH
#define SCHEDULER_30_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "TransactionHandler.mqh"
#include "ReconcileEngine.mqh"
#include "CleanupEngine.mqh"
#include "StrategyBridge.mqh"
#include "../Utils/AsyncTrade.mqh"
#include "../Utils/ProfilerUtils.mqh"

ulong g_lastFastMs       = 0;
ulong g_lastMediumMs     = 0;
ulong g_lastBackgroundMs = 0;

ulong g_profileStartUs          = 0;
ulong g_profileWorkUs           = 0;
ulong g_profileIntervalStartUs  = 0;
ulong g_profileIntervalWorkUs   = 0;
ulong g_profileIntervalMaxUs    = 0;
ulong g_profileIntervalFrames   = 0;
ulong g_lastFrameUs             = 0;
ulong g_maxFrameUs              = 0;
ulong g_lastProfileMs           = 0;

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

void InitScheduler30()
  {
   ulong now = GetTickCount64();
   ulong nowUs = GetMicrosecondCount();

   g_lastFastMs       = 0;
   g_lastMediumMs     = 0;
   g_lastBackgroundMs = now;

   g_profileStartUs         = nowUs;
   g_profileWorkUs          = 0;
   g_profileIntervalStartUs = nowUs;
   g_profileIntervalWorkUs  = 0;
   g_profileIntervalMaxUs   = 0;
   g_profileIntervalFrames  = 0;
   g_lastFrameUs            = 0;
   g_maxFrameUs             = 0;
   g_lastProfileMs          = now;

   Profiler30ResetAll();
   ResetTransactionQueue();
  }

void PrintSchedulerProfile30(ulong nowMs, GridState &state)
  {
   if(!InpEnableCpuProfiler) return;

   ulong intervalMs = (ulong)MathMax(1000, InpCpuProfileIntervalMs);
   if(nowMs - g_lastProfileMs < intervalMs) return;

   ulong nowUs = GetMicrosecondCount();
   ulong elapsedAllUs = nowUs - g_profileStartUs;
   ulong elapsedIntervalUs = nowUs - g_profileIntervalStartUs;

   double dutyAll = (elapsedAllUs > 0)
                    ? 100.0 * (double)g_profileWorkUs / (double)elapsedAllUs
                    : 0.0;
   double dutyInterval = (elapsedIntervalUs > 0)
                         ? 100.0 * (double)g_profileIntervalWorkUs / (double)elapsedIntervalUs
                         : 0.0;
   double avgFrameInterval = (g_profileIntervalFrames > 0)
                             ? (double)g_profileIntervalWorkUs / (double)g_profileIntervalFrames
                             : 0.0;

   ulong printStart = GetMicrosecondCount();
   PrintFormat("[REV30.01 CPU PROFILE] WallDutyInt=%.3f%% WallDutyAll=%.3f%% LastFrame=%I64u us MaxInt=%I64u us MaxAll=%I64u us AvgFrameInt=%.1f us Frames=%I64u Items=%d TxQueued=%d",
               dutyInterval,
               dutyAll,
               g_lastFrameUs,
               g_profileIntervalMaxUs,
               g_maxFrameUs,
               avgFrameInterval,
               g_profileIntervalFrames,
               ArraySize(state.items),
               ArraySize(g_transactionQueue) - g_transactionHead);
   Profiler30Record(PROF30_PROFILE_REPORT_PRINT, printStart);

   Profiler30PrintAndResetInterval();

   g_profileIntervalStartUs = GetMicrosecondCount();
   g_profileIntervalWorkUs  = 0;
   g_profileIntervalMaxUs   = 0;
   g_profileIntervalFrames  = 0;
   g_lastProfileMs          = nowMs;
  }

//+------------------------------------------------------------------+
//| Record frame timing before any early return.                     |
//+------------------------------------------------------------------+
void FinishSchedulerFrame30(ulong frameStartUs, ulong nowMs, GridState &state)
  {
   g_lastFrameUs = GetMicrosecondCount() - frameStartUs;
   g_profileWorkUs += g_lastFrameUs;
   g_profileIntervalWorkUs += g_lastFrameUs;
   g_profileIntervalFrames++;
   if(g_lastFrameUs > g_maxFrameUs) g_maxFrameUs = g_lastFrameUs;
   if(g_lastFrameUs > g_profileIntervalMaxUs) g_profileIntervalMaxUs = g_lastFrameUs;
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
   ulong profTxStage = GetMicrosecondCount();
   ProcessTransactionQueue(state, frameStartUs, budgetUs);
   Profiler30Record(PROF30_SCHED_TRANSACTION_STAGE, profTxStage);
   if(!FrameBudgetAvailable(frameStartUs, budgetUs))
     {
      FinishSchedulerFrame30(frameStartUs, nowMs, state);
      return;
     }

   // 2) Whole-cycle safety request -> cleanup lifecycle.
   if(state.safetyStopPending && state.lifecycle != GRID_CLEANUP)
     {
      ulong profCleanupStart = GetMicrosecondCount();
      StartCleanup(state, state.safetyStopReason);
      Profiler30Record(PROF30_SCHED_CLEANUP_STAGE, profCleanupStart);
      state.safetyStopPending = false;
     }

   // 3) Strategy/item actions -> OrderSendAsync().
   ulong profActionStage = GetMicrosecondCount();
   ProcessPendingActions(state, frameStartUs, budgetUs);
   Profiler30Record(PROF30_SCHED_ACTION_STAGE, profActionStage);
   if(!FrameBudgetAvailable(frameStartUs, budgetUs))
     {
      FinishSchedulerFrame30(frameStartUs, nowMs, state);
      return;
     }

   // 4) Broker state is final confirmation.
   ulong profNeedReconcile = GetMicrosecondCount();
   bool needsReconcile = TradeBookNeedsReconcile(state);
   Profiler30Record(PROF30_TRADEBOOK_NEEDS_RECONCILE, profNeedReconcile);

   if(needsReconcile || state.lifecycle == GRID_CLEANUP)
     {
      ulong profReconcileStage = GetMicrosecondCount();
      ReconcileTradeItems(state);
      Profiler30Record(PROF30_SCHED_RECONCILE_STAGE, profReconcileStage);
     }

   if(state.lifecycle == GRID_CLEANUP)
     {
      ulong profCleanupStage = GetMicrosecondCount();
      ProcessCleanupState(state);
      Profiler30Record(PROF30_SCHED_CLEANUP_STAGE, profCleanupStage);
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
        {
         ulong profStrategy = GetMicrosecondCount();
         Strategy_Fast(state);
         Profiler30Record(PROF30_STRATEGY_FAST, profStrategy);
        }

      if(FrameBudgetAvailable(frameStartUs, budgetUs) &&
         TierDue(nowMs, g_lastMediumMs, (ulong)InpMediumTierIntervalMs))
        {
         ulong profStrategy = GetMicrosecondCount();
         Strategy_Medium(state);
         Profiler30Record(PROF30_STRATEGY_MEDIUM, profStrategy);
        }

      if(FrameBudgetAvailable(frameStartUs, budgetUs) &&
         TierDue(nowMs, g_lastBackgroundMs, (ulong)InpBackgroundTierIntervalMs))
        {
         ulong profStrategy = GetMicrosecondCount();
         Strategy_Background(state);
         Profiler30Record(PROF30_STRATEGY_BACKGROUND, profStrategy);
        }
     }

   FinishSchedulerFrame30(frameStartUs, nowMs, state);
  }

#endif
