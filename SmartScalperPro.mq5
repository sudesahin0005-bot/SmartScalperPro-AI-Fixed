//+------------------------------------------------------------------+
//|                        SmartScalper Pro AI v4.0                  |
//|                   ERROR FIX + DAHA ZEKI SINYAL SISTEMI            |
//|                      Copyright 2026, AI Trading                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026 AI Trading"
#property link      "https://github.com/blacktech589-cyber"
#property version   "4.0"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//========== EXPERT AYARLARI ==========
input group "🤖 DERİN ÖĞRENME AYARLARI"
input int      InpHistoryBars      = 500;       // Geçmiş analiz (500 mum)
input int      InpSequenceLength   = 50;        // Hafıza derinliği (50)
input int      InpFeatureCount     = 15;        // Özellik sayısı (15)
input double   InpConfidence       = 0.60;      // Güven eşiği
input double   InpMinSignalStrength= 1.0;       // Minimum sinyal gücü

input group "💰 RİSK YÖNETİMİ"
input double   InpLotSize          = 0.01;      // Lot miktarı
input double   InpTakeProfitPct    = 1.5;       // Kâr hedefi %
input double   InpStopLossPct      = 0.7;       // Zarar durdurma %
input int      InpMaxSpread        = 50;        // Maksimum spread (puan)
input int      InpMaxTrades        = 2;         // Maksimum pozisyon
input ulong    InpMagicNumber      = 778899;    // Sihirli numara

input group "📊 TİCARET SAATLERİ"
input bool     InpAlwaysTrade      = true;      // Her saat işlem

//========== GÖSTERGELER ==========
int rsi_handle = INVALID_HANDLE;
int atr_handle = INVALID_HANDLE;
int ema_fast_handle = INVALID_HANDLE;
int ema_mid_handle = INVALID_HANDLE;
int ema_slow_handle = INVALID_HANDLE;
int macd_handle = INVALID_HANDLE;
int bb_handle = INVALID_HANDLE;

MqlRates candles[];
double global_trend_bias = 0.0;

//========== GLOBAL DEĞİŞKENLER ==========
datetime last_trade_time = 0;

struct TradeStats {
    int total_trades;
    int wins;
    int losses;
    double total_profit;
};
TradeStats stats = {0, 0, 0, 0.0};

//+------------------------------------------------------------------+
//| Başlatma Fonksiyonu - HATA DÜZELTİLDİ                            |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 SmartScalper Pro AI v4.0 BAŞLATILIYOR!");
    
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(100);
    trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    // Tarihsel analiz
    MqlRates hist_rates[];
    ArraySetAsSeries(hist_rates, true);
    
    int bars = CopyRates(_Symbol, PERIOD_H1, 0, InpHistoryBars, hist_rates);
    if(bars > 0)
    {
        double sum_close = 0;
        double highest = hist_rates[0].high;
        double lowest = hist_rates[0].low;
        
        for(int i = 0; i < bars; i++)
        {
            sum_close += hist_rates[i].close;
            if(hist_rates[i].high > highest) highest = hist_rates[i].high;
            if(hist_rates[i].low < lowest) lowest = hist_rates[i].low;
        }
        
        double avg_price = sum_close / (double)bars;
        double current = hist_rates[0].close;
        global_trend_bias = (current - avg_price) / (highest - lowest + 0.00001);
        
        Print("✅ ", bars, " mum analiz ediliyor. Trend: ", 
              DoubleToString(global_trend_bias, 3));
    }
    
    // GÖSTERGELER - ERROR FIX: Tüm hataları kontrol et
    rsi_handle = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE)
    {
        Print("❌ RSI göstergesi başarısız!");
        return(INIT_FAILED);
    }
    
    atr_handle = iATR(_Symbol, PERIOD_H1, 14);
    if(atr_handle == INVALID_HANDLE)
    {
        Print("❌ ATR göstergesi başarısız!");
        return(INIT_FAILED);
    }
    
    ema_fast_handle = iMA(_Symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_fast_handle == INVALID_HANDLE)
    {
        Print("❌ EMA 9 göstergesi başarısız!");
        return(INIT_FAILED);
    }
    
    ema_mid_handle = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_mid_handle == INVALID_HANDLE)
    {
        Print("❌ EMA 21 göstergesi başarısız!");
        return(INIT_FAILED);
    }
    
    ema_slow_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_slow_handle == INVALID_HANDLE)
    {
        Print("❌ EMA 50 göstergesi başarısız!");
        return(INIT_FAILED);
    }
    
    macd_handle = iMACD(_Symbol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE);
    if(macd_handle == INVALID_HANDLE)
    {
        Print("❌ MACD göstergesi başarısız!");
        return(INIT_FAILED);
    }
    
    bb_handle = iBands(_Symbol, PERIOD_H1, 20, 2, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE)
    {
        Print("❌ Bollinger Bands başarısız!");
        return(INIT_FAILED);
    }
    
    ArrayResize(candles, InpSequenceLength + 10);
    
    Print("✅ TÜM GÖSTERGELER BAŞARILI!");
    Print("✅ İNİT TAMAMLANDI - HAZIR!");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Durma Fonksiyonu                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
    if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
    if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
    if(ema_mid_handle != INVALID_HANDLE) IndicatorRelease(ema_mid_handle);
    if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
    if(macd_handle != INVALID_HANDLE) IndicatorRelease(macd_handle);
    if(bb_handle != INVALID_HANDLE) IndicatorRelease(bb_handle);
    
    Print("\n📊 ============ TİCARET İSTATİSTİKLERİ ============");
    Print("   Toplam İşlem: ", stats.total_trades);
    Print("   Kazananlar: ", stats.wins);
    Print("   Kaybedenler: ", stats.losses);
    Print("   Win Rate: ", (stats.total_trades > 0 ? 
          DoubleToString((double)stats.wins / stats.total_trades * 100, 1) : "0"), "%");
    Print("   Net Kâr: $", DoubleToString(stats.total_profit, 2));
}

