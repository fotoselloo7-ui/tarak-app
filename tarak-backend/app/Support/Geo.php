<?php

namespace App\Support;

use Illuminate\Http\Request;

/** Small great-circle helpers for "nearest provider" sorting and distance filters. */
final class Geo
{
    private const EARTH_RADIUS_KM = 6371.0;

    /** Distance between two points in km, or null when either point is unknown. */
    public static function distanceKm(mixed $lat1, mixed $lng1, mixed $lat2, mixed $lng2): ?float
    {
        if ($lat1 === null || $lng1 === null || $lat2 === null || $lng2 === null) {
            return null;
        }
        [$lat1, $lng1, $lat2, $lng2] = [(float) $lat1, (float) $lng1, (float) $lat2, (float) $lng2];

        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return round(self::EARTH_RADIUS_KM * 2 * asin(min(1.0, sqrt($a))), 1);
    }

    /**
     * The customer's position from `lat` / `lng` query parameters (default address or device
     * location, chosen by the client). Out-of-range or missing values mean "unknown".
     *
     * @return array{0: float, 1: float}|null
     */
    public static function origin(Request $request): ?array
    {
        $lat = $request->query('lat');
        $lng = $request->query('lng');
        if (!is_numeric($lat) || !is_numeric($lng)) {
            return null;
        }
        $lat = (float) $lat;
        $lng = (float) $lng;
        if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180 || ($lat == 0.0 && $lng == 0.0)) {
            return null;
        }

        return [$lat, $lng];
    }

    /** `max_distance_km` query parameter: a positive number up to 500, otherwise no limit. */
    public static function maxDistance(Request $request): ?float
    {
        $max = $request->query('max_distance_km');

        return is_numeric($max) && (float) $max > 0 ? min((float) $max, 500.0) : null;
    }

    /**
     * SQL expression (and bindings) for the distance in km from a point to a lat/lng column pair.
     *
     * @param array{0: float, 1: float} $origin
     * @return array{0: string, 1: array<int, float>}
     */
    public static function sql(array $origin, string $latColumn, string $lngColumn): array
    {
        $expr = '(' . self::EARTH_RADIUS_KM . ' * 2 * ASIN(SQRT(POWER(SIN(RADIANS(' . $latColumn . ' - ?) / 2), 2)'
            . ' + COS(RADIANS(?)) * COS(RADIANS(' . $latColumn . ')) * POWER(SIN(RADIANS(' . $lngColumn . ' - ?) / 2), 2))))';

        return [$expr, [$origin[0], $origin[0], $origin[1]]];
    }
}
