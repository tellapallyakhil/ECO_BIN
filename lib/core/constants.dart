class AppConstants {
  static const String appName = 'EcoBin';
  static const String appDescription = 'Smart Plastic Waste Management';

  // Worldwide Plastic Waste Data
  static const String dailyPlasticWaste = '220 Million Tons/Year';
  static const String mismanagedPlastic = '69.5 Million Tons/Year';
  static const String oceanLeakage = '2,000 Garbage Trucks/Day';

  // Impact Data
  static const String impactTitle = 'The Power of EcoBin';
  static const String impactDescription =
      'By implementing smart segregation and real-time monitoring, EcoBin reduces '
      'mismanaged plastic waste by up to 40% in participating communities. '
      'The reward system incentivizes 3x faster collection rates and '
      'has the potential to divert millions of tons of plastic from landfills.';

  // Supabase
  static const String supabaseUrl = 'https://gtotmudrbkdixyuclyxy.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd0b3RtdWRyYmtkaXh5dWNseXh5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMzI3MzQsImV4cCI6MjA4ODkwODczNH0.uTpFw07DRd7qjHUqZfm9yDqk58GhjWl2ZsfXeLk7gBw';

  // ═══════════════════════════════════════════════════════
  //  BIN CAPACITY & THRESHOLDS (in grams)
  // ═══════════════════════════════════════════════════════
  
  /// Max bin capacity in grams
  static const double binCapacityGrams = 200.0;
  
  /// Default threshold in kg (for Supabase smart_bins table)
  static const double defaultThresholdKg = 0.2; // 200g = 0.2kg
  
  /// Green zone: 0 to this value (grams)
  static const double greenMaxGrams = 80.0;
  
  /// Orange/Medium zone: greenMax to this value (grams)
  static const double orangeMaxGrams = 125.0;
  
  /// Red/Full zone: orangeMax and above (grams)
  static const double redMinGrams = 125.0;
  
  /// Alert trigger: bin is considered FULL at this weight (grams)
  static const double fullAlertGrams = 200.0;

  // ═══════════════════════════════════════════════════════
  //  REWARD SYSTEM (calibrated for 200g bin)
  // ═══════════════════════════════════════════════════════
  
  /// Coins awarded per gram of plastic deposited
  /// 1 coin per 2 grams → Full 200g deposit = 100 coins
  static const double coinsPerGram = 0.5;
  
  /// Starting coins for new users (welcome bonus)
  static const int startingCoins = 50;
  
  /// Calculate coins from weight in grams
  static int calculateCoins(double weightGrams) {
    return (weightGrams * coinsPerGram).toInt();
  }
}
