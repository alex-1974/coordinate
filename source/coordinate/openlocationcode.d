/** TODO

  | Code length | Block size | Approximately |
  |-------------|------------|---------------|
  | 2 | 20° | 2200 km |
  | 4 | 1° | 110 km |
  | 6 | 0.05° (3') | 5.5 km |
  | 8 | 0.0025° (9') | 275 m |
  | + | | |
  | 10 | 0.000125° (0.45') | 14 m |
  | 11 | | 3.5 m |

  See: https://github.com/google/open-location-code/blob/master/cpp/openlocationcode.cc
**/
module coordinate.openlocationcode;
// also called plus code
import coordinate.mathematics;
import coordinate: GEO;
import coordinate.utils: AltitudeType, AccuracyType, defaultDatum;
import std.math: log, floor, pow;
debug import std.stdio;

enum char separator = '+';
enum char padding = '0';
static immutable char[20] alphabet = "23456789CFGHJMPQRVWX";
enum encodingBase = alphabet.length;
enum uint maxDigitCount = 15;
enum uint pairCodeLength = 10;
enum uint gridCodeLength = maxDigitCount - pairCodeLength;
enum uint gridColumns = 4;
enum uint gridRows = encodingBase / gridColumns;
enum uint separatorPosition = 8;
// Work out the encoding base exponent necessary to represent 360 degrees.
enum size_t initialExponent = cast(size_t)((360.log / encodingBase.log).floor);
// Work out the enclosing resolution (in degrees) for the grid algorithm.
enum double gridSizeDegree = 1 / (encodingBase).pow(pairCodeLength / 2 - (initialExponent + 1));
// Inverse (1/) of the precision of the final pair digits in degrees. (20^3)
enum size_t pairPrecisionInverse = 8000;
// Inverse (1/) of the precision of the final grid digits in degrees.
// (Latitude and longitude are different.)
enum size_t gridLatPrecisionInverse = pairPrecisionInverse * gridRows.pow(gridCodeLength);
enum size_t gridLonPrecisionInverse = pairPrecisionInverse * gridColumns.pow(gridCodeLength);
// Latitude bounds are -kLatitudeMaxDegrees degrees and +kLatitudeMaxDegrees
// degrees which we transpose to 0 and 180 degrees.
enum double latMaxDegrees = 90.0;
enum double lonMaxDegrees = 180.0;
// Lookup table of the alphabet positions of characters 'C' through 'X',
// inclusive. A value of -1 means the character isn't part of the alphabet.
enum int['X' - 'C' + 1] positionLUT = [8,  -1, -1, 9,  10, 11, -1, 12,
                                         -1, -1, 13, -1, -1, 14, 15, 16,
                                         -1, -1, -1, 17, 18, 19];

/** Raises a number to an exponent, handling negative exponents. **/
private double powNeg (double base, double exponent) {
  if (exponent == 0.0)
    return 1.0;
  else if (exponent > 0.0)
    return base.pow(exponent);
  return 1.0 / base.pow(-exponent);
}
unittest {
  assert(10.powNeg(0) == 1);
  assert(10.powNeg(2) == 100);
  assert(10.powNeg(-2) == 0.01);
}

/** Compute the latitude precision value for a given code length. Lengths <= 10
    have the same precision for latitude and longitude, but lengths > 10 have
    different precisions due to the grid method having fewer columns than rows.
**/
private double computePrecisionForLength (size_t codeLength) {
  if (codeLength <= 10)
    return powNeg(encodingBase, ((codeLength / -2.0) + 2.0).floor);
  return powNeg(encodingBase, -3.0) / 5.0.pow(codeLength - 10.0);
}
unittest {
  writefln("cpfl %s", computePrecisionForLength(2));
  writefln("cpfl %s", computePrecisionForLength(10));
  writefln("cpfl %s", computePrecisionForLength(12));

}

/** Returns the position of a char in the encoding alphabet, or -1 if invalid. **/
private int getAlphabetPosition (char c) {
  if (c >= 'C' && c <= 'X') return positionLUT[c - 'C'];
  if (c >= 'c' && c <= 'x') return positionLUT[c - 'c'];
  if (c >= '2' && c <= '9') return c - '2';
  return -1;
}
unittest {
  writefln("getABCPos %s", getAlphabetPosition('c'));
  writefln("getABCPos %s", getAlphabetPosition('9'));
}
/** Normalize a longitude into the range -180 to 180, not including 180. **/
private double normalizeLongitude (double lon) {
  while (lon < -lonMaxDegrees) lon += 360.0;
  while (lon >= lonMaxDegrees) lon -= 360.0;
  return lon;
}
unittest {
  assert(normalizeLongitude(0) == 0.0);
  writefln("nLon %s", normalizeLongitude(180.0));
  writefln("nLon %s", normalizeLongitude(-180.0));
  writefln("nLon %s", normalizeLongitude(360.0));
  writefln("nLon %s", normalizeLongitude(-360.0));
  writefln("nLon %s", normalizeLongitude(270.0));
  writefln("nLon %s", normalizeLongitude(-270.0));
}

