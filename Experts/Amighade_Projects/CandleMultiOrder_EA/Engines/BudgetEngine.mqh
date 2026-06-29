//+------------------------------------------------------------------+
//| BudgetEngine.mqh                                                  |
//| Budget exhaustion check and SL chain continuation                |
//+------------------------------------------------------------------+
#ifndef CMO_BUDGET_ENGINE_MQH
#define CMO_BUDGET_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "LotEngine.mqh"
#include "ResetEngine.mqh"

//+------------------------------------------------------------------+
//| Add SL to next oldest unprotected opposite deal                  |
//+------------------------------------------------------------------+
void AddSLToNextOppositeDeal(PosLists &poslists)
{
   int n = ArraySize(poslists.lstAll);
   SortByOpenTimeAscending(poslists.lstAll);
   if(n < 2) return;

   ulong  lastTicket = poslists.lstAll[n-1].ticket;
   double lastSL     = poslists.lstAll[n-1].sl;
   if(lastSL > 0.0) return; // already protected

   double refPrice = poslists.lstAll[n-2].openPrice;
   UpdateSL(lastTicket, refPrice);
   BuildAllListsSorted(poslists);
}

//+------------------------------------------------------------------+
//| Manage budget: SL chain continuation when exhausted             |
//+------------------------------------------------------------------+
void ManageBudget(PosLists &poslists)
{
   if(!UseBudgetExhaustion) return;
   if(gABWCLArmed) { ResetBudgetExhausted(); return; }

   int n = ArraySize(poslists.lstAll);
   if(n < 2) { ResetBudgetExhausted(); return; }

   if(gBudgetExhausted)
      AddSLToNextOppositeDeal(poslists);
}

//+------------------------------------------------------------------+
//| Check if budget is exhausted — sets gBudgetExhausted             |
//+------------------------------------------------------------------+
void ExhaustBudgetCheck(PosLists &poslists)
{
   if(!UseBudgetExhaustion) return;

   int    nWNSL    = ArraySize(poslists.lstWNSL);
   int    nAll     = ArraySize(poslists.lstAll);
   double totalLot = 0.0;
   for(int i = 0; i < nWNSL; i++) totalLot += poslists.lstWNSL[i].lots;

   // Check open deal count limit
   if(ExhaustMaxOpenDeals > 0 && (nAll >= ExhaustMaxOpenDeals || totalLot >= gMaxLot))
     { gBudgetExhausted = true; return; }

   const double balance      = AccountInfoDouble(ACCOUNT_BALANCE);
   const double marginUsedNow= AccountInfoDouble(ACCOUNT_MARGIN);
   double budgetLimit        = (AllowedEquity > 0.0) ? AllowedEquity : balance;
   if(budgetLimit <= 0.0) { gBudgetExhausted = true; return; }

   // Compute next lot
   double buyEntry  = gbuyEntry_range;
   double sellEntry = gsellEntry_range;
   ENUM_ORDER_TYPE ptype;
   double nextLot = ComputeNextLotSizeINC(ptype, buyEntry, sellEntry, poslists);

   if(nextLot < 0.0) { gBudgetExhausted = true; return; }

   // Calculate dominant lots after next order
   double buyLots = 0.0, sellLots = 0.0;
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   for(int i = 0; i < nAllDeals; i++)
     {
      if(poslists.lstAllDeals[i].type==POSITION_TYPE_BUY)  buyLots  += poslists.lstAllDeals[i].lots;
      else                                                   sellLots += poslists.lstAllDeals[i].lots;
     }

   if(ptype==ORDER_TYPE_BUY_STOP||ptype==ORDER_TYPE_BUY_LIMIT)       buyLots  += nextLot;
   else if(ptype==ORDER_TYPE_SELL_STOP||ptype==ORDER_TYPE_SELL_LIMIT) sellLots += nextLot;
   else { gBudgetExhausted = true; return; }

   double dominantAfter = MathAbs(buyLots - sellLots);
   ENUM_ORDER_TYPE marginType = (buyLots >= sellLots ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double px = (marginType==ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol,SYMBOL_BID));

   double marginReqAfter = 0.0;
   if(dominantAfter > 0.0)
      if(!OrderCalcMargin(marginType, _Symbol, dominantAfter, px, marginReqAfter))
        { gBudgetExhausted = true; return; }

   if(marginReqAfter > budgetLimit) { gBudgetExhausted = true; return; }

   // Max lot check
   if(nextLot >= gMaxLot) { gBudgetExhausted = true; return; }

   // Deal size exhaustion check
   if(ExhaustMaxDealSize > 0.0 && nWNSL > 0)
     {
      double trigger = (LotSizeInput / gMinLot) * ExhaustMaxDealSize;
      if(nextLot >= trigger) { gBudgetExhausted = true; return; }
     }

   if(EnableDebugLogs)
      PrintFormat("[BudgetEngine] Margin OK. Future=%.2f Limit=%.2f Used=%.2f",
                  marginReqAfter, budgetLimit, marginUsedNow);
}

#endif
