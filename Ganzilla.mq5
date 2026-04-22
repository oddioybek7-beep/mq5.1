//+------------------------------------------------------------------+
//|                                                     Ganzilla.mq5 |
//|                                   Copyright 2026, GitHub Copilot |
//+------------------------------------------------------------------+
#property copyright "GitHub Copilot"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input parameters
input double InpGannAngle = 90.0;         // Gann burchagi (90, 180, 360)
input double InpRiskPercent = 2.0;        // Risk: Balansdan foizda tavakkal
input double InpRiskReward = 2.0;         // Risk/Reward Ratio (1:2)
input ulong  InpMagicNumber = 777777;     // Magic Number

CTrade trade;
CPositionInfo posInfo;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   Print("Ganzilla (Matematik Gann Square of 9) ishga tushdi.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Grafikdagi barcha panellarni tozalash
   ObjectsDeleteAll(0, "GannGUI_");
   Print("Ganzilla o'chirildi va manitor tozalandi.");
  }

//+------------------------------------------------------------------+
//| Ekrandagi Manitorni Chizish (GUI)                                |
//+------------------------------------------------------------------+
void DrawLabel(string name, string text, int x, int y, color clr, int fontSize, bool isBold = false)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_FONT, isBold ? "Arial Bold" : "Arial");
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

void UpdateDashboard(double dailyOpen, double gannUp, double gannDown, double currentPrice)
  {
   string panelName = "GannGUI_Bg";
   if(ObjectFind(0, panelName) < 0)
     {
      ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 360);
      ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 180);
      ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrBlack); // Qora manitor
      ObjectSetInteger(0, panelName, OBJPROP_BORDER_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, panelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
     }
     
   DrawLabel("GannGUI_Title",  "=== GANZILLA SQUARE OF 9 ===",     20, 30,  clrYellow, 12, true);
   DrawLabel("GannGUI_Open",   "KUNLIK OCHIQ (Open): " + DoubleToString(dailyOpen, _Digits), 20, 60,  clrWhite, 10);
   DrawLabel("GannGUI_Up",     "Yashil (BUY) Zona > " + DoubleToString(gannUp, _Digits),     20, 80,  clrLime,  10);
   DrawLabel("GannGUI_Down",   "Qizil (SELL) Zona < " + DoubleToString(gannDown, _Digits),   20, 100, clrRed,   10);
   DrawLabel("GannGUI_Price",  "HOZIRGI NARX: " + DoubleToString(currentPrice, _Digits),     20, 130, clrWhite, 11, true);
   
   string signalInfo = "KUTILMOQDA...";
   color sigClr = clrGray;
   
   if(PositionsTotal() > 0)
     {
      signalInfo = "SAVDO OCHIQ! (BUY/SELL)";
      sigClr = clrGold;
     }
   else if(currentPrice >= gannUp - 5 * _Point)
     {
      signalInfo = "[!] BUYGA TAYYORLANING (BREAKOUT)";
      sigClr = clrLime;
     }
   else if(currentPrice <= gannDown + 5 * _Point)
     {
      signalInfo = "[!] SELLGA TAYYORLANING (BREAKOUT)";
      sigClr = clrRed;
     }
     
   DrawLabel("GannGUI_Signal", "SIGNAL: " + signalInfo, 20, 160, sigClr, 12, true);
  }

//+------------------------------------------------------------------+
//| Aqlli Lot o'lchamini hisoblash                                   |
//+------------------------------------------------------------------+
double GetSmartLotSize(double stopLossPoints)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
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
//| Gann Square of 9 darajasini hisoblash funksiyasi (Matematik)     |
//+------------------------------------------------------------------+
double CalculateGannLevel(double price, double degrees, int direction)
  {
   // Forex narxlari uchun (masalan 1.0500) butun songa o'tkazish kerak
   double multiplier = MathPow(10, _Digits == 5 || _Digits == 3 ? _Digits - 1 : _Digits);
   double scaledPrice = price * multiplier;
   
   // Formula: Yangi narx = (sqrt(Narx) +/- (Burchak / 180))^2
   double step = degrees / 180.0; 
   double resultPrice = 0;
   
   if (direction > 0) // Yuqoriga o'sish darajasi (Resistance)
      resultPrice = MathPow(MathSqrt(scaledPrice) + step, 2);
   else               // Pastga tushish darajasi (Support)
      resultPrice = MathPow(MathSqrt(scaledPrice) - step, 2);
      
   return NormalizeDouble(resultPrice / multiplier, _Digits);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Kunlik ochiq narxni (Daily Open) asos sifatida olish
   double dailyOpen = iOpen(_Symbol, PERIOD_D1, 0);
   if (dailyOpen == 0) return;

   // Gann darajalarini hisoblash
   double gannUpLevel = CalculateGannLevel(dailyOpen, InpGannAngle, 1);
   double gannDownLevel = CalculateGannLevel(dailyOpen, InpGannAngle, -1);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Har bir tikda Manitorni (GUI) yangilab turish
   UpdateDashboard(dailyOpen, gannUpLevel, gannDownLevel, currentPrice);

   // Faqat yangi shamda (bar) strategiya tekshirish
   static datetime lastTime = 0;
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if (currentTime == lastTime) return;
   
   // Faqat bitta ochiq pozitsiya bo'lishiga ruxsat berish
   if (PositionsTotal() > 0) return;

   lastTime = currentTime;

   double currentClose = iClose(_Symbol, _Period, 1);
   double currentOpen = iOpen(_Symbol, _Period, 1);

   // SOTIB OLISH (BUY): Agar narx matematik Gann Up darajasini yorib o'tsa
   if (currentOpen < gannUpLevel && currentClose > gannUpLevel)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = dailyOpen; // Stop Loss kunlik ochiq narxda qoladi
      double slDistance = ask - sl;
      
      if (slDistance > 0)
        {
         double tp = ask + (slDistance * InpRiskReward);
         double lot = GetSmartLotSize(slDistance);
         trade.Buy(lot, _Symbol, ask, sl, tp, "Gann Math Buy");
         Print("Gann BUY ochildi! Daraja: ", gannUpLevel);
        }
     }
     
   // SOTISH (SELL): Agar narx matematik Gann Down darajasini yorib o'tsa
   if (currentOpen > gannDownLevel && currentClose < gannDownLevel)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = dailyOpen; // Stop Loss kunlik ochiq narxda qoladi
      double slDistance = sl - bid;
      
      if (slDistance > 0)
        {
         double tp = bid - (slDistance * InpRiskReward);
         double lot = GetSmartLotSize(slDistance);
         trade.Sell(lot, _Symbol, bid, sl, tp, "Gann Math Sell");
         Print("Gann SELL ochildi! Daraja: ", gannDownLevel);
        }
     }
  }
//+------------------------------------------------------------------+