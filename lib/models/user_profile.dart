class UserProfile {
  String nickname;
  String nationality;
  List<String> favoriteTags;

  UserProfile({
    this.nickname = '',
    this.nationality = '',
    List<String>? favoriteTags,
  }) : favoriteTags = favoriteTags ?? [];

  static const nationalities = [
    'United States', 'United Kingdom', 'Spain', 'Mexico',
    'Colombia', 'Argentina', 'Brazil', 'Chile', 'Peru',
    'Philippines', 'Indonesia', 'Thailand', 'Vietnam', 'Malaysia',
    'France', 'Germany', 'Italy', 'Netherlands', 'Poland',
    'Other',
  ];
}
