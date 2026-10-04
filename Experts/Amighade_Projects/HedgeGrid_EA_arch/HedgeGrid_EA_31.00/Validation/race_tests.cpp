#include "mt5_mock.hpp"
#include "ea_under_test.hpp"
#include <functional>

int passed=0;
void fresh(GridState &s)
  {
   orders.clear();positions.clear();historyOrders.clear();historyDeals.clear();
   sends.clear();submissions.clear();selectedHistoryDeals.clear();
   selectedOrder=selectedPosition=-1;connected=tradeAllowed=sendOK=true;
   mock_ms=1000;mock_us=1000000;nextRequest=1;
   s=GridState{};ResetGridState(s);s.magicNumber=77;InitScheduler30();
  }
void step(GridState &s)
  {
   mock_ms+=500;mock_us+=500000;ReconcileTradeItems(s);
   if(s.lifecycle==GRID_CLEANUP)StartCleanup(s,"test");
  }
void send(GridState &s){ProcessPendingActions(s,GetMicrosecondCount(),15000);}
void result(GridState &s,uint id,int code,ulong order=0,ulong deal=0)
  {
   MqlTradeTransaction tx{};tx.type=TRADE_TRANSACTION_REQUEST;
   MqlTradeRequest req{};req.symbol=_Symbol;req.magic=77;
   MqlTradeResult res{};res.request_id=id;res.retcode=code;res.order=order;res.deal=deal;
   OnTradeTransaction(tx,req,res);ProcessTransactionQueue(s,GetMicrosecondCount(),15000);
  }
void check(const char *name,std::function<void()> body)
  {body();passed++;std::cout<<"PASS "<<name<<std::endl;}
