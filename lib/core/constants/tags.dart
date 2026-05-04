import 'package:flutter/material.dart';

class KokTags {
  // ── Issue Tags ──
  static const issueTags = [
    'COMEBACK', 'CHART', 'AWARD', 'AGENCY', 'CONTRACT',
    'CONTROVERSY', 'FANDOM', 'MILITARY', 'RELATIONSHIP', 'LEGAL',
    'SOCIAL_MEDIA', 'PERFORMANCE', 'COLLABORATION', 'BRAND_DEAL',
    'VARIETY_SHOW', 'WORLD_TOUR', 'DEBUT', 'DISBANDMENT', 'SOLO', 'OST',
  ];

  static const issueTagDisplay = {
    'COMEBACK': 'Comeback',
    'CHART': 'Chart',
    'AWARD': 'Award',
    'AGENCY': 'Agency',
    'CONTRACT': 'Contract',
    'CONTROVERSY': 'Controversy',
    'FANDOM': 'Fandom',
    'MILITARY': 'Military',
    'RELATIONSHIP': 'Relationship',
    'LEGAL': 'Legal',
    'SOCIAL_MEDIA': 'Social Media',
    'PERFORMANCE': 'Performance',
    'COLLABORATION': 'Collab',
    'BRAND_DEAL': 'Brand Deal',
    'VARIETY_SHOW': 'Variety',
    'WORLD_TOUR': 'World Tour',
    'DEBUT': 'Debut',
    'DISBANDMENT': 'Disbandment',
    'SOLO': 'Solo',
    'OST': 'OST',
  };

  static const issueTagIcons = {
    'COMEBACK': Icons.album_rounded,
    'CHART': Icons.insights_rounded,
    'AWARD': Icons.workspace_premium_rounded,
    'AGENCY': Icons.business_rounded,
    'CONTRACT': Icons.description_rounded,
    'CONTROVERSY': Icons.bolt_rounded,
    'FANDOM': Icons.favorite_rounded,
    'MILITARY': Icons.shield_rounded,
    'RELATIONSHIP': Icons.link_rounded,
    'LEGAL': Icons.gavel_rounded,
    'SOCIAL_MEDIA': Icons.alternate_email_rounded,
    'PERFORMANCE': Icons.mic_external_on_rounded,
    'COLLABORATION': Icons.handshake_rounded,
    'BRAND_DEAL': Icons.diamond_rounded,
    'VARIETY_SHOW': Icons.tv_rounded,
    'WORLD_TOUR': Icons.public_rounded,
    'DEBUT': Icons.auto_awesome_rounded,
    'DISBANDMENT': Icons.heart_broken_rounded,
    'SOLO': Icons.person_rounded,
    'OST': Icons.movie_rounded,
  };

  // ── Artist Tags ──
  static const artistTags = [
    'BTS', 'BLACKPINK', 'NewJeans', 'IVE', 'aespa',
    'LE SSERAFIM', 'SEVENTEEN', 'Stray Kids', 'NCT', 'RIIZE',
    'TXT', 'ENHYPEN', 'BABYMONSTER', 'ILLIT', 'TWICE',
    'ITZY', 'EXO', 'Red Velvet', '(G)I-DLE', 'NMIXX',
    'TREASURE', 'ATEEZ', 'BOYNEXTDOOR', 'ZEROBASEONE', 'xikers',
  ];

  // ── Agency Tags ──
  static const agencyTags = [
    'HYBE', 'ADOR', 'SM', 'JYP', 'YG',
    'STARSHIP', 'CUBE', 'PLEDIS', 'SOURCE_MUSIC', 'BELIFT',
    'KOZ', 'WAKEONE', 'IST', 'FNC', 'RBW',
  ];

  static List<String> get allFilterTags => [...issueTags, ...artistTags, ...agencyTags];
  static List<String> get allArtistAndAgency => [...artistTags, ...agencyTags];
}