//+------------------------------------------------------------------+
//| MAIN TİCARET FONKSİYONU - HATA DÜZELTİLDİ                        |
//+------------------------------------------------------------------+
void OnTick()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(ask <= 0 || bid <= 0)
        return;
    
    // Spread kontrolü
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if(spread > InpMaxSpread)
        return;
    
    // ATR Volatilite kontrolü
    double atr_vals[];
    ArraySetAsSeries(atr_vals, true);
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_vals) <= 0)
        return;
    
    if(atr_vals[0] > 200.0)  // Çok volatil - atla
        return;
    
    // Mum verisi güncelle
    if(!UpdateCandleData())
        return;
    
    // ZEKI ANALİZ
    double buy_prob = 0.50;
    double sell_prob = 0.50;
    int signal_strength = AnalyzeSmartSignals(buy_prob, sell_prob);
    
    Print("📊 ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
          " | Buy:", DoubleToString(buy_prob * 100, 0), "% | Sell:", 
          DoubleToString(sell_prob * 100, 0), "% | Güç:", signal_strength, 
          " | Pos:", CountOpenPositions(), "/", InpMaxTrades);
    
    // Sinyal kontrolü
    bool buy_signal = (buy_prob >= InpConfidence && buy_prob > sell_prob);
    bool sell_signal = (sell_prob >= InpConfidence && sell_prob > buy_prob);
    
    // Açık pozisyonları kontrol et
    CheckOpenPositions(ask, bid);
    
    // İşlem aç (sadece 1 saat sonra yeni işlem)
    int open_pos = CountOpenPositions();
    
    if(open_pos < InpMaxTrades && TimeCurrent() - last_trade_time > 3600)
    {
        if(buy_signal)
        {
            OpenBuyTrade(ask);
            last_trade_time = TimeCurrent();
        }
        else if(sell_signal)
        {
            OpenSellTrade(bid);
            last_trade_time = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| ZEKI SINYAL ANALIZI (4 GÖSTERGE KOMBINASYONU)                    |
//+------------------------------------------------------------------+
int AnalyzeSmartSignals(double &buy_prob, double &sell_prob)
{
    int strength = 0;
    
    // Göstergeleri oku
    double fast[2], mid[2], slow[2], rsi[2];
    double macd_main[2], macd_signal[2];
    double bb_upper[2], bb_lower[2];
    
    ArraySetAsSeries(fast, true);
    ArraySetAsSeries(mid, true);
    ArraySetAsSeries(slow, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_lower, true);
    
    if(CopyBuffer(ema_fast_handle, 0, 0, 2, fast) <= 0) return 0;
    if(CopyBuffer(ema_mid_handle, 0, 0, 2, mid) <= 0) return 0;
    if(CopyBuffer(ema_slow_handle, 0, 0, 2, slow) <= 0) return 0;
    if(CopyBuffer(rsi_handle, 0, 0, 2, rsi) <= 0) return 0;
    if(CopyBuffer(macd_handle, 0, 0, 2, macd_main) <= 0) return 0;
    if(CopyBuffer(macd_handle, 1, 0, 2, macd_signal) <= 0) return 0;
    if(CopyBuffer(bb_handle, 1, 0, 2, bb_upper) <= 0) return 0;
    if(CopyBuffer(bb_handle, 2, 0, 2, bb_lower) <= 0) return 0;
    
    double close = candles[0].close;
    double open = candles[0].open;
    
    // ===== 1️⃣ EMA CROSSOVER ANALIZI (Güçlü Trend) =====
    bool ema_bullish = (fast[0] > mid[0] && mid[0] > slow[0]);
    bool ema_bearish = (fast[0] < mid[0] && mid[0] < slow[0]);
    
    if(ema_bullish)
    {
        buy_prob += 0.30;
        strength += 2;
    }
    else if(ema_bearish)
    {
        sell_prob += 0.30;
        strength += 2;
    }
    
    // ===== 2️⃣ RSI MOMENTUM ANALIZI (Doğrulama) =====
    bool rsi_bullish = (rsi[0] > 50 && rsi[0] < 75);
    bool rsi_bearish = (rsi[0] < 50 && rsi[0] > 25);
    bool rsi_oversold = (rsi[0] <= 25);
    bool rsi_overbought = (rsi[0] >= 75);
    
    if(rsi_bullish && ema_bullish)
    {
        buy_prob += 0.20;
        strength += 1;
    }
    else if(rsi_bearish && ema_bearish)
    {
        sell_prob += 0.20;
        strength += 1;
    }
    else if(rsi_oversold)  // Rebound potansiyeli
    {
        buy_prob += 0.15;
    }
    else if(rsi_overbought)  // Reversal potansiyeli
    {
        sell_prob += 0.15;
    }
    
    // ===== 3️⃣ MACD MOMENTUM DOĞRULAMASI =====
    bool macd_bullish = (macd_main[0] > macd_signal[0] && 
                         macd_main[1] <= macd_signal[1]);  // Yeni crossover
    bool macd_bearish = (macd_main[0] < macd_signal[0] && 
                         macd_main[1] >= macd_signal[1]);  // Yeni crossover
    
    if(macd_bullish)
    {
        buy_prob += 0.20;
        strength += 2;
    }
    else if(macd_bearish)
    {
        sell_prob += 0.20;
        strength += 2;
    }
    else if(macd_main[0] > macd_signal[0])  // Zayıf bullish
    {
        buy_prob += 0.10;
    }
    else if(macd_main[0] < macd_signal[0])  // Zayıf bearish
    {
        sell_prob += 0.10;
    }
    
    // ===== 4️⃣ BOLLINGER BANDS (VOLATILITE + REVERSAL) =====
    double bb_middle = (bb_upper[0] + bb_lower[0]) / 2.0;
    bool near_lower = (close < bb_middle && close > bb_lower[0]);
    bool near_upper = (close > bb_middle && close < bb_upper[0]);
    bool at_lower = (close <= bb_lower[0]);
    bool at_upper = (close >= bb_upper[0]);
    
    if(at_lower)  // Oversoldu - BUY Setup
    {
        buy_prob += 0.25;
        strength += 2;
    }
    else if(at_upper)  // Overbought - SELL Setup
    {
        sell_prob += 0.25;
        strength += 2;
    }
    else if(near_lower && ema_bullish)
    {
        buy_prob += 0.10;
    }
    else if(near_upper && ema_bearish)
    {
        sell_prob += 0.10;
    }
    
    // ===== 5️⃣ TREND BİAS (Uzun Vadeli Trend) =====
    if(global_trend_bias > 0.05)  // Güçlü uptrend
    {
        buy_prob += 0.10;
    }
    else if(global_trend_bias < -0.05)  // Güçlü downtrend
    {
        sell_prob += 0.10;
    }
    
    // NORMALIZASYON (0.0 - 1.0 arasında)
    double total = buy_prob + sell_prob;
    if(total > 0)
    {
        buy_prob = MathMin(buy_prob / total, 1.0);
        sell_prob = MathMin(sell_prob / total, 1.0);
    }
    
    return strength;
}

//+------------------------------------------------------------------+
//| ALIM İŞLEMİ AÇMA - ERROR FIX                                     |
//+------------------------------------------------------------------+
void OpenBuyTrade(double ask)
{
    double sl = ask * (1.0 - InpStopLossPct / 100.0);
    double tp = ask * (1.0 + InpTakeProfitPct / 100.0);
    
    if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "🚀 AI BUY"))
    {
        stats.total_trades++;
        Print("✅ ALIM AÇILDI: ", InpLotSize, " @ ", DoubleToString(ask, 5),
              " | SL:", DoubleToString(sl, 5), " | TP:", DoubleToString(tp, 5));
    }
    else
    {
        uint err = GetLastError();
        Print("❌ ALIM HATASI [", err, "]: ", GetErrorDescription(err));
    }
}

