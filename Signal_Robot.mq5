//+------------------------------------------------------------------+
//|                                                 Signal_Robot.mq5 |
//|                                   Copyright 2026, GitHub Copilot |
//|       Trading Robot based on signal.mq5 (T2 Trend Signal)        |
//+------------------------------------------------------------------+
#property copyright "GitHub Copilot"
#property link      "https://github.com/oddioybek7-beep"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input parameters
input double InpRiskPercent = 1.0;       // Balansga nisbatan Risk (%)
input ulong  InpMagicNumber = 777777;    // Magic Number

CTrade trade;
CPositionInfo posInfo;
int signalHandle = INVALID_HANDLE;

// Ekran uchun ma'lumotlar
string currentSignalStr = "KUTILMOQDA";
color currentSignalColor = clrGray;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // signal.mq5 indikatorini ulash
   signalHandle = iCustom(_Symbol, _Period, "signal");
   
   if(signalHandle == INVALID_HANDLE)
     {
      Print("XATOLIK: 'signal.ex5' indikatori topilmadi! Iltimos indikatorni kompilyatsiya qiling.");
      return(INIT_FAILED);
     }
     
   ChartIndicatorAdd(0, 0, signalHandle);
   
   Print("Signal Robot ishga tushdi! (Asoschi: oddioybek7)");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(signalHandle != INVALID_HANDLE) IndicatorRelease(signalHandle);
   ObjectsDeleteAll(0, "SIG_GUI_");
   Print("Signal Robot o'chirildi va manitor tozalandi.");
  }

//+------------------------------------------------------------------+
//| Balansga qarab "Avto Lot" hisoblash (Risk menejment)             |
//+------------------------------------------------------------------+
double GetAutoLotSize()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Har $1000 balans uchun 0.01 lot
   double calculatedLot = (balance / 1000.0) * 0.01 * InpRiskPercent;
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLot = MathRound(calculatedLot / stepLot) * stepLot;
   if(calculatedLot < minLot) calculatedLot = minLot;
   if(calculatedLot > maxLot) calculatedLot = maxLot;
   
   return calculatedLot;
  }

//+------------------------------------------------------------------+
//| Dashboard / Manitor UI funksiyalari                              |
//+------------------------------------------------------------------+
void DrawLabel(string name, string text, int x, int y, color clr, int fontSize, bool isBold = false)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, isBold ? "Trebuchet MS Bold" : "Trebuchet MS");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

void UpdateDashboard()
  {
   // Orqa fonni chizish
   string panelName = "SIG_GUI_Bg";
   if(ObjectFind(0, panelName) < 0)
     {
      ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 320);
      ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 190);
      ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrWhiteSmoke); // Ochroq kulrang (yumshoq) fon
      ObjectSetInteger(0, panelName, OBJPROP_BORDER_COLOR, clrDarkGray); // To'q kulrang ramka
      ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, panelName, OBJPROP_BACK, true);
      ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
     }
     
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Ochiq bitimlarni hisoblash
   double totalLot = 0.0;
   double totalFloatingProfit = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(posInfo.SelectByIndex(i))
        {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
           {
            totalLot += posInfo.Volume();
            totalFloatingProfit += posInfo.Profit();
           }
        }
     }
     
   color pnlColor = (totalFloatingProfit > 0) ? clrGreen : ((totalFloatingProfit < 0) ? clrRed : clrBlack);
     
   DrawLabel("SIG_GUI_Title", "=== SIGNAL ROBOT ==",  30, 30,  clrBlack, 12, true);
   DrawLabel("SIG_GUI_Bal",   "Balans: $" + DoubleToString(balance, 2), 30, 60, clrBlack, 11);
   DrawLabel("SIG_GUI_PnL",   "Robot Foydasi: $" + DoubleToString(totalFloatingProfit, 2),  30, 85, pnlColor, 12, true);
   DrawLabel("SIG_GUI_Sig",   "Joriy Signal: " + currentSignalStr,     30, 110, currentSignalColor, 11, true);
   DrawLabel("SIG_GUI_Lot",   "Ochiq Lot hajmi: " + DoubleToString(totalLot, 2), 30, 135, clrBlack, 10);
   DrawLabel("SIG_GUI_Line",  "--------------------------------------------------", 30, 150, clrGray, 10);
   DrawLabel("SIG_GUI_Dev",   "Asoschi: oddioybek7", 30, 170, clrBlue, 11, true);
  }

