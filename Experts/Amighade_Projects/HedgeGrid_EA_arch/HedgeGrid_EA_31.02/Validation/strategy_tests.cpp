#include "mt5_mock.hpp"
#include "ea_under_test.hpp"
#include <functional>

int passed=0;
void fresh(GridState &s)
  {
   orders.clear();positions.clear();historyOrders.clear();historyDeals.clear();
   sends.clear();submissions.clear();selectedOrder=selectedPosition=-1;
   connected=tradeAllowed=sendOK=true;mock_ms=1000;mock_us=1000000;nextRequest=1;
   s=GridState{};ResetGridState(s);s.magicNumber=77;InitScheduler30();
   InpEnableDebugLog=false;InpCleanupAsyncBatch=3;
  }
void check(const char *name,std::function<void()> body)
  {body();passed++;std::cout<<"PASS "<<name<<std::endl;}
int main()
  {
   check("initial grid sends three async requests, waits for confirmation, then sends the remainder",[]()
     {
      GridState s;fresh(s);
      InpInitialGridLevels=3;InpInitialGap=2.0;InpGridSpacing=.5;
      InpInitialSizing=SIZING_FIXED;InpFixedLot=.01;
      InpGridAnchorMode=ANCHOR_CURRENT_PRICE;InpFirstLevelSLMode=FIRST_SL_NONE;
      InpLotIncreaseMode=LOT_INC_NONE;InpInsideMaintenanceStyle=MAINTENANCE_NONE;
      InpOutsideRefillStyle=OUTSIDE_NONE;InpSLArmMode=SL_NONE;InpSLTrailMode=SL_NONE;
      UseTimeFilter=false;

      Strategy_MediumGrid(s);
      assert(s.lifecycle==GRID_BUILDING);
      assert(ArraySize(s.items)==6);
      assert(sends.empty()); // The strategy only creates intents.
      for(int level=1;level<=3;level++)
        {
         bool foundBuy=false,foundSell=false;
         for(auto &item:s.items)
           {
            assert(item.action==ACTION_PLACE&&item.actionStatus==ACTION_READY);
            if(item.level!=level)continue;
            assert(std::abs(item.targetLot-.01)<1e-9);
            if(item.orderType==ORDER_TYPE_BUY_STOP&&
               std::abs(item.targetPrice-(101.0+.5*(level-1)))<1e-9)foundBuy=true;
            if(item.orderType==ORDER_TYPE_SELL_STOP&&
               std::abs(item.targetPrice-(99.0-.5*(level-1)))<1e-9)foundSell=true;
           }
         assert(foundBuy&&foundSell);
        }

      ProcessPendingActions(s,GetMicrosecondCount(),15000);
      assert(sends.size()==3);
      assert(submissions.size()==3);
      int waiting=0,ready=0;
      for(auto &item:s.items)
        {
         if(item.actionStatus==ACTION_WAIT_RESULT)
           {waiting++;assert(item.requestId>0);}
         else if(item.actionStatus==ACTION_READY) ready++;
        }
      assert(waiting==3&&ready==3);
      for(auto &request:sends) assert(request.action==TRADE_ACTION_PENDING);

      // Do not send the remaining half until all three first requests have
      // returned and their live orders have been reconciled.
      ProcessPendingActions(s,GetMicrosecondCount(),15000);
      assert(sends.size()==3);
      for(auto &item:s.items)
         if(item.actionStatus==ACTION_WAIT_RESULT)
           {item.action=ACTION_NONE;item.actionStatus=ACTION_IDLE;item.brokerPresent=true;}
      ProcessPendingActions(s,GetMicrosecondCount(),15000);
      assert(sends.size()==6&&submissions.size()==6);
     });
   check("partial initial grid cleans up and retries the whole grid",[]()
     {
      GridState s;fresh(s);
      InpInitialGridLevels=1;InpInitialGap=2.0;InpGridSpacing=.5;
      InpInitialSizing=SIZING_FIXED;InpFixedLot=.01;
      InpGridAnchorMode=ANCHOR_CURRENT_PRICE;InpFirstLevelSLMode=FIRST_SL_NONE;
      InpLotIncreaseMode=LOT_INC_NONE;InpInsideMaintenanceStyle=MAINTENANCE_NONE;
      InpOutsideRefillStyle=OUTSIDE_NONE;InpSLArmMode=SL_NONE;InpSLTrailMode=SL_NONE;
      UseTimeFilter=false;

      uint rejected=RequestPlacePending(s,ORDER_TYPE_BUY_STOP,101,.01,0,0,1);
      uint accepted=RequestPlacePending(s,ORDER_TYPE_SELL_STOP,99,.01,0,0,1);
      s.anchorBuy=101;s.anchorSell=99;
      int buy=FindItemById(s,rejected),sell=FindItemById(s,accepted);
      s.items[buy].actionStatus=ACTION_FAILED; // Invalid-price result.
      s.items[sell].action=ACTION_NONE;
      s.items[sell].actionStatus=ACTION_IDLE;
      s.items[sell].orderTicket=700;
      s.items[sell].brokerPresent=true;
      orders.push_back(Order{700});

      StrategyVerifyInitialGrid(s);
      assert(s.safetyStopPending&&s.safetyStopReason=="INITIAL_GRID_INCOMPLETE");
      StartCleanup(s,s.safetyStopReason);
      assert(s.lifecycle==GRID_CLEANUP);
      assert(ArraySize(s.items)==1&&s.items[0].action==ACTION_DELETE);
      ProcessPendingActions(s,GetMicrosecondCount(),15000);
      assert(sends.size()==1&&sends[0].action==TRADE_ACTION_REMOVE);

      // A broker rejection does not finish cleanup: retry the same deletion
      // after the normal delay, then wait for live absence and history.
      TransactionItem rejectTx{};ResetTransactionItem(rejectTx);
      rejectTx.type=TRADE_TRANSACTION_REQUEST;rejectTx.requestMagic=77;
      rejectTx.requestId=s.items[0].requestId;rejectTx.retcode=10013; // TRADE_RETCODE_INVALID
      assert(HandleRequestTransaction(s,rejectTx));
      ReconcileTradeItems(s);
      StartCleanup(s,s.cleanupReason);
      ProcessPendingActions(s,GetMicrosecondCount(),15000);
      assert(sends.size()==1);
      mock_ms+=500;mock_us+=500000;
      StartCleanup(s,s.cleanupReason);
      ProcessPendingActions(s,GetMicrosecondCount(),15000);
      assert(sends.size()==2&&s.items[0].actionStatus==ACTION_WAIT_RESULT);
      TransactionItem acceptTx{};ResetTransactionItem(acceptTx);
      acceptTx.type=TRADE_TRANSACTION_REQUEST;acceptTx.requestMagic=77;
      acceptTx.requestId=s.items[0].requestId;acceptTx.retcode=TRADE_RETCODE_DONE;
      assert(HandleRequestTransaction(s,acceptTx));
      ReconcileTradeItems(s);
      assert(!CleanupFinished(s)&&sends.size()==2); // Result is not live confirmation.

      orders.clear();
      Order canceled{700};canceled.status=ORDER_STATE_CANCELED;
      historyOrders[700]=canceled;
      ReconcileTradeItems(s);
      assert(CleanupFinished(s));
      ProcessCleanupState(s);
      assert(s.lifecycle==GRID_IDLE&&ArraySize(s.items)==0);

      s.sessionAllowed=true;
      Strategy_MediumGrid(s);
      assert(s.lifecycle==GRID_BUILDING&&ArraySize(s.items)==2);
      for(auto &item:s.items)
         assert(item.action==ACTION_PLACE&&item.actionStatus==ACTION_READY);
     });
   check("nearest-grid SL candidate still requires a non-negative net basket",[]()
     {
      GridState s;fresh(s);s.lastHitPrice=100.0;s.lastHitDirection=ORDER_TYPE_BUY;
      s.buyVolume=1.0;s.buyAvgEntry=100.0;
      InpCommissionPerLot=6.0;
      assert(StrategySLCandidate(s,POSITION_TYPE_BUY,SL_FIRST_GRID)==0.0);
      InpCommissionPerLot=0.0;
      assert(std::abs(StrategySLCandidate(s,POSITION_TYPE_BUY,SL_FIRST_GRID)-100.0)<1e-9);
     });
   check("full position exit triggers cleanup after reconciliation removes the position item",[]()
     {
      GridState s;fresh(s);positions.push_back(Position{900,100});orders.push_back(Order{101});
      ReconcileTradeItems(s);s.lifecycle=GRID_ACTIVE;
      historyDeals[501]=Deal{501,201,100,DEAL_ENTRY_OUT,1.0};
      positions.clear();
      TransactionItem tx{};ResetTransactionItem(tx);tx.type=TRADE_TRANSACTION_DEAL_ADD;
      tx.symbol=_Symbol;tx.dealTicket=501;tx.positionTicket=900;
      assert(HandleDealTransaction(s,tx));
      assert(s.lifecycle==GRID_CLEANUP);
      int order=FindItemByOrderTicket(s,101);
      assert(order>=0&&s.items[order].action==ACTION_DELETE);
     });
   std::cout<<passed<<" strategy scenario groups passed\n";
  }
