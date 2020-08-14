/**

  Plus codes represent an area, not a point. As digits are added to a code, the area shrinks, so a long code is more precise than a short code.
  Codes that are similar are located closer together than codes that are different.

  Open Location Code (or plus-codes) are short codes that can be used like street addresses.
  Instead of a pair of coordinates they encode an area.
  A code consists of 8 *digits*, a *+* symbol and optional digits after the plus.
  The first ten digits encode longitude and latitude.
  Every two digits specify the area more accurately.
  The eleventh and following digits simply divide the area in twenty rectangles
  The digits are represented in base 20 with a character set that avoids similar looking characters.

  ## Character Set ##

  ## Encoding ##

  ### Most significant 10 digits ###

  ### Least significant five digits ###

  ### Code precision ###

  | Code length | Block size | Precision |
  |-------------|------------|---------------|
  | 2 | 20° | 2226 km |
  | 4 | 1° | 111.321 km |
  | 6 | 0.05° (3') | 5.566 km |
  | 8 | 0.0025° (9') | 278 m |
  | + | | |
  | 10 | 0.000125° (0.45') | 13.9 m |
  | 11 | 0.000025° x 0.00003125° | 2.8 x 3.5 m |
  | 12 | 0.000005° x 0.000007812° | 56 x 87 cm |
  | 13 | 0.000001° x 0.000001953° | 11 x 22 cm |
  | 14 | 0.0000002° x 0.000000488° | 2 x 5 cm |
  | 15 | 0,00000004° x 0,000000122° | 4 x 14 mm |

  This table assumes all distances are calculated on the equator with one degree is 111321 m.

  ## Decoding ##

  ## Short codes ##

  See: https://github.com/google/open-location-code/blob/master/cpp/openlocationcode.cc
**/
module coordinate.openlocationcode;
// also called plus code

import std.conv: to;
import std.algorithm: map, min, max;
import std.array: array;
import coordinate.mathematics;
import coordinate.latlon: GEO, LAT, LON;
import coordinate.exceptions: OLCException;
import coordinate.utils: AltitudeType, AccuracyType;
import coordinate.datums;
import std.math: log, floor, pow;
debug import std.stdio;

private {
  const int codePrecisionNormal = 10; // Provides a normal precision code, approximately 14x14 meters. Used to specify encoded code length
  const int codePrecisionExtra = 11;  // Provides an extra precision code length, approximately 2x3 meters. Used to specify encoded code length
  const char separatorChar = 0x002B;  // A separator used to break the code into two parts to aid memorability.
  const char paddingChar = 0x0030;    // The character used to pad codes.
  const int separatorPosition = 8;    // The number of characters to place before the separator.
  // The character set used to encode the digit values.
  // [50..57,67,70..72,74,77,80..82,86..88]
  const string codeAlphabet = "23456789CFGHJMPQRVWX"; // [50..57,67,70..72,74,77,80..82,86..88]
  const int encodingBase = 20;  // The base to use to convert numbers to/from. codeAlphabet.length
  const int encodingBaseSquared = encodingBase * encodingBase; // The encoding base squared also rep
  const int latitudeMax = 90;   // The maximum value for latitude in degrees.
  const int longitudeMax = 180; // The maximum value for longitude in degrees.
  const int maxDigitCount = 15; // Maximum code length for any plus code
  const int pairCodeLength = 10;  //  Maximum code length using just lat/lng pair encoding.
  const int gridCodeLength = maxDigitCount - pairCodeLength;  // Number of digits in the grid coding section.
  const int gridColumns = 4;  // Number of columns in the grid refinement method.
  const int gridRows = 5;     // Number of rows in the grid refinement method.
  const int firstLatitudeDigitValueMax = 8; // The maximum latitude digit value for the first grid layer. lat -> 90
  const int firstLongitudeDigitValueMax = 17; // The maximum longitude digit value for the first grid layer. lon -> 180
  const long gridRowsMultiplier = 3125; // pow(gridRows, gridCodeLength)
  const long gridColumnsMultiplier = 1024;  // pow(gridColumns, gridCodeLength)
  // Value to multiple latitude degrees to convert it to an integer with the maximum encoding
  // precision. I.e. ENCODING_BASE**3 * GRID_ROWS**GRID_CODE_LENGTH
  const long latIntegerMultiplier = 8000 * gridRowsMultiplier;
  // Value to multiple longitude degrees to convert it to an integer with the maximum encoding
  // precision. I.e. ENCODING_BASE**3 * GRID_COLUMNS**GRID_CODE_LENGTH
  const long lonIntegerMultiplier = 8000 * gridColumnsMultiplier;
  // Value of the most significant latitude digit after it has been converted to an integer.
  const long latMspValue = latIntegerMultiplier * encodingBaseSquared;
  // Value of the most significant longitude digit after it has been converted to an integer.
  const long lonMspValue = lonIntegerMultiplier * encodingBaseSquared;
  // The ASCII integer of the minimum digit character used as the offset for indexed code digits
  const int indexedDigitValueOffset = codeAlphabet[0];  // 50
  // The digit values indexed by the character ASCII integer for efficient lookup of a digit value by its character
  static const int[codeAlphabet[codeAlphabet.length - 1]-indexedDigitValueOffset + 1] indexedDigitValues;
}

