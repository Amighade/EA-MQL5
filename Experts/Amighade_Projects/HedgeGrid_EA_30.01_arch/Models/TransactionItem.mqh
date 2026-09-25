#ifndef TRANSACTION_ITEM_MQH
#define TRANSACTION_ITEM_MQH

//+------------------------------------------------------------------+
//| REV 30.01                                                        |
//| One element = one fact delivered by OnTradeTransaction().        |
//| No strategy state lives here. After HandleTransaction() consumes |
//| the fact, the durable result belongs in GridState / TradeItem[].  |
//+------------------------------------------------------------------+
struct TransactionItem
  {
   ENUM_TRADE_TRANSACTION_TYPE type;

   string                      symbol;
   ulong                       orderTicket;
   ulong                       positionTicket;
   ulong                       dealTicket;

   ENUM_ORDER_TYPE             orderType;
   ENUM_DEAL_TYPE              dealType;
   double                      price;
   double                      volume;

   // Request/result correlation for OrderSendAsync().
   uint                        requestId;
   int                         retcode;
   ulong                       resultOrder;
   ulong                       resultDeal;

   // Request fields are copied because TRADE_TRANSACTION_REQUEST may not
   // carry enough useful information in MqlTradeTransaction itself.
   ENUM_TRADE_REQUEST_ACTIONS  requestAction;
   long                        requestMagic;
   ulong                       requestOrder;
   ulong                       requestPosition;
   ENUM_ORDER_TYPE             requestType;
   double                      requestPrice;
   double                      requestVolume;
   double                      requestSL;
   double                      requestTP;

   // History-dependent classification may be retried later by the handler.
   int                         historyRetries;
  };

void ResetTransactionItem(TransactionItem &item)
  {
   item.type            = TRADE_TRANSACTION_REQUEST;
   item.symbol          = "";
   item.orderTicket     = 0;
   item.positionTicket  = 0;
   item.dealTicket      = 0;
   item.orderType       = (ENUM_ORDER_TYPE)WRONG_VALUE;
   item.dealType        = (ENUM_DEAL_TYPE)WRONG_VALUE;
   item.price           = 0.0;
   item.volume          = 0.0;
   item.requestId       = 0;
   item.retcode         = 0;
   item.resultOrder     = 0;
   item.resultDeal      = 0;
   item.requestAction   = TRADE_ACTION_DEAL;
   item.requestMagic    = 0;
   item.requestOrder    = 0;
   item.requestPosition = 0;
   item.requestType     = (ENUM_ORDER_TYPE)WRONG_VALUE;
   item.requestPrice    = 0.0;
   item.requestVolume   = 0.0;
   item.requestSL       = 0.0;
   item.requestTP       = 0.0;
   item.historyRetries  = 0;
  }

#endif