//+------------------------------------------------------------------+
//| Pozitsiyalarni nazorat qilish va ochish/yopish                   |
//+------------------------------------------------------------------+
void ManageTrades(int signalType)
  {
   if (signalType == 0) return; // Signal yo'q bo'lsa hech qanday harakat qilinmaydi

   int total = PositionsTotal();
   bool hasBuy = false;
   bool hasSell = false;
   
   // 1 a reverse mantig'i:
   // - Agar Qizil (Sell, signalType == -1) berilsa: bor Buy bitimlarni yopamiz
   // - Agar Ko'k (Buy, signalType == 1) berilsa: bor Sell bitimlarni yopamiz
   for(int i = total - 1; i >= 0; i--)
     {
      if(posInfo.SelectByIndex(i))
        {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
           {
            if(posInfo.PositionType() == POSITION_TYPE_BUY)
              {
               if(signalType == -1) // Qizil signal - Selga aylantiramiz
                 { trade.PositionClose(posInfo.Ticket()); } 
               else if(signalType == 1) 
                 { hasBuy = true; } // Kutamiz, allaqachon Buy mavjud
              }
            else if(posInfo.PositionType() == POSITION_TYPE_SELL)
              {
               if(signalType == 1)  // Ko'k signal - Buyga aylantiramiz
                 { trade.PositionClose(posInfo.Ticket()); } 
               else if(signalType == -1) 
                 { hasSell = true; } // Kutamiz, allaqachon Sell mavjud
              }
           }
        }
     }
     
   // Yangi pozitsiya ochish (agar yo'q bo'lsa)
   if(signalType == 1 && !hasBuy)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(GetAutoLotSize(), _Symbol, ask, 0, 0, "Signal Robot Buy");
     }
   else if(signalType == -1 && !hasSell)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(GetAutoLotSize(), _Symbol, bid, 0, 0, "Signal Robot Sell");
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Har bir tickda Dashboard pnl yangilanadi
   UpdateDashboard();

   // Signal faqat sham yopilib yangi sham ochilganda aniqlanadi:
   static datetime lastTime = 0;
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if (currentTime == lastTime) return; // Agar ayni usha sham ichida bo'lsak kutamiz
   
   // Indikatordan 1-indexli shamdagi signallarni olishamiz (yopilgan sham bo'yicha)
   double buyBuffer[1], sellBuffer[1];
   if(CopyBuffer(signalHandle, 1, 1, 1, buyBuffer) <= 0) return;
   if(CopyBuffer(signalHandle, 2, 1, 1, sellBuffer) <= 0) return;
   
   int signalType = 0;
   
   // Agar ko'k (Buy) signal qatori qiymatga ega bo'lsa
   if(buyBuffer[0] != 0.0) 
     {
      signalType = 1; 
      currentSignalStr = "KO'K (BUY)"; 
      currentSignalColor = clrBlue;
     }
   // Agar qizil (Sell) signal qatori qiymatga ega bo'lsa
   else if(sellBuffer[0] != 0.0) 
     {
      signalType = -1; 
      currentSignalStr = "QIZIL (SELL)"; 
      currentSignalColor = clrRed;
     }

   // Pozitsiyalarni boshqarish: Reverse logic
   ManageTrades(signalType);
   
   // Vaqtni yozib qo'yamiz (keyingi sham ochilishni kutish uchun)
   lastTime = currentTime;
  }
//+------------------------------------------------------------------+