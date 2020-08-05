/** Defines an Universal-Transverse Mercator (*UTM*) coordinate type

  Universal Transverse Mercator is a projected coordinate system,
  which is a type of plane rectangular coordinate system (also called Cartesian coordinate system).

  ## Features ##

  ### Form ###
    - Conformal
    - Accurate reproduction of small shapes
    - Minimal distortion of larger shapes within the zone
  ### Area ###
  Minimal distortion within each UTM zone
  ### Direction ###
  Local angles are real.
  ### Distance ###
  The scale is constant along the mean meridian and has a scale factor of 0.9996
  to reduce lateral distortion within each zone.
  With this scale factor, lines 180 km east and west and parallel to the mid-meridian
  have a scale factor of 1.


*/
module coordinate.utm;

import std.traits: isSomeChar, isNumeric, isFloatingPoint;
public import coordinate.datums;
import coordinate.utils: UTMType, AltitudeType, AccuracyType;
import coordinate.exceptions: UTMException, MGRSException;
debug import std.stdio;

/** Latitude bands C..X (excluding I and O) 8° each, covering 80°S to 84°N **/
package const char[21] mgrsBands = "CDEFGHJKLMNPQRSTUVWXX".dup; // X is repeated for 80-84°N

/** 100km grid square column A..Z (excluding I and O) letters repeat every third zone **/
package const char[][3] e100kLetters = [ "ABCDEFGH".dup, "JKLMNPQR".dup, "STUVWXYZ".dup ];

/** 100km grid square row A..V (excluding I and O) letters repeat every other zone **/
package const char[][2] n100kLetters = [ "ABCDEFGHJKLMNPQRSTUV".dup, "FGHJKLMNPQRSTUVABCDE".dup ];


package const real falseEasting = 500e3;    /// false easting
package const real falseNorthing = 10000e3; /// false northing

/** **/
struct UTM {
  import coordinate.utils: ExtendCoordinate, ExtendDatum;
  char hemisphere; /// Hemisphere
  uint zone;       /// UTM zone
  UTMType easting;   /// Easting
  UTMType northing;  /// Northing
  mixin ExtendCoordinate; ///
  mixin ExtendDatum; ///
  /** Constructor

    Params:
      zone = UTM zone
      hemisphere = Hemisphere (N or S)
      easting = East of in meters
      northing = North of in meters
      altitude = Altitude in meters
      accuracy = Accuracy in meters
      altitudeAccuracy = Accuracy of altitude in meters
      datum = Datum of projection
  **/
  this (uint zone, char hemisphere, UTMType easting, UTMType northing, AltitudeType altitude, Datum datum = defaultDatum) {
    import std.uni: toUpper;
    this(zone, hemisphere, easting, northing, altitude, AccuracyType.nan, AccuracyType.nan, datum);
  }
  /** ditto **/
  this (uint zone, char hemisphere, UTMType easting, UTMType northing,
        AltitudeType altitude, AccuracyType accuracy, AccuracyType altitudeAccuracy, Datum datum = defaultDatum) {
    import std.uni: toUpper;
    this.hemisphere = cast(char)(hemisphere.toUpper);
    this.zone = zone;
    this.easting = easting;
    this.northing = northing;
    this.altitude = altitude;
    this.accuracy = accuracy;
    this.altitudeAccuracy = altitudeAccuracy;
    this.datum = datum;
  }
  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    import std.uni: toUpper;
    sink(this.zone.to!string ~ " " ~ this.hemisphere.toUpper.to!string ~ " " ~ this.easting.to!string ~ " " ~ this.northing.to!string);
  }
  invariant {
    import std.uni: toUpper;
    assert(hemisphere.toUpper == 'N' || hemisphere.toUpper == 'S', "Wrong hemisphere!");
    assert(0 < zone && zone <= 60, "Zone number out of range!");
  }
}
/** **/
auto band (UTM utm) {
  /// TODO: compute and return latitude band
}