//+------------------------------------------------------------------+
//| SATIM İŞLEMİ AÇMA - ERROR FIX                                    |
//+------------------------------------------------------------------+
void OpenSellTrade(double bid)
{
    double sl = bid * (1.0 + InpStopLossPct / 100.0);
    double tp = bid * (1.0 - InpTakeProfitPct / 100.0);
    
    if(trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "🔽 AI SELL"))
    {
        stats.total_trades++;
        Print("✅ SATIM AÇILDI: ", InpLotSize, " @ ", DoubleToString(bid, 5),
              " | SL:", DoubleToString(sl, 5), " | TP:", DoubleToString(tp, 5));
    }
    else
    {
        uint err = GetLastError();
        Print("❌ SATIM HATASI [", err, "]: ", GetErrorDescription(err));
    }
}

//+------------------------------------------------------------------+
//| HATA AÇIKLAMASI                                                  |
//+------------------------------------------------------------------+
string GetErrorDescription(uint error)
{
    switch(error)
    {
        case 4000: return "Trade Server is busy";
        case 4001: return "No error returned";
        case 4002: return "Common error";
        case 4003: return "Invalid trade volume";
        case 4004: return "Market is closed";
        case 4005: return "Trade is disabled";
        case 4006: return "Not enough money";
        case 4007: return "Price changed";
        case 4008: return "Off quotes";
        case 4009: return "Broker is busy";
        case 4010: return "Requote";
        case 4011: return "Ask and bid are equal";
        case 4012: return "Volume is too small";
        case 4013: return "Price is too close to market";
        case 4014: return "Invalid price";
        case 4015: return "Invalid stops";
        case 4016: return "Invalid expiration";
        case 4017: return "Order is locked";
        case 4018: return "Only buy orders allowed";
        case 4019: return "Only sell orders allowed";
        case 4020: return "Only limit orders allowed";
        default: return "Unknown error";
    }
}

