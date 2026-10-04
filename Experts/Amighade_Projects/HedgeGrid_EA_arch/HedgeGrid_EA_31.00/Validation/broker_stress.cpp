#include "mt5_mock.hpp"
#include "ea_under_test.hpp"
#include <deque>
#include <functional>
#include <random>
#include <set>
#include <sstream>
#include <stdexcept>

struct Totals
  {
   long frames=0, sends=0, executions=0, rejected=0, localFailed=0;
   long entries=0, exits=0, partialEntries=0, partialCloses=0;
   long callbacks=0, droppedFacts=0, disconnects=0, completed=0;
  } totals;

struct Job { ulong due; std::function<void()> run; };
struct Flight { uint request; ulong cycle; uint item; MqlTradeRequest req; };

class BrokerTrial
  {
   std::mt19937 rng;
   unsigned seed;
   std::vector<Order> serverOrders;
   std::vector<Position> serverPositions;
   std::vector<Job> serverJobs, networkJobs;
   std::map<uint,Flight> active;
   std::deque<string> trace;
   size_t taken=0;
   ulong serial=100, dealSerial=10000, revision=0, visibleOrderRevision=0, visiblePositionRevision=0;
   bool draining=false, cleanupStarted=false;
   ulong reconnectAt=0;

   int pick(int n) { return int(rng()%n); }
   bool chance(int n) { return pick(100)<n; }
   void log(const string &s)
     {
      trace.push_back(std::to_string(mock_ms)+" "+s);
      if(trace.size()>1000) trace.pop_front();
     }
   void require(bool yes, const string &what)
     {
      if(yes) return;
      std::cerr<<"FAIL seed="<<seed<<" time="<<mock_ms<<" "<<what<<"\n";
      for(auto &s:trace)std::cerr<<s<<"\n";
      std::cerr<<"server="<<ownedOrders()<<" orders,"<<ownedPositions()<<" positions; view="<<orders.size()<<","<<positions.size()<<"; lifecycle="<<g_state.lifecycle<<"\n";
      for(auto &i:g_state.items)
         std::cerr<<"item "<<i.id<<" kind="<<i.kind<<" order="<<i.orderTicket<<" pos="<<i.positionTicket<<" action="<<i.action<<" status="<<i.actionStatus<<" req="<<i.requestId<<" present="<<i.brokerPresent<<" volume="<<i.volume<<" requested="<<i.requestedLot<<" retcode="<<i.lastRetcode<<" pending="<<i.reconcilePending<<"\n";
      throw std::runtime_error(what);
     }
   int orderAt(ulong t)
     {
      for(int i=0;i<(int)serverOrders.size();i++) if(serverOrders[i].ticket==t) return i;
      return -1;
     }
   int positionAt(ulong t)
     {
      for(int i=0;i<(int)serverPositions.size();i++) if(serverPositions[i].ticket==t) return i;
      return -1;
     }
   int ownedOrders() { int n=0;for(auto &o:serverOrders)if(o.magic==77&&o.symbol==_Symbol)n++;return n; }
   int ownedPositions() { int n=0;for(auto &p:serverPositions)if(p.magic==77&&p.symbol==_Symbol)n++;return n; }

   void publishView()
     {
      auto os=serverOrders; auto ps=serverPositions; ulong v=++revision;
      networkJobs.push_back({mock_ms+ulong(pick(8))*15,[this,os,ps,v]()
        {
         if(v<visibleOrderRevision)return;
         orders=os; selectedOrder=-1; visibleOrderRevision=v;
        }});
      networkJobs.push_back({mock_ms+ulong(pick(8))*15,[this,ps,v]()
        {
         if(v<visiblePositionRevision)return;
         positions=ps; selectedPosition=-1; visiblePositionRevision=v;
        }});
     }
   void publishOrderHistory(Order o)
     {
      networkJobs.push_back({mock_ms+ulong(pick(14))*15,[o](){historyOrders[o.ticket]=o;}});
     }
   void publishDeal(Deal d, ulong ticket)
     {
      networkJobs.push_back({mock_ms+ulong(pick(14))*15,[d](){historyDeals[d.ticket]=d;}});
      MqlTradeTransaction tx{};tx.type=TRADE_TRANSACTION_DEAL_ADD;tx.symbol=_Symbol;
      tx.order=d.order;tx.position=ticket;tx.deal=d.ticket;tx.price=d.price;tx.volume=d.volume;tx.deal_type=d.type;
      event(tx);
     }
   void event(MqlTradeTransaction tx)
     {
      // Losing a notification must not lose the live broker object.
      if(chance(8)){totals.droppedFacts++;return;}
      int copies=chance(8)?2:1;
      for(int n=0;n<copies;n++)networkJobs.push_back({mock_ms+ulong(pick(14))*15,[tx]()
        {
         MqlTradeRequest unrelated{};unrelated.symbol="POISON";unrelated.magic=999;
         MqlTradeResult unrelatedResult{};unrelatedResult.request_id=999999;
         OnTradeTransaction(tx,unrelated,unrelatedResult);totals.callbacks++;
        }});
     }
   void requestResult(const Flight &f, int code, ulong order=0, ulong deal=0)
     {
      log("result req="+std::to_string(f.request)+" code="+std::to_string(code));
      MqlTradeTransaction tx{};tx.type=TRADE_TRANSACTION_REQUEST;tx.symbol="POISON";
      MqlTradeResult res{};res.request_id=f.request;res.retcode=code;res.order=(deal&&f.req.action==TRADE_ACTION_DEAL&&f.request%2==0)?0:order;res.deal=deal;
      networkJobs.push_back({mock_ms+ulong(pick(16))*15,[tx,res,f]()
        {OnTradeTransaction(tx,f.req,res);totals.callbacks++;}});
     }
   void exitPosition(ulong ticket, double quantity, int magic)
     {
      int p=positionAt(ticket);if(p<0)return;
      Position old=serverPositions[p];quantity=std::min(quantity,old.volume);
      Deal d{++dealSerial,++serial,old.identifier,DEAL_ENTRY_OUT,quantity,100,magic};
      d.type=(old.side==POSITION_TYPE_BUY)?DEAL_TYPE_SELL:DEAL_TYPE_BUY;
      serverPositions[p].volume-=quantity;
      if(serverPositions[p].volume<1e-8)serverPositions.erase(serverPositions.begin()+p);
      Order execution{d.order};execution.type=ENUM_ORDER_TYPE(d.type);
      execution.status=ORDER_STATE_FILLED;execution.positionId=old.identifier;
      execution.initial=quantity;execution.volume=0;publishOrderHistory(execution);
      publishDeal(d,ticket);publishView();totals.exits++;
     }
   void fill(ulong ticket)
     {
      int o=orderAt(ticket);if(o<0)return;
      Order old=serverOrders[o];
      bool partial=chance(35)&&old.volume>.11;
      double quantity=partial?old.volume*.5:old.volume;
      ulong posTicket=ticket+100000;
      int p=positionAt(posTicket);
      if(p<0)
        {
         Position pos{posTicket,ticket,quantity,old.price,old.sl,old.tp};
         pos.side=(old.type==ORDER_TYPE_BUY_LIMIT||old.type==ORDER_TYPE_BUY_STOP)?POSITION_TYPE_BUY:POSITION_TYPE_SELL;
         serverPositions.push_back(pos);
        }
      else serverPositions[p].volume+=quantity;
      serverOrders[o].volume-=quantity;serverOrders[o].positionId=ticket;
      MqlTradeTransaction tx{};tx.symbol=_Symbol;tx.order=ticket;
      if(serverOrders[o].volume<1e-8)
        {
         Order h=serverOrders[o];h.status=ORDER_STATE_FILLED;
         publishOrderHistory(h);serverOrders.erase(serverOrders.begin()+o);
         tx.type=TRADE_TRANSACTION_ORDER_DELETE;
        }
      else
        {
         serverOrders[o].status=ORDER_STATE_PARTIAL;tx.type=TRADE_TRANSACTION_ORDER_UPDATE;
         if(chance(65))serverJobs.push_back({mock_ms+ulong(5+pick(20))*15,[this,ticket](){fill(ticket);}});
         totals.partialEntries++;
        }
      event(tx);
      Deal d{++dealSerial,ticket,ticket,DEAL_ENTRY_IN,quantity,old.price};
      d.type=(old.type==ORDER_TYPE_BUY_LIMIT||old.type==ORDER_TYPE_BUY_STOP)?DEAL_TYPE_BUY:DEAL_TYPE_SELL;
      publishDeal(d,posTicket);publishView();totals.entries++;
      if(!partial&&chance(15))serverJobs.push_back({mock_ms+ulong(10+pick(30))*15,[this,posTicket]()
        {int p=positionAt(posTicket);if(p>=0)exitPosition(posTicket,serverPositions[p].volume,0);}});
      log("fill order="+std::to_string(ticket)+(partial?" partial":" full"));
     }
   void execute(uint rid)
     {
      Flight f=active.at(rid);active.erase(rid);totals.executions++;
      MqlTradeRequest r=f.req;
      log("execute req="+std::to_string(rid)+" action="+std::to_string(r.action));
      if(chance(draining?8:15))
        {requestResult(f,TRADE_RETCODE_REJECT);totals.rejected++;return;}
      if(r.action==TRADE_ACTION_PENDING)
        {
         Order o{++serial,r.type,r.price,r.volume,r.volume,r.sl,r.tp};
         serverOrders.push_back(o);publishView();requestResult(f,TRADE_RETCODE_PLACED,o.ticket);
         MqlTradeTransaction tx{};tx.type=TRADE_TRANSACTION_ORDER_ADD;tx.symbol=_Symbol;tx.order=o.ticket;event(tx);
         if(chance(75))serverJobs.push_back({mock_ms+ulong(1+pick(35))*15,[this,o](){fill(o.ticket);}});
        }
      else if(r.action==TRADE_ACTION_REMOVE)
        {
         int o=orderAt(r.order);
         if(o<0){requestResult(f,TRADE_RETCODE_REJECT);totals.rejected++;return;}
         require(serverOrders[o].magic==77&&serverOrders[o].symbol==_Symbol,"delete touched foreign owner");
         Order h=serverOrders[o];h.status=ORDER_STATE_CANCELED;publishOrderHistory(h);
         serverOrders.erase(serverOrders.begin()+o);publishView();requestResult(f,TRADE_RETCODE_DONE);
         MqlTradeTransaction tx{};tx.type=TRADE_TRANSACTION_ORDER_DELETE;tx.symbol=_Symbol;tx.order=r.order;event(tx);
        }
      else
        {
         int p=positionAt(r.position);
         if(p<0){requestResult(f,TRADE_RETCODE_REJECT);totals.rejected++;return;}
         require(serverPositions[p].magic==77&&serverPositions[p].symbol==_Symbol,"position request touched foreign owner");
         if(r.action==TRADE_ACTION_SLTP)
           {
            serverPositions[p].sl=r.sl;serverPositions[p].tp=r.tp;publishView();requestResult(f,TRADE_RETCODE_DONE);
            MqlTradeTransaction tx{};tx.type=TRADE_TRANSACTION_POSITION;tx.symbol=_Symbol;tx.position=r.position;event(tx);
           }
         else
           {
            require(r.position!=0,"naked market request");
            require(r.type!=ENUM_ORDER_TYPE(serverPositions[p].side),"close direction is wrong");
            if(r.volume>serverPositions[p].volume+1e-8){requestResult(f,TRADE_RETCODE_REJECT);totals.rejected++;return;}
            bool partial=chance(25)&&r.volume>.11;
            double quantity=partial?r.volume*.5:r.volume;
            exitPosition(r.position,quantity,77);
            requestResult(f,partial?TRADE_RETCODE_DONE_PARTIAL:TRADE_RETCODE_DONE,serial,dealSerial);
            if(partial)totals.partialCloses++;
           }
        }
     }
   void runDue(std::vector<Job> &jobs)
     {
      std::vector<Job> due;
      for(size_t i=0;i<jobs.size();)
         if(jobs[i].due<=mock_ms){due.push_back(jobs[i]);jobs.erase(jobs.begin()+i);}else i++;
      std::shuffle(due.begin(),due.end(),rng);
      for(auto &job:due)job.run();
     }
   void captureSubmissions()
     {
      while(taken<submissions.size())
        {
         Submission s=submissions[taken++];totals.sends++;
         if(!s.sent){totals.localFailed++;continue;}
         int i=FindItemByRequestId(g_state,s.result.request_id);
         require(i>=0,"submission has no correlated item");
         TradeItem item=g_state.items[i];
         require(item.actionStatus==ACTION_WAIT_RESULT,"submitted item not WAIT_RESULT");
         for(auto &kv:active)
            require(kv.second.cycle!=g_state.cycleId||kv.second.item!=item.id,"two broker requests outstanding for one item");
         auto r=s.request;
         for(auto &kv:active)
           {
            auto old=kv.second.req;
            if(r.position)require(old.position!=r.position,"overlapping requests for one broker position");
            if(r.order)require(old.order!=r.order,"overlapping requests for one broker order");
           }
         require(r.magic==77&&r.symbol==_Symbol,"bad outbound owner or symbol");
         if(r.action==TRADE_ACTION_PENDING)
           require(r.price==item.requestedPrice&&r.volume==item.requestedLot&&r.sl==item.requestedSL&&r.tp==item.requestedTP,"PLACE payload altered");
         if(r.action==TRADE_ACTION_SLTP)require(r.sl==item.requestedSL&&r.position==item.positionTicket,"SL payload altered");
         if(r.action==TRADE_ACTION_REMOVE)require(r.order==item.orderTicket,"DELETE target altered");
         if(r.action==TRADE_ACTION_DEAL)require(r.position==item.positionTicket&&r.volume==item.requestedLot,"CLOSE payload altered");
         if(cleanupStarted)require(r.action==TRADE_ACTION_REMOVE||r.action==TRADE_ACTION_DEAL,"cleanup sent non-liquidation request");
         Flight f{s.result.request_id,g_state.cycleId,item.id,r};active[f.request]=f;
         serverJobs.push_back({mock_ms+ulong(1+pick(7))*15,[this,f](){execute(f.request);}});
         log("send req="+std::to_string(f.request)+" item="+std::to_string(item.id)+" action="+std::to_string(r.action));
        }
     }
   void assertBook()
     {
      std::set<ulong> liveOrders,livePositions;
      std::set<uint> ids,requests;
      for(auto &i:g_state.items)
        {
         require(ids.insert(i.id).second,"duplicate local item ID");
         if(i.kind==ITEM_ORDER&&i.orderTicket)require(liveOrders.insert(i.orderTicket).second,"duplicate broker order mapping");
         if(i.kind==ITEM_POSITION&&i.positionTicket)require(livePositions.insert(i.positionTicket).second,"duplicate broker position mapping");
         if(i.requestId)require(requests.insert(i.requestId).second,"duplicate request correlation");
        }
      if(cleanupStarted&&g_state.lifecycle!=GRID_CLEANUP)
        {
         require(ownedOrders()==0&&ownedPositions()==0,"cleanup finished before authoritative broker zero/zero");
         for(auto &kv:active)require(kv.second.req.action!=TRADE_ACTION_PENDING,"cleanup finished with outstanding broker PLACE");
        }
     }
   void command()
     {
      if(chance(40))
        {
         int level=pick(16);
         RequestPlacePending(g_state,(level%2)?ORDER_TYPE_SELL_STOP:ORDER_TYPE_BUY_STOP,100+level*.5,.2+pick(4)*.2,0,0,level);
        }
      if(g_state.items.empty())return;
      TradeItem i=g_state.items[pick(g_state.items.size())];
      if(i.kind==ITEM_ORDER&&i.orderTicket)
        {
         if(chance(50))RequestReplaceOrder(g_state,i.orderTicket,110+pick(16)*.5,.4,0,0);
         else RequestDeleteOrder(g_state,i.orderTicket);
        }
      else if(i.kind==ITEM_POSITION)
        {
         if(chance(55))RequestModifySL(g_state,i.positionTicket,90+pick(10)*.5);
         else RequestClosePosition(g_state,i.positionTicket);
        }
     }
   void frame(bool drive)
     {
      mock_ms+=15;mock_us+=15000;totals.frames++;
      if(reconnectAt&&mock_ms>=reconnectAt){connected=true;reconnectAt=0;log("reconnect");}
      if(drive&&!reconnectAt&&chance(1))
        {connected=false;reconnectAt=mock_ms+ulong(10+pick(25))*15;totals.disconnects++;log("disconnect");}
      runDue(serverJobs);
      if(connected)runDue(networkJobs);
      sendOK=draining||!chance(3);tradeAllowed=draining||!chance(5);
      if(drive&&connected)command();
      OnTimer();captureSubmissions();assertBook();
     }
public:
   BrokerTrial(unsigned n):rng(n),seed(n)
     {
      orders.clear();positions.clear();historyOrders.clear();historyDeals.clear();sends.clear();submissions.clear();
      selectedHistoryDeals.clear();selectedOrder=selectedPosition=-1;
      mock_ms=1000;mock_us=1000000;nextRequest=1;connected=tradeAllowed=sendOK=true;
      accountMode=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;fifo=false;InpMagicNumber=77;InpEnableDebugLog=false;
      InpSchedulerMaxTransactionsPerFrame=32;InpSchedulerBudgetMs=15;InpCleanupAsyncBatch=3;
      g_state=GridState{};
      require(OnInit()==INIT_SUCCEEDED,"startup failed");
      g_state.mode=MODE_PAUSED; // This harness drives broker intents independently of strategy.
      Order foreign{900000};foreign.magic=88;serverOrders.push_back(foreign);
      Position foreignP{900001,900001};foreignP.magic=88;serverPositions.push_back(foreignP);
      publishView();
     }
   void run()
     {
      for(int n=0;n<300;n++)frame(true);
      draining=true;connected=tradeAllowed=sendOK=true;reconnectAt=0;
      g_state.mode=MODE_PAUSED; // Prevent a new strategy cycle after cleanup resets the state.
      StartCleanup(g_state,"stress drain");cleanupStarted=true;log("cleanup start");
      for(int n=0;n<1600;n++)
        {
         frame(false);
         if(g_state.lifecycle==GRID_IDLE&&active.empty()&&serverJobs.empty()&&networkJobs.empty()&&g_transactionQueue.empty())
           {totals.completed++;return;}
        }
      require(false,"cleanup failed to converge after all bounded broker responses");
     }
  };

int main(int argc,char **argv)
  {
   unsigned first=argc>1?std::stoul(argv[1]):1;
   unsigned count=argc>2?std::stoul(argv[2]):100;
   try{for(unsigned n=first;n<first+count;n++)BrokerTrial(n).run();}
   catch(const std::exception &e){std::cerr<<e.what()<<"\n";return 1;}
   std::cout<<"PASS broker stress seeds "<<first<<".."<<(first+count-1)<<"\n"
            <<"completed="<<totals.completed<<" frames="<<totals.frames<<" submissions="<<totals.sends<<" executions="<<totals.executions<<" broker_rejections="<<totals.rejected<<" local_failures="<<totals.localFailed<<"\n"
            <<"entries="<<totals.entries<<" partial_entries="<<totals.partialEntries<<" exits="<<totals.exits<<" partial_closes="<<totals.partialCloses<<" callbacks="<<totals.callbacks<<" dropped_facts="<<totals.droppedFacts<<" disconnects="<<totals.disconnects<<"\n";
  }