private static this () {
  // Fill indexedDigitValues at start of module
  for (int i = 0, digitVal = 0; i < indexedDigitValues.length; i++) {
    int digitIndex = codeAlphabet[digitVal] - indexedDigitValueOffset;
    indexedDigitValues[i] = (digitIndex == i)? digitVal++:-1;
  }
}

/** Get digit value of char **/
private int digitValueOf(char digitChar) {
  return indexedDigitValues[digitChar - indexedDigitValueOffset];
}

/** Clip latitude between -90 and +90 **/
private double clipLatitude (double latitude) {
  return min(max(latitude, -latitudeMax), latitudeMax);
}
unittest {
  writefln("clip 90 %s", clipLatitude(90));
  writefln("clip -90 %s", clipLatitude(-90));
  writefln("clip 180 %s", clipLatitude(180));
  writefln("clip -180 %s", clipLatitude(-180));

}
/** Normalize Longitude between -180 and +180 **/
private double normalizeLongitude (double longitude) {
  while(longitude < -longitudeMax) longitude += longitudeMax * 2;
  while(longitude >= longitudeMax) longitude -= longitudeMax * 2;
  return longitude;
}
unittest {
  writefln("normedLon 180 %s", normalizeLongitude(180));
  writefln("normedLon -180 %s", normalizeLongitude(-180));
  writefln("normedLon 270 %s", normalizeLongitude(270));
  writefln("normedLon -270 %s", normalizeLongitude(-270));

}

/** Normalize a location code by adding the separator '+' character and any padding '0' characters
    that are necessary to form a valid location code.
**/
private string normalizeCode(string code) {
  import std.conv: to;
  // if code needs padding
  if (code.length < separatorPosition) {
    return code;
  }
  // if code needs ends with separator
  else if (code.length == separatorPosition)
    return code ~ separatorChar.to!string;
  // if code needs separator inbetween
  else if (code[separatorPosition] != separatorChar)
    return code[0..separatorPosition] ~ separatorChar.to!string ~ code[separatorPosition..$];
  else return code;
}
unittest {
  assert(normalizeCode("abcdefgh") == "abcdefgh+");
  assert(normalizeCode("abcdefghijk") == "abcdefgh+ijk");

}

/** Trim a location code by removing the separator '+' character and any padding '0' characters
    resulting in only the code digits in upper case.
**/
private string trimCode (string code) {
  import std.algorithm: remove;
  import std.uni: toUpper;
  import std.string: indexOf;
  code = code.dup.remove!(a => a == separatorChar).toUpper.idup;
  auto i = indexOf(code, paddingChar);
  if (i > 0) {
    code = code[0..i];
  }
  return code;
}
unittest {
  assert(trimCode("abcdefgh+ijk") == "ABCDEFGHIJK");
  assert(trimCode("abcd0000+") == "ABCD");

}

/** Compute the latitude precision value for a given code length. Lengths &lt;= 10 have the same
    precision for latitude and longitude, but lengths > 10 have different precisions due to the
    grid method having fewer columns than rows.
**/
private double computeLatitudePrecision(int codeLength) {
  import std.math: pow;
  if(codeLength <= codePrecisionNormal) {
    return encodingBase.pow(codeLength / -2.0 + 2);
  }
  return encodingBase.pow(-3) / gridRows.pow(codeLength - pairCodeLength);
}

