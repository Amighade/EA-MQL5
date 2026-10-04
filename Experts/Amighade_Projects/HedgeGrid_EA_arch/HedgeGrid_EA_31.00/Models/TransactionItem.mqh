#ifndef TRANSACTION_ITEM_MQH
#define TRANSACTION_ITEM_MQH

// One incoming broker fact. Outgoing commands belong only to TradeItem.
struct TransactionItem
  {
   ENUM_TRADE_TRANSACTION_TYPE type;
   string                     symbol;
   ulong                      orderTicket;
   ulong                      positionTicket;
   ulong                      dealTicket;
   ENUM_DEAL_TYPE             dealType;
   double                     price;
   double                     volume;
   uint                       requestId;
   int                        retcode;
   ulong                      resultOrder;
   long                       requestMagic;
   int                        handlerRetries;
  };

void ResetTransactionItem(TransactionItem &item)
  {
   item.type = TRADE_TRANSACTION_REQUEST;
   item.symbol = "";
   item.orderTicket = 0;
   item.positionTicket = 0;
   item.dealTicket = 0;
   item.dealType = (ENUM_DEAL_TYPE)WRONG_VALUE;
   item.price = 0.0;
   item.volume = 0.0;
   item.requestId = 0;
   item.retcode = 0;
   item.resultOrder = 0;
   item.requestMagic = 0;
   item.handlerRetries = 0;
  }

#endif
