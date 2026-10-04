#pragma once
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <iostream>
#include <map>
#include <string>
#include <vector>
#include <cctype>
using std::string;
using datetime = long;
using ENUM_TIMEFRAMES = int;
const int WRONG_VALUE=-1, INIT_FAILED=1, INIT_SUCCEEDED=0, INIT_PARAMETERS_INCORRECT=2;
const string _Symbol="TEST";
const double _Point=.01;
const int _Period=1;
const int _Digits=2;
enum ENUM_ORDER_TYPE { ORDER_TYPE_BUY, ORDER_TYPE_SELL, ORDER_TYPE_BUY_LIMIT, ORDER_TYPE_SELL_LIMIT, ORDER_TYPE_BUY_STOP, ORDER_TYPE_SELL_STOP, ORDER_TYPE_BUY_STOP_LIMIT, ORDER_TYPE_SELL_STOP_LIMIT, ORDER_TYPE_CLOSE_BY };
enum ENUM_POSITION_TYPE { POSITION_TYPE_BUY, POSITION_TYPE_SELL };
enum ENUM_ORDER_TYPE_FILLING { ORDER_FILLING_FOK, ORDER_FILLING_IOC, ORDER_FILLING_RETURN };
enum ENUM_TRADE_REQUEST_ACTIONS { TRADE_ACTION_DEAL, TRADE_ACTION_PENDING, TRADE_ACTION_SLTP, TRADE_ACTION_REMOVE };
enum ENUM_TRADE_TRANSACTION_TYPE { TRADE_TRANSACTION_REQUEST, TRADE_TRANSACTION_ORDER_ADD, TRADE_TRANSACTION_ORDER_UPDATE, TRADE_TRANSACTION_ORDER_DELETE, TRADE_TRANSACTION_DEAL_ADD, TRADE_TRANSACTION_POSITION };
enum ENUM_DEAL_TYPE { DEAL_TYPE_BUY, DEAL_TYPE_SELL };
enum ENUM_DEAL_ENTRY { DEAL_ENTRY_IN, DEAL_ENTRY_OUT, DEAL_ENTRY_INOUT, DEAL_ENTRY_OUT_BY };
enum ENUM_ORDER_STATE { ORDER_STATE_STARTED, ORDER_STATE_PLACED, ORDER_STATE_CANCELED, ORDER_STATE_PARTIAL, ORDER_STATE_FILLED, ORDER_STATE_REJECTED, ORDER_STATE_EXPIRED, ORDER_STATE_REQUEST_ADD, ORDER_STATE_REQUEST_MODIFY, ORDER_STATE_REQUEST_CANCEL };
enum { SYMBOL_FILLING_MODE=100, SYMBOL_FILLING_IOC=2, SYMBOL_FILLING_FOK=1, SYMBOL_TRADE_TICK_SIZE=101, SYMBOL_BID, SYMBOL_ASK, SYMBOL_TRADE_STOPS_LEVEL, SYMBOL_VOLUME_MIN, ORDER_TIME_GTC, TERMINAL_CONNECTED, TERMINAL_TRADE_ALLOWED, MQL_TRADE_ALLOWED, ACCOUNT_MARGIN_MODE, ACCOUNT_MARGIN_MODE_RETAIL_HEDGING, ACCOUNT_FIFO_CLOSE, ORDER_SYMBOL, ORDER_MAGIC, ORDER_TYPE, ORDER_PRICE_OPEN, ORDER_VOLUME_CURRENT, ORDER_VOLUME_INITIAL, ORDER_SL, ORDER_TP, ORDER_STATE, ORDER_POSITION_ID, POSITION_SYMBOL, POSITION_MAGIC, POSITION_TYPE, POSITION_PRICE_OPEN, POSITION_VOLUME, POSITION_SL, POSITION_TP, POSITION_IDENTIFIER, DEAL_SYMBOL, DEAL_MAGIC, DEAL_ENTRY, DEAL_POSITION_ID, DEAL_ORDER, DEAL_TYPE, DEAL_PRICE, DEAL_VOLUME };
enum { TRADE_RETCODE_REQUOTE=10004, TRADE_RETCODE_REJECT=10006, TRADE_RETCODE_PLACED=10008, TRADE_RETCODE_DONE=10009, TRADE_RETCODE_DONE_PARTIAL=10010, TRADE_RETCODE_TIMEOUT=10012, TRADE_RETCODE_NO_CHANGES=10025, TRADE_RETCODE_CONNECTION=10031 };
struct MqlTradeRequest { string symbol; ulong magic=0; ENUM_TRADE_REQUEST_ACTIONS action{}; ENUM_ORDER_TYPE type{}; double volume=0,price=0,sl=0,tp=0; int type_time=0; ENUM_ORDER_TYPE_FILLING type_filling{}; ulong order=0,position=0; uint deviation=0; };
struct MqlTradeResult { uint request_id=0,retcode=0; ulong order=0,deal=0; };
struct MqlTradeTransaction { ENUM_TRADE_TRANSACTION_TYPE type{}; string symbol; ulong order=0,position=0,deal=0; ENUM_ORDER_TYPE order_type{}; ENUM_DEAL_TYPE deal_type{}; double price=0,volume=0; };
struct Order { ulong ticket; ENUM_ORDER_TYPE type=ORDER_TYPE_BUY_STOP; double price=100,volume=1,initial=1,sl=0,tp=0; int magic=77; string symbol="TEST"; ENUM_ORDER_STATE status=ORDER_STATE_PLACED; ulong positionId=0; };
struct Position { ulong ticket,identifier; double volume=1,price=100,sl=0,tp=0; int magic=77; string symbol="TEST"; ENUM_POSITION_TYPE side=POSITION_TYPE_BUY; };
struct Deal { ulong ticket,order,position; ENUM_DEAL_ENTRY entry=DEAL_ENTRY_IN; double volume=1,price=100; int magic=77; string symbol="TEST"; ENUM_DEAL_TYPE type=DEAL_TYPE_BUY; };
std::vector<Order> orders;
std::vector<Position> positions;
std::map<ulong,Order> historyOrders;
std::map<ulong,Deal> historyDeals;
std::vector<MqlTradeRequest> sends;
struct Submission { MqlTradeRequest request; MqlTradeResult result; bool sent; ulong at; };
std::vector<Submission> submissions;
int selectedOrder=-1,selectedPosition=-1;
ulong mock_ms=1000,mock_us=1000000;
uint nextRequest=1;
bool connected=true,tradeAllowed=true,sendOK=true;
long accountMode=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING; bool fifo=false;
ulong GetTickCount64(){return mock_ms;}
ulong GetMicrosecondCount(){return mock_us++;}
struct MqlTick { double bid=100.0,ask=100.1; };
void ResetLastError(){}
int GetLastError(){return sendOK?0:999;}
template<class T> int ArrayResize(std::vector<T>& v,int n,int reserve=0){if(n<0)return -1;if(reserve>0 && (size_t)n>v.capacity())v.reserve(n+reserve);v.resize(n);return n;}
template<class T> int ArraySize(const std::vector<T>& v){return (int)v.size();}
template<class A,class B> auto MathMax(A a,B b){return std::max((double)a,(double)b);}
double MathAbs(double n){return std::abs(n);}
long TerminalInfoInteger(int p){return p==TERMINAL_CONNECTED?connected:tradeAllowed;}
long MQLInfoInteger(int){return tradeAllowed;}
long AccountInfoInteger(int p){return p==ACCOUNT_MARGIN_MODE?accountMode:fifo;}
int PositionsTotal(){return positions.size();} int OrdersTotal(){return orders.size();}
ulong PositionGetTicket(int i){selectedPosition=i;return i>=0&&i<(int)positions.size()?positions[i].ticket:0;}
bool PositionSelectByTicket(ulong t){for(int i=0;i<(int)positions.size();i++)if(positions[i].ticket==t){selectedPosition=i;return true;}selectedPosition=-1;return false;}
string PositionGetString(int){assert(selectedPosition>=0);return positions[selectedPosition].symbol;}
long PositionGetInteger(int p){assert(selectedPosition>=0);auto v=positions[selectedPosition];if(p==POSITION_MAGIC)return v.magic;if(p==POSITION_TYPE)return v.side;if(p==POSITION_IDENTIFIER)return v.identifier;assert(false);return 0;}
double PositionGetDouble(int p){assert(selectedPosition>=0);auto v=positions[selectedPosition];if(p==POSITION_VOLUME)return v.volume;if(p==POSITION_PRICE_OPEN)return v.price;if(p==POSITION_SL)return v.sl;if(p==POSITION_TP)return v.tp;assert(false);return 0;}
ulong OrderGetTicket(int i){selectedOrder=i;return i>=0&&i<(int)orders.size()?orders[i].ticket:0;}
bool OrderSelect(ulong t){for(int i=0;i<(int)orders.size();i++)if(orders[i].ticket==t){selectedOrder=i;return true;}selectedOrder=-1;return false;}
string OrderGetString(int){assert(selectedOrder>=0);return orders[selectedOrder].symbol;}
long OrderGetInteger(int p){assert(selectedOrder>=0);auto v=orders[selectedOrder];if(p==ORDER_MAGIC)return v.magic;if(p==ORDER_TYPE)return v.type;if(p==ORDER_STATE)return v.status;assert(false);return 0;}
double OrderGetDouble(int p){assert(selectedOrder>=0);auto v=orders[selectedOrder];if(p==ORDER_PRICE_OPEN)return v.price;if(p==ORDER_VOLUME_CURRENT)return v.volume;if(p==ORDER_VOLUME_INITIAL)return v.initial;if(p==ORDER_SL)return v.sl;if(p==ORDER_TP)return v.tp;assert(false);return 0;}
bool HistoryOrderSelect(ulong t){return historyOrders.count(t);}
long HistoryOrderGetInteger(ulong t,int p){assert(historyOrders.count(t));auto v=historyOrders.at(t);if(p==ORDER_MAGIC)return v.magic;if(p==ORDER_TYPE)return v.type;if(p==ORDER_STATE)return v.status;if(p==ORDER_POSITION_ID)return v.positionId?v.positionId:(v.status==ORDER_STATE_FILLED?v.ticket:0);assert(false);return 0;}
double HistoryOrderGetDouble(ulong t,int p){assert(historyOrders.count(t));auto v=historyOrders.at(t);if(p==ORDER_PRICE_OPEN)return v.price;if(p==ORDER_VOLUME_INITIAL)return v.initial;if(p==ORDER_VOLUME_CURRENT)return v.volume;assert(false);return 0;}
bool HistoryDealSelect(ulong t){return historyDeals.count(t);}
string HistoryDealGetString(ulong t,int){return historyDeals.at(t).symbol;}
long HistoryDealGetInteger(ulong t,int p){auto v=historyDeals.at(t);if(p==DEAL_MAGIC)return v.magic;if(p==DEAL_ENTRY)return v.entry;if(p==DEAL_POSITION_ID)return v.position;if(p==DEAL_ORDER)return v.order;if(p==DEAL_TYPE)return v.type;assert(false);return 0;}
double HistoryDealGetDouble(ulong t,int p){auto v=historyDeals.at(t);return p==DEAL_PRICE?v.price:v.volume;}
bool SymbolInfoInteger(string,int,long &v){v=SYMBOL_FILLING_IOC;return true;}
long SymbolInfoInteger(string,int){return 0;}
bool SymbolInfoTick(string,MqlTick &tick){tick=MqlTick{};return true;}
double SymbolInfoDouble(string,int p){if(p==SYMBOL_TRADE_TICK_SIZE)return .01;if(p==SYMBOL_BID)return 100;if(p==SYMBOL_ASK)return 100.1;if(p==SYMBOL_VOLUME_MIN)return .01;return 0;}
double MathCeil(double n){return std::ceil(n);}
double MathFloor(double n){return std::floor(n);}
double NormalizeDouble(double n,int){return n;}
bool OrderSendAsync(MqlTradeRequest r,MqlTradeResult &v){sends.push_back(r);v.request_id=nextRequest++;v.retcode=TRADE_RETCODE_PLACED;submissions.push_back({r,v,sendOK,mock_ms});return sendOK;}
bool EventSetMillisecondTimer(int){return true;} void EventKillTimer(){}
void Print(string){} void PrintFormat(const char*,...){}
string StringFormat(const char *fmt,...){return string(fmt);}
void StringToUpper(string &s){for(char &c:s)c=std::toupper(c);}
int StringLen(string s){return s.size();} int StringGetCharacter(string s,int i){return s[i];}
string StringSubstr(string s,int i,int n){return s.substr(i,n);}

std::vector<ulong> selectedHistoryDeals;
bool HistorySelectByPosition(ulong id){selectedHistoryDeals.clear();for(auto &kv:historyDeals)if(kv.second.position==id)selectedHistoryDeals.push_back(kv.first);return true;}
int HistoryDealsTotal(){return selectedHistoryDeals.size();}
ulong HistoryDealGetTicket(int i){return selectedHistoryDeals.at(i);}