/** // Adjusts 90 degree latitude to be lower so that a legal OLC code can be generated. **/
private double adjustLat (double lat, size_t codeLength) {
  import std.algorithm: max, min;
  lat = min(90.0, max(-90.0, lat));
  if (lat < latMaxDegrees) return lat;
  // Subtract half the code precision to get the latitude into the code
  // area.
  double precision = computePrecisionForLength(codeLength);
  return lat - precision / 2;
}
unittest {
  writefln ("aLat %s", adjustLat(0, 12));
  writefln ("aLat %s", adjustLat(90, 12));
  writefln ("aLat %s", adjustLat(-90, 12));

  writefln ("aLat %s", adjustLat(180, 12));
  writefln ("aLat %s", adjustLat(-180, 12));
  writefln ("aLat %s", adjustLat(90, 4));

}
private void cleanCodeChars (ref char[] code) {
  import std.algorithm: remove, canFind, countUntil;
  import std.string: indexOf;
  code.remove!(a => a == separator);
  auto i = indexOf(code, padding);
  if (i > 0) {
    code = code[0..i];
  }
}
unittest {
  char[] c1 = "8FVC2222+22".dup;
  char[] c2 = "CFX30000+".dup;
  cleanCodeChars(c1);
  cleanCodeChars(c2);
  writefln ("ccc %s", c1);
  writefln ("ccc %s", c2);

}

size_t codeLength(ref string code) {
  char[] cleanCode = code.dup;
  cleanCodeChars(cleanCode);
  return cleanCode.length;
}

/** **/
string encode (double latitude, double longitude, size_t codeLength = pairCodeLength) {
  import std.algorithm: min;
  codeLength = min(codeLength, maxDigitCount);
  double lat = adjustLat(latitude, codeLength);
  double lon = normalizeLongitude(longitude);
  char[] code = "123456789abcdef".dup;

  auto latVal = latMaxDegrees * gridLatPrecisionInverse;
  auto lonVal = lonMaxDegrees * gridLonPrecisionInverse;
  latVal += lat * gridLatPrecisionInverse;
  lonVal += lon * gridLonPrecisionInverse;

  size_t pos = maxDigitCount - 1;
  if (codeLength > pairCodeLength) {
    foreach (i; 0..gridCodeLength) {
      int latDigit = cast(int)(latVal % gridRows);
      int lonDigit = cast(int)(lonVal % gridColumns);
      int ndx = latDigit * gridColumns + lonDigit;
      code[pos--] = alphabet[ndx];
      latVal /= gridRows;
      lonVal /= gridColumns;
    }
  }
  else {
    latVal /= gridRows.pow(gridCodeLength);
    lonVal /= gridColumns.pow(gridCodeLength);
  }
  pos = pairCodeLength - 1;

  foreach (i; 0..pairCodeLength / 2) {
    int latNdx = cast(int)(latVal % encodingBase);
    int lonNdx = cast(int)(lonVal % encodingBase);
    code[pos--] = alphabet[lonNdx];
    code[pos--] = alphabet[latNdx];
    latVal /= encodingBase;
    lonVal /= encodingBase;
  }
  code = code[0..separatorPosition]
              ~ separator
              ~ code[separatorPosition..$];
  if (codeLength >= separatorPosition) return code[0..codeLength+1].idup;
  foreach (i; codeLength..separatorPosition) {
    code[i] = padding;
  }
  return code[0..separatorPosition].idup;
}
/** **/
unittest {
  import coordinate: geo;
  auto c = geo(47.0000625, 8.0000625);
  writefln ("encode olc %s", encode(c.lat, c.lon));      // 8FVC2222+22
  writefln ("encode olc %s", encode(c.lat, c.lon, 16));  // 8FVC2222+22GCCCC
}

