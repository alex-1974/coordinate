/** Defines an Universal-Transverse Mercator (*UTM*) coordinate type **/
module coordinate.utm;

import std.traits: isSomeChar, isNumeric, isFloatingPoint;
import coordinate.exceptions: UTMException, MGRSException;
debug import std.stdio;

//const char[20] mgrsBands = ['c','d','e','f','g','h','j','k','l','m','n','p','q','r','s','t','u','v','w','x'];

/** Latitude bands C..X 8° each, covering 80°S to 84°N **/
const char[21] mgrsBands = "CDEFGHJKLMNPQRSTUVWXX".dup; // X is repeated for 80-84°N

/** 100km grid square column (‘e’) letters repeat every third zone **/
const char[][3] e100kLetters = [ "ABCDEFGH".dup, "JKLMNPQR".dup, "STUVWXYZ".dup ];

/** 100km grid square row (‘n’) letters repeat every other zone **/
const char[][2] n100kLetters = [ "ABCDEFGHJKLMNPQRSTUV".dup, "FGHJKLMNPQRSTUVABCDE".dup ];


const real falseEasting = 500e3;
const real falseNorthing = 10000e3;

/** **/
struct UTM {
  char hemisphere; /// Hemisphere
  uint zone;       /// UTM zone
  real easting;   /// Easting
  real northing;  /// Northing
  //string datum;
  this (char hemisphere, uint zone, real easting, real northing) {
    import std.uni: toUpper;
    this.hemisphere = cast(char)(hemisphere.toUpper);
    this.zone = zone;
    this.easting = easting;
    this.northing = northing;
  }
  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    import std.uni: toUpper;
    sink(this.hemisphere.toUpper.to!string ~ " " ~ this.zone.to!string ~ " " ~ this.easting.to!string ~ " " ~ this.northing.to!string);
  }
  invariant {
    import std.uni: toUpper;
    assert(hemisphere.toUpper == 'N' || hemisphere.toUpper == 'S', "Wrong hemisphere!");
    assert(0 < zone && zone <= 60, "Zone number out of range!");
  }
}
/** **/
auto utm (T,U,V) (T hemisphere, U zone, V easting, V northing, string file = __FILE__, size_t line = __LINE__)
  if (isSomeChar!T && isNumeric!U && isNumeric!V) {
  import std.exception: enforce;
  import std.math: isNaN;
  import std.uni: toUpper;
  import mathematics.floating: ltE;
  enforce!UTMException(hemisphere.toUpper == 'N' || hemisphere.toUpper == 'S', "Wrong hemisphere [N, S]!");
  enforce!UTMException(0 <= zone && zone <= 60, "Zone number out of range [0..60]!");
  return UTM(cast(char)hemisphere.toUpper, cast(uint)zone, cast(real)easting, cast(real)northing);
}

/** **/
auto utm (string ccord, string file = __FILE__, size_t line = __LINE__) {

}
/** Military Grid Reference System (MGRS/NATO)

  MGRS grid references provides geocoordinate references, covering the entire globe, based on UTM projections.
  MGRS references comprise a grid zone designator, a 100km square identification, and an easting
  and northing (in metres); e.g. ‘31U DQ 48251 11932’.
**/
struct MGRS {
  uint zone;      /// 6° UTM longitudinal zone (1..60 covering 180°W..180°E)
  char band;      /// 8° latitudinal band (C..X covering 80°S..84°N)
  char[2] grid;   /// 100km grid square ([east, north])
  real easting;   /// Easting in metres within 100km grid square
  real northing;  /// Northing in metres within 100km grid square
  this(uint zone, char band, string grid, real easting, real northing) {
    import std.uni: toUpper;
    this.zone = zone;
    this.band = cast(char)(band.toUpper);
    this.grid = cast(char[])(grid[].toUpper);
    this.easting = easting;
    this.northing = northing;
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
