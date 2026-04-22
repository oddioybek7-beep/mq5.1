//+------------------------------------------------------------------+
//|                                             Smart_HHMA_Robot.mq5 |
//|                                   Copyright 2026, GitHub Copilot |
//|       Trading Robot based on Hyperbolic Hull Moving Average      |
//+------------------------------------------------------------------+
#property copyright "GitHub Copilot"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input parameters
input double InpRiskPercent = 1.0;       // Balansga nisbatan Risk (Lot hajmi uchun)
input int    InpLength  = 24;            // HHMA Length (Period)
input double InpTension = 2.0;           // HHMA Tension
input color  InpBullishColor = clrLimeGreen; // Bullish Color
input color  InpBearishColor = clrRed;   // Bearish Color
input ulong  InpMagicNumber = 888888;    // Magic Number

CTrade trade;
CPositionInfo posInfo;
int hhmaHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Grafik (Chart) rangini oq-qora formatga o'tkazish                |
//+------------------------------------------------------------------+
void SetChartColorsWhiteAndBlack()
  {
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_GRID, clrWhiteSmoke);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrWhite);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrBlack);
   ChartSetInteger(0, CHART_COLOR_VOLUME, clrGray);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Indikatorni ulash
   hhmaHandle = iCustom(_Symbol, _Period, "Smart_HHMA", InpLength, InpTension, InpBullishColor, InpBearishColor);
   
   if(hhmaHandle == INVALID_HANDLE)
     {
      Print("XATOLIK: Smart_HHMA indikatori topilmadi!");
      return(INIT_FAILED);
     }
     
   ChartIndicatorAdd(0, 0, hhmaHandle);
   SetChartColorsWhiteAndBlack(); // Grafikni darhol kerakli rangga kiritish
   
   Print("Smart HHMA Robot ishga tushdi!");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hhmaHandle != INVALID_HANDLE) IndicatorRelease(hhmaHandle);
   ObjectsDeleteAll(0, "HHMA_GUI_");
   Print("Smart HHMA Robot o'chirildi va manitor tozalandi.");
  }

//+------------------------------------------------------------------+
//| Balansga qarab "Avto Lot" hisoblash (Risk menejment)             |
//+------------------------------------------------------------------+
double GetAutoLotSize()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Har $1000 balans uchun 0.01 lot bazaviy tarzda olinadi va risk foiziga ko'paytiriladi.
   // Bu trendga ergashadigan robotlar uchun eng optimal xavfsiz lot hisoblashdir.
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
//| HUD (Dashboard) Manitor funksiyalari                             |
//+------------------------------------------------------------------+
void DrawLabel(string name, string text, int x, int y, color clr, int fontSize, bool isBold = false)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
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
   string panelName = "HHMA_GUI_Bg";
   if(ObjectFind(0, panelName) < 0)
     {
      ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 300);
      ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 200);
      ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrWhite);   // Oq orqa fon
      ObjectSetInteger(0, panelName, OBJPROP_BORDER_COLOR, clrBlack); // Qora ramka
      ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, panelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
     }
     
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Ochiq bitimlarni hisoblash
   int openTrades = 0;
   double totalLot = 0.0;
   double totalFloatingProfit = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(posInfo.SelectByIndex(i))
        {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
           {
            openTrades++;
            totalLot += posInfo.Volume();
            totalFloatingProfit += posInfo.Profit();
           }
        }
     }
     
   color pnlColor = (totalFloatingProfit > 0) ? clrLimeGreen : ((totalFloatingProfit < 0) ? clrRed : clrBlack);
     
   DrawLabel("HHMA_GUI_Title", "=== SMART HHMA MANITOR ===",  30, 30,  clrBlack, 12, true);
   DrawLabel("HHMA_GUI_Bal",   "Joriy Balans: $" + DoubleToString(balance, 2), 30, 60, clrBlack, 11);
   DrawLabel("HHMA_GUI_Cnt",   "Ochiq Bitimlar Soni: " + IntegerToString(openTrades), 30, 85, clrBlack, 10);
   DrawLabel("HHMA_GUI_Lot",   "Jami Lotlar: " + DoubleToString(totalLot, 2), 30, 105, clrBlack, 10);
   DrawLabel("HHMA_GUI_PnL",   "Hozirgi Foyda/Zarar: $" + DoubleToString(totalFloatingProfit, 2), 30, 130, pnlColor, 12, true);
   
   // Asoschi logotipi - Qism
   DrawLabel("HHMA_GUI_Line",  "---------------------------------------------", 30, 155, clrGray, 10);
   DrawLabel("HHMA_GUI_Dev",   "Asoschi: oddioybek7", 30, 175, clrMediumBlue, 11, true);
  }

//+------------------------------------------------------------------+
//| Pozitsiyalarni nazorat qilish va ochish/yopish                   |
//+------------------------------------------------------------------+
void ManageTrades(bool isBullish)
  {
   int total = PositionsTotal();
   bool hasBuy = false;
   bool hasSell = false;
   
   for(int i = total - 1; i >= 0; i--)
     {
      if(posInfo.SelectByIndex(i))
        {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
           {
            if(posInfo.PositionType() == POSITION_TYPE_BUY)
              {
               if(!isBullish) { trade.PositionClose(posInfo.Ticket()); } 
               else { hasBuy = true; } 
              }
            else if(posInfo.PositionType() == POSITION_TYPE_SELL)
              {
               if(isBullish) { trade.PositionClose(posInfo.Ticket()); } 
               else { hasSell = true; } 
              }
           }
        }
     }
     
   if(isBullish && !hasBuy)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(GetAutoLotSize(), _Symbol, ask, 0, 0, "Smart HHMA Buy");
     }
   else if(!isBullish && !hasSell)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(GetAutoLotSize(), _Symbol, bid, 0, 0, "Smart HHMA Sell");
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Har bir narx o'zgarishida joriy foyda/dashbordni yangilab hisoblash
   UpdateDashboard();

   // Tizim qarori faqat sham yopilganda qabul qilinadi
   static datetime lastTime = 0;
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if (currentTime == lastTime) return;
   
   // Indikatordan rang (trend) olinadi
   double hhmaColorBuffer[];
   if(CopyBuffer(hhmaHandle, 1, 1, 1, hhmaColorBuffer) <= 0) return;
   
   bool isBullish = (hhmaColorBuffer[0] == 0.0);
   ManageTrades(isBullish);
   
   lastTime = currentTime;
  }
//+------------------------------------------------------------------+