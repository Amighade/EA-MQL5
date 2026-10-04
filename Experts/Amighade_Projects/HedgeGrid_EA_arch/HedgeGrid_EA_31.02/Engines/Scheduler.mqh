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
   if(state.needsGridVerification || state.lifecycle == GRID_CLEANUP) return true;
   for(int i = 0; i < ArraySize(state.items); i++)
      if(state.items[i].reconcilePending || state.items[i].actionStatus != ACTION_IDLE)
         return true;
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
   PrintFormat("[REV30.04 CPU PROFILE] WallDutyInt=%.3f%% WallDutyAll=%.3f%% LastFrame=%I64u us MaxInt=%I64u us MaxAll=%I64u us AvgFrameInt=%.1f us Frames=%I64u Items=%d TxQueued=%d",
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
   if(!InpEnableCpuProfiler) return;
   g_lastFrameUs = GetMicrosecondCount() - frameStartUs;
   g_profileWorkUs += g_lastFrameUs;
   g_profileIntervalWorkUs += g_lastFrameUs;
   g_profileIntervalFrames++;
   if(g_lastFrameUs > g_maxFrameUs) g_maxFrameUs = g_lastFrameUs;
   if(g_lastFrameUs > g_profileIntervalMaxUs) g_profileIntervalMaxUs = g_lastFrameUs;
   PrintSchedulerProfile30(nowMs, state);
  }

// One frame: consume facts -> reconcile -> route cleanup -> send -> strategy.
// Each stage shares frameStartUs/budgetUs; broker scans are cooperative stages,
// not interruptible API calls. No separate budget is created inside a stage.
void RunScheduler30(GridState &state)
  {
   ulong frameStartUs = GetMicrosecondCount();
   ulong nowMs = GetTickCount64();
   ulong budgetUs = (ulong)InpSchedulerBudgetMs * 1000;
   bool mediumDue = (nowMs - g_lastMediumMs >= (ulong)InpMediumTierIntervalMs);

   // One exit path keeps the profiler and the control flow easy to follow.
   do
     {
      ProcessTransactionQueue(state, frameStartUs, budgetUs);
      if(!FrameBudgetAvailable(frameStartUs, budgetUs)) break;
      if(!TerminalInfoInteger(TERMINAL_CONNECTED)) break;

      if(state.safetyStopPending)
        {
         StartCleanup(state, state.safetyStopReason);
         state.safetyStopPending = false;
        }
      if(mediumDue || TradeBookNeedsReconcile(state))
        {
         ReconcileTradeItems(state);
         if(mediumDue) g_lastMediumMs = nowMs;
        }
      if(!FrameBudgetAvailable(frameStartUs, budgetUs)) break;

      if(state.lifecycle == GRID_CLEANUP)
        {
         StartCleanup(state, state.cleanupReason);
         ProcessPendingActions(state, frameStartUs, budgetUs);
         if(FrameBudgetAvailable(frameStartUs, budgetUs) &&
            g_transactionHead >= ArraySize(g_transactionQueue))
            ProcessCleanupState(state);
         break; // Cleanup owns the entire frame, including its final frame.
        }

      ProcessPendingActions(state, frameStartUs, budgetUs);
      if(!FrameBudgetAvailable(frameStartUs, budgetUs)) break;
      if(TierDue(nowMs, g_lastFastMs, (ulong)InpFastTierIntervalMs))
         Strategy_Fast(state);
      if(state.lifecycle == GRID_CLEANUP || state.safetyStopPending) break;
      if(FrameBudgetAvailable(frameStartUs, budgetUs) && mediumDue)
         Strategy_Medium(state);
      if(state.lifecycle == GRID_CLEANUP || state.safetyStopPending) break;
      if(FrameBudgetAvailable(frameStartUs, budgetUs) &&
         TierDue(nowMs, g_lastBackgroundMs, (ulong)InpBackgroundTierIntervalMs))
         Strategy_Background(state);
     }
   while(false);
   FinishSchedulerFrame30(frameStartUs, nowMs, state);
  }

#endif
