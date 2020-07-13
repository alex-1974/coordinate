/** TODO: **/
module coordinate.utm;

debug import std.stdio;



/** **/
struct UTM {
  char hemisphere; /// Hemisphere
  uint zone;       /// UTM zone
  real easting;   /// Easting
  real northing;  /// Northing
  //string datum;
  this(char hemisphere, uint zone, real easting, real northing) {
    import std.uni: toLower;
    this.hemisphere = cast(char)(hemisphere.toLower);
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
    import std.uni: toLower;
    assert(hemisphere.toLower == 'n' || hemisphere.toLower == 's', "Wrong hemisphere!");
    assert(0 < zone && zone <= 60, "Zone number out of range!");
  }
}
/** **/
auto utm (char hemisphere, uint zone, real easting, real northing) {
  return UTM(hemisphere, zone, easting, northing);
}

const char[20] mgrsBands = ['c','d','e','f','g','h','j','k','l','m','n','p','q','r','s','t','u','v','w','x'];

/** **/
struct MGRS {
  char band;      /// Latitude band
  uint zone;       /// UTM zone
  real easting;   /// Easting
  real northing;  /// Northing
  this(char band, uint zone, real easting, real northing) {
    import std.uni: toLower;
    this.band = cast(char)(band.toLower);
    this.zone = zone;
    this.easting = easting;
    this.northing = northing;
  }
  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    import std.uni: toUpper;
    sink(this.band.toUpper.to!string ~ " " ~ this.zone.to!string ~ " " ~ this.easting.to!string ~ " " ~ this.northing.to!string);
  }
  invariant {
    import std.algorithm;
    //assert (mgrsBands.canFind(band), "Latitude band out of range!");
  }
}
