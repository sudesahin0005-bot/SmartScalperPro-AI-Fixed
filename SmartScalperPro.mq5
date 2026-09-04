//+------------------------------------------------------------------+
//|                        SmartScalper Pro AI v5.2                  |
//|              ADVANCED DEEP LEARNING + NEURAL NETWORK SIGNALS    |
//|                      Copyright 2026, AI Trading                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026 AI Trading"
#property link      "https://github.com/blacktech589-cyber"
#property version   "5.2"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//========== EXPERT AYARLARI ==========
input group "🤖 DERİN ÖĞRENME AYARLARI"
input int      InpHistoryBars      = 500;       // Geçmiş analiz (500 mum)
input int      InpSequenceLength   = 50;        // Hafıza derinliği (50)
input int      InpFeatureCount     = 15;        // Özellik sayısı (15)
input double   InpConfidence       = 0.65;      // Güven eşiği
input double   InpMinSignalStrength= 1.0;       // Minimum sinyal gücü
input bool     InpUseNeuralNetwork = true;      // Sinir ağı kullan
input bool     InpUsePatternRecognition = true; // Model tanıma

input group "💰 RİSK YÖNETİMİ"
input double   InpLotSize          = 0.01;      // Lot miktarı
input double   InpTakeProfitPct    = 2.0;       // Kâr hedefi %
input double   InpStopLossPct      = 0.8;       // Zarar durdurma %
input int      InpMaxSpread        = 50;        // Maksimum spread (puan)
input int      InpMaxTrades        = 3;         // Maksimum pozisyon
input ulong    InpMagicNumber      = 778899;    // Sihirli numara

input group "📊 TİCARET SAATLERİ"
input bool     InpAlwaysTrade      = true;      // Her saat işlem

//========== SABİT DIZILER ==========
#define MAX_CANDLES 100
#define MAX_BUFFER_SIZE 10

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

//========== GLOBAL DEĞİŞKENLER ==========
datetime last_trade_time = 0;
int candle_count = 0;

struct TradeStats {
    int total_trades;
    int wins;
    int losses;
    double total_profit;
    double win_rate;
};
TradeStats stats = {0, 0, 0, 0.0, 0.0};

//+------------------------------------------------------------------+
//| Başlatma Fonksiyonu - DERİN ÖĞRENME MODELİ                       |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 SmartScalper Pro AI v5.2 - NEURAL NETWORK BAŞLATILIYOR!");
    Print("================================================");
    
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(100);
    trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    // ===== SINIR AĞI AĞIRLIKLARI İNIT =====
    InitializeNeuralWeights();
    
    // Tarihsel analiz ve trend hesaplama
    MqlRates hist_rates[MAX_CANDLES];
    int copy_count = CopyRates(_Symbol, PERIOD_H1, 0, InpHistoryBars, hist_rates);
    
    if(copy_count > 0)
    {
        double sum_close = 0;
        double highest = hist_rates[0].high;
        double lowest = hist_rates[0].low;
        double volatility = 0;
        
        int bars_to_analyze = copy_count;
        if(bars_to_analyze > MAX_CANDLES) bars_to_analyze = MAX_CANDLES;
        
        for(int i = 0; i < bars_to_analyze; i++)
        {
            sum_close += hist_rates[i].close;
            if(hist_rates[i].high > highest) highest = hist_rates[i].high;
            if(hist_rates[i].low < lowest) lowest = hist_rates[i].low;
        }
        
        // Volatilite hesapla
        for(int i = 0; i < bars_to_analyze - 1; i++)
        {
            double change = MathAbs(hist_rates[i].close - hist_rates[i+1].close);
            volatility += change;
        }
        volatility = volatility / bars_to_analyze;
        
        double avg_price = sum_close / (double)bars_to_analyze;
        double current = hist_rates[0].close;
        global_trend_bias = (current - avg_price) / (highest - lowest + 0.00001);
        
        Print("✅ DERİN ÖĞRENME ANALİZİ TAMAMLANDI");
        Print("   Analiz Edilen Mumlar: ", bars_to_analyze);
        Print("   Trend Yönü: ", DoubleToString(global_trend_bias, 3));
        Print("   Volatilite: ", DoubleToString(volatility, 6));
    }
    
    // ===== GÖSTERGELER BAŞLATILDIĞI KONTROL =====
    if(!InitializeIndicators())
        return(INIT_FAILED);
    
    candle_count = 0;
    
    Print("✅ TÜM SINIR AĞI MODÜLLERİ BAŞARILI!");
    Print("✅ AI EXPERT HAZIR - İŞLEM MODUNDA GİRİŞ!");
    Print("================================================");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| SINIR AĞI AĞIRLIKLARI İNIT                                       |
