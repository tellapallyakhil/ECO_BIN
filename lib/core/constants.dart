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
  static const String supabaseAnonKey = 'sb_publishable_QpYHLUB6pXNG-idT4SeoNA_Tya7foE4';

  // Reward coins per kg of plastic collected
  static const int coinsPerKg = 50;
  // Starting coins for new users
  static const int startingCoins = 100;
  // Bin threshold default in kg
  static const double defaultThreshold = 10.0;
}
