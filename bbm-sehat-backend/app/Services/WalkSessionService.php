<?php

namespace App\Services;

use Illuminate\Support\Carbon;

/**
 * Turns a raw GPS point trail into the two things a walk session needs to
 * store: total distance (Haversine sum between consecutive points, with
 * GPS jump/speed noise excluded — see isGpsNoise()) and a Google encoded
 * polyline (the same format google_maps_flutter and most mapping SDKs
 * decode natively, so the Flutter side never has to ship or parse the raw
 * point array itself).
 */
class WalkSessionService
{
    private const EARTH_RADIUS_METERS = 6371000.0;

    /**
     * A segment right after starting that implies faster than this is
     * treated as a stale/jumped fix, not real movement (e.g. the
     * emulator's location snapping to a different point via Extended
     * Controls, or a device's first fix drifting from cell-tower to GPS
     * accuracy) — only checked for the very first segment.
     */
    private const FIRST_FIX_JUMP_METERS = 500.0;

    private const FIRST_FIX_JUMP_SECONDS = 5.0;

    /** No human plausibly walks/runs faster than this — anything above is a GPS multipath/reflection spike. */
    private const MAX_WALKING_SPEED_KMH = 20.0;

    /**
     * Re-derives distance from the raw point trail independently of
     * whatever the client already filtered — a client-side bug (or a
     * future client that doesn't filter at all) must not be able to
     * corrupt what's actually persisted.
     *
     * @param array<int, array{lat: float, lng: float, timestamp: string}> $points
     */
    public function totalDistanceMeters(array $points): float
    {
        $total = 0.0;
        for ($i = 1; $i < count($points); $i++) {
            $prev = $points[$i - 1];
            $curr = $points[$i];

            $segmentMeters = $this->haversineMeters($prev['lat'], $prev['lng'], $curr['lat'], $curr['lng']);
            $segmentSeconds = abs(
                Carbon::parse($curr['timestamp'])->diffInMilliseconds(Carbon::parse($prev['timestamp']))
            ) / 1000;

            if ($this->isGpsNoise($segmentMeters, $segmentSeconds, isFirstSegment: $i === 1)) {
                continue;
            }

            $total += $segmentMeters;
        }

        return $total;
    }

    /**
     * Rejects a GPS segment as noise rather than genuine movement:
     * - The very first segment right after a session starts, if it's a
     *   huge jump in under 5 seconds.
     * - Any segment anywhere implying an inhuman walking/running speed.
     */
    private function isGpsNoise(float $segmentMeters, float $segmentSeconds, bool $isFirstSegment): bool
    {
        if ($isFirstSegment && $segmentMeters > self::FIRST_FIX_JUMP_METERS && $segmentSeconds < self::FIRST_FIX_JUMP_SECONDS) {
            return true;
        }

        $speedKmh = $segmentSeconds > 0 ? ($segmentMeters / $segmentSeconds) * 3.6 : INF;

        return $speedKmh > self::MAX_WALKING_SPEED_KMH;
    }

    private function haversineMeters(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return self::EARTH_RADIUS_METERS * $c;
    }

    /**
     * @param array<int, array{lat: float, lng: float}> $points
     */
    public function encodePolyline(array $points): string
    {
        $encoded = '';
        $prevLat = 0;
        $prevLng = 0;

        foreach ($points as $point) {
            $lat = (int) round($point['lat'] * 1e5);
            $lng = (int) round($point['lng'] * 1e5);

            $encoded .= $this->encodeSignedNumber($lat - $prevLat);
            $encoded .= $this->encodeSignedNumber($lng - $prevLng);

            $prevLat = $lat;
            $prevLng = $lng;
        }

        return $encoded;
    }

    private function encodeSignedNumber(int $num): string
    {
        $shifted = $num << 1;
        if ($num < 0) {
            $shifted = ~$shifted;
        }

        return $this->encodeUnsignedNumber($shifted);
    }

    private function encodeUnsignedNumber(int $num): string
    {
        $encoded = '';
        while ($num >= 0x20) {
            $encoded .= chr((0x20 | ($num & 0x1f)) + 63);
            $num >>= 5;
        }
        $encoded .= chr($num + 63);

        return $encoded;
    }
}
