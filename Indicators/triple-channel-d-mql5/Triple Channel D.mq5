/*
   Triple Channel D
   Copyright 2019-2025, Orchard Forex
   https://www.orchardforex.com

*/

#property copyright "Copyright (c) 2013-2025 Orchard Forex"
#property link "orchardforex.com"
#property version "1.00"
#property description "Triple Channel D"

// Indicator properties
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots 4

// Upper line properties
#property indicator_label1 "Upper"
#property indicator_color1 clrYellow
#property indicator_style1 STYLE_SOLID
#property indicator_type1  DRAW_LINE
#property indicator_width1 1

#property indicator_label2 "High"
#property indicator_color2 clrGreen
#property indicator_style2 STYLE_DOT
#property indicator_type2  DRAW_LINE
#property indicator_width2 1

#property indicator_label3 "Low"
#property indicator_color3 clrOrange
#property indicator_style3 STYLE_DOT
#property indicator_type3  DRAW_LINE
#property indicator_width3 1

// Lower line properties
#property indicator_label4 "Lower"
#property indicator_color4 clrRed
#property indicator_style4 STYLE_SOLID
#property indicator_type4  DRAW_LINE
#property indicator_width4 1

input int    InpPeriod       = 10; // Period
input double InpUpperPercent = 30; // Upper band percent
input double InpLowerPercent = 30; // Lower band percent

// Buffers
double       BufferUpper[];
double       BufferHigh[];
double       BufferLow[];
double       BufferLower[];

int          OnInit() {

   SetIndexBuffer( 0, BufferUpper, INDICATOR_DATA );
   ArraySetAsSeries( BufferUpper, true );

   SetIndexBuffer( 1, BufferHigh, INDICATOR_DATA );
   ArraySetAsSeries( BufferHigh, true );

   SetIndexBuffer( 2, BufferLow, INDICATOR_DATA );
   ArraySetAsSeries( BufferLow, true );

   SetIndexBuffer( 3, BufferLower, INDICATOR_DATA );
   ArraySetAsSeries( BufferLower, true );

   return ( INIT_SUCCEEDED );
}

int OnCalculate( const int32_t rates_total, const int32_t prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[],
                 const double &close[], const long &tick_volume[], const long &volume[], const int &spread[] ) {

   if ( IsStopped() ) return ( 0 );

   if ( rates_total < InpPeriod ) return ( 0 );

   int count;
   if ( prev_calculated > rates_total || prev_calculated < 0 ) {
      count = rates_total;
   }
   else {
      count = rates_total - prev_calculated;
      if ( prev_calculated > 0 ) count++;
   }

   for ( int i = count - 1; i >= 0 && !IsStopped(); i-- ) {

      BufferUpper[i] = iHigh( Symbol(), Period(), iHighest( Symbol(), Period(), MODE_HIGH, InpPeriod, i ) );
      BufferLower[i] = iLow( Symbol(), Period(), iLowest( Symbol(), Period(), MODE_LOW, InpPeriod, i ) );

      double delta   = BufferUpper[i] - BufferLower[i];

      BufferLow[i]   = BufferLower[i] + ( delta * InpLowerPercent / 100 );
      BufferHigh[i]  = BufferUpper[i] - ( delta * InpUpperPercent / 100 );
   }

   return ( rates_total );
}