int main()
  {
   check("stable and deleting orders cannot hide fills behind an empty position snapshot",[]()
     {
      for(bool deleting:{false,true})
        {
         GridState s;fresh(s);orders.push_back(Order{100});step(s);
         if(deleting){RequestDeleteOrder(s,100);send(s);}
         orders.clear();StartCleanup(s,"test");
         // Neither final history nor the position snapshot has arrived.
         for(int n=0;n<10;n++){step(s);assert(!CleanupFinished(s));}
         Order h{100};h.status=ORDER_STATE_FILLED;h.positionId=100;historyOrders[100]=h;
         historyDeals[500]=Deal{500,100,100};
         for(int n=0;n<10;n++){step(s);assert(!CleanupFinished(s));}
         positions.push_back(Position{900,100});step(s);send(s);
         assert(sends.back().action==TRADE_ACTION_DEAL);
         positions.clear();historyDeals[501]=Deal{501,101,100,DEAL_ENTRY_OUT};step(s);
         assert(CleanupFinished(s));
        }
     });
   check("successful CLOSE with an offsetting entry fill closes the remaining exposure",[]()
     {
      for(int code:{TRADE_RETCODE_DONE,TRADE_RETCODE_DONE_PARTIAL,TRADE_RETCODE_PLACED})
        {
         GridState s;fresh(s);positions.push_back(Position{900,100,.4});
         historyDeals[500]=Deal{500,100,100,DEAL_ENTRY_IN,.4};step(s);
         RequestClosePosition(s,900);send(s);uint req=s.items[0].requestId;
         result(s,req,code,code==TRADE_RETCODE_DONE?0:101,502);step(s);assert(s.items[0].actionStatus==ACTION_WAIT_CONFIRM);
         // The old snapshot has the same volume as the eventual new snapshot.
         // Execution evidence is still required, even with a successful result.
         historyDeals[501]=Deal{501,100,100,DEAL_ENTRY_IN,.4};
         Order close{101};close.initial=.4;close.volume=0;close.status=ORDER_STATE_FILLED;
         close.positionId=100;historyOrders[101]=close;
         // Final order history alone is not live execution confirmation.
         historyDeals.erase(501);step(s);assert(s.items[0].actionStatus==ACTION_WAIT_CONFIRM);
         historyDeals[501]=Deal{501,100,100,DEAL_ENTRY_IN,.4};
         historyDeals[502]=Deal{502,101,100,DEAL_ENTRY_OUT,.4};
         step(s);assert(s.items[0].actionStatus==ACTION_READY);send(s);
         assert(sends.size()==2&&sends.back().volume==.4);
         assert(s.items[0].lastDealTicket==0); // Result did not consume a DEAL callback.
        }
     });
   check("partial CLOSE does not resend while its execution order remains live",[]()
     {
      GridState s;fresh(s);positions.push_back(Position{900,100});
      historyDeals[500]=Deal{500,100,100};step(s);RequestClosePosition(s,900);send(s);
      result(s,s.items[0].requestId,TRADE_RETCODE_DONE_PARTIAL,101,501);
      historyDeals[501]=Deal{501,101,100,DEAL_ENTRY_OUT,.4};positions[0].volume=.6;
      Order closing{101};closing.type=ORDER_TYPE_SELL;closing.status=ORDER_STATE_PARTIAL;orders.push_back(closing);
      step(s);send(s);assert(sends.size()==1);
      orders.clear();step(s);send(s);assert(sends.size()==1); // History still missing.
      closing.status=ORDER_STATE_CANCELED;closing.volume=.6;closing.positionId=100;historyOrders[101]=closing;
      step(s);send(s);assert(sends.size()==2);
     });
   check("same-price broker object never confirms an unrelated outstanding PLACE",[]()
     {
      GridState s;fresh(s);RequestPlacePending(s,ORDER_TYPE_BUY_STOP,100,.4,0,0,7);send(s);
      uint req=s.items[0].requestId;
      orders.push_back(Order{100});step(s);
      int plan=FindItemByRequestId(s,req);assert(plan>=0&&s.items[plan].orderTicket==0);
      int live=FindItemByOrderTicket(s,100);assert(live>=0&&live!=plan);
      assert(s.items[live].action==ACTION_NONE);
      result(s,req,TRADE_RETCODE_PLACED,101);orders.push_back(Order{101});step(s);
      assert(s.items.size()==2);assert(FindItemByOrderTicket(s,100)>=0&&FindItemByOrderTicket(s,101)>=0);
     });
   check("late exact PLACE result merges metadata without overwriting live DELETE",[]()
     {
      GridState s;fresh(s);RequestPlacePending(s,ORDER_TYPE_BUY_STOP,100,.4,0,0,7);send(s);
      uint req=s.items[0].requestId;orders.push_back(Order{100});step(s);
      RequestDeleteOrder(s,100);send(s);int live=FindItemByOrderTicket(s,100);uint del=s.items[live].requestId;
      result(s,req,TRADE_RETCODE_PLACED,100);assert(s.items.size()==1);
      assert(s.items[0].requestId==del&&s.items[0].action==ACTION_DELETE&&s.items[0].level==7);
     });
   check("missing PLACE result remains locked and a late rejection releases cleanup",[]()
     {
      GridState s;fresh(s);RequestPlacePending(s,ORDER_TYPE_SELL_STOP,100,.4);send(s);
      uint req=s.items[0].requestId;StartCleanup(s,"test");
      for(int n=0;n<500;n++){step(s);send(s);assert(!CleanupFinished(s));}
      assert(sends.size()==1);result(s,req,TRADE_RETCODE_REJECT);step(s);assert(CleanupFinished(s));
     });
   check("old flat history cannot conceal a newly filled remainder",[]()
     {
      GridState s;fresh(s);Order o{100};o.volume=.6;orders.push_back(o);step(s);
      historyDeals[500]=Deal{500,100,100,DEAL_ENTRY_IN,.4};
      historyDeals[501]=Deal{501,101,100,DEAL_ENTRY_OUT,.4};
      orders.clear();o.status=ORDER_STATE_FILLED;o.volume=0;o.positionId=100;historyOrders[100]=o;
      StartCleanup(s,"test");for(int n=0;n<5;n++){step(s);assert(!CleanupFinished(s));}
      historyDeals[502]=Deal{502,100,100,DEAL_ENTRY_IN,.6};step(s);assert(!CleanupFinished(s));
      positions.push_back(Position{900,100,.6});step(s);send(s);
      assert(sends.size()==1&&sends.back().action==TRADE_ACTION_DEAL);
     });
   check("canceled partial remainder waits for its filled position before replacement",[]()
     {
      GridState s;fresh(s);Order o{100};orders.push_back(o);step(s);
      RequestReplaceOrder(s,100,105,.4);send(s);orders.clear();
      o.status=ORDER_STATE_CANCELED;o.volume=.6;o.positionId=100;historyOrders[100]=o;
      for(int n=0;n<5;n++){step(s);send(s);assert(sends.size()==1);}
      historyDeals[500]=Deal{500,100,100,DEAL_ENTRY_IN,.4};step(s);send(s);assert(sends.size()==1);
      positions.push_back(Position{900,100,.4});step(s);send(s);
      assert(sends.size()==2&&sends.back().action==TRADE_ACTION_PENDING&&sends.back().price==105);
     });
   std::cout<<passed<<" race scenario groups passed\n";
  }
