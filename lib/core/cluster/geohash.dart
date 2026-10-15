// lib/core/cluster/geohash.dart
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Geohash {
  static const List<String> _base32NumberToChar = <String>[
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'b', 'c', 'd', 'e', 'f', 'g', 'h', 'j', 'k', 'm',
    'n', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x',
    'y', 'z',
  ];

  static String encode(final LatLng latLng, {final int codeLength = 12}) {
    if (codeLength > 20 || (identical(1.0, 1) && codeLength > 12)) {
      throw ArgumentError(
          'latitude and longitude are not precise enough to encode $codeLength characters');
    }
    final latitudeBase2 = (latLng.latitude + 90) * (pow(2.0, 52) / 180);
    final longitudeBase2 = (latLng.longitude + 180) * (pow(2.0, 52) / 360);
    final longitudeBits = (codeLength ~/ 2) * 5 + (codeLength % 2) * 3;
    final latitudeBits = codeLength * 5 - longitudeBits;
    var longitudeCode = (identical(1.0, 1))
        ? (longitudeBase2 / (pow(2.0, 52 - longitudeBits))).floor()
        : longitudeBase2.floor() >> (52 - longitudeBits);
    var latitudeCode = (identical(1.0, 1))
        ? (latitudeBase2 / (pow(2.0, 52 - latitudeBits))).floor()
        : latitudeBase2.floor() >> (52 - latitudeBits);

    final stringBuffer = <String>[];
    for (var localCodeLength = codeLength;
        localCodeLength > 0;
        localCodeLength--) {
      int bigEndCode, littleEndCode;
      if (localCodeLength % 2 == 0) {
        bigEndCode = latitudeCode;
        littleEndCode = longitudeCode;
        latitudeCode >>= 3;
        longitudeCode >>= 2;
      } else {
        bigEndCode = longitudeCode;
        littleEndCode = latitudeCode;
        latitudeCode >>= 2;
        longitudeCode >>= 3;
      }
      final code = ((bigEndCode & 4) << 2) |
          ((bigEndCode & 2) << 1) |
          (bigEndCode & 1) |
          ((littleEndCode & 2) << 2) |
          ((littleEndCode & 1) << 1);
      stringBuffer.add(_base32NumberToChar[code]);
    }
    return stringBuffer.reversed.join();
  }
}
