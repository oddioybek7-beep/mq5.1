//+------------------------------------------------------------------+
//|                                              OrderBlockRobot.mq5 |
//|                                      Copyright 2026, GitHub Copilot |
//+------------------------------------------------------------------+
#property copyright "GitHub Copilot"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

input int InpBarsToScan = 300; // Qancha shamni (bar) tekshirish kerak
input double InpMinMomentum = 50.0; // OBni tasdiqlash uchun impuls kuchi (Pointlarda)
input double InpRiskPercent = 2.0; // Risk: Balansdan foizda tavakkaljami
input int InpStopLossPips = 10; // Qat'iy Stop Loss (Pips)

CTrade trade;
CPositionInfo posInfo;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(123456);
   Print("Order Block R/R Robot ishga tushdi.");
   return(INIT_SUCCEEDED);
  }
      
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "OB_");
   Print("Order Block Robot o'chirildi.");
  }

// Lot o'lchamini hisoblash (Balans va Stop Loss masofasiga qarab)
double GetSmartLotSize(double stopLossPoints)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if (stopLossPoints <= 0 || tickValue <= 0) return 0.01;
   
   double points = stopLossPoints / _Point;
   double lot = riskAmount / (points * tickValue);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathRound(lot / stepLot) * stepLot;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   return lot;
  }
      
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Faqat yangi sham (bar) ochilganda ishlaydigan mantiq
   static datetime lastTime = 0;
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if (currentTime == lastTime) return;
   lastTime = currentTime;

   // Order Block(OB)larni qidirish
   for (int i = 2; i <= InpBarsToScan; i++)
     {
      string obName = "OB_" + TimeToString(iTime(_Symbol, _Period, i));
      if(ObjectFind(0, obName) >= 0) continue; // Agar topilgan bo'lsa o'tkazish

      double open1 = iOpen(_Symbol, _Period, i);
      double close1 = iClose(_Symbol, _Period, i);
      double high1 = iHigh(_Symbol, _Period, i);
      double low1 = iLow(_Symbol, _Period, i);

      double open2 = iOpen(_Symbol, _Period, i-1);
      double close2 = iClose(_Symbol, _Period, i-1);
      
      bool isBearish1 = (close1 < open1);
      bool isBullish1 = (close1 > open1);
      
      bool isBullish2 = (close2 > open2);
      bool isBearish2 = (close2 < open2);
      
      double body2 = MathAbs(close2 - open2) / _Point;

      // Bullish Order Block (Yashil): Yaratilganda BUY ochamiz
      if (isBearish1 && isBullish2 && body2 >= InpMinMomentum && close2 > high1)
        {
         DrawRectangle(obName, iTime(_Symbol, _Period, i), high1, iTime(_Symbol, _Period, 0) + PeriodSeconds(_Period)*10, low1, clrGreen);
         
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double pipsToPoints = (_Digits == 5 || _Digits == 3) ? 10.0 : 1.0;
         double slDistance = InpStopLossPips * pipsToPoints * _Point; // 10 pips masofa
         double sl = ask - slDistance;
         
         // 3 xil Take Profit (1:2, 1:3, 1:4)
         double tp1 = ask + (slDistance * 2.0); // 1:2
         double tp2 = ask + (slDistance * 3.0); // 1:3
         double tp3 = ask + (slDistance * 4.0); // 1:4
         
         // Lotni 3 bo'lakka bo'lamiz (total risk o'zgarmasligi uchun)
         double totalLot = GetSmartLotSize(slDistance);
         double lot1 = NormalizeDouble(totalLot / 3.0, 2);
         if(lot1 < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) lot1 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         
         trade.Buy(lot1, _Symbol, ask, sl, tp1, "Buy OB 1:2");
         trade.Buy(lot1, _Symbol, ask, sl, tp2, "Buy OB 1:3");
         trade.Buy(lot1, _Symbol, ask, sl, tp3, "Buy OB 1:4");
         break; // Bitta signaldan keyin to'xtatish
        }
      // Bearish Order Block (Qizil): Yaratilganda SELL ochamiz
      else if (isBullish1 && isBearish2 && body2 >= InpMinMomentum && close2 < low1)
        {
         DrawRectangle(obName, iTime(_Symbol, _Period, i), high1, iTime(_Symbol, _Period, 0) + PeriodSeconds(_Period)*10, low1, clrRed);
         
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double pipsToPoints = (_Digits == 5 || _Digits == 3) ? 10.0 : 1.0;
         double slDistance = InpStopLossPips * pipsToPoints * _Point; // 10 pips masofa
         double sl = bid + slDistance;
         
         // 3 xil Take Profit (1:2, 1:3, 1:4)
         double tp1 = bid - (slDistance * 2.0); // 1:2
         double tp2 = bid - (slDistance * 3.0); // 1:3
         double tp3 = bid - (slDistance * 4.0); // 1:4
         
         // Lotni 3 bo'lakka bo'lamiz
         double totalLot = GetSmartLotSize(slDistance);
         double lot1 = NormalizeDouble(totalLot / 3.0, 2);
         if(lot1 < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) lot1 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         
         trade.Sell(lot1, _Symbol, bid, sl, tp1, "Sell OB 1:2");
         trade.Sell(lot1, _Symbol, bid, sl, tp2, "Sell OB 1:3");
         trade.Sell(lot1, _Symbol, bid, sl, tp3, "Sell OB 1:4");
         break; // Bitta signaldan keyin to'xtatish
        }
     }
  }

//+------------------------------------------------------------------+
//| Grafikda to'rtburchak (Order Block) chizish funksiyasi          |
//+------------------------------------------------------------------+
void DrawRectangle(string name, datetime time1, double price1, datetime time2, double price2, color clr)
  {
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
  }
