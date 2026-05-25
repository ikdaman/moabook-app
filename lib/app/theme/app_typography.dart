import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const dungGeunMoHomeTitle = TextStyle(
    fontFamily: 'DungGeunMo', fontSize: 28, height: 48 / 28,
  );
  static const dungGeunMoHeader = TextStyle(
    fontFamily: 'DungGeunMo', fontSize: 22,
  );
  static const dungGeunMoPopupTitle = TextStyle(
    fontFamily: 'DungGeunMo', fontSize: 18,
  );
  static const dungGeunMoBody = TextStyle(
    fontFamily: 'DungGeunMo', fontSize: 16, height: 1.0,
  );
  static const dungGeunMoSubtitle = TextStyle(
    fontFamily: 'DungGeunMo', fontSize: 14, height: 1.0,
  );
  static const dungGeunMoTag = TextStyle(
    fontFamily: 'DungGeunMo', fontSize: 12, height: 1.4,
  );

  static const wantedSansBookTitle = TextStyle(
    fontFamily: 'WantedSans', fontWeight: FontWeight.w600,
    fontSize: 16, height: 18 / 16,
  );
  static const wantedSansBookTitleLarge = TextStyle(
    fontFamily: 'WantedSans', fontWeight: FontWeight.w600, fontSize: 20,
  );
  static const wantedSansBody = TextStyle(
    fontFamily: 'WantedSans', fontSize: 16, height: 22.4 / 16,
  );
  static const wantedSansBodySmall = TextStyle(
    fontFamily: 'WantedSans', fontSize: 14,
  );
  static const wantedSansCaption = TextStyle(
    fontFamily: 'WantedSans', fontSize: 10,
  );
}