/** **/
package auto encode (double latitude, double longitude, string file = __FILE__, size_t line = __LINE__) {
  return encode (latitude, longitude, pairCodeLength, file, line);
}
/** ditto **/
auto encode (double latitude, double longitude, int codeLength, string file = __FILE__, size_t line = __LINE__) {
  import std.math: round;
  import std.algorithm: reverse;
  codeLength = min(codeLength, maxDigitCount);
  if (codeLength < 2 || (codeLength < pairCodeLength && codeLength % 2 == 1))
    throw new OLCException("Illegal code length.", file, line);
  latitude = clipLatitude(latitude);
  longitude = normalizeLongitude(longitude);

  if (latitude == latitudeMax) {
    latitude -= 0.9 * computeLatitudePrecision(codeLength);
  }
  char[] code;

  long latVal = cast(long)(round((latitude + latitudeMax) * latIntegerMultiplier * 1e6) / 1e6);
  long lonVal = cast(long)(round((longitude + longitudeMax) * lonIntegerMultiplier * 1e6) / 1e6);

  if(codeLength > pairCodeLength) {
    foreach(i; 0..gridCodeLength) {
      long latDigit = latVal % gridRows;
      long lonDigit = lonVal % gridColumns;
      int ndx = cast(int)(latDigit * gridColumns + lonDigit);
      code ~= codeAlphabet[ndx];
      latVal /= gridRows;
      lonVal /= gridColumns;
    }
  } else {
    latVal /= gridRowsMultiplier;
    lonVal /= gridColumnsMultiplier;
  }
  // Compute the pair section of the code.
  foreach(i; 0..pairCodeLength/2) {
    code ~= codeAlphabet[lonVal % encodingBase];
    code ~= codeAlphabet[latVal % encodingBase];
    latVal /= encodingBase;
    lonVal /= encodingBase;
    if (i==0) code ~= separatorChar;
  }

  code.reverse;
  if (codeLength < separatorPosition) {
    code = code[0..codeLength];
    foreach(i; codeLength..separatorPosition) { code ~= paddingChar; }
    code ~= separatorChar;
  }
  return code[0..max(separatorPosition +1, codeLength +1)].idup;
}
unittest {
  // 20.3701125,2.782234375,11,7FG49QCJ+2VX
  writefln("encode: %s", encode(20.3701125,2.782234375,11));
  // 20.375,2.775,6,7FG49Q00+
  writefln("encode: %s", encode(20.375,2.775,6));
  // 90,1,4,CFX30000+
  writefln("encode: %s", encode(90,1,4));

}

/** **/
package CodeArea decode (string code, string file = __FILE__, size_t line = __LINE__) {
  import std.algorithm: min;
  if (!code.isFull) throw new OLCException("Passed Open Location Code is not a valid full code", file, line);
  string codeDigits = code.trimCode;
  //writefln("trimmed code %s", codeDigits);
  long latVal = -latitudeMax * latIntegerMultiplier;
  long lonVal = -longitudeMax * lonIntegerMultiplier;
  long latPlaceVal = latMspValue;
  long lonPlaceVal = lonMspValue;

  int pairPartLength = min(codeDigits.length, pairCodeLength);
  int codeLength = min(codeDigits.length, maxDigitCount);
  for (int i = 0; i < pairPartLength; i += 2) {
    latPlaceVal /= encodingBase;
    lonPlaceVal /= encodingBase;
    latVal += digitValueOf(codeDigits[i]) * latPlaceVal;
    lonVal += digitValueOf(codeDigits[i + 1]) * lonPlaceVal;
  }
  //writefln("grid part:");
  for (int i = pairCodeLength; i < codeLength; i++) {
    latPlaceVal /= gridRows;
    lonPlaceVal /= gridColumns;
    //writefln("codeDigit[%s] is %s", i, codeDigits[i]);
    int digit = digitValueOf(codeDigits[i]);
    int row = digit / gridColumns;
    int col = digit % gridColumns;
    latVal += row * latPlaceVal;
    lonVal += col * lonPlaceVal;
  }
  return CodeArea(
    cast(double)latVal / latIntegerMultiplier,                  // southLatitude
    cast(double)lonVal / lonIntegerMultiplier,                  // westLongitude
    cast(double)(latVal + latPlaceVal) / latIntegerMultiplier,  // northLatitude
    cast(double)(lonVal + lonPlaceVal) / lonIntegerMultiplier,  // eastLongitude
    codeLength
  );
}

