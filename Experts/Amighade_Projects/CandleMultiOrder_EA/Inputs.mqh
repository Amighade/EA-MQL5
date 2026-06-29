//+------------------------------------------------------------------+
//| Inputs.mqh                                                        |
//| All input parameters and enums for CandleMultiOrder EA           |
//| Single source of truth for all configurable values               |
//+------------------------------------------------------------------+
#ifndef CMO_INPUTS_MQH
#define CMO_INPUTS_MQH

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+

enum RiskModeEnum    { RISK_PERCENT, RISK_VALUE };
enum LotSizeModeEnum { LS_INPUT, LS_AUTO };

enum BreakoutModeEnum
{
   MODE_FLOATING_BREAKOUT = 0,
   MODE_RANGE_ANCHOR      = 1,
   MODE_ASYMMETRIC_ANCHOR = 2
};

enum EntryMode
{
   PREV_N_CANDLE_HIGH_LOW_MAX_MIN           = 0,
   PREV_N_CANDLE_BODY_MAX_MIN               = 1,
   PREV_N_CANDLE_HIGH_LOW_AVRG              = 2,
   PREV_N_CANDLE_BODY_AVRG                  = 3,
   PREV_N_CANDLE_HIGH_LOW_BODY_AVRG_MAX_MIN = 4,
   PREV_N_CANDLE_HIGH_LOW_MID_P_RANGE       = 5
};

enum WinnerWallMode
{
   PREV_CANDLE_BODY     = 0,
   PREV_CANDLE_HIGH_LOW = 1,
   PREV_CANDLE_AVRG     = 2
};

enum CandleSourceMode
{
   CANDLE_SOURCE_HA = 0,  // Heiken Ashi
   CANDLE_SOURCE_RC = 1   // Regular candles
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

input string _________Section1        = "--- General Settings ---";
input bool   EnableDebugLogs          = false;

//--- Risk
input RiskModeEnum    RiskMode        = RISK_PERCENT;
input double          RiskValue       = 10.0;
input double          RiskPercent     = 0.5;

//--- Lot sizing
input LotSizeModeEnum LotSizeMode     = LS_INPUT;
input double          LotSizeInput    = 0.01;
input int             Slippage        = 5;

//--- Timeframe
input ENUM_TIMEFRAMES Timeframe       = (ENUM_TIMEFRAMES)0;

//--- Magic number (0 = auto-generate from symbol + timeframe)
input ulong           InMagicNumber   = 555111;

//--- Lot limits (0 = use broker defaults)
input double          LotMin          = 0;
input double          LotMax          = 0;
input int             MaxTradesInCycle= 0;

//--- Time filter
input bool   UseTimeFilter            = false;
input bool   EnableLondon             = true;
input bool   EnableNewYork            = true;
input bool   EnableAsia               = true;
input string ExtraWindow1             = "";   // HH:MM-HH:MM
input string ExtraWindow2             = "";   // HH:MM-HH:MM

//--- ATR buffer
input bool   UseATRinBuffer           = false;
input double ATR_BufferFactor         = 1.0;
input int    ATR_Period               = 14;
input string BaseBufferPrice          = "0";
input double MarginUsedBufferLevel    = 4000;
input double BufferLotDivisor         = 4.0;
input int    BufferLotQty             = 0;

//--- Breakout mode
input BreakoutModeEnum BreakoutMode   = MODE_RANGE_ANCHOR;
input double AsymmetricRangeDistanceInPrice = 1.5;

//--- Budget exhaustion
input bool   UseBudgetExhaustion      = true;
input double MarginReserve            = 0.0;
input double AllowedEquity            = 0.0;
input int    ExhaustMaxOpenDeals      = 18;
input double ExhaustMaxDealSize       = 0;

//--- Compression protection
input bool   UseCompressionProtect    = true;
input int    CompressionStartDeals    = 3;
input int    DealsKeepToward          = 1;
input int    DealsKeepAgainst         = 2;

//--- Resonance window
input int    WindowSize               = 4;
input int    widenMaxSteps            = 10;

//--- Entry mode
input EntryMode InpEntryMode          = PREV_N_CANDLE_HIGH_LOW_MAX_MIN;
input int       InpEntryModeN         = 1;

//--- Entry range filters
input bool   UseEntryRangeFilter_1    = true;
input bool   UseEntryRangeFilter_2    = false;
input double EntryMinRangeFactor      = 0.5;
input double EntryMaxRangeFactor      = 2.0;

//--- Winner wall mode
input WinnerWallMode InpWinnerWallMode = PREV_CANDLE_BODY;

//--- Candle source
input CandleSourceMode InpCandleSourceMode = CANDLE_SOURCE_HA;

#endif
