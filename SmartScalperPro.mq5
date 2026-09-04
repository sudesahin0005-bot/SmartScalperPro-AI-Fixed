//+------------------------------------------------------------------+
//|                        SmartScalper Pro AI v5.3                  |
//|              ADVANCED DEEP LEARNING + NEURAL NETWORK SIGNALS    |
//|                      Copyright 2026, AI Trading                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026 AI Trading"
#property link      "https://github.com/blacktech589-cyber"
#property version   "5.3"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//========== EXPERT AYARLARI ==========
input group "🤖 DERİN ÖĞRENME AYARLARI"
input int      InpHistoryBars      = 500;
input int      InpSequenceLength   = 50;
input int      InpFeatureCount     = 15;
input double   InpConfidence       = 0.65;
input double   InpMinSignalStrength= 1.0;
input bool     InpUseNeuralNetwork = true;
input bool     InpUsePatternRecognition = true;

input group "💰 RİSK YÖNETİMİ"
input double   InpLotSize          = 0.01;
input double   InpTakeProfitPct    = 2.0;
input double   InpStopLossPct      = 0.8;
input int      InpMaxSpread        = 50;
input int      InpMaxTrades        = 3;
input ulong    InpMagicNumber      = 778899;

input group "📊 TİCARET SAATLERİ"
input bool     InpAlwaysTrade      = true;

//========== SABİT BOYUTLAR ==========
#define MAX_HIST 100
#define MAX_CANDLES 100
#define MAX_BUFFER 10
#define CANDLE_SIZE 50

//========== GÖSTERGELER ==========
int rsi_handle = INVALID_HANDLE;
int atr_handle = INVALID_HANDLE;
int ema_fast_handle = INVALID_HANDLE;
int ema_mid_handle = INVALID_HANDLE;
int ema_slow_handle = INVALID_HANDLE;
int macd_handle = INVALID_HANDLE;
int bb_handle = INVALID_HANDLE;
int stoch_handle = INVALID_HANDLE;
int momentum_handle = INVALID_HANDLE;

MqlRates candles[MAX_CANDLES];
double global_trend_bias = 0.0;
double neural_weights[15];
datetime last_trade_time = 0;

struct TradeStats
{
    int total_trades;
    int wins;
    int losses;
    double total_profit;
    double win_rate;
};
TradeStats stats;

//+------------------------------------------------------------------+
//| BAŞLATMA FONKSIYONU                                              |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 SmartScalper Pro AI v5.3 BAŞLATILIYOR!");
    Print("================================================");
    
    stats.total_trades = 0;
    stats.wins = 0;
    stats.losses = 0;
    stats.total_profit = 0.0;
    stats.win_rate = 0.0;
    
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(100);
    trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    InitializeNeuralWeights();
    
    // Tarihsel analiz
    MqlRates hist_rates[MAX_HIST];
    int copy_count = CopyRates(_Symbol, PERIOD_H1, 0, MAX_HIST, hist_rates);
    
    if(copy_count > 0)
    {
        double sum_close = 0;
        double highest = hist_rates[0].high;
        double lowest = hist_rates[0].low;
        double volatility = 0;
        
        int bars_analyze = copy_count;
        if(bars_analyze > MAX_HIST) bars_analyze = MAX_HIST;
        
        for(int i = 0; i < bars_analyze; i++)
        {
            sum_close += hist_rates[i].close;
            if(hist_rates[i].high > highest) highest = hist_rates[i].high;
            if(hist_rates[i].low < lowest) lowest = hist_rates[i].low;
        }
        
        for(int i = 0; i < bars_analyze - 1; i++)
        {
            volatility += MathAbs(hist_rates[i].close - hist_rates[i+1].close);
        }
        volatility = volatility / bars_analyze;
        
        double avg_price = sum_close / (double)bars_analyze;
        double current = hist_rates[0].close;
        global_trend_bias = (current - avg_price) / (highest - lowest + 0.00001);
        
        Print("✅ TREND ANALIZI TAMAMLANDI");
        Print("   Mumlar: ", bars_analyze);
        Print("   Trend: ", DoubleToString(global_trend_bias, 3));
    }
    
    if(!InitializeIndicators())
        return(INIT_FAILED);
    
    Print("✅ TÜM SİSTEM BAŞARILI!");
    Print("================================================");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| SINIR AĞI AĞIRLIKLARI İNIT                                       |
//+------------------------------------------------------------------+
void InitializeNeuralWeights()
{
    for(int i = 0; i < 15; i++)
    {
        neural_weights[i] = (double)(i + 1) / 15.0 * 0.8;
    }
}