/** Low-level api

  Params:
    zone = UTM zone
    band = UTM band
    hemisphere = Hemisphere (N or S)
    easting = East of in meters
    northing = North of in meters
    altitude = Altitude in meters
    accuracy = Accuracy in meters
    altitudeAccuracy = Accuracy of altitude in meters
    datum = Datum of projection
  Returns: UTM
**/
auto utm (alias string Type, T, U, V, X, Y) (T zone, U band, V easting, V northing,
          X altitude, Y accuracy, Y altitudeAccuracy, Datum datum, string file = __FILE__, size_t line = __LINE__)
          if (Type == "band" && isSomeChar!U && isNumeric!T && isNumeric!V && isNumeric!X && isNumeric!Y) {
  const char hemisphere = (band.toUpper >= 'N') ? 'N' : 'S';
  return utm!"hemisphere"(zone, hemisphere, easting, northing,
                          altitude, accuracy, altitudeAccuracy,
                          datum, file, line);
}
/** ditto **/
auto utm (alias string Type = "hemisphere", T, U, V, X, Y) (T zone, U hemisphere, V easting, V northing,
          X altitude, Y accuracy, Y altitudeAccuracy, Datum datum = defaultDatum, string file = __FILE__, size_t line = __LINE__)
          if (Type != "band" && isSomeChar!U && isNumeric!T && isNumeric!V && isNumeric!X && isNumeric!Y) {
  import std.exception: enforce;
  import std.math: isNaN;
  import std.uni: toUpper;
  import mathematics.floating: ltE;
  static if (Type != "hemisphere")  static assert(0, "Type not valid!");
  enforce!UTMException(hemisphere.toUpper == 'N' || hemisphere.toUpper == 'S', "Wrong hemisphere [N, S]!", file, line);
  enforce!UTMException(0 <= zone && zone <= 60, "Zone number out of range [0..60]!", file, line);
  return UTM(cast(uint)zone, cast(char)hemisphere.toUpper, cast(UTMType)easting, cast(UTMType)northing,
          cast(AltitudeType)altitude, cast(AccuracyType)accuracy, cast(AccuracyType)altitudeAccuracy, datum);
}
/** ditto **/
auto utm (alias string Type, T, U, V) (T zone, U band, V easting, V northing, string file = __FILE__, size_t line = __LINE__)
  if (Type == "band" && isSomeChar!U && isNumeric!T && isNumeric!V) {
  import std.uni: toUpper;
  const char hemisphere = (band.toUpper >= 'N') ? 'N' : 'S';
  return utm!"hemisphere"(zone, hemisphere, easting, northing, file, line);
}
/** ditto **/
auto utm (alias string Type = "hemisphere", T,U,V) (T zone, U hemisphere, V easting, V northing, string file = __FILE__, size_t line = __LINE__)
  if (Type != "band" && isSomeChar!U && isNumeric!T && isNumeric!V) {
  static if (Type != "hemisphere")  static assert(0, "Type not valid!");
  return utm(zone, hemisphere, easting, northing, AltitudeType.nan, AccuracyType.nan, AccuracyType.nan, defaultDatum, file, line);
}
/** **/
unittest {
  auto london = utm(30, 'N', 699327.190, 5710155.503);         // call with hemisphere (default)
  auto berlin = utm!"band"(33, 'U', 390676.879, 5819766.930);  // call with band
}
/**

    Params:
      coord = UTM coordinates
**/
auto utm (alias string Type) (string coord, string file = __FILE__, size_t line = __LINE__)
  if (Type == "band") {
  import std.uni: toUpper;
  import std.exception: enforce;
  uint zone; char band; UTMType easting, northing;
  coord.parseUTM(zone, band, easting, northing, file, line);
  const char hemisphere = (band.toUpper >= 'N') ? 'N' : 'S';
  return utm(zone, hemisphere, easting, northing, file, line);
}
/** ditto **/
UTM utm (alias string Type = "hemisphere") (string coord, string file = __FILE__, size_t line = __LINE__)
  if (Type != "band") {
  static if (Type != "hemisphere")  static assert(0, "Type not valid!");
  uint zone; char hemisphere; UTMType easting, northing;
  coord.parseUTM(zone, hemisphere, easting, northing, file, line);
  return utm(zone, hemisphere, easting, northing, file, line);
}
/** **/
unittest {
  //auto capetown = utm!"band"("10T 384085.536 4480405.310");
  auto sydney = utm("56S 335003.521 6252510.623");
}

/** **/
private void parseUTM (string coord, out uint zone, out char hemisphere, out UTMType easting, out UTMType northing, string file = __FILE__, size_t line = __LINE__) {
  import std.regex: ctRegex, matchFirst;
  import std.string: strip;
  import std.conv: to;
  import std.algorithm: substitute;
  import std.uni: asUpperCase;
  import std.utf: byCodeUnit;
  import std.range;
  auto ct = ctRegex!(`([\d]{1,2})[\s]*([ns]?)[\s]*([\d]+(?:[.,]?[\d]+))[\s]([\d]+(?:[.,]?[\d]+))`, "i");
  // m[1]: zone, m[2]: hemisphere, m[3]: easting, m[4]: northing
  auto m = matchFirst(coord.strip, ct);
  if (m.empty) throw new UTMException("Failed to parse coordinates!", file, line);
  zone = m[1].to!uint;
  hemisphere = m[2].asUpperCase.byCodeUnit.front.to!char; // hemisphere or band
  easting = m[3].strip.substitute(',', '.').to!UTMType; // easting
  northing = m[4].strip.substitute(',', '.').to!UTMType; // northing
}