/** **/
string shorten (string code, double refLat, double refLon, string file = __FILE__, size_t line = __LINE__) {
  if (!code.isFull) throw new OLCException("Code cannot be short.", file, line);
  if (code.isPadded) throw new OLCException("Code cannot be padded.", file, line);
  return shorten(decode(code), code, refLat, refLon, file, line);
}
/** **/
string shorten (CodeArea codeArea, string code, double referenceLatitude, double referenceLongitude, string file = __FILE__, size_t line = __LINE__) {
  import std.math: fabs, fmax, cmp;
  import coordinate: GEO;
  GEO center = codeArea.center;
  double range = fmax(
    fabs(referenceLatitude - center.lat),
    fabs(referenceLongitude - center.lon)
  );
  // We are going to check to see if we can remove three pairs, two pairs or just one pair of
  // digits from the code.
  for (int i = 4; i >= 1; i--) {
    // Check if we're close enough to shorten. The range must be less than 1/2
    // the precision to shorten at all, and we want to allow some safety, so
    // use 0.3 instead of 0.5 as a multiplier.
    if (range < computeLatitudePrecision(i * 2) * 0.3)
      return code[i*2..$];  // We're done.
  }
  throw new OLCException("Reference location is too far from the Open Location Code center.", file, line);
}
unittest {
  // 9C3W9QCJ+2VX,51.3701125,-1.217765625,+2VX,B
  writefln("shorten: %s", shorten("9C3W9QCJ+2VX", 51.3701125, -1.217765625));
  // 9C3W9QCJ+2VX,51.3708675,-1.217765625,CJ+2VX,B
  writefln("shorten: %s", shorten("9C3W9QCJ+2VX", 51.3708675, -1.217765625));

}

/** **/
auto recoverNearest (string shortCode, double referenceLatitude, double referenceLongitude, string file = __FILE__, size_t line = __LINE__) {
  import std.string: indexOf;
  import coordinate: GEO;
  if (!shortCode.isShort) throw new OLCException("Is not a valid short Open Location Code.", file, line);
  referenceLatitude = clipLatitude(referenceLatitude);
  referenceLongitude = normalizeLongitude(referenceLongitude);

  int digitsToRecover = separatorPosition - cast(int)shortCode.indexOf(separatorChar);
  double prefixPrecision = encodingBase.pow(2 - (digitsToRecover / 2.0));

  string recoveredPrefix = encode(referenceLatitude, referenceLongitude)[0..digitsToRecover];
  string recovered = recoveredPrefix ~ shortCode;
  GEO recoveredCodeAreaCenter = decode(recovered).center;
  double recoveredLatitude = recoveredCodeAreaCenter.lat;
  double recoveredLongitude = recoveredCodeAreaCenter.lon;

  double latitudeDiff = recoveredLatitude - referenceLatitude;
  if (latitudeDiff > prefixPrecision / 2 && recoveredLatitude - prefixPrecision > -latitudeMax) {
    recoveredLatitude -= prefixPrecision;
  } else if (latitudeDiff < -prefixPrecision / 2 && recoveredLatitude + prefixPrecision < latitudeMax) {
    recoveredLatitude += prefixPrecision;
  }

  double longitudeDiff = recoveredCodeAreaCenter.lon - referenceLongitude;
  if (longitudeDiff > prefixPrecision / 2) {
    recoveredLongitude -= prefixPrecision;
  } else if (longitudeDiff < -prefixPrecision / 2) {
    recoveredLongitude += prefixPrecision;
  }
  return encode(recoveredLatitude, recoveredLongitude, cast(int)recovered.trimCode.length);
}
unittest {
  // 9C3W9QCJ+2VX,51.3708675,-1.217765625,CJ+2VX,B
  writefln("recover %s", recoverNearest("CJ+2VX", 51.3708675,-1.217765625));
}

/** **/
bool isValid (string code) {
  import std.string: indexOf;
  import std.algorithm: count, remove, any;
  if (code.length < 2) return false;

  // There must be exactly one separator.
  int separatorIndex = cast(int)code.indexOf(separatorChar);
  if (separatorIndex == -1) return false;
  //if (separatorIndex != code.lastIndexOf(separatorCharacter)) return false;
  // There must be an even number of at most eight characters before the separator.
  if (separatorIndex % 2 != 0 || separatorIndex > separatorPosition) return false;

  // Check first two characters: only some values from the alphabet are permitted.
  if (separatorIndex == separatorPosition) {
    // First latitude character can only have first 9 values.
    if (codeAlphabet.indexOf(code[0]) > firstLatitudeDigitValueMax) return false;
    // First longitude character can only have first 18 values.
    if (codeAlphabet.indexOf(code[1]) > firstLongitudeDigitValueMax) return false;
  }
  // Check the characters before the separator.
  bool paddingStarted = false;
  for (int i = 0; i < separatorIndex; i++) {
    if(paddingStarted) {
      if(code[i] != paddingChar) return false;
    } else if (code[i] == paddingChar) {
      paddingStarted = true;
      // Short codes cannot have padding
      if (separatorIndex < separatorPosition) return false;
      // Padding can start on even character: 2, 4 or 6.
      if (i != 2 && i != 4 && i != 6) return false;
    } else if (codeAlphabet.indexOf(code[i])  == -1) return false;  // illegal character
  }
  // Check the characters after the separator.
  if (code.length > separatorIndex + 1) {
    if(paddingStarted) return false;
    // Only one character after separator is forbidden.
    if (code.length == separatorIndex + 2) return false;
    for (int i = separatorIndex + 1; i < code.length; i++) {
      if (codeAlphabet.indexOf(code[i]) == -1) return false;
    }
  }
  return true;
}
unittest {
  assert("8FWC2345+G6".isValid);
}

