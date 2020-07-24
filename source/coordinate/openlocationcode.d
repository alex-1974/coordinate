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
import coordinate: GEO;
import coordinate.exceptions: OLCException;
import coordinate.utils: AltitudeType, AccuracyType, defaultDatum;
import std.math: log, floor, pow;
debug import std.stdio;

const int codePrecisionNormal = 10;
const int codePrecisionExtra = 11;
const char separatorChar = 0x002B;
const char paddingChar = 0x0030;
const int separatorPosition = 8;
const string codeAlphabet = "23456789CFGHJMPQRVWX"; // [50..57,67,70..72,74,77,80..82,86..88]
const int encodingBase = 20;
const int encodingBaseSquared = encodingBase * encodingBase;
const int latitudeMax = 90;
const int longitudeMax = 180;
const int maxDigitCount = 15;
const int pairCodeLength = 10;
const int gridCodeLength = maxDigitCount - pairCodeLength;
const int gridColumns = 4;
const int gridRows = 5;
const int firstLatitudeDigitValueMax = 8; // lat -> 90
const int firstLongitudeDigitValueMax = 17; // lon -> 180
const long gridRowsMultiplier = 3125; // pow(gridRows, gridCodeLength)
const long gridColumnsMultiplier = 1024;  // pow(gridColumns, gridCodeLength)
const long latIntegerMultiplier = 8000 * gridRowsMultiplier;
const long lonIntegerMultiplier = 8000 * gridColumnsMultiplier;
const long latMspValue = latIntegerMultiplier * encodingBaseSquared;
const long lonMspValue = lonIntegerMultiplier * encodingBaseSquared;
const int indexedDigitValueOffset = codeAlphabet[0];  // 50
static const int[codeAlphabet[codeAlphabet.length - 1]-indexedDigitValueOffset + 1] indexedDigitValues;

static this () {
  writefln("indexedDigitValueOffset %s", indexedDigitValueOffset);
  for (int i = 0, digitVal = 0; i < indexedDigitValues.length; i++) {
    int digitIndex = codeAlphabet[digitVal] - indexedDigitValueOffset;
    indexedDigitValues[i] = (digitIndex == i)? digitVal++:-1;
  }
  foreach (idx; indexedDigitValues) {
    int i = (idx == -1)? -1:idx+50;
    writefln("i %s", i);
  }
}
int digitValueOf(char digitChar) {
  //writefln("digitValueOf: digitChar %s", digitChar);
  //writefln("index %s", digitChar - indexedDigitValueOffset);
  return indexedDigitValues[digitChar - indexedDigitValueOffset];
}

