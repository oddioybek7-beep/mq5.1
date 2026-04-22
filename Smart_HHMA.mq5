//+------------------------------------------------------------------+
//|                                                   Smart_HHMA.mq5 |
//|                                   Copyright 2026, GitHub Copilot |
//|        Converted from PineScript: Hyperbolic Hull Moving Average |
//+------------------------------------------------------------------+
#property copyright "GitHub Copilot"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1

//--- plot HHMA
#property indicator_label1  "Smart HHMA"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLimeGreen,clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- input parameters
input int    InpLength  = 24;       // Length (Period)
input double InpTension = 2.0;      // Tension
// InpAppliedPrice ni MQL5 o'zi standart tarzda berishi uchun olib tashlandi

//--- Colors
input color InpBullishColor = clrLimeGreen; // Bullish Color
input color InpBearishColor = clrRed;       // Bearish Color

//--- indicator buffers
double         HHMABuffer[];
double         HHMAColorBuffer[];
double         TempFastBuffer[];
double         TempSlowBuffer[];
double         TempRawHullBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- indicator buffers mapping
   SetIndexBuffer(0, HHMABuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HHMAColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, TempFastBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, TempSlowBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, TempRawHullBuffer, INDICATOR_CALCULATIONS);

   //--- Set drawing parameters
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpLength);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpBullishColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpBearishColor);
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Hyperbolic Sine (sinh) Weighting function                        |
//+------------------------------------------------------------------+
double GetSinhWeight(int index, int len, double tension, const double &price[])
  {
   if(index < len - 1) return 0.0;
   
   double weightSum = 0.0;
   double weightedVal = 0.0;
   
   for(int i = 0; i < len; i++)
     {
      double x = (double)(len - i) / (double)len * tension;
      // sinh(x) = (exp(x) - exp(-x)) / 2
      double w = (MathExp(x) - MathExp(-x)) / 2.0;
      
      weightedVal += price[index - i] * w;
      weightSum += w;
     }
     
   if(weightSum == 0.0) return 0.0;
   return weightedVal / weightSum;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function (Standart 1-Massivli)        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   //--- check for minimum bars
   if(rates_total < InpLength) return(0);
   
   //--- Define the lengths for HHMA calculations
   int halfLen = (int)MathMax(1, MathFloor(InpLength / 2.0));
   int sqrtLen = (int)MathMax(1, MathFloor(MathSqrt(InpLength)));

   //--- main calculation loop
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   if(start < InpLength) start = InpLength; // Safety boundary

   for(int i = start; i < rates_total; i++)
     {
      // 1. Calculate fastSinh and slowSinh
      TempFastBuffer[i] = GetSinhWeight(i, halfLen, InpTension, price);
      TempSlowBuffer[i] = GetSinhWeight(i, InpLength, InpTension, price);
      
      // 2. Calculate Raw Hull
      TempRawHullBuffer[i] = 2.0 * TempFastBuffer[i] - TempSlowBuffer[i];
      
      // 3. To calculate the final HHMA, we need rawHull array up to 'i'.
      HHMABuffer[i] = GetSinhWeight(i, sqrtLen, InpTension, TempRawHullBuffer);
      
      // 4. Color logic based on slope (Trendni aniqlash)
      if(i > 0)
        {
         if(HHMABuffer[i] > HHMABuffer[i-1]) 
            HHMAColorBuffer[i] = 0; // Bullish Color (0-indeks)
         else if(HHMABuffer[i] < HHMABuffer[i-1])
            HHMAColorBuffer[i] = 1; // Bearish Color (1-indeks)
         else
            HHMAColorBuffer[i] = HHMAColorBuffer[i-1];
        }
      else
        {
         HHMAColorBuffer[i] = 0;
        }
     }

   //--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+