//+------------------------------------------------------------------+
//| GÖSTERGELER İNIT                                                 |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    rsi_handle = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return false;
    
    atr_handle = iATR(_Symbol, PERIOD_H1, 14);
    if(atr_handle == INVALID_HANDLE) return false;
    
    ema_fast_handle = iMA(_Symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_fast_handle == INVALID_HANDLE) return false;
    
    ema_mid_handle = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_mid_handle == INVALID_HANDLE) return false;
    
    ema_slow_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_slow_handle == INVALID_HANDLE) return false;
    
    macd_handle = iMACD(_Symbol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE);
    if(macd_handle == INVALID_HANDLE) return false;
    
    bb_handle = iBands(_Symbol, PERIOD_H1, 20, 2, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) return false;
    
    stoch_handle = iStochastic(_Symbol, PERIOD_H1, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    if(stoch_handle == INVALID_HANDLE) return false;
    
    momentum_handle = iMomentum(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
    if(momentum_handle == INVALID_HANDLE) return false;
    
    Print("✅ 8 GÖSTERGE YÜKLÜ");
    return true;
}

//+------------------------------------------------------------------+
//| DURMA FONKSIYONU                                                 |
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
    if(stoch_handle != INVALID_HANDLE) IndicatorRelease(stoch_handle);
    if(momentum_handle != INVALID_HANDLE) IndicatorRelease(momentum_handle);
    
    if(stats.total_trades > 0)
    {
        stats.win_rate = (double)stats.wins / stats.total_trades * 100;
    }
    
    Print("\n📊 İSTATİSTİKLER");
    Print("Toplam: ", stats.total_trades);
    Print("Kazanç: ", stats.wins);
    Print("Kayıp: ", stats.losses);
    Print("Win Rate: ", DoubleToString(stats.win_rate, 1), "%");
}

