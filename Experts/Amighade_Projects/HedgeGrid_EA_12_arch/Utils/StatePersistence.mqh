#ifndef STATE_PERSISTENCE_MQH
#define STATE_PERSISTENCE_MQH

#include "../Models/GridState.mqh"

#define STATE_FILE_VERSION 1

string GetStateFileName(int magicNumber)
{
   return "HedgeGrid_state_" + IntegerToString(magicNumber) + ".bin";
}

void SaveGridState(GridState &state)
{
   int fh = FileOpen(GetStateFileName(state.magicNumber), FILE_WRITE | FILE_BIN);
   if(fh == INVALID_HANDLE) { LogDebug("[StatePersistence] Save failed to open file."); return; }

   FileWriteInteger(fh, STATE_FILE_VERSION);

   FileWriteInteger(fh, state.cycleActive);
   FileWriteInteger(fh, state.gridPlaced);
   FileWriteInteger(fh, state.passCounter);
   FileWriteInteger(fh, (int)state.lotMode);
   FileWriteDouble (fh, state.anchorBuy);
   FileWriteDouble (fh, state.anchorSell);

   FileWriteInteger(fh, (int)state.lastHitDirection);
   FileWriteInteger(fh, (int)state.prevHitDirection);
   FileWriteDouble (fh, state.lastHitLot);
   FileWriteDouble (fh, state.lastHitPrice);
   FileWriteDouble (fh, state.prevHitPrice);
   FileWriteLong   (fh, (long)state.lastHitTime);
   FileWriteLong   (fh, (long)state.lastHitTicket);

   FileWriteDouble (fh, state.farthestHitBuy);
   FileWriteDouble (fh, state.farthestHitSell);
   FileWriteDouble (fh, state.currentBlockLot);

   FileWriteInteger(fh, ArraySize(state.levelPrices));
   FileWriteArray  (fh, state.levelPrices);
   FileWriteArray  (fh, state.levelVisitCount);
   FileWriteArray  (fh, state.levelLastSide);
   FileWriteArray  (fh, state.levelBaseLot);      // same length as levelPrices, no separate prefix

   FileWriteInteger(fh, ArraySize(state.runLevels));
   FileWriteArray  (fh, state.runLevels);
   FileWriteInteger(fh, state.runSide);

   FileWriteDouble (fh, state.basketProfit);
   FileWriteDouble (fh, state.basketBuyProfit);
   FileWriteDouble (fh, state.basketSellProfit);

   FileWriteInteger(fh, state.slApplied);
   FileWriteDouble (fh, state.slLevel);
   FileWriteInteger(fh, state.slWinnerSide);
   FileWriteInteger(fh, state.slWallArmed);
   FileWriteInteger(fh, state.slAllWinnersClosed);

   FileWriteInteger(fh, state.refillNeeded);

   FileWriteInteger(fh, (int)state.cleanupType);
   FileWriteInteger(fh, state.cleanupInProgress);
   FileWriteInteger(fh, state.cleanupStep);

   FileWriteInteger(fh, state.marginWarning);
   FileWriteInteger(fh, state.sessionAllowed);
   FileWriteInteger(fh, state.gapFaultDetected);

   FileWriteLong   (fh, (long)state.lastBarGridCheck);
   FileWriteLong   (fh, (long)state.lastBarRecenter);

   FileWriteInteger(fh, (int)state.mode);

   FileClose(fh);
}

// Returns true if a valid saved state was found and loaded into 'state'.
// Caller must call ResetGridState first if this returns false.
bool LoadGridState(GridState &state)
{
   string fname = GetStateFileName(state.magicNumber);
   if(!FileIsExist(fname)) return false;

   int fh = FileOpen(fname, FILE_READ | FILE_BIN);
   if(fh == INVALID_HANDLE) return false;

   int version = FileReadInteger(fh);
   if(version != STATE_FILE_VERSION)
     {
      FileClose(fh);
      LogDebug("[StatePersistence] Saved state version mismatch — ignoring, fresh start.");
      return false;
     }

   state.cycleActive        = (bool)FileReadInteger(fh);
   state.gridPlaced         = (bool)FileReadInteger(fh);
   state.passCounter        = FileReadInteger(fh);
   state.lotMode            = (ENUM_LOT_MODE)FileReadInteger(fh);
   state.anchorBuy          = FileReadDouble(fh);
   state.anchorSell         = FileReadDouble(fh);

   state.lastHitDirection   = (ENUM_ORDER_TYPE)FileReadInteger(fh);
   state.prevHitDirection   = (ENUM_ORDER_TYPE)FileReadInteger(fh);
   state.lastHitLot         = FileReadDouble(fh);
   state.lastHitPrice       = FileReadDouble(fh);
   state.prevHitPrice       = FileReadDouble(fh);
   state.lastHitTime        = (datetime)FileReadLong(fh);
   state.lastHitTicket      = (ulong)FileReadLong(fh);

   state.farthestHitBuy     = FileReadDouble(fh);
   state.farthestHitSell    = FileReadDouble(fh);
   state.currentBlockLot    = FileReadDouble(fh);

   int levelCount = FileReadInteger(fh);
   ArrayResize(state.levelPrices,     levelCount);
   ArrayResize(state.levelVisitCount, levelCount);
   ArrayResize(state.levelLastSide,   levelCount);
   ArrayResize(state.levelBaseLot,    levelCount);
   FileReadArray(fh, state.levelPrices);
   FileReadArray(fh, state.levelVisitCount);
   FileReadArray(fh, state.levelLastSide);
   FileReadArray(fh, state.levelBaseLot);

   int runCount = FileReadInteger(fh);
   ArrayResize(state.runLevels, runCount);
   FileReadArray(fh, state.runLevels);
   state.runSide            = FileReadInteger(fh);

   state.basketProfit       = FileReadDouble(fh);
   state.basketBuyProfit    = FileReadDouble(fh);
   state.basketSellProfit   = FileReadDouble(fh);

   state.slApplied          = (bool)FileReadInteger(fh);
   state.slLevel            = FileReadDouble(fh);
   state.slWinnerSide       = FileReadInteger(fh);
   state.slWallArmed        = (bool)FileReadInteger(fh);
   state.slAllWinnersClosed = (bool)FileReadInteger(fh);

   state.refillNeeded       = (bool)FileReadInteger(fh);

   state.cleanupType        = (ENUM_CLEANUP_MODE)FileReadInteger(fh);
   state.cleanupInProgress  = (bool)FileReadInteger(fh);
   state.cleanupStep        = FileReadInteger(fh);

   state.marginWarning      = (bool)FileReadInteger(fh);
   state.sessionAllowed     = (bool)FileReadInteger(fh);
   state.gapFaultDetected   = (bool)FileReadInteger(fh);

   state.lastBarGridCheck   = (datetime)FileReadLong(fh);
   state.lastBarRecenter    = (datetime)FileReadLong(fh);

   state.mode               = (EA_MODE)FileReadInteger(fh);

   FileClose(fh);
   return true;
}

#endif