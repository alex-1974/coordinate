/** Defines a geographic coordinate type with latitude and Longitude

## Latitude ##
The latitude (denoted by the Greek letter phi *ϕ*) specifies the north–south position of a point on the Earth's surface.
Lines of constant latitude, or *parallels*, run east–west as circles parallel to the equator.
> Latus is latin for *side*. Latitude lines go from side to side, east to west -- Mnemonic

## Longitude ##
The longitude (denoted by the Greek letter lambda *λ*) specifies the east–west position of a point on the Earth's surface.
Lines of constant longitude, or *meridians*, running from pole to pole.

## Precision of latitude in decimal degree ##

  The radius of the semi-major axis of the Earth at the equator is 6,378,137.0 m resulting in a circumference of 40,075,016.7 m.
  The equator is divided into 360 degrees of longitude, so each degree at the equator represents 111,319.5 m or approximately 111.32 km.

  | dd.ddddd° | decimal places  | dd°mm.mm' | dd°mm'ss,ss" | Distance on equator | Resolution |
  |:----------|:---------------:|:-----------|:-------------|:--------------------|:-------------------|
  | 1° | 0 | 1° | 1° | 111.12 km | country or large region |
  | 0.1° | 1 | 0°06' | 0°06' | 11.112 km | large city or district |
  | 0.01° | 2 | 0°00,6' | 0°00'36" | 1.111 km | town or village |
  | 0.001° | 3 | 0°00.06' | 0°00'03.6" | 111.12 m | neighborhood, street |
  | 0.0001° | 4 | 0°00.006' | 0°00'00.36" | 11.112 m | individual street, land parcel |
  | 0.00001° | 5 | 0°00.0006' | 0°00'00.04" | 1.1112 m | individual trees, door entrance |
  | 0.000001° | 6 | 0°00.00006' | 0°00'00.004" | 11.11 cm | individual humans |
  | 0.0000001° | 7 | 0°00.000006' | 0°00'00.0004" | 1.11 cm | practical limit of survey |
  | 0.00000001° | 8 | 0°00.0000006' | 0°00'00.00004" | 1.11 mm | motion of tectonic plates, the width of paperclip wire. |


 ## Precision of longitude ##

  The precision of longitudes is dependent on the latitude. The higher the latitude, the closer the meridians are to each other.
  The value in meters is to be multiplied by the cosine of the latitude.

**/
module coordinate.latlon;

import std.traits: isNumeric, isFloatingPoint;
debug import std.stdio;
public import coordinate.datums;
import coordinate.exceptions: CoordException;
import coordinate.utils: AltitudeType, AccuracyType;


static const dchar degChar = 0x00B0;
static const dchar minChar = 0x2032;
static const dchar secChar = 0x2033;

/** Defines latitude **/
struct LAT {
  real lat; /// Latitude
  alias lat this;
  /** Constructor **/
  this (T) (T lat) { this.lat = lat; }
  /** **/
  auto opBinary (string op) (const LAT rhs) {
    import coordinate.mathematics: wrap90;
    return mixin("LAT( (this.lat "~op~" rhs.lat).wrap90 )");
  }
  invariant { import mathematics.floating: ltE; assert((-90).ltE(this.lat) && this.lat.ltE(90), "Latitude out of bounds [-90;+90]!"); }
}
/** **/
unittest {
  auto lat1 = LAT(-85); auto lat2 = LAT(15);
  writefln ("%s + %s = %s", lat1, lat2, lat1 - lat2);
}
/** Defines longitude **/
struct LON {
  real lon; /// Longitude
  alias lon this;
  /** Constructor **/
  this (T) (T lon) { this.lon = lon; }
  /** **/
  auto opBinary (string op) (const LON rhs) {
    import coordinate.mathematics: wrap180;
    return mixin("LON( (this.lon "~op~" rhs.lon).wrap180 )");
  }
  invariant { import mathematics.floating: ltE; assert((-180).ltE(this.lon) && this.lon.ltE(180), "Longitude out of bounds [-180;+180]!"); }
}
/** **/
unittest {
  auto lon1 = LON(-85); auto lon2 = LON(15);
  writefln ("%s + %s = %s", lon1, lon2, lon1 - lon2);
}
/** Defines geographic coordinates **/
struct GEO {
  import coordinate.utils;
  LAT lat;                          /// [Latitude](#Lat)
  LON lon;                          /// [Longitude](#Lon)
  mixin ExtendCoordinate; ///
  mixin ExtendDatum; ///
  /** **/
  this(LAT lat, LON lon, AltitudeType altitude, AccuracyType accuracy, AccuracyType altitudeAccuracy, Datum datum) {
    this.lat = lat;
    this.lon = lon;
    this.altitude = altitude;
    this.accuracy = accuracy;
    this.altitudeAccuracy = altitudeAccuracy;
    this.datum = datum;
  }
  invariant {
    import std.math: isNaN;
    import mathematics.floating: ltE;
    assert ((-90.0).ltE(lat) && lat.ltE(90.0), "Latitude out of bounds [-90;+90]!");
    assert ((-180.0).ltE(lon) && lon.ltE(180.0), "Longitude out of bounds [-180;+180]!");
    assert (accuracy.isNaN || 0.ltE(accuracy), "Accuracy out of range!");
    assert (altitudeAccuracy.isNaN || 0.ltE(altitudeAccuracy), "Altitude accuracy out of range!");
  }
  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    sink("Lat " ~ this.lat.to!string ~ degChar.to!string ~ " Lon " ~ this.lon.to!string ~ degChar.to!string);
  }
}

/**  Low-level convenience function defining [Geographic](#Geo) type

    Params:
      lat = Latitude in decimal degree
      lon = Longitude in decimal degree
      altitude = Altitude in meters
      accuracy = Accuracy of Lat/Lon in meters
      altitudeAccuracy = Altitude accuracy in meters
      datum = Datum (defaults to World Geodetic System 1984)
    Returns: [Geo] type
    Throws: [CoordException](exceptions.html#CoordException) if latitude/longitude or accuracies are out of bounds.
**/
auto geo (T, U) (T lat, T lon, U altitude, AccuracyType accuracy, AccuracyType altitudeAccuracy, Datum datum = defaultDatum, string file = __FILE__, size_t line = __LINE__)
if (isFloatingPoint!T && isNumeric!U)
{
  import std.exception: enforce;
  import std.math: isNaN;
  import mathematics.floating: ltE;
  enforce!CoordException((-90).ltE(lat) && lat.ltE(90), "Latitude out of bounds [-90;+90]!", file, line);
  enforce!CoordException((-180).ltE(lon) && lon.ltE(180), "Longitude out of bounds [-180;+180]!", file, line);
  enforce!CoordException(accuracy.isNaN || 0.ltE(accuracy), "Accuracy out of range!", file, line);
  enforce!CoordException(altitudeAccuracy.isNaN || 0.ltE(altitudeAccuracy), "Altitude accuracy out of range!", file, line);
  return GEO(LAT(lat), LON(lon), cast(AltitudeType)altitude, cast(AccuracyType)accuracy, cast(AccuracyType)altitudeAccuracy, datum);
}
/** **/
unittest {
  auto mpt = geo(-25.96553, 32.58322, 47, 0, 0);
}
/**  Convenience functions defining a [Geo] type given numerical values

    Params:
      lat = Latitude
      lon = Longitude
      coord = Array of Lat/Lon coordinates
      altitude = Altitude
    Returns: [Geo] type
    Throws: They call the low-level geo function, which throws a [CoordException](exceptions.html#CoordException) if latitude/longitude or accuracies are out of bounds.
**/
auto geo (T, U) (T lat, T lon, U altitude, string file = __FILE__, size_t line = __LINE__)
if (isNumeric!T && isNumeric!U)
{
  return geo(lat, lon, altitude, AccuracyType.nan, AccuracyType.nan, defaultDatum, file, line);
}
/** ditto **/
auto geo (T, U) (T[2] coord, U altitude, string file = __FILE__, size_t line = __LINE__)
if (isNumeric!T && isNumeric!U)
{
  return geo(coord[0], coord[1], altitude, file, line);
}
/** ditto **/
auto geo (T) (T lat, T lon, string file = __FILE__, size_t line = __LINE__)
if (isNumeric!T)
{
  return geo(lat, lon, AltitudeType.nan, file, line);
}
/** ditto **/
auto geo (T) (T[2] coord, string file = __FILE__, size_t line = __LINE__)
if (isNumeric!T)
{
  return geo(coord[0], coord[1], AltitudeType.nan, file, line);
}
/** **/
unittest {
  // with altitude
  auto vie = geo(48.20849, 16.37208, 151);
  auto cpt = geo([-33.92584, 18.42322], 5);
  // without altitude
  auto nrb = geo(-1.28333, 36.81667);
  auto bmk = geo([12.65, -8.0]);
}
/**  Convenience functions defining a [Geo] type given string values

    Params:
      lat = Latitude
      lon = Longitude
      coord = String of Lat/Lon coordinates
    Returns: [Geo] type
    Throws: [CoordException](exceptions.html#CoordException) if string can't be parsed.
**/
auto geo (string lat, string lon, string file = __FILE__, size_t line = __LINE__) {
  import std.math: isNaN;
  import std.exception: enforce;
  auto la = parseLatLon(lat);
  auto lo = parseLatLon(lon);
  enforce!CoordException(!la.isNaN && !lo.isNaN, "Failed to parse coordinates!", file, line);
  return geo(la, lo, file, line);
}
/** ditto **/
auto geo (string coord, string file = __FILE__, size_t line = __LINE__) {
  import std.exception: enforce;
  string[2] c = splitLatLon(coord);
  enforce!CoordException(c[0].length && c[1].length, "Failed to parse coordinates!", file, line);
  return geo(c[0], c[1], file, line);
}
/** **/
unittest {
  auto bnj = geo("13.453056,-16.5775");
  auto mrk = geo("31.635278°, -8.000278°");
  auto mpt = geo("N 14° 29.8586', W 4°11.9383'");
  auto lme = geo("6° 7′ 55″ N, 1° 13′ 22″ O");
}
unittest {
  import std.exception: assertThrown;
  assertThrown!CoordException(geo("abc"));
}
/** Helper function spliting string into latitude and longitude parts **/
protected auto splitLatLon (string coord) {
  import std.algorithm: count, splitter;
  import std.array;
  auto c = count(coord, ',');
  string[2] s;
  switch (c) {
    case 0: goto case 2;
    case 1: s = coord.splitter(",").array; break;
    case 2: {
      auto a = coord.splitter(" ").array;
      s = [a[0..a.length/2].join(' '),a[a.length/2..$].join(' ')];
      break;
    }
    case 3: {
      string[4] a = coord.splitter(",").array;
      s = [a[0..2].join('.'),a[2..4].join('.')];
      break;
    }
    default: break;
  }
  return s;

}
/** **/
unittest {
  splitLatLon("S 33.92584, O 18.42322");
  splitLatLon("33.92584 S, 18.42322 E");
  splitLatLon("S 33,92584, O 18,42322");
  splitLatLon("33,92584 S, 18,42322 E");
  splitLatLon("S 33,92584 E 18,42322");
  splitLatLon("33.92584 S 18.42322 E");
  splitLatLon("N 33 deg 9 min 25,84 sec S 18 deg 42 min 3,22 sec");
  splitLatLon("N 33 deg 9 min 25,84 sec, S 18 deg 42 min 3,22 sec");
  splitLatLon("N 33 deg 9 min 25.84 sec S 18 deg 42 min 3.22 sec");
}