/** Determines if a code is a valid short Open Location Code. **/
bool isShort (string code) {
  import std.string: indexOf;
  if (!code.isValid) return false;
  int separatorIndex = cast(int)code.indexOf(separatorChar);
  return (0 <= separatorIndex && separatorIndex < separatorPosition);
}
/** Determines if a code is a valid full Open Location Code. **/
bool isFull (string code) {
  import std.string: indexOf;
  if (!code.isValid) return false;
  return code.indexOf(separatorChar) == separatorPosition;
}
bool isPadded (string code) {
  import std.string: indexOf;
  if(!code.isValid) return false;
  return code.indexOf(paddingChar) >= 0;
}

/** **/
struct PlusCode {
  import coordinate.utils: ExtendCoordinate;
  string code;            ///
  alias code this;
  mixin ExtendCoordinate; ///
  this (string pluscode, AltitudeType altitude, AccuracyType accuracy, AccuracyType altitudeAccuracy) {
    this.code = pluscode;
    this.altitude = altitude;
    this.accuracy = accuracy;
    this.altitudeAccuracy = altitudeAccuracy;
  }
}
/** **/
auto pluscode (string code,
              AltitudeType altitude, AccuracyType accuracy, AccuracyType altitudeAccuracy,
              string file = __FILE__, size_t line = __LINE__) {
  return PlusCode(code, altitude, accuracy, altitudeAccuracy);
}
/** **/
auto pluscode (string code, string file = __FILE__, size_t line = __LINE__) {
  return pluscode(code, AltitudeType.init, AccuracyType.init, AccuracyType.init, file, line);
}
/** **/
struct CodeArea {
  private double[2] _min;  // [southLatitude, westLongitude]
  private double[2] _max;  // [northLatitude, eastLongitude]
  size_t codeLength;  /// code length

  /** **/
  this (double southLatitude, double westLongitude, double northLatitude, double eastLongitude, size_t codeLength, string file = __FILE__, size_t line = __LINE__) {
    import std.exception: enforce;
    enforce!OLCException(southLatitude <= northLatitude, "South latitude must be less or equal north latitude!", file, line);
    enforce!OLCException(westLongitude <= eastLongitude, "West longitude must be less or equal east longitude!", file, line);
    this._min[0] = southLatitude;
    this._min[1] = westLongitude;
    this._max[0] = northLatitude;
    this._max[1] = eastLongitude;
    this.codeLength = codeLength;
  }

  double[2] min () { return _min; } // The min (south west) point coordinates of the area bounds.
  double[2] max () { return _max; } // The max (north east) point coordinates of the area bounds.
  double southLatitude () { return _min[0]; } /// The south (min) latitude coordinate in decimal degrees.
  double westLongitude () { return _min[1]; } /// The west (min) longitude coordinate in decimal degrees.
  double northLatitude () { return _max[0]; } /// The north (max) latitude coordinate in decimal degrees.
  double eastLongitude () { return _max[1]; } /// The east (max) longitude coordinate in decimal degrees.

  /** The center point of the area which is equidistant between min and max. **/
  GEO center () {
    import std.algorithm: min;
    import coordinate: GEO, LAT, LON, geo;
    return geo(centerLatitude, centerLongitude, AltitudeType.init, AccuracyType.init, AccuracyType.init, Datum.epsg(6326));
  }
  /** The center latitude coordinate in decimal degrees. **/
  private LAT centerLatitude () {
    return LAT((_min[0] + _max[0]) / 2.0); }
  /** The center longitude coordinate in decimal degrees. **/
  private LON centerLongitude () { return LON((_min[1] + _max[1]) / 2); }

  /** Check if this geo area contains the provided point **/
  bool contains (GEO point) {
    return contains (point.lat, point.lon);
  }
  /** ditto **/
  bool contains (double latitude, double longitude) {
    return (min[0] <= latitude && latitude < max[0]
         && min[1] <= longitude && longitude < max[1]);
  }
}
