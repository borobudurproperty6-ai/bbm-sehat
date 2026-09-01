import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/walk_session.dart';

Future<String>? _mapStyleFuture;

/// Loads assets/map_style/dark_green.json once and caches it — every map
/// instance in the app shares the same dark, green-tinted style.
Future<String> loadDarkMapStyle() {
  return _mapStyleFuture ??= rootBundle.loadString('assets/map_style/dark_green.json');
}

/// A Google Map with a Strava-style "glowing" route: two overlapping
/// polylines over the same points — a thick, translucent one underneath
/// for the blur/glow, a thin solid one on top as the line's core.
///
/// [live] true = camera follows the latest point at a fixed close zoom
/// (active tracking); false = camera fits the whole route once on load
/// (a finished session's summary/thumbnail).
class GlowRouteMap extends StatefulWidget {
  final List<RoutePoint> points;
  final Color routeColor;
  final bool live;

  const GlowRouteMap({
    super.key,
    required this.points,
    required this.routeColor,
    this.live = false,
  });

  @override
  State<GlowRouteMap> createState() => _GlowRouteMapState();
}

class _GlowRouteMapState extends State<GlowRouteMap> {
  GoogleMapController? _controller;
  String? _style;

  @override
  void initState() {
    super.initState();
    loadDarkMapStyle().then((style) {
      if (mounted) setState(() => _style = style);
    });
  }

  @override
  void didUpdateWidget(covariant GlowRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live && widget.points.length != oldWidget.points.length && widget.points.isNotEmpty) {
      _controller?.animateCamera(CameraUpdate.newLatLng(_toLatLng(widget.points.last)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_style == null || widget.points.isEmpty) {
      return const ColoredBox(color: Color(0xFF0D0D0D));
    }

    final latLngs = widget.points.map(_toLatLng).toList();

    return GoogleMap(
      style: _style,
      initialCameraPosition: CameraPosition(target: latLngs.last, zoom: 17),
      onMapCreated: (controller) {
        _controller = controller;
        if (!widget.live && latLngs.length > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds(controller, latLngs));
        }
      },
      polylines: latLngs.length < 2
          ? const {}
          : {
              Polyline(
                polylineId: const PolylineId('glow'),
                points: latLngs,
                color: widget.routeColor.withValues(alpha: 0.35),
                width: 14,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
              Polyline(
                polylineId: const PolylineId('core'),
                points: latLngs,
                color: widget.routeColor,
                width: 4,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            },
      markers: {
        Marker(
          markerId: const MarkerId('start'),
          position: latLngs.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          zIndexInt: 0,
        ),
        if (!widget.live && latLngs.length > 1)
          Marker(
            markerId: const MarkerId('end'),
            position: latLngs.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            zIndexInt: 1,
          ),
      },
      myLocationEnabled: widget.live,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      liteModeEnabled: !widget.live,
    );
  }

  LatLng _toLatLng(RoutePoint p) => LatLng(p.lat, p.lng);

  void _fitBounds(GoogleMapController controller, List<LatLng> points) {
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    controller.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      48,
    ));
  }
}