/** **/
CodeArea decode (ref string olc) {
  import std.algorithm: min;
  import std.math: round;
  char[] code = olc.dup;
  code.cleanCodeChars;
  // Constrain to the maximum length
  if (code.length > maxDigitCount) code = code[0..maxDigitCount];
  // Initialise the values for each section. We work them out as integers and
  // convert them to floats at the end.
  int normLat = cast(int)(-latMaxDegrees * pairPrecisionInverse);
  int normLon = cast(int)(-lonMaxDegrees * pairPrecisionInverse);
  int extraLat = 0;
  int extraLon = 0;
  // How many digits do we have to process?
  size_t digits = min(pairCodeLength, code.length);
  // Define the place value for the most significant pair.
  int pv = cast(int)(encodingBase.pow(pairCodeLength / 2 - 1));
  for (size_t i = 0; i < digits - 1; i += 2) {
    normLat += getAlphabetPosition(code[i]) * pv;
    normLon += getAlphabetPosition(code[i+1]) * pv;
    if (i < digits - 2) pv /= encodingBase;
  }
  // Convert the place value to a float in degrees.
  double latPrecision = cast(double)pv / pairPrecisionInverse;
  double lonPrecision = cast(double)pv / pairPrecisionInverse;
  // Process any extra precision digits.
  if (code.length > pairCodeLength) {
    // Initialise the place values for the grid.
    int rowPv = gridRows.pow(gridCodeLength-1);
    int colPv = gridColumns.pow(gridCodeLength-1);
    // How many digits do we have to process?
    digits = min(maxDigitCount, code.length);
    foreach(i; pairCodeLength..digits) {
      int dval = getAlphabetPosition(code[i]);
      int row = dval / gridColumns;
      int col = dval % gridColumns;
      extraLat += row * rowPv;
      extraLon += col * colPv;
      if (i < digits - 1) {
        rowPv /= gridRows;
        colPv /= gridColumns;
      }
    }
    // Adjust the precisions from the integer values to degrees.
    latPrecision = cast(double)rowPv / gridLatPrecisionInverse;
    lonPrecision = cast(double)colPv / gridLonPrecisionInverse;
  }
  // Merge the values from the normal and extra precision parts of the code.
  // Everything is ints so they all need to be cast to floats.
  double lat = cast(double)normLat / pairPrecisionInverse + cast(double)extraLat / gridLatPrecisionInverse;
  double lon = cast(double)normLon / pairPrecisionInverse + cast(double)extraLon / gridLonPrecisionInverse;
  // Round everything off to 14 places.
  return CodeArea(round(lat * 1e14) / 1e14,                   // latLo
                  round(lon * 1e14) / 1e14,                   // lonLo
                  round((lat + latPrecision) * 1e14) / 1e14,  // latHi
                  round((lon + lonPrecision) * 1e14) / 1e14,  // lonHi
                  code.length);                               // code length
}
/** **/
unittest {
  auto code = OLC("8FVC2222+22");
  writefln("decode olc %s", decode(code.code));
  auto shortCode = OLC("8FVC2222+");
  writefln("decode olc %s", decode(shortCode.code));
}

/** **/
auto shorten (string code, GEO reference) {
  import coordinate: GEO;
  import std.algorithm: max;
  import std.math: fabs;
  CodeArea codeArea = decode(code);
  GEO center = codeArea.getCenter;
  writefln ("code area %s", codeArea);
  writefln ("center %s", center);
  // Ensure that latitude and longitude are valid.
  double lat = adjustLat(reference.lat, codeLength(code));
  double lon = normalizeLongitude(reference.lon);
  // How close are the latitude and longitude to the code center.
  double range = max(fabs(center.lat - lat), fabs(center.lon - lon));
  writefln ("center lat %s lon %s", center.lat, center.lon);
  writefln ("lat %s lon %s range %s", lat, lon, range);
  string codeCopy = code;
  const double safetyFactor = 0.3;
  const int[3] removalLengths = [8, 6, 4];
  writefln ("codeCopy %s", codeCopy);
  foreach (removalLength; removalLengths) {
    // Check if we're close enough to shorten. The range must be less than 1/2
    // the resolution to shorten at all, and we want to allow some safety, so
    // use 0.3 instead of 0.5 as a multiplier.
    double areaEdge = computePrecisionForLength(removalLength) * safetyFactor;
    writefln ("areaEdge %s", areaEdge);
    if (range < areaEdge) {
      codeCopy = codeCopy[0..removalLength];
      writefln ("codeCopy %s", codeCopy);
      break;
    }
  }
  return codeCopy;
}
/** **/
unittest {
  import coordinate: geo;
  auto olc = "9C3W9QCJ+2VX";
  auto reference = geo(51.3708675, -1.217765625);
  writefln ("olc for shorten %s", olc.decode);
  writefln ("ref %s", encode(reference.lat, reference.lon));
  writefln ("shorten %s", shorten(olc, reference) );
}
/** **/
struct OLC {
  import coordinate.utils: ExtendCoordinate;
  string code;            ///
  mixin ExtendCoordinate; ///
}
/** **/
struct CodeArea {
  double latLo;   /// low Latitude
  double lonLo;   /// low Longitude
  double latHi;   /// high Latitide
  double lonHi;   /// high Longitude
  size_t codeLength;  /// code length
  this (double latLo, double lonLo, double latHi, double lonHi, size_t codeLength) {
    this.latLo = latLo;
    this.lonLo = lonLo;
    this.latHi = latHi;
    this.lonHi = lonHi;
    this.codeLength = codeLength;
  }
  auto getCenter () {
    import std.algorithm: min;
    import coordinate: GEO, LAT, LON;
    const double latCenter = min(latLo + (latHi - latLo) / 2.0, latMaxDegrees);
    const double lonCenter = min(lonLo + (lonHi - lonLo) / 2.0, lonMaxDegrees);
    return GEO(LAT(latCenter), LON(lonCenter), real.nan, real.nan, real.nan);
  }
}