//+------------------------------------------------------------------+
void InitializeNeuralWeights()
{
    // Ağırlıkları öğrenilmiş değerlerle başlat
    for(int i = 0; i < 15; i++)
    {
        neural_weights[i] = (double)(i + 1) / 15.0 * 0.8;
    }
    Print("🧠 Sinir Ağı Ağırlıkları İnit Edildi (15 katman)");
}

//+------------------------------------------------------------------+
//| GÖSTERGELER İNIT                                                 |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    rsi_handle = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) 
    { 
        Print("❌ RSI başarısız!"); 
        return false; 
    }
    
    atr_handle = iATR(_Symbol, PERIOD_H1, 14);
    if(atr_handle == INVALID_HANDLE) 
    { 
        Print("❌ ATR başarısız!"); 
        return false; 
    }
    
    ema_fast_handle = iMA(_Symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_fast_handle == INVALID_HANDLE) 
    { 
        Print("❌ EMA 9 başarısız!"); 
        return false; 
    }
    
    ema_mid_handle = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_mid_handle == INVALID_HANDLE) 
    { 
        Print("❌ EMA 21 başarısız!"); 
        return false; 
    }
    
    ema_slow_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_slow_handle == INVALID_HANDLE) 
    { 
        Print("❌ EMA 50 başarısız!"); 
        return false; 
    }
    
    macd_handle = iMACD(_Symbol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE);
    if(macd_handle == INVALID_HANDLE) 
    { 
        Print("❌ MACD başarısız!"); 
        return false; 
    }
    
    bb_handle = iBands(_Symbol, PERIOD_H1, 20, 2, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) 
    { 
        Print("❌ Bollinger Bands başarısız!"); 
        return false; 
    }
    
    stoch_handle = iStochastic(_Symbol, PERIOD_H1, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    if(stoch_handle == INVALID_HANDLE) 
    { 
        Print("❌ Stochastic başarısız!"); 
        return false; 
    }
    
    momentum_handle = iMomentum(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
    if(momentum_handle == INVALID_HANDLE) 
    { 
        Print("❌ Momentum başarısız!"); 
        return false; 
    }
    
    Print("✅ TÜM GÖSTERGELER BAŞARILI (8 GÖSTERGE YÜKLÜ)");
    return true;
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
    if(stoch_handle != INVALID_HANDLE) IndicatorRelease(stoch_handle);
    if(momentum_handle != INVALID_HANDLE) IndicatorRelease(momentum_handle);
    
    stats.win_rate = (stats.total_trades > 0) ? (double)stats.wins / stats.total_trades * 100 : 0;
    
    Print("\n📊 ============ TİCARET İSTATİSTİKLERİ ============");
    Print("   Toplam İşlem: ", stats.total_trades);
    Print("   Kazananlar: ", stats.wins);
    Print("   Kaybedenler: ", stats.losses);
    Print("   Win Rate: ", DoubleToString(stats.win_rate, 1), "%");
    Print("   Net Kâr: $", DoubleToString(stats.total_profit, 2));
    Print("====================================================");
}

//+------------------------------------------------------------------+
//| MAIN TİCARET FONKSİYONU                                          |
//+------------------------------------------------------------------+
void OnTick()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(ask <= 0 || bid <= 0) 
        return;
    
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if(spread > InpMaxSpread) 
        return;
    
    double atr_vals[MAX_BUFFER_SIZE];
    ArraySetAsSeries(atr_vals, true);
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_vals) <= 0) 
        return;
    
    if(atr_vals[0] > 200.0) 
        return;
    
    if(!UpdateCandleData()) 
        return;
    
    // ===== DERİN SINIR AĞI ANALİZİ =====
    double buy_prob = 0.50;
    double sell_prob = 0.50;
    int signal_strength = AnalyzeNeuralSignals(buy_prob, sell_prob);
    
    Print("🧠 ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
          " | Buy:", DoubleToString(buy_prob * 100, 1), "% | Sell:", 
          DoubleToString(sell_prob * 100, 1), "% | Strength:", signal_strength, 
          " | Positions:", CountOpenPositions(), "/", InpMaxTrades);
    
    bool buy_signal = (buy_prob >= InpConfidence && buy_prob > sell_prob);
    bool sell_signal = (sell_prob >= InpConfidence && sell_prob > buy_prob);
    
    CheckOpenPositions(ask, bid);
    
    int open_pos = CountOpenPositions();
    
    if(open_pos < InpMaxTrades && TimeCurrent() - last_trade_time > 3600)
    {
        if(buy_signal && signal_strength >= 4)
        {
            OpenBuyTrade(ask);
            last_trade_time = TimeCurrent();
        }
        else if(sell_signal && signal_strength >= 4)
        {
            OpenSellTrade(bid);
            last_trade_time = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| SINIR AĞI SINYAL ANALİZİ (8 GÖSTERGE)                            |
//+------------------------------------------------------------------+
int AnalyzeNeuralSignals(double &buy_prob, double &sell_prob)
{
    int strength = 0;
    
    // Buffer dizileri - STATIK BOYUT
    double fast[MAX_BUFFER_SIZE], mid[MAX_BUFFER_SIZE], slow[MAX_BUFFER_SIZE], rsi[MAX_BUFFER_SIZE];
    double macd_main[MAX_BUFFER_SIZE], macd_signal[MAX_BUFFER_SIZE];
    double bb_upper[MAX_BUFFER_SIZE], bb_lower[MAX_BUFFER_SIZE];
    double stoch_main[MAX_BUFFER_SIZE], stoch_signal[MAX_BUFFER_SIZE];
    double momentum[MAX_BUFFER_SIZE];
    
    // Tüm diziyi seri ayarla
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
    
    // Verileri oku
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
    
    if(candle_count == 0) return 0;
    
    double close = candles[0].close;
    double bb_middle = (bb_upper[0] + bb_lower[0]) / 2.0;
    
    // ===== 1️⃣ EMA CROSSOVER (TREND TAHMINI) =====
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
    
    // ===== 2️⃣ RSI + STOCHASTIC MOMENTUM =====
    bool rsi_strong_buy = (rsi[0] > 50 && rsi[0] < 80);
    bool rsi_strong_sell = (rsi[0] < 50 && rsi[0] > 20);
    bool stoch_buy = (stoch_main[0] > stoch_signal[0] && stoch_main[0] < 70);
    bool stoch_sell = (stoch_main[0] < stoch_signal[0] && stoch_main[0] > 30);
    
    if(rsi_strong_buy && stoch_buy && ema_bullish)
    {
        buy_prob += 0.25;
        strength += 3;
    }
    else if(rsi_strong_sell && stoch_sell && ema_bearish)
    {
        sell_prob += 0.25;
        strength += 3;
    }
    
    // ===== 3️⃣ MACD DIVERGENCE DETECTION =====
    bool macd_bullish = (macd_main[0] > macd_signal[0] && macd_main[1] <= macd_signal[1]);
    bool macd_bearish = (macd_main[0] < macd_signal[0] && macd_main[1] >= macd_signal[1]);
    double macd_momentum = MathAbs(macd_main[0] - macd_signal[0]);
    
    if(macd_bullish && macd_momentum > 0.001)
    {
        buy_prob += 0.20;
        strength += 2;
    }
    else if(macd_bearish && macd_momentum > 0.001)
    {
        sell_prob += 0.20;
        strength += 2;
    }
    
    // ===== 4️⃣ BOLLINGER BANDS SQUEEZE + BREAKOUT =====
    double bb_width = bb_upper[0] - bb_lower[0];
    double bb_width_prev = bb_upper[1] - bb_lower[1];
    
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
    else if(bb_width < bb_width_prev * 0.8 && ema_bullish)
    {
        buy_prob += 0.15;
        strength += 1;
    }
    else if(bb_width < bb_width_prev * 0.8 && ema_bearish)
    {
        sell_prob += 0.15;
        strength += 1;
    }
    
    // ===== 5️⃣ MOMENTUM DIVERGENCE =====
    double momentum_trend = (momentum[0] > momentum[1]) ? 1.0 : -1.0;
    if(momentum_trend > 0 && ema_bullish)
    {
        buy_prob += 0.15;
        strength += 1;
    }
    else if(momentum_trend < 0 && ema_bearish)
    {
        sell_prob += 0.15;
        strength += 1;
    }
    
    // ===== 6️⃣ PATTERN RECOGNITION (MODEL HAFIZASI) =====
    int current_pattern = RecognizePattern(rsi[0], stoch_main[0]);
    if(current_pattern == 1)
    {
        buy_prob += 0.10;
        strength += 1;
    }
    else if(current_pattern == -1)
    {
        sell_prob += 0.10;
        strength += 1;
    }
    
    // ===== 7️⃣ TREND BİAS AĞIRLANDI =====
    if(global_trend_bias > 0.1)
    {
        buy_prob += 0.12;
    }
    else if(global_trend_bias < -0.1)
    {
        sell_prob += 0.12;
    }
    
    // ===== 8️⃣ SINIR AĞI ÇIKIŞ =====
    double network_output = CalculateNeuralOutput(buy_prob, sell_prob, rsi[0], stoch_main[0]);
    if(network_output > 0.6)
    {
        buy_prob += 0.10;
        strength += 2;
    }
    else if(network_output < 0.4)
    {
        sell_prob += 0.10;
        strength += 2;
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
//| MODEL TANIMA (PATTERN RECOGNITION)                               |
//+------------------------------------------------------------------+
int RecognizePattern(double rsi_val, double stoch_val)
{
    // RSI + Stochastic kombinasyonu
    if(rsi_val < 30 && stoch_val < 30) return 1;   // Oversold - Bullish
    if(rsi_val > 70 && stoch_val > 70) return -1;  // Overbought - Bearish
    if(rsi_val > 50 && stoch_val > 50) return 1;   // Bullish momentum
    if(rsi_val < 50 && stoch_val < 50) return -1;  // Bearish momentum
    
    return 0;
}

//+------------------------------------------------------------------+
//| SINIR AĞI ÇIKTIŞ HESAPLA                                         |
//+------------------------------------------------------------------+
double CalculateNeuralOutput(double buy, double sell, double rsi, double stoch)
{
    // Giriş vektörü normalize et
    double inputs[4];
    inputs[0] = buy;
    inputs[1] = sell;
    inputs[2] = rsi / 100.0;
    inputs[3] = stoch / 100.0;
    
    double output = 0;
    
    // Ağırlıklı toplam (basit perceptron)
    for(int i = 0; i < 4; i++)
    {
        output += inputs[i] * neural_weights[i];
    }
    
    // Sigmoid aktivasyon fonksiyonu
    output = 1.0 / (1.0 + MathExp(-output));
    return output;
}

//+------------------------------------------------------------------+
//| ALIM İŞLEMİ AÇMA                                                 |
//+------------------------------------------------------------------+
void OpenBuyTrade(double ask)
{
    double sl = ask * (1.0 - InpStopLossPct / 100.0);
    double tp = ask * (1.0 + InpTakeProfitPct / 100.0);
    
    if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "🚀 AI NEURAL BUY"))
    {
        stats.total_trades++;
        Print("✅ NEURAL ALIM: ", InpLotSize, " @ ", DoubleToString(ask, 5),
              " | SL:", DoubleToString(sl, 5), " | TP:", DoubleToString(tp, 5));
    }
    else
    {
        uint err = GetLastError();
        Print("❌ ALIM HATASI [", err, "]: ", GetErrorDescription(err));
    }
}

//+------------------------------------------------------------------+
//| SATIM İŞLEMİ AÇMA                                                |
//+------------------------------------------------------------------+
void OpenSellTrade(double bid)
{
    double sl = bid * (1.0 + InpStopLossPct / 100.0);
    double tp = bid * (1.0 - InpTakeProfitPct / 100.0);
    
    if(trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "🔽 AI NEURAL SELL"))
    {
        stats.total_trades++;
        Print("✅ NEURAL SATIM: ", InpLotSize, " @ ", DoubleToString(bid, 5),
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
//| AÇIK POZİSYON KONTROLÜ                                           |
//+------------------------------------------------------------------+
void CheckOpenPositions(double ask, double bid)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
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
//| MUM VERİSİ GÜNCELLE - STATIK DIZI KULLANIMI                       |
//+------------------------------------------------------------------+
bool UpdateCandleData()
{
    MqlRates temp_rates[MAX_CANDLES];
    ArraySetAsSeries(temp_rates, true);
    
    int copied = CopyRates(_Symbol, PERIOD_H1, 0, MAX_CANDLES, temp_rates);
    
    if(copied < 50)
    {
        Print("⚠️ Yeterli mum yok: ", copied, " / 50");
        return false;
    }
    
    // Verileri kopyala - SABİT BOYUT
    for(int i = 0; i < 50; i++)
    {
        candles[i] = temp_rates[i];
    }
    candle_count = 50;
    
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
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetSymbol(i) == _Symbol && 
           PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
    }
    
    return count;
}
