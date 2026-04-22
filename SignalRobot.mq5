//+------------------------------------------------------------------+
//|                                                 SignalRobot.mq5 |
//|                                   Copyright 2026, GitHub Copilot |
//|                                              Asoschi: oddioybek7 |
//+------------------------------------------------------------------+
#property copyright "Asoschi: oddioybek7"
#property link      "https://github.com/oddioybek7-beep"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

input double   InpRiskRisk       = 1.0;     // Balansga nisbatan risk (%)
input ulong    InpMagic          = 777777;  // Magic Number

// Signal Indicator parametrari
input int      InpTemaPeriod   = 8;      // TEMA period
input bool     InpNoiseFilter  = true;   // Noise filter on/off?
input int      InpFilterFast   = 8;      // Filter fast length
input int      InpFilterSlow   = 14;     // Filter slow length
input int      InpFilterSignal = 9;      // Filter signal length

CTrade         trade;
CPositionInfo  pos;
CSymbolInfo    symb;

int            signalHandle;

// Dashboard uchun global o'zgaruvchilar
string lastSignalStatus = "Kutish";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   symb.Name(_Symbol);
   symb.Refresh();
   
   // signal.ex5 indikatorni yuklash
   signalHandle = iCustom(_Symbol, _Period, "signal", InpTemaPeriod, InpNoiseFilter, InpFilterFast, InpFilterSlow, InpFilterSignal, true);
   
   if(signalHandle == INVALID_HANDLE)
     {
      Print("XATOLIK: 'signal.ex5' indikatorini yuklab bo'lmadi! Avval signal.mq5 ni compile qiling.");
      return(INIT_FAILED);
     }
     
   CreateDashboard();
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "DB_");
   IndicatorRelease(signalHandle);
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Balance                              |
//+------------------------------------------------------------------+
double CalculateLotSize()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Hisob balansidan kelib chiqib lotni hisoblash (1000 birlik uchun 0.01 lot * risk%)
   double simpleLot = (balance / 1000.0) * 0.01 * InpRiskRisk;
   
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   simpleLot = MathRound(simpleLot / step) * step;
   
   if(simpleLot < min_lot) simpleLot = min_lot;
   if(simpleLot > max_lot) simpleLot = max_lot;
   
   return simpleLot;
  }

//+------------------------------------------------------------------+
//| Calculate Total Robot Profit                                     |
//+------------------------------------------------------------------+
double GetRobotProfit()
  {
   double profit = 0;
   
   // Tarixdagi yopilgan bitimlar foydasi
   if(HistorySelect(0, TimeCurrent()))
     {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
           {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagic)
              {
               profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
               profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
               profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
              }
           }
        }
     }
     
   // Ochiq turgan pozitsiyalar foydasi
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(pos.SelectByIndex(i))
        {
         if(pos.Symbol() == _Symbol && pos.Magic() == InpMagic)
           {
            profit += pos.Profit();
            profit += pos.Swap();
           }
        }
     }
     
   return profit;
  }

//+------------------------------------------------------------------+
//| Close all positions of specific type                             |
//+------------------------------------------------------------------+
void ClosePosition(ENUM_POSITION_TYPE type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(pos.SelectByIndex(i))
        {
         if(pos.Symbol() == _Symbol && pos.Magic() == InpMagic && pos.PositionType() == type)
           {
            trade.PositionClose(pos.Ticket());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Check open positions                                             |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_POSITION_TYPE type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(pos.SelectByIndex(i))
        {
         if(pos.Symbol() == _Symbol && pos.Magic() == InpMagic && pos.PositionType() == type)
           {
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Faqat yangi shamda ishlash uchun tekshiruv qilsa ham bo'ladi, 
   // lekin indicator bar yopilganda signalni qayd qilgani uchun 1-indexdagi barlarni tekshiramiz.
   
   double buyBuf[];
   double sellBuf[];
   ArraySetAsSeries(buyBuf, true);
   ArraySetAsSeries(sellBuf, true);
   
   // 1-indexdagi 1 ta bar (yopilgan eng so'nggi sham) malumotini olish
   if(CopyBuffer(signalHandle, 1, 1, 1, buyBuf) <= 0) return;
   if(CopyBuffer(signalHandle, 2, 1, 1, sellBuf) <= 0) return;
   
   // Agar noldan katta qiymat bo'lsa (ya'ni o'q chizilgan bo'lsa) signal hisoblanadi
   bool isBuySignal = (buyBuf[0] > 0.0);
   bool isSellSignal = (sellBuf[0] > 0.0);
   
   if(isBuySignal)
     {
      lastSignalStatus = "BUY (Ko'k)";
      
      // Qizil signal berilishi bilan oldingi sell yopilgan edi, 
      // Endi ko'k signal berilganda agar ochiq Sell bo'lsa, uni yopamiz:
      if(HasOpenPosition(POSITION_TYPE_SELL))
        {
         ClosePosition(POSITION_TYPE_SELL);
        }
      
      // Va Buy bitimini ochamiz
      if(!HasOpenPosition(POSITION_TYPE_BUY))
        {
         double lot = CalculateLotSize();
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         trade.Buy(lot, _Symbol, ask, 0, 0, "Signal Buy");
        }
     }
   else if(isSellSignal)
     {
      lastSignalStatus = "SELL (Qizil)";
      
      // Qizil signal berilishi bilan oldingi Buy bitimni yopamiz
      if(HasOpenPosition(POSITION_TYPE_BUY))
        {
         ClosePosition(POSITION_TYPE_BUY);
        }
      
      // Va Sell bitimini ochamiz
      if(!HasOpenPosition(POSITION_TYPE_SELL))
        {
         double lot = CalculateLotSize();
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         trade.Sell(lot, _Symbol, bid, 0, 0, "Signal Sell");
        }
     }
     
   UpdateDashboard();
  }

//+------------------------------------------------------------------+
//| Dashboard functions                                              |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   CreateLabel("DB_Author", "Asoschi: oddioybek7", 20, 20, clrWhite, 20);
   CreateLabel("DB_Balance", "Balans: 0.0", 20, 50, clrLightGreen, 14);
   CreateLabel("DB_Profit", "Robot Foydasi: 0.0", 20, 80, clrGold, 14);
   CreateLabel("DB_Signal", "Signal: Kutish", 20, 110, clrSkyBlue, 14);
  }

void CreateLabel(string name, string text, int x, int y, color clr, int size)
  {
   if(ObjectFind(0, name) != 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetColor(0, name, OBJPROP_COLOR, clr);
     }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

void UpdateDashboard()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double profit = GetRobotProfit();
   
   ObjectSetString(0, "DB_Balance", OBJPROP_TEXT, "Balans: " + DoubleToString(balance, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
   
   color profClr = (profit >= 0) ? clrGold : clrRed;
   ObjectSetColor(0, "DB_Profit", OBJPROP_COLOR, profClr);
   ObjectSetString(0, "DB_Profit", OBJPROP_TEXT, "Robot Foydasi: " + DoubleToString(profit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
   
   color sigClr = clrYellow;
   if(lastSignalStatus == "BUY (Ko'k)") sigClr = clrDodgerBlue;
   if(lastSignalStatus == "SELL (Qizil)") sigClr = clrCrimson;
   ObjectSetColor(0, "DB_Signal", OBJPROP_COLOR, sigClr);
   ObjectSetString(0, "DB_Signal", OBJPROP_TEXT, "Signal: " + lastSignalStatus);
   
   ChartRedraw();
  }
//+------------------------------------------------------------------+
