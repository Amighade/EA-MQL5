//+------------------------------------------------------------------+
//| TelegramUtils.mqh                                                 |
//| Telegram message routing and sending                              |
//| Adapted from the CandleMultiOrder Telegram utility for HedgeGrid. |
//| Used exclusively by Utils/SafetyNet.mqh to send the broker-fault  |
//| / safety-stop alarm. No engine calls this directly.               |
//+------------------------------------------------------------------+
#ifndef TELEGRAM_UTILS_MQH
#define TELEGRAM_UTILS_MQH

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| Hardcoded credentials (per user decision — not input fields)      |
//| >>> FILL THESE IN BEFORE USE <<<                                  |
//| MT5 also requires https://api.telegram.org to be whitelisted:     |
//| Tools -> Options -> Expert Advisors -> Allow WebRequest for       |
//| listed URL. This is a one-time manual step, the EA cannot do it.  |
//+------------------------------------------------------------------+
string botToken = "PUT_YOUR_BOT_TOKEN_HERE";
string group_id = "PUT_YOUR_GROUP_CHAT_ID_HERE";
string topic_id = "";

//+------------------------------------------------------------------+
//| Symbol -> topic routing table                                    |
//| Extend/edit as needed. Unmatched symbols fall back to demo/live   |
//| default topics below.                                             |
//+------------------------------------------------------------------+
struct SymbolRoute
  {
   string symbolKey;
   string demoTopic;
   string liveTopic;
  };

SymbolRoute g_telegramRoutes[] =
  {
   {"XAUUSD", "2",   "14"},
   {"UKOUSD", "459", "460"},
   {"DJ30",   "476", "477"},
   {"AUDUSD", "478", "479"},
   {"AUDNZD", "478", "479"},
   {"BTCUSD", "483", "485"}
  };

//+------------------------------------------------------------------+
//| Detect correct topic from symbol and account type                 |
//| Call once from OnInit                                             |
//+------------------------------------------------------------------+
void SetTelegramRoute()
  {
   bool   isDemo = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO);
   string s      = _Symbol;
   topic_id      = "";

   for(int i = 0; i < ArraySize(g_telegramRoutes); i++)
     {
      if(StringFind(s, g_telegramRoutes[i].symbolKey) >= 0)
        {
         topic_id = isDemo ? g_telegramRoutes[i].demoTopic : g_telegramRoutes[i].liveTopic;
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
//| Send a message to the configured Telegram group/topic             |
//+------------------------------------------------------------------+
void SendTelegramMessage(string text)
  {
   if(!InpEnableTelegramAlerts) return;

   if(topic_id == "")
      SetTelegramRoute();

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
      PrintFormat("[Telegram] WebRequest failed. Error: %d (check WebRequest URL whitelist)", GetLastError());
  }

#endif
