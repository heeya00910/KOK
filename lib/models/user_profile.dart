class UserProfile {
  String nickname;
  String nationality;
  String representativeFandom;
  List<String> favoriteTags;

  UserProfile({
    this.nickname = '',
    this.nationality = '',
    this.representativeFandom = '',
    List<String>? favoriteTags,
  }) : favoriteTags = favoriteTags ?? [];

  String get nationalityShort => nationalityCode[nationality] ?? nationality;

  static const nationalities = [
    'United States', 'United Kingdom', 'Spain', 'Mexico',
    'Colombia', 'Argentina', 'Brazil', 'Chile', 'Peru',
    'Philippines', 'Indonesia', 'Thailand', 'Vietnam', 'Malaysia',
    'France', 'Germany', 'Italy', 'Netherlands', 'Poland',
    'Other',
  ];

  static const nationalityCode = {
    'United States': 'US',
    'United Kingdom': 'UK',
    'Spain': 'ES',
    'Mexico': 'MX',
    'Colombia': 'CO',
    'Argentina': 'AR',
    'Brazil': 'BR',
    'Chile': 'CL',
    'Peru': 'PE',
    'Philippines': 'PH',
    'Indonesia': 'ID',
    'Thailand': 'TH',
    'Vietnam': 'VN',
    'Malaysia': 'MY',
    'France': 'FR',
    'Germany': 'DE',
    'Italy': 'IT',
    'Netherlands': 'NL',
    'Poland': 'PL',
    'Other': '--',
  };

  static String shortCode(String nationality) =>
      nationalityCode[nationality] ?? nationality;
}
