import '../models/walk_session.dart';

/// Decodes a Google encoded polyline (precision 5) — the same format the
/// backend's WalkSessionService encodes route_polyline in, and the format
/// google_maps_flutter and most map SDKs speak natively.
List<RoutePoint> decodePolyline(String encoded) {
  final points = <RoutePoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    final (latDelta, afterLat) = _decodeSignedNumber(encoded, index);
    lat += latDelta;
    index = afterLat;

    final (lngDelta, afterLng) = _decodeSignedNumber(encoded, index);
    lng += lngDelta;
    index = afterLng;

    // The polyline format has no timestamp per point, and these decoded
    // points are only ever used to render a past route on the map — never
    // re-submitted to the backend — so this placeholder is never read.
    points.add(RoutePoint(lat: lat / 1e5, lng: lng / 1e5, timestamp: DateTime.fromMillisecondsSinceEpoch(0)));
  }

  return points;
}

/// Decodes one signed, variable-length number starting at [startIndex].
/// Returns (value, indexAfterThisNumber).
(int, int) _decodeSignedNumber(String encoded, int startIndex) {
  var index = startIndex;
  var result = 0;
  var shift = 0;
  int b;
  do {
    b = encoded.codeUnitAt(index++) - 63;
    result |= (b & 0x1f) << shift;
    shift += 5;
  } while (b >= 0x20);

  final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  return (value, index);
}