double clipLatitude (double latitude) {
  return min(max(latitude, -latitudeMax), latitudeMax);
}
unittest {
  writefln("clip 90 %s", clipLatitude(90));
  writefln("clip -90 %s", clipLatitude(-90));
  writefln("clip 180 %s", clipLatitude(180));
  writefln("clip -180 %s", clipLatitude(-180));

}
double normalizeLongitude (double longitude) {
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
string normalizeCode(string code) {
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
  writefln("normalized code %s", normalizeCode("abcdefgh"));
  writefln("normalized code %s", normalizeCode("abcdefghijk"));

}

/** Trim a location code by removing the separator '+' character and any padding '0' characters
    resulting in only the code digits.
**/
string trimCode (string code) {
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
  writefln("trimmed code %s", trimCode("abcdefgh+ijk"));
  writefln("trimmed code %s", trimCode("abcd0000+"));

}

/** Compute the latitude precision value for a given code length. Lengths &lt;= 10 have the same
    precision for latitude and longitude, but lengths > 10 have different precisions due to the
    grid method having fewer columns than rows.
**/
double computeLatitudePrecision(int codeLength) {
  import std.math: pow;
  if(codeLength <= codePrecisionNormal) {
    return encodingBase.pow(codeLength / -2.0 + 2);
  }
  return encodingBase.pow(-3) / gridRows.pow(codeLength - pairCodeLength);
}

auto encode (double latitude, double longitude, int codeLength = pairCodeLength) {
  import std.math: round;
  import std.algorithm: reverse;
  codeLength = min(codeLength, maxDigitCount);
  if (codeLength < 2 || (codeLength < pairCodeLength && codeLength % 2 == 1))
    throw new OLCException("Illegal code length.");
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

CodeArea decode (string code) {
  import std.algorithm: min;
  //if (!olc.isFull) throw new OLCException("Passed Open Location Code is not a valid full code");
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
    cast(double)latVal / latIntegerMultiplier,
    cast(double)lonVal / lonIntegerMultiplier,
    cast(double)(latVal + latPlaceVal) / latIntegerMultiplier,
    cast(double)(lonVal + lonPlaceVal) / lonIntegerMultiplier,
    codeLength
  );
}

string shorten (string code, double refLat, double refLon) {
  return shorten(decode(code), code, refLat, refLon);
}
string shorten (CodeArea codeArea, string code, double referenceLatitude, double referenceLongitude) {
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
  throw new OLCException("Reference location is too far from the Open Location Code center.");
}
unittest {
  // 9C3W9QCJ+2VX,51.3701125,-1.217765625,+2VX,B
  writefln("shorten: %s", shorten("9C3W9QCJ+2VX", 51.3701125, -1.217765625));
  // 9C3W9QCJ+2VX,51.3708675,-1.217765625,CJ+2VX,B
  writefln("shorten: %s", shorten("9C3W9QCJ+2VX", 51.3708675, -1.217765625));

}

auto recoverNearest (string shortCode, double referenceLatitude, double referenceLongitude) {
  import std.string: indexOf;
  import coordinate: GEO;
  if (!shortCode.isValid) throw new OLCException("Is not a valid short Open Location Code.");
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

bool isValid (string code) {
  import std.string: indexOf;
  import std.algorithm: count, remove, any;
  if (!code.length) return false;
  // separator is required but there must be only one separator
  if (code.count(separatorChar) != 1) return false;
  // is the separator the only character?
  if (code.length == 1) return false;
  // is the separator in an illegal position?
  auto sepPos = code.indexOf(separatorChar);
  if (sepPos > separatorPosition || sepPos % 2 == 1) return false;
  // We can have an even number of padding characters before the separator,
  // but then it must be the final character.
  auto padStart = code.indexOf(paddingChar);
  if (padStart > 0) {
    // short codes cannot have padding
    if (sepPos < separatorPosition) return false;
    // the first padding character needs to be in an odd position
    if (padStart == 0 || padStart % 2) return false;
    // Padded codes must not have anything after the separator
    if (code.length > sepPos + 1) return false;
    // get from first padding character to separator
    auto padSec = code[padStart..separatorPosition];
    if (remove!(a => a == paddingChar)(padSec.dup).length) return false;
  }
  // if there are characters after the separator, make sure there isn't just one of them (not legal)
  if (code.length - sepPos - 1 == 1) return false;
  // Are there any invalid characters?
  foreach (c; code) {
    //if (c != separatorChar && c != paddingChar && getAlphabetPosition(c) < 0) return false;
  }
  return true;

}
/++
static const char separator = 0x002B;  // A '+' separator used to break the code into two parts to aid memorability.
static const char padding = 0x0030;    // The '0' character used to pad codes.
static immutable char[20] alphabet = "23456789CFGHJMPQRVWX";  // The character set used to encode
static const size_t encodingBase = alphabet.length; // The base to use to convert numbers to/from.
static const size_t maxDigitCount = 15;   // The max number of digits for any plus code.
static const size_t pairCodeLength = 10;  // Maximum code length using just lat/lng pair encoding.
static const size_t gridCodeLength = maxDigitCount - pairCodeLength;  // Number of digits in the grid coding section.
static const size_t gridColumns = 4;                        // Number of columns in the grid refinement method.
static const size_t gridRows = encodingBase / gridColumns;  // Number of rows in the grid refinement method.
static const size_t separatorPosition = 8;  // The number of characters to place before the separator.
// Work out the encoding base exponent necessary to represent 360 degrees.
static const size_t initialExponent = cast(size_t)((360.log / encodingBase.log).floor);
// Work out the enclosing resolution (in degrees) for the grid algorithm.
static const double gridSizeDegree = 1.0 / (encodingBase).pow(pairCodeLength / 2 - (initialExponent + 1));
// Inverse (1/) of the precision of the final pair digits in degrees. (20^3)
static const size_t pairPrecisionInverse = 8000;
// Inverse (1/) of the precision of the final grid digits in degrees.
// (Latitude and longitude are different.)
static const size_t gridLatPrecisionInverse = pairPrecisionInverse * pow(gridRows, gridCodeLength);
static const size_t gridLonPrecisionInverse = pairPrecisionInverse * gridColumns.pow(gridCodeLength);
// Latitude bounds are -latMaxDegrees degrees and +latMaxDegrees
// degrees which we transpose to 0 and 180 degrees.
static const double latMaxDegrees = 90.0;   // The maximum value for latitude in degrees.
static const double lonMaxDegrees = 180.0;  // The maximum value for longitude in degrees.
// Lookup table of the alphabet positions of characters 'C' through 'X',
// inclusive. A value of -1 means the character isn't part of the alphabet.
static const int['X' - 'C' + 1] positionLUT = [8,  -1, -1, 9,  10, 11, -1, 12,
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
deprecated ("use computeLatitudePrecision") private double computePrecisionForLength (size_t length) { return computeLatitudePrecision(length); }

private double computeLatitudePrecision (size_t length) {
  if (length <= pairCodeLength)
    //return powNeg(encodingBase, ((length / -2) + 2.0).floor);
    return encodingBase.pow(length / -2 + 2);
  //return powNeg(encodingBase, -3) / gridRows.pow(length - pairCodeLength);
  return encodingBase.pow(-3) / gridRows.pow(length - pairCodeLength);
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
private double normalizeLongitude (double lon)
out (result) { assert( -180 <= result && result < 180); }
do {
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

/** Adjusts 90 degree latitude to be lower so that a legal OLC code can be generated. **/
private double adjustLat (double lat) {
  import std.algorithm: max, min;
  //lat = min(90.0, max(-90.0, lat));
  return min(max(lat, -latMaxDegrees), latMaxDegrees);
  //return lat; // in csharp lat gets just clipped (no case < 90°)
  /++
  if (lat < latMaxDegrees) return lat;
  // Subtract half the code precision to get the latitude into the code
  // area.
  double precision = computePrecisionForLength(length);
  writefln("adjustLat lat %s (length %s) to %s", lat, length, lat - precision / 2);
  return lat - precision / 2;
  ++/
}
unittest {

}

/** Normalize a location code by adding the separator '+' character and any padding '0' characters
    that are necessary to form a valid location code.
**/
private string normalizeCode (string code) {
  import std.conv: to;
  // if code needs padding
  if (code.length < separatorPosition) {
    return code;
  }
  // if code needs ends with separator
  else if (code.length == separatorPosition)
    return code ~ separator.to!string;
  // if code needs separator inbetween
  else if (code[separatorPosition] != separator)
    return code[0..separatorPosition] ~ separator ~ code[separatorPosition..$];
  else return code;
}
/** Trim a location code by removing the separator '+' character and any padding '0' characters
  resulting in only the code digits.
**/
deprecated("Use trimCode") private void cleanCodeChars (ref char[] code) { trimCode(code); }

private void trimCode (ref char[] code) {
  import std.algorithm: remove;
  import std.uni: toUpper;
  import std.string: indexOf;
  code.remove!(a => a == separator).toUpper;
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

size_t codeLength(string code) {
  char[] cleanCode = code.dup;
  cleanCodeChars(cleanCode);
  return cleanCode.length;
}

/** **/
string encode (double latitude, double longitude, size_t length = pairCodeLength) {
  import std.algorithm: min;
  // Limit the maximum number of digits in the code.
  debug size_t l1 = length;
  length = min(length, maxDigitCount);
  debug if(l1 != length) writefln ("clipped length from %s to %s", l1, length);
  // Check that the code length requested is valid.
  if (length < 2 || (length < pairCodeLength && length % 2 == 1))
    throw new OLCException("Illegal code length!");
  // Adjust latitude and longitude so they fall into positive ranges.
  double lat = adjustLat(latitude);
  double lon = normalizeLongitude(longitude);
  writefln ("clipped lat %s and lon %s", lat, lon);

  // csharp Conversion
  if (lat == latMaxDegrees) {
    lat -= 0.9 * computePrecisionForLength(length);
    writefln ("  needed to trim lat to %s", lat);
  }
  writefln ("trimmed lat %s and lon %s", lat, lon);
  // Reserve 15 characters for the code digits. The separator will be inserted
  // at the end.
  //char[] code = "123456789abcdef".dup;
  char[16] code;
  // Compute the code.
  // This approach converts each value to an integer after multiplying it by
  // the final precision. This allows us to use only integer operations, so
  // avoiding any accumulation of floating point representation errors.

  // Multiply values by their precision and convert to positive without any
  // floating point operations.
  // long are signed 64 bits
  long latVal1 = cast(long)(latMaxDegrees * gridLatPrecisionInverse);
  long lonVal1 = cast(long)(lonMaxDegrees * gridLonPrecisionInverse);
  writefln("positives ... latValue1 %s lonValue1 %s", latVal1, lonVal1);
  assert(0 <= latVal1 && 0 <= lonVal1);
  long latVal = cast(long)(latVal1 + lat * gridLatPrecisionInverse);
  long lonVal = cast(long)(lonVal1 + lon * gridLonPrecisionInverse);
  writefln("latValue %s lonValue %s", latVal, lonVal);
  int pos = maxDigitCount - 1;
  // Compute the grid part of the code if necessary.
  // 10 lat/lng pair codes and up to 5 grid codes
  if (length > pairCodeLength) {  // more than 10 digits in code
    writefln ("compute grid section:");
    debug if(latitude < 0) writefln("  Cave negative latitude!!!");
    debug if(longitude < 0) writefln("  Cave negative longitude!!!");
    do {
      long latDigit = latVal % gridRows;
      long lonDigit = lonVal % gridColumns;
      int ndx = cast(int)(latDigit * gridColumns + lonDigit);
      //writefln ("latDigit: %s mod %s is %s", latVal, gridRows, latDigit);
      //writefln ("lonDigit: %s mod %s is %s", lonVal, gridColumns, lonDigit);
      //writefln("  pos %s alphabet[%s] is %s", pos, ndx, alphabet[ndx]);
      //writefln("pos %s alphabet.length %s ndx %s", pos, alphabet.length, ndx);
      // cpp string:replace(string, pos, 1, 1, abc)
      code[pos--] = alphabet[ndx];
      // Note! Integer division.
      latVal /= gridRows;
      lonVal /= gridColumns;
    } while (pos > (maxDigitCount - gridCodeLength)-1);
  }
  else {
    writefln ("%s.pow(%s) = %s", gridRows, gridCodeLength, gridRows.pow(gridCodeLength));
    latVal /= gridRows.pow(gridCodeLength);
    lonVal /= gridColumns.pow(gridCodeLength);
    writefln("  in grid section: latVal %s lonVal %s", latVal, lonVal);
  }
  writefln ("after grid section: latVal %s lonVal %s", latVal, lonVal);

  // Compute the pair section of the code.
  pos = pairCodeLength-1;
  do {
    int latNdx = cast(int)(latVal % encodingBase);
    int lonNdx = cast(int)(lonVal % encodingBase);
    code[pos--] = alphabet[lonNdx];
    code[pos--] = alphabet[latNdx];
    // Note! Integer division.
    latVal /= encodingBase;
    lonVal /= encodingBase;
  } while (pos > 0);
  // Add the separator character.
  code = code[0..separatorPosition]
              ~ separator
              ~ code[separatorPosition..$-1];
  // If we don't need to pad the code, return the requested section.
  if (length >= separatorPosition) return code[0..length+1].idup;
  // Add the required padding characters.
  foreach (i; length..separatorPosition) {
    code[i] = padding;
  }
  // Return the code up to and including the separator.
  return code[0..separatorPosition+1].idup;
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
  if (!olc.isFull) throw new OLCException("Passed Open Location Code is not a valid full code");
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
  int pv = cast(int)(encodingBase.pow(pairCodeLength / 2.0 - 1.0));
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
    //int rowPv = cast(int)(gridRows.pow(gridCodeLength-1.0));
    //int colPv = cast(int)(gridColumns.pow(gridCodeLength-1.0));
    int rowPv = cast(int)(gridRows.pow(gridCodeLength));
    int colPv = cast(int)(gridColumns.pow(gridCodeLength));
    // How many digits do we have to process?
    digits = min(maxDigitCount, code.length);
    foreach(i; pairCodeLength..digits) {
      int dval = getAlphabetPosition(code[i]); // digit value
      int row = cast(int)(dval / gridColumns);
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
  double lat = cast(double)normLat / pairPrecisionInverse +
               cast(double)extraLat / gridLatPrecisionInverse;
  double lon = cast(double)normLon / pairPrecisionInverse +
               cast(double)extraLon / gridLonPrecisionInverse;

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
auto shorten (string code, double latitude, double longitude) {
  import coordinate: GEO;
  import std.string: indexOf;
  import std.algorithm: max;
  import std.math: fabs;
  //import std.uni: asUpperCase;
  if (!code.isFull) throw new OLCException("Passed code is not valid and full!");
  // we can't shorten padded code?
  if (code.indexOf(padding) != -1) throw new OLCException("Cannot shorten padded codes!");
  CodeArea codeArea = decode(code);
  GEO center = codeArea.getCenter;
  // Ensure that latitude and longitude are valid.
  //double lat = adjustLat(latitude, codeLength(code));
  double lat = adjustLat(latitude);

  double lon = normalizeLongitude(longitude);
  // How close are the latitude and longitude to the code center.
  double range = max(fabs(center.lat - lat),
                     fabs(center.lon - lon));
  string codeCopy = code;
  const double safetyFactor = 0.3;
  const int[3] removalLengths = [8, 6, 4];
  foreach (removalLength; removalLengths) {
    // Check if we're close enough to shorten. The range must be less than 1/2
    // the resolution to shorten at all, and we want to allow some safety, so
    // use 0.3 instead of 0.5 as a multiplier.
    double areaEdge = computePrecisionForLength(removalLength) * safetyFactor;
    if (range < areaEdge) {
      // get from removalLength to the end
      codeCopy = codeCopy[removalLength..$];
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
  writefln ("shorten %s", shorten(olc, reference.lat, reference.lon) );
}

/** **/
string recoverNearest (string shortCode, double lat, double lon) {
  import std.string: indexOf;
  import std.uni: toUpper;
  // If not short code return
  if (!shortCode.isShort) return shortCode.toUpper;
  // Ensure that latitude and longitude are valid.
  //lat = adjustLat(lat, codeLength(shortCode));
  lat = adjustLat(lat);

  lon = normalizeLongitude(lon);
  // Compute the number of digits we need to recover.
  size_t paddingLength = separatorPosition - shortCode.indexOf(separator);
  // The resolution (height and width) of the padded area in degrees.
  double resolution = powNeg(encodingBase, 2.0 - (paddingLength / 2.0));
  // Distance from the center to an edge (in degrees).
  double halfRes = resolution / 2.0;
  //GEO latlon = geo(lat, lon);
  string paddingCode = encode(lat, lon);
  paddingCode = paddingCode[0..paddingLength] ~ shortCode;
  CodeArea codeRect = decode(paddingCode);
  // How many degrees latitude is the code from the reference? If it is more
  // than half the resolution, we need to move it north or south but keep it
  // within -90 to 90 degrees.
  double centerLat = codeRect.getCenter().lat.lat;
  double centerLon = codeRect.getCenter().lon.lon;
  if (lat + halfRes < centerLat && centerLat - resolution > -latMaxDegrees) {
    // If the proposed code is more than half a cell north of the reference
    // location, it's too far, and the best match will be one cell south.
    centerLat -= resolution;
  }
  else if (lat - halfRes > centerLat && centerLat + resolution < latMaxDegrees) {
    // If the proposed code is more than half a cell south of the reference
    // location, it's too far, and the best match will be one cell north.
    centerLat += resolution;
  }
  // How many degrees longitude is the code from the reference?
  if (lon + halfRes < centerLon) {
    centerLon -= resolution;
  }
  else if (lon - halfRes > centerLon) {
    centerLon += resolution;
  }
  return encode(centerLat, centerLon, codeLength(shortCode) + paddingLength);
}

/** **/
bool isValid (string code) {
  import std.string: indexOf;
  import std.algorithm: count, remove, any;
  if (!code.length) return false;
  // separator is required but there must be only one separator
  if (code.count(separator) != 1) return false;
  // is the separator the only character?
  if (code.length == 1) return false;
  // is the separator in an illegal position?
  auto sepPos = code.indexOf(separator);
  if (sepPos > separatorPosition || sepPos % 2 == 1) return false;
  // We can have an even number of padding characters before the separator,
  // but then it must be the final character.
  auto padStart = code.indexOf(padding);
  if (padStart > 0) {
    // short codes cannot have padding
    if (sepPos < separatorPosition) return false;
    // the first padding character needs to be in an odd position
    if (padStart == 0 || padStart % 2) return false;
    // Padded codes must not have anything after the separator
    if (code.length > sepPos + 1) return false;
    // get from first padding character to separator
    auto padSec = code[padStart..separatorPosition];
    if (remove!(a => a == padding)(padSec.dup).length) return false;
  }
  // if there are characters after the separator, make sure there isn't just one of them (not legal)
  if (code.length - sepPos - 1 == 1) return false;
  // Are there any invalid characters?
  foreach (c; code) {
    if (c != separator && c != padding && getAlphabetPosition(c) < 0) return false;
  }
  return true;
}
/** **/
unittest {
  assert(isValid("9C3W9QCJ+2VX"));
}

/** **/
bool isShort (string code) {
  import std.string: indexOf;
  // check it's valid
  if (!code.isValid) return false;
  // if there are less characters than expected before the separator
  if (code.indexOf(separator) < separatorPosition) return true;
  return false;
}

/** **/
bool isFull (string code) {
  if (!code.isValid) return false;
  // if it's short it's not full
  if (code.isShort) return false;
  // work out what the first latitude character indicates for latitude
  size_t firstLatValue = getAlphabetPosition(code[0]);
  firstLatValue *= encodingBase;
  // The code would decode to a latitude of >= 90 degrees.
  if (firstLatValue >= latMaxDegrees * 2) return false;
  if (code.length > 1) {
    // Work out what the first longitude character indicates for longitude.
    size_t firstLonValue = getAlphabetPosition(code[1]);
    firstLonValue *= encodingBase;
    if (firstLonValue >= lonMaxDegrees * 2) return false;
  }
  return true;
}
++/
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
  auto center () {
    import std.algorithm: min;
    import coordinate: GEO, LAT, LON;
    //const double latCenter = min(latLo + (latHi - latLo) / 2.0, latitudeMax);
    const double latCenter = (latLo + latHi) / 2;
    //const double lonCenter = min(lonLo + (lonHi - lonLo) / 2.0, longitudeMax);
    const double lonCenter = (lonLo + lonHi) / 2;
    return GEO(LAT(latCenter), LON(lonCenter), real.nan, real.nan, real.nan);
  }
}