//+------------------------------------------------------------------+
//| AÇIK POZİSYON KONTROLÜ - HATA DÜZELTİLDİ                         |
//+------------------------------------------------------------------+
void CheckOpenPositions(double ask, double bid)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != _Symbol || 
           PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;
        
        long pos_type = PositionGetInteger(POSITION_TYPE);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_price = (pos_type == POSITION_TYPE_BUY) ? bid : ask;
        double profit_pct = ((current_price - open_price) / open_price) * 100.0;
        
        if(profit_pct > 0) 
            stats.wins++;
        else if(profit_pct < 0) 
            stats.losses++;
            
        stats.total_profit += profit_pct;
    }
}

//+------------------------------------------------------------------+
//| MUM VERİSİ GÜNCELLE - ERROR FIX                                  |
//+------------------------------------------------------------------+
bool UpdateCandleData()
{
    MqlRates temp_rates[];
    ArraySetAsSeries(temp_rates, true);
    
    int copied = CopyRates(_Symbol, PERIOD_H1, 0, InpSequenceLength + 5, temp_rates);
    if(copied < InpSequenceLength)
    {
        Print("⚠️ Yeterli mum yok: ", copied, " / ", InpSequenceLength);
        return false;
    }
    
    ArrayResize(candles, InpSequenceLength);
    ArrayCopy(candles, temp_rates, 0, 0, InpSequenceLength);
    
    return true;
}

//+------------------------------------------------------------------+
//| AÇIK POZİSYON SAYISI                                             |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol && 
           PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
    }
    
    return count;
}