/** Helper function parsing lat/lon string **/
protected auto parseLatLon (string coord) @safe  {
  import std.string: strip;
  import std.algorithm: map, canFind, filter, substitute;
  import std.uni: asLowerCase;
  import std.utf: byCodeUnit;
  import std.regex: ctRegex, matchFirst;
  import std.conv: to;
  import std.range: empty, array;
  real[] n;
  int sign = 1;
  string co;
  auto ct = ctRegex!(`(?:(\d{1,3})[^\d.,]+(\d{1,2})[^\d,.]+(\d{1,2}[.,]?\d*))|(?:(\d{1,3})[^\d.,]+(\d{1,2}[.,]?\d*))|(?:([+-]?\d{1,3}[.,]?\d*))`);
  auto c = coord.strip(", ").asLowerCase.byCodeUnit.array; // strip leading and trailing trash
  // if string starts with cardinale
  if (['n', 's', 'e', 'o', 'w'].canFind(c[0])) {
    if (['s', 'e', 'o'].canFind(c[0])) sign = -1;
    co = c[1..$].to!string;
  }
  // if string ends with cardinale
  else if (['n', 's', 'e', 'o', 'w'].canFind(c[$-1])) {
    if (['s', 'e', 'o'].canFind(c[$-1])) sign = -1;
    co = c[0..$-1].to!string.strip;
  }
  // TODO: check cardinale for sanity
  // TODO: check accuracy
  // if string has no cardinale
  else co = coord.strip;
  // get numbers out of string
  auto m = matchFirst(co, ct).filter!(a => !a.empty);
  if (!m.empty) {
    m.popFront;
    // substitute ',' by '.' and convert to real
    n = m.map!(a => a.substitute(',', '.').to!real).array;
    scope(failure) n.length = 0;
  }
  return (0 < n.length && n.length <= 3)? toDecimalDegree(n)*sign:real.nan;
}
/** **/
unittest {
  writefln ("south %s", parseLatLon(" S 33.92584, "));
  writefln ("south %s", parseLatLon(" 33.92584 S, "));
  writefln ("pos %s", parseLatLon(" 33.92584"));
  writefln ("neg %s", parseLatLon(" -33.92584"));
  writefln ("pos %s", parseLatLon(" 33°9.25''"));

  writefln ("pos %s", parseLatLon(" 33°9'25,84''"));
  writefln("failed parseLatLon %s", parseLatLon("abc"));
}
/** Converts *d° m.m'* and *d° m' s.s''* to decimal degree

  Params:
    deg = [d,m] or [d,m,s]
    d = degree
    m = minutes
    s = seconds
  Returns: Decimal degree
**/
auto toDecimalDegree (T) (T[] deg) pure nothrow @safe @nogc if (isNumeric!T) {
  switch (deg.length) {
    default: assert(0);
    case 1: return deg[0];
    case 2: return toDecimalDegree(deg[0], deg[1]);
    case 3: return toDecimalDegree(deg[0], deg[1], deg[2]);
  }
}
/** ditto **/
auto toDecimalDegree (T,U) (T d, U m) pure nothrow @safe @nogc if (isNumeric!T && isFloatingPoint!U) { return d + m/60.0; }
/** ditto **/
auto toDecimalDegree (T,U) (T d, T m, U s) pure nothrow @safe @nogc  if (isNumeric!T && isFloatingPoint!U ){ return toDecimalDegree(d, m+s/60.0); }
/** **/
unittest {
  writefln ("dd %s", toDecimalDegree(23,26,49.0));
}
/** **/
unittest {
  auto vie = geo(48.20849, 16.37208);
  auto cpt = geo(-33.92584, 18.42322);
}
/** **/
unittest {
  import std.exception: assertThrown;
  assertThrown!Exception(geo(95.0, 0.0));
  assertThrown!Exception(geo(0.0, 185.0));

}
