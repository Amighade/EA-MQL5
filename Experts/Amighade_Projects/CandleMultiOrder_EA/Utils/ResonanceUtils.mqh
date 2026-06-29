//+------------------------------------------------------------------+
//| ResonanceUtils.mqh                                               |
//| Market resonance detection from tick price window               |
//| Classifies market as TRENDING, RANGING, or REVERSED             |
//+------------------------------------------------------------------+
#ifndef CMO_RESONANCE_UTILS_MQH
#define CMO_RESONANCE_UTILS_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"

//+------------------------------------------------------------------+
//| Calculate resonance from a sliding price window                  |
//| Updates: resonanceScore, resonanceRange, resonanceDirection,     |
//|          resonanceType                                           |
//+------------------------------------------------------------------+
void CalculateResonance(double &prices[], int size)
{
   if(size < 3)
     {
      resonanceScore     = 0;
      resonanceRange     = 0;
      resonanceDirection = "NONE";
      resonanceType      = "";
      return;
     }

   double P1 = prices[0];
   double PN = prices[size - 1];

   double maxPrice = prices[0], minPrice = prices[0];
   for(int i = 1; i < size; i++)
     {
      if(prices[i] > maxPrice) maxPrice = prices[i];
      if(prices[i] < minPrice) minPrice = prices[i];
     }
   resonanceRange = maxPrice - minPrice;

   if(resonanceRange == 0)
     {
      resonanceScore     = 0;
      resonanceDirection = "FLAT";
      resonanceType      = "FLAT";
      return;
     }

   // Find extreme point
   double maxDistance = 0;
   int    extremeIdx  = 0;
   for(int i = 0; i < size; i++)
     {
      double distance = MathAbs(prices[i] - P1);
      if(distance > maxDistance) { maxDistance = distance; extremeIdx = i; }
     }

   double P_extreme      = prices[extremeIdx];
   double extremePosition= (double)extremeIdx / (double)size;

   double penetration    = MathAbs(P_extreme - P1);
   double recovery       = MathAbs(PN - P_extreme);
   double totalMovement  = penetration + recovery;
   double netMovement    = MathAbs(PN - P1);

   if(totalMovement == 0) { resonanceScore = 0; resonanceDirection = "FLAT"; resonanceType = "FLAT"; return; }

   double returnRatio = 1.0 - (netMovement / totalMovement);
   resonanceScore     = returnRatio * 100.0;

   // Direction from first/last 30% of window
   int sectionSize = MathMax(1, MathMin(size, size * 3 / 10));
   double firstSection = 0, lastSection = 0;
   for(int i = 0; i < sectionSize; i++)             firstSection += prices[i];
   for(int i = size - sectionSize; i < size; i++)   lastSection  += prices[i];
   firstSection /= sectionSize;
   lastSection  /= sectionSize;

   if(resonanceScore < 30)
     {
      resonanceType = "TRENDING";
      resonanceDirection = (lastSection > firstSection) ? "TREND UP" :
                           (lastSection < firstSection) ? "TREND DOWN" : "FLAT";
     }
   else
     {
      double rangePercent = (resonanceRange / PN) * 100.0;
      bool   smallRange   = (rangePercent < 0.5);
      bool   extremeEarly = (extremePosition < 0.6);

      if(smallRange || !extremeEarly)
        {
         resonanceType      = "RANGING";
         resonanceDirection = "RANGING";
        }
      else
        {
         resonanceType      = "REVERSED";
         resonanceDirection = (lastSection > firstSection) ? "UP" : "DOWN";
        }
     }
}

#endif
