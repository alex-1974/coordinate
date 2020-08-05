/**

  A geocode system invented in 2008 by Gustavo Niemeyer.

  ## Digits and precision in km ##

  | length | lat bits | lon bits | lat error | lon error | km error |
  |--------|----------|----------|-----------|-----------|----------|
  | 1 | 2 | 3 | &plusmn; 23 | &plusmn; 23 | &plusmn; 2500 |
  | 2 | 5 | 5 | &plusmn; 2.8 | &plusmn; 5.6 | &plusmn; 630 |
  | 3 | 7 | 8 | &plusmn; 0.70 | &plusmn; 0.70 | &plusmn; 78 |
  | 4 | 10 | 10 | &plusmn; 0.087 | &plusmn; 0.18 | &plusmn; 20 |
  | 5 | 12 | 13 | &plusmn; 0.022 | &plusmn; 0.022 | &plusmn; 2.4 |
  | 6 | 15 | 15 | &plusmn; 0.0027 | &plusmn; 0.0055 | &plusmn; 0.61 |
  | 7 | 17 | 18 | &plusmn; 0.00068 | &plusmn; 0.00068 | &plusmn; 0.076 |
  | 8 | 20 | 20 | &plusmn; 0.000085 | &plusmn; 0.00017 | &plusmn; 0.019 |


**/
module coordinate.geohash;

//import coordinate: GEO;
import coordinate.utils: AltitudeType, AccuracyType;
import coordinate.datums: Datum, defaultDatum;
import coordinate.mathematics;
debug import std.stdio;


/** **/
struct GeoHash {
  import coordinate.utils;
  string geohash; ///
  mixin ExtendCoordinate; ///
  mixin ExtendDatum; ///
  this (string hash, AltitudeType altitude, AccuracyType accuracy, AccuracyType altitudeAccuracy, Datum datum) {
    this.geohash = hash;
    this.altitude = altitude;
    this.accuracy = accuracy;
    this.altitudeAccuracy = altitudeAccuracy;
    this.datum = datum;
  }
}
GeoHash geohash (string hash,
                 AltitudeType altitude, AccuracyType accuracy, AccuracyType altitudeAccuracy,
                 Datum datum) {
  return GeoHash(hash, altitude, accuracy, altitudeAccuracy, datum);
}
GeoHash geohash (string hash) {
  return geohash(hash, AltitudeType.nan, AccuracyType.nan, AccuracyType.nan, defaultDatum);
}


package const char[] base32 = "0123456789bcdefghjkmnpqrstuvwxyz"; // (geohash-specific) Base32 map

/** Encodes latitude/longitude to geohash.

  Either to specified precision or to automatically evaluated precision.
  Params:
    lat = Latitude
    lon = Longitude
    precision = Precision
  Returns: Returns a geohash string
**/
string encode (real lat, real lon, size_t precision = 0) {
  if (precision == 0) {
    for (size_t p = 1; p <= 12; p++) {
      const char[] hash = encode(lat, lon, p);
      const real[2] posn = decode(hash.idup);
      if (posn[0] == lat && posn[1] == lon) return hash.idup;
    }
    precision = 12; // set to maximum
  }

  ulong idx = 0; // index into base32 map;
  uint bit = 0; // each char holds 5 bits;
  bool evenBit = true;
  char[] geohash;

  real latMin = -90, latMax = 90;
  real lonMin = -180, lonMax = 180;

  while (geohash.length < precision) {
    if (evenBit) {
      // bisect E-W longitude
      const real lonMid = (lonMin + lonMax) / 2;
      if (lon >= lonMid) {
        idx = idx*2 + 1;
        lonMin = lonMid;
      }
      else {
        idx = idx*2;
        lonMax = lonMid;
      }
    }
    else {
      // bisect N-S latitude
      const real latMid = (latMin + latMax) / 2;
      if (lat >= latMid) {
        idx = idx*2 + 1;
        latMin = latMid;
      }
      else {
        idx = idx*2;
        latMax = latMid;
      }
    }
    evenBit = !evenBit;

    if (++bit == 5) {
      // 5 bits gives us a character: append it and start over
      geohash ~= base32[idx];
      bit = 0;
      idx = 0;
    }
  }
  return geohash.idup;
}
/** **/
unittest {
  writefln ("encode geohash %s", encode(52.205, 0.119));
}

/** Decode geohash to latitude/longitude

    Location is approximate centre of geohash cell.
**/
real[2] decode (string geohash) {
  const real[4] bound = bounds(geohash);
  // now determine the centre of the cell
  const real latMin = bound[0], lonMin = bound[1];
  const real latMax = bound[2], lonMax = bound[3];

  // cell centre
  real lat = (latMin + latMax) / 2;
  real lon = (lonMin + lonMax) / 2;

  return [lat, lon];
}
unittest {
  writefln ("decode geohash %s", decode("u120fxw"));
}
/** Returns SW/NE latitude/longitude bounds of specified geohash. **/
private auto bounds (string geohash) {
  import std.string: indexOf;
  import std.uni: asLowerCase;
  import std.array;
  int evenBit = true;
  real latMin = -90, latMax = 90;
  real lonMin = -180, lonMax = 180;

  for (uint i = 0; i < geohash.length; i++) {
    const char chr = cast(char)(geohash.asLowerCase.array[i]);
    auto idx = cast(int)base32.indexOf(chr);
    for (byte n = 4; n >= 0; n--) {
      auto bitN = idx >> n & 1;
      if (evenBit) {
        // longitude
        const real lonMid = (lonMin+lonMax) / 2;
        if (bitN == 1) {
          lonMin = lonMid;
        }
        else {
          lonMax = lonMid;
        }
      }
      else {
        // latitude
        const real latMid = (latMin + latMax) / 2;
        if (bitN == 1) {
          latMin = latMid;
        }
        else {
          latMax = latMid;
        }
      }
      evenBit = !evenBit;
    }
  }
  const real[4] bounds = [latMin, lonMin, latMax, lonMax];
  return bounds;
}