//+------------------------------------------------------------------+
//| MAIN TİCARET DÖNGÜSÜ                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(ask <= 0 || bid <= 0) return;
    
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if(spread > InpMaxSpread) return;
    
    double atr_vals[MAX_BUFFER];
    ArraySetAsSeries(atr_vals, true);
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_vals) <= 0) return;
    if(atr_vals[0] > 200.0) return;
    
    if(!UpdateCandleData()) return;
    
    double buy_prob = 0.50;
    double sell_prob = 0.50;
    int signal_strength = AnalyzeSignals(buy_prob, sell_prob);
    
    bool buy_signal = (buy_prob >= InpConfidence && buy_prob > sell_prob);
    bool sell_signal = (sell_prob >= InpConfidence && sell_prob > buy_prob);
    
    int open_pos = CountPositions();
    
    if(open_pos < InpMaxTrades && TimeCurrent() - last_trade_time > 3600)
    {
        if(buy_signal && signal_strength >= 4)
        {
            OpenBuy(ask);
            last_trade_time = TimeCurrent();
        }
        else if(sell_signal && signal_strength >= 4)
        {
            OpenSell(bid);
            last_trade_time = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| SINYAL ANALIZI                                                   |
//+------------------------------------------------------------------+
int AnalyzeSignals(double &buy_prob, double &sell_prob)
{
    int strength = 0;
    
    double fast[MAX_BUFFER], mid[MAX_BUFFER], slow[MAX_BUFFER], rsi[MAX_BUFFER];
    double macd_main[MAX_BUFFER], macd_signal[MAX_BUFFER];
    double bb_upper[MAX_BUFFER], bb_lower[MAX_BUFFER];
    double stoch_main[MAX_BUFFER], stoch_signal[MAX_BUFFER];
    double momentum[MAX_BUFFER];
    
    ArraySetAsSeries(fast, true);
    ArraySetAsSeries(mid, true);
    ArraySetAsSeries(slow, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_lower, true);
    ArraySetAsSeries(stoch_main, true);
    ArraySetAsSeries(stoch_signal, true);
    ArraySetAsSeries(momentum, true);
    
    if(CopyBuffer(ema_fast_handle, 0, 0, 2, fast) <= 0) return 0;
    if(CopyBuffer(ema_mid_handle, 0, 0, 2, mid) <= 0) return 0;
    if(CopyBuffer(ema_slow_handle, 0, 0, 2, slow) <= 0) return 0;
    if(CopyBuffer(rsi_handle, 0, 0, 2, rsi) <= 0) return 0;
    if(CopyBuffer(macd_handle, 0, 0, 2, macd_main) <= 0) return 0;
    if(CopyBuffer(macd_handle, 1, 0, 2, macd_signal) <= 0) return 0;
    if(CopyBuffer(bb_handle, 1, 0, 2, bb_upper) <= 0) return 0;
    if(CopyBuffer(bb_handle, 2, 0, 2, bb_lower) <= 0) return 0;
    if(CopyBuffer(stoch_handle, 0, 0, 2, stoch_main) <= 0) return 0;
    if(CopyBuffer(stoch_handle, 1, 0, 2, stoch_signal) <= 0) return 0;
    if(CopyBuffer(momentum_handle, 0, 0, 2, momentum) <= 0) return 0;
    
    double close = candles[0].close;
    
    // EMA ANALIZI
    bool ema_bullish = (fast[0] > mid[0] && mid[0] > slow[0]);
    bool ema_bearish = (fast[0] < mid[0] && mid[0] < slow[0]);
    
    if(ema_bullish)
    {
        buy_prob += 0.35;
        strength += 3;
    }
    else if(ema_bearish)
    {
        sell_prob += 0.35;
        strength += 3;
    }
    
    // RSI + STOCHASTIC
    bool rsi_buy = (rsi[0] > 50 && rsi[0] < 80);
    bool rsi_sell = (rsi[0] < 50 && rsi[0] > 20);
    bool stoch_buy = (stoch_main[0] > stoch_signal[0] && stoch_main[0] < 70);
    bool stoch_sell = (stoch_main[0] < stoch_signal[0] && stoch_main[0] > 30);
    
    if(rsi_buy && stoch_buy && ema_bullish)
    {
        buy_prob += 0.25;
        strength += 3;
    }
    else if(rsi_sell && stoch_sell && ema_bearish)
    {
        sell_prob += 0.25;
        strength += 3;
    }
    
    // MACD
    bool macd_bullish = (macd_main[0] > macd_signal[0] && macd_main[1] <= macd_signal[1]);
    bool macd_bearish = (macd_main[0] < macd_signal[0] && macd_main[1] >= macd_signal[1]);
    
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
    
    // BOLLINGER BANDS
    if(close >= bb_upper[0])
    {
        sell_prob += 0.20;
        strength += 2;
    }
    else if(close <= bb_lower[0])
    {
        buy_prob += 0.20;
        strength += 2;
    }
    
    // MOMENTUM
    if(momentum[0] > momentum[1] && ema_bullish)
    {
        buy_prob += 0.15;
        strength += 1;
    }
    else if(momentum[0] < momentum[1] && ema_bearish)
    {
        sell_prob += 0.15;
        strength += 1;
    }
    
    // TREND BIAS
    if(global_trend_bias > 0.1)
    {
        buy_prob += 0.12;
    }
    else if(global_trend_bias < -0.1)
    {
        sell_prob += 0.12;
    }
    
    // NORMALIZASYON
    double total = buy_prob + sell_prob;
    if(total > 0)
    {
        buy_prob = MathMin(buy_prob / total, 1.0);
        sell_prob = MathMin(sell_prob / total, 1.0);
    }
    
    return strength;
}

//+------------------------------------------------------------------+
//| ALIM AÇMA                                                         |
//+------------------------------------------------------------------+
void OpenBuy(double ask)
{
    double sl = ask * (1.0 - InpStopLossPct / 100.0);
    double tp = ask * (1.0 + InpTakeProfitPct / 100.0);
    
    if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "AI BUY"))
    {
        stats.total_trades++;
        Print("✅ BUY: ", InpLotSize, " @ ", DoubleToString(ask, 5));
    }
}

//+------------------------------------------------------------------+
//| SATIM AÇMA                                                        |
//+------------------------------------------------------------------+
void OpenSell(double bid)
{
    double sl = bid * (1.0 + InpStopLossPct / 100.0);
    double tp = bid * (1.0 - InpTakeProfitPct / 100.0);
    
    if(trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "AI SELL"))
    {
        stats.total_trades++;
        Print("✅ SELL: ", InpLotSize, " @ ", DoubleToString(bid, 5));
    }
}

//+------------------------------------------------------------------+
//| MUM VERİSİ GÜNCELLE                                              |
//+------------------------------------------------------------------+
bool UpdateCandleData()
{
    MqlRates temp_rates[MAX_CANDLES];
    ArraySetAsSeries(temp_rates, true);
    
    int copied = CopyRates(_Symbol, PERIOD_H1, 0, CANDLE_SIZE, temp_rates);
    
    if(copied < CANDLE_SIZE)
    {
        return false;
    }
    
    for(int i = 0; i < CANDLE_SIZE; i++)
    {
        candles[i] = temp_rates[i];
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| AÇIK POZİSYON SAYISI                                             |
//+------------------------------------------------------------------+
int CountPositions()
{
    int count = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionSelectByTicket(ticket))
            {
                if(PositionGetSymbol(i) == _Symbol)
                {
                    if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                    {
                        count++;
                    }
                }
            }
        }
    }
    
    return count;
}