/** Military Grid Reference System (MGRS/NATO or UTMRef)

  MGRS grid references provides geocoordinate references, covering the entire globe, based on UTM projections.
  MGRS references comprise a grid zone designator, a 100km square identification, and an easting
  and northing inside this grid (in metres); e.g. ‘31U DQ 48251 11932’.
**/
struct MGRS {
  import coordinate.utils: ExtendCoordinate, ExtendDatum;
  uint zone;      /// 6° UTM longitudinal zone (1..60 covering 180°W..180°E)
  char band;      /// 8° latitudinal band (C..X covering 80°S..84°N)
  char[2] grid;   /// 100km grid square ([east, north])
  UTMType easting;   /// Easting in metres within 100km grid square
  UTMType northing;  /// Northing in metres within 100km grid square
  mixin ExtendCoordinate; ///
  mixin ExtendDatum; ///
  /** Constructor

    Params:
      zone = Longitudinal zone (1..60)
      band = Latidudinal band (C..X)
      grid = MGRS grid [east, north]
      easting = East of in meters
      northing = North of in meters
      altitude = Altitude in meters
      accuracy = Accuracy in meters
      altitudeAccuracy = Accuracy of altitude in meters
      datum = Datum of projection
  **/
  this(uint zone, char band, string grid, UTMType easting, UTMType northing, AltitudeType altitude, AccuracyType accuracy, AccuracyType altitudeAccuracy, Datum datum = defaultDatum) {
    import std.uni: toUpper;
    this.zone = zone;
    this.band = cast(char)(band.toUpper);
    this.grid = cast(char[])(grid[].toUpper);
    this.easting = easting;
    this.northing = northing;
    this.accuracy = accuracy;
    this.altitude = altitude;
    this.altitudeAccuracy = altitudeAccuracy;
    this.datum = datum;
  }
  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    import std.uni: toUpper;
    sink(this.zone.to!string ~ this.band.toUpper.to!string ~ " ");
    sink(this.grid[0].to!string ~ this.grid[1].to!string ~ " ");
    sink(this.easting.to!string ~ " " ~ this.northing.to!string);
  }
  invariant {
    import std.algorithm;
    //assert (mgrsBands.canFind(band), "Latitude band out of range!");
  }
}
/**

    Params:
      zone = Longitudinal zone (1..60)
      band = Latidudinal band (C..X)
      grid = MGRS grid [east, north]
      easting = East of in meters
      northing = North of in meters
      altitude = Altitude in meters
      accuracy = Accuracy in meters
      altitudeAccuracy = Accuracy of altitude in meters
      datum = Datum of projection
**/
MGRS mgrs (uint zone, char band, string grid, UTMType easting, UTMType northing,
           AltitudeType altitude, AccuracyType accuracy, AccuracyType altitudeAccuracy,
           Datum datum, string file = __FILE__, size_t line = __LINE__) {
  return MGRS(zone, band, grid, easting, northing, altitude, accuracy, altitudeAccuracy, datum);
}
/** ditto **/
MGRS mgrs (uint zone, char band, string grid, UTMType easting, UTMType northing,
           string file = __FILE__, size_t line = __LINE__) {
  return mgrs(zone, band, grid, easting, northing, AltitudeType.nan, AccuracyType.nan, AccuracyType.nan, Datum.wgs84);
}
/** **/
unittest {
  writefln ("mgrs %s", mgrs(15, 'S', "WC", 80817, 51205));
}
/**

    Params:
      coord = MGRS coordinates
**/
MGRS mgrs (string coord, string file = __FILE__, size_t line = __LINE__) {
  import std.regex: ctRegex, matchFirst;
  import std.string: strip;
  import std.conv: to;
  import std.algorithm: substitute, count, splitter;
  import std.uni: asUpperCase;
  import std.utf: byCodeUnit;
  import std.range;
  // m[1]: zone, m[2]: band, m[3]: grid, m[4]: easting and northing
  auto ct = ctRegex!(`([\d]{1,2})[\s]*([a-z])[\s]*([a-z]{2})[\s]*([\d,.\s]*)`, "i");
  auto m = matchFirst(coord.strip, ct);
  if (m.empty) throw new MGRSException("Failed to parse coordinates!", file, line);
  const uint zone = m[1].to!uint;
  const char band = m[2].asUpperCase.byCodeUnit.front.to!char;
  const string grid = m[3];
  string[2] s;
  auto c = count(m[4], ',');
  switch (c) {
    case 0: goto case 2;                          // if e n
    case 1: s = m[4].splitter(",").array; break;  // if e,n
    case 2: {                                     // if e,e n,n
      auto a = m[4].splitter(" ").array;
      s = [a[0..a.length/2].join(' '),a[a.length/2..$].join(' ')];
      break;
    }
    case 3: {                                     // if e,e, n,n
      string[4] a = m[4].splitter(",").array;
      s = [a[0..2].join('.'),a[2..4].join('.')];
      break;
    }
    default: break;
  }
  // if we have no seperator between easting and northing (eg. 15SWC8081751205)
  if (!s[0].length) {
    s[0] = s[1][0..s[1].length/2];
    s[1] = s[1][s[1].length/2..$];
  }
  const real easting = s[0].strip.substitute(',', '.').to!UTMType;
  const real northing = s[1].strip.substitute(',', '.').to!UTMType;
  return mgrs(zone, band, grid, easting, northing, file, line);
}
/** **/
unittest {
  writefln ("mgrs %s", mgrs("15SWC8081751205"));
}
