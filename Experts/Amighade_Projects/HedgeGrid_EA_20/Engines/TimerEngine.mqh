//+------------------------------------------------------------------+
//| CleanupReset.mqh                                                  |
//| BRICK 7: what "cleanup" means once SL hits (all winners closed)  |
//| or a broker fault/manual emergency fires.                        |
//|                                                                    |
//| Manual/broker-fault emergency close is now fully unified — it     |
//| just calls Utils/SafetyNet's TriggerSafetyStop, which always      |
//| closes everything and lets the next candle-open check rebuild.   |
//| No more per-style branching (see HedgeGrid_Info.md changelog).   |
//|                                                                    |
//| Normal SL-triggered cleanup respects InpCleanupMode:               |
//|   CLEANUP_CLOSE_ALL       — delete all orders, close all          |
//|                              remaining positions, full reset.     |
//|   CLEANUP_CLOSE_POSITIONS — close remaining positions only,       |
//|                              leave pending orders in place.       |
//| Both close positions in the zigzag profit order (most positive,   |
//| most negative, alternating — ticket order tie-break), one         |
//| position per OnTradeTransaction confirmation (Closing always      |
//| outranks opening/modifying — cleanupInProgress gates every other  |
//| brick off until this completes).                                  |
//+------------------------------------------------------------------+
#ifndef TIMER_ENGINE_MQH
#define TIMER_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/CloseOrderUtils.mqh"
#include "../Utils/SafetyNet.mqh"
#include "../Utils/SafetyNet.mqh"

// timer system
#define BASE_HEARTBEAT_MS       10      // Base native MQL5 timer pulse
#define MAX_CPU_BUDGET_MICRO    15000   // Hard cap: 15ms max work per pulse
#define INTERVAL_FAST_50MS      50      // Fast non-critical tasks (Trailing, etc)
#define INTERVAL_MEDIUM_500MS   500     // Reconciliation / Position safety checks
#define INTERVAL_SLOW_2000MS    2000    // Dashboard / Statistics updates
#define INTERVAL_BACKGROUND_1M  60000   // Session states / Diagnostics / File IO

// Runs every 50ms (or when forced by a fresh transaction)
void ExecuteFastTasks(ulong frameStartMicro, ulong frameworkBudget, GridState &state)
{
    // Process local lossless transaction queue if active
    if(state.g_txDirty)
    {
        ProcessTransactionQueue(frameStartMicro, frameworkBudget, state);
    }

    // --- [MODIFICATION POINT] ---
    // Add your quick trailing stop or emergency trade protective management here.
}

// Runs every 500ms (Slices heavy computational loops dynamically)
void ExecuteMediumTasks(ulong frameStartMicro, ulong allowedBudgetMicro, GridState &state)
{
    int totalPositions = PositionsTotal();
    if(totalPositions == 0)
    {
        state.g_nextCleanupIndex = 0;
        state.g_cleanupInProgress = false;
        return;
    }

    state.g_cleanupInProgress = true;

    // Time-Budgeted Slicer Loop
    while(state.g_nextCleanupIndex < totalPositions)
    {
        // Enforce performance checkpoint
        if((GetMicrosecondCount() - frameStartMicro) >= MAX_CPU_BUDGET_MICRO)
        {
            // Out of time! Exit. g_nextCleanupIndex is saved for the next frame.
            return;
        }

        // Safe item retrieval using state index pointer
        ulong ticket = PositionGetTicket(state.g_nextCleanupIndex);
        if(ticket > 0)
        {
            // --- [MODIFICATION POINT] ---
            // Execute heavy scanning logic per individual position here.
            // Example: EvaluatePositionSafety(ticket);
        }
        
        state.g_nextCleanupIndex++;
    }
    
    // If the loop completely clears out without breaching budget:
    state.g_nextCleanupIndex = 0;
    state.g_cleanupInProgress = false;
}

// Runs every 2 seconds
void ExecuteSlowTasks()
{
    // --- [MODIFICATION POINT] ---
    // Place graphic updates, text labels, or standard panel draws here.
}

// Runs every 1 minute
void ExecuteBackgroundTasks()
{
    // --- [MODIFICATION POINT] ---
    // Handle structural state saves, history analytics, or file prints here.
}

//====================================================================
// 5. QUEUE MANAGEMENT UTILITIES
//====================================================================
void ProcessTransactionQueue(ulong frameStartMicro, ulong frameworkBudget, GridState &state)
{
    int totalElements = ArraySize(state.g_txQueue);
    
    for(int i = 0; i < totalElements; i++)
    {
        // Performance Breaker Check
        if((GetMicrosecondCount() - frameStartMicro) >= frameworkBudget)
        {
            TruncateQueue(i, state);
            return;
        }

        // Process item step-by-step
        MqlTradeTransactionShort currentTx = state.g_txQueue[i];
        
        // --- [MODIFICATION POINT] ---
        // Insert state changes or logic checking based on transaction parameters.
        // Example: If currentTx.type == TRADE_TRANSACTION_DEAL_ADD -> trigger cleanups
    }

    // All items processed successfully -> Clear Memory
    ArrayFree(state.g_txQueue);
    state.g_txDirty = false;
}

// Moves unprocessed entries to the front of the queue if time runs out
void TruncateQueue(int processedCount, GridState &state)
{
    int totalSize = ArraySize(state.g_txQueue);
    int remainingCount = totalSize - processedCount;
    
    if(remainingCount <= 0)
    {
        ArrayFree(state.g_txQueue);
        state.g_txDirty = false;
        return;
    }
    
    // Shift remaining elements down to index 0
    for(int i = 0; i < remainingCount; i++)
    {
        state.g_txQueue[i] = state.g_txQueue[processedCount + i];
    }
    
    ArrayResize(state.g_txQueue, remainingCount);
}

#endif
