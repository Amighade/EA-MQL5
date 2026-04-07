/*

   Triple Channel
   Copyright 2014-2025, Orchard Forex
   https://orchardforex.com

   Version 2
   Enter when crossing past the outer boundary, trade reversion
   Multiple take profit levels, l1, l2, l3

*/

#property copyright "Copyright 2014-2025, Orchard Forex"
#property link "https://orchardforex.com"
#property version "2.00"

enum ENUM_TP_LEVEL {
   TP_LEVEL_1, // Level 1
   TP_LEVEL_2, // Level 2
   TP_LEVEL_3, // Level 3
};

#include <Trade/Trade.mqh>
CTrade              Trade;
CPositionInfo       PositionInfo;

input               group "Indicator settings";
input string        InpIndicatorPath = "/Indicators/Orchard/Triple Channel D/Triple Channel D.ex5"; // indicator path

input int           InpPeriod        = 48; // Period
input double        InpUpperPercent  = 30; // Upper band percent
input double        InpLowerPercent  = 30; // Lower band percent

input               group "Expert settings";
input ENUM_TP_LEVEL InpTPLevel         = TP_LEVEL_2;         // Take profit level
input bool          InpSingleTrade     = false;              // Only one trade at a time per direction
input bool          InpUseStopLoss     = false;              // Use stop loss
input double        InpTakeProfitRatio = 1.0;                // TP:SL ratio if using stop loss
input bool          InpTrailTakeProfit = true;               // Trail take profit price
input double        InpVolume          = 0.10;               // Volume
input long          InpMagic           = 250700;             // Magic
const string        InpComment         = "Triple Channel 2"; // Trade comment

int                 Handle;
const int           UpperBuffer  = 0;
const int           HighBuffer   = 1;
const int           LowBuffer    = 2;
const int           LowerBuffer  = 3;

const int           SignalOffset = 2;
int                 BuyCount;
int                 SellCount;

;
int OnInit() {

   Trade.SetExpertMagicNumber( InpMagic );

   Handle = iCustom( Symbol(), Period(), InpIndicatorPath, InpPeriod, InpUpperPercent, InpLowerPercent );

   IsNewBar();

   return ( INIT_SUCCEEDED );
}

void OnDeinit( const int reason ) { IndicatorRelease( Handle ); }

void OnTick() {

   if ( !IsNewBar() ) return;

   double   upperValue = GetBufferValue( UpperBuffer );
   double   highValue  = GetBufferValue( HighBuffer );
   double   lowValue   = GetBufferValue( LowBuffer );
   double   lowerValue = GetBufferValue( LowerBuffer );

   MqlRates ratesArr[];
   CopyRates( _Symbol, _Period, 1, 1, ratesArr );
   MqlRates rates = ratesArr[0];

   UpdateTrades( upperValue, highValue, lowValue, lowerValue );

   if ( SellCount == 0 || !InpSingleTrade ) {

      if ( rates.close > upperValue ) {
         OpenPosition( ORDER_TYPE_SELL, upperValue, highValue, lowValue, lowerValue );
      }
   }

   if ( BuyCount == 0 || !InpSingleTrade ) {

      if ( rates.close < lowerValue ) {
         OpenPosition( ORDER_TYPE_BUY, upperValue, highValue, lowValue, lowerValue );
      }
   }
}

void UpdateTrades( double upperValue, double highValue, double lowValue, double lowerValue ) {

   BuyCount  = 0;
   SellCount = 0;

   for ( int i = PositionsTotal() - 1; i >= 0; i-- ) {

      if ( !PositionInfo.SelectByIndex( i ) ) continue;
      if ( PositionInfo.Symbol() != Symbol() ) continue;
      if ( PositionInfo.Magic() != InpMagic ) continue;

      if ( PositionInfo.PositionType() == POSITION_TYPE_BUY ) BuyCount++;
      if ( PositionInfo.PositionType() == POSITION_TYPE_SELL ) SellCount++;

      if ( InpTrailTakeProfit ) UpdateTPSL( upperValue, highValue, lowValue, lowerValue );
   }
}

void UpdateTPSL( double upperValue, double highValue, double lowValue, double lowerValue ) {

   double openPrice       = PositionInfo.PriceOpen();
   double takeProfitPrice = GetTakeProfitPrice( PositionInfo.PositionType(), upperValue, highValue, lowValue, lowerValue );
   double stopLossPrice   = GetStopLossPrice( openPrice, takeProfitPrice );

   if ( takeProfitPrice != PositionInfo.TakeProfit() || stopLossPrice != PositionInfo.StopLoss() ) {
      Trade.PositionModify( PositionInfo.Ticket(), stopLossPrice, takeProfitPrice );
   }
}

void OpenPosition( ENUM_ORDER_TYPE type, double upperValue, double highValue, double lowValue, double lowerValue ) {

   MqlTick tick;
   SymbolInfoTick( Symbol(), tick );

   double openPrice       = ( type == ORDER_TYPE_BUY ) ? tick.ask : tick.bid;
   double takeProfitPrice = GetTakeProfitPrice( type, upperValue, highValue, lowValue, lowerValue );
   double stopLossPrice   = GetStopLossPrice( openPrice, takeProfitPrice );

   openPrice              = NormalizeDouble( openPrice, Digits() );

   Trade.PositionOpen( Symbol(), type, InpVolume, openPrice, stopLossPrice, takeProfitPrice, InpComment );
}

double GetTakeProfitPrice( int type, double upperValue, double highValue, double lowValue, double lowerValue ) {

   double takeProfitPrice = 0;
   switch ( InpTPLevel ) {
      case TP_LEVEL_1:
         takeProfitPrice = ( type == ORDER_TYPE_BUY ) ? lowValue : highValue;
         break;
      case TP_LEVEL_2:
         takeProfitPrice = ( type == ORDER_TYPE_BUY ) ? highValue : lowValue;
         break;
      case TP_LEVEL_3:
         takeProfitPrice = ( type == ORDER_TYPE_BUY ) ? upperValue : lowerValue;
         break;
   }

   takeProfitPrice = NormalizeDouble( takeProfitPrice, Digits() );

   return takeProfitPrice;
}

double GetStopLossPrice( double openPrice, double takeProfitPrice ) {

   if ( !InpUseStopLoss ) return 0.0;

   double stopLossPrice = openPrice - ( ( takeProfitPrice - openPrice ) / InpTakeProfitRatio );
   stopLossPrice        = NormalizeDouble( stopLossPrice, Digits() );

   return stopLossPrice;
}

double GetBufferValue( int bufferNumber ) {

   double buffer[];
   CopyBuffer( Handle, bufferNumber, SignalOffset, 1, buffer );
   return buffer[0];
}

bool IsNewBar() {

   static datetime prevTime    = 0;
   datetime        currentTime = iTime( Symbol(), Period(), 0 );
   if ( prevTime == currentTime ) return false;
   prevTime = currentTime;
   return true;
}
