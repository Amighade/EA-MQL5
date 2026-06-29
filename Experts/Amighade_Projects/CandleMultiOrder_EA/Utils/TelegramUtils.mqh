//+------------------------------------------------------------------+
//| TelegramUtils.mqh                                                 |
//| Telegram message routing and sending                             |
//| To be added to HedgeGrid EA as well                             |
//+------------------------------------------------------------------+
#ifndef CMO_TELEGRAM_UTILS_MQH
#define CMO_TELEGRAM_UTILS_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"

//+------------------------------------------------------------------+
//| Symbol → topic routing table                                     |
//+------------------------------------------------------------------+
struct SymbolRoute
{
   string symbolKey;
   string demoTopic;
   string liveTopic;
};

SymbolRoute routes[] =
{
   {"XAUUSD", "2",   "14"},
   {"UKOUSD", "459", "460"},
   {"DJ30",   "476", "477"},
   {"AUDUSD", "478", "479"},
   {"AUDNZD", "478", "479"},
   {"BTCUSD", "483", "485"}
};

//+------------------------------------------------------------------+
//| Detect correct topic from symbol and account type                |
//+------------------------------------------------------------------+
void SetTelegramRoute()
{
   bool   isDemo = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO);
   string s      = _Symbol;
   topic_id      = "";

   for(int i = 0; i < ArraySize(routes); i++)
     {
      if(StringFind(s, routes[i].symbolKey) >= 0)
        {
         topic_id = isDemo ? routes[i].demoTopic : routes[i].liveTopic;
         break;
        }
     }

   // Fallback if symbol not in routing table
   if(topic_id == "")
      topic_id = isDemo ? "99" : "199";
}

//+------------------------------------------------------------------+
//| URL-encode a string for HTTP transmission                        |
//+------------------------------------------------------------------+
string UrlEncode(string str)
{
   string encoded = "";
   for(int i = 0; i < StringLen(str); i++)
     {
      uchar c = (uchar)StringGetCharacter(str, i);
      if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
         (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
         encoded += CharToString(c);
      else
         encoded += "%" + StringFormat("%02X", c);
     }
   return encoded;
}

//+------------------------------------------------------------------+
//| Send a message to the configured Telegram group/topic            |
//+------------------------------------------------------------------+
void SendTelegramMessage(string text)
{
   if(topic_id == "")
     {
      Print("[Telegram] ERROR: topic_id not set");
      return;
     }

   string safeText = UrlEncode(text);
   string url      = "https://api.telegram.org/bot" + botToken + "/sendMessage";
   string data     = "chat_id=" + group_id +
                     "&message_thread_id=" + topic_id +
                     "&text=" + safeText;

   char   post[];
   char   result[];
   string headers;
   StringToCharArray(data, post);

   int res = WebRequest("POST", url, "", "", 5000, post, ArraySize(post), result, headers);
   if(res == -1)
      PrintFormat("[Telegram] WebRequest failed. Error: %d", GetLastError());
}

#endif
