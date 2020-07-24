/** **/
module coordinate.mathematics;

/** **/
T toRadians (T) (T deg) pure nothrow @safe @nogc { import std.math: PI; return deg*PI/180.0; }
/** **/
T toDegree (T) (T rad) pure nothrow @safe @nogc { import std.math: PI; return rad*180.0/PI; }

/** Constrain degrees to range 0..360 (e.g. for bearings); -1 => 359, 361 => 1.

  Params: degrees
  Returns: Degrees within range 0..360.
**/
T wrap360 (T) (T degrees) pure nothrow @safe @nogc
out (result) { import mathematics.floating; assert (0.ltE(result) && result.ltE(360)); }
do {
  import std.conv;
  if (0.0 <= degrees && degrees <= 360.0) return degrees; // avoid rounding due to arithmetic ops if within range
  return cast(T)((degrees % 360.0 + 360.0) % 360.0); // sawtooth wave p:360, a:360
}
/** **/
unittest {
  assert(240.wrap360 == 240);
}
/** Constrain degrees to range -180..+180 (e.g. for longitude); -181 => 179, 181 => -179.

  Params: degrees
  Returns: Degrees within range -180..+180.
**/
T wrap180 (T) (T degrees) pure nothrow @safe @nogc
out (result) { import mathematics.floating; assert ((-180).ltE(result) && result.ltE(180)); }
do {
  //import std.math;
  if (-180.0 <= degrees && degrees <= 180.0) return degrees; // avoid rounding due to arithmetic ops if within range
  return cast(T)((degrees + 540.0) % 360.0 - 180.0); // sawtooth wave p:180, a:±180
}
/** **/
unittest {
  assert(170.wrap180 == 170);
}
/** Constrain degrees to range -90..+90 (e.g. for latitude); -91 => -89, 91 => 89.

  Params: degrees
  Returns: Degrees within range -90..+90.
**/
T wrap90 (T) (T degrees) pure nothrow @safe @nogc
out (result) { import mathematics.floating; assert ((-90).ltE(result) && result.ltE(90)); }
do {
  import std.math;
  if (-90.0 <= degrees && degrees <= 90.0) return degrees; // avoid rounding due to arithmetic ops if within range
  return cast(T)((degrees % 360.0 + 270.0) % 360.0 - 180.0).abs - cast(T)90.0; // triangle wave p:360 a:±90 TODO: fix e.g. -315°
}
/** **/
unittest {
  assert(45.wrap90 == 45);
}

/** Round to given digits after comma **/
T roundTo (T) (T coord, int dec) {
  import std.math: pow, round;
  return round(coord * 10.pow(dec)) / 10.pow(dec);
}
unittest {
  import std.stdio;
  writefln("round to 5 %s", 1.123456789.roundTo(5));
}
