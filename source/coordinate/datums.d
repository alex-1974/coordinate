/** Definitions of geographic datums and ellipsoids

**/

module coordinate.datums;

import std.math: isNaN;
import coordinate.exceptions: DatumException;
debug import std.stdio;

/** Ellipsoid parameters

  An ellipsoid is defined by its semi-major axis (*a*), semi-minor axis (*b*), and flattening (*f*).

  <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
    <mtext>Semi minor axis:</mtext><mspace width="3ex"/>
    <mi>b</mi><mo> = </mo><mi>a</mi><mo>&times;</mo><mo>(</mo><mn>1</mn><mo>-</mo><mi>f</mi><mo>)</mo>
  </mrow></math>

  <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
    <mtext>Flattening:</mtext><mspace width="3ex"/>
    <mi>f</mi><mo> = </mo>
    <mfrac bevelled="true"><mrow><mo>(</mo><mi>a</mi><mo>-</mo><mi>b</mi><mo>)</mo></mrow><mi>a</mi></mfrac>
  </mrow></math>

  <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
    <mtext>Eccentricity squared:</mtext><mspace width="3ex"/>
    <msup><mi>e</mi><mn>2</mn></msup><mo> = </mo><mn>1</mn><mo>-</mo>
    <mfrac><msup><mi>b</mi><mn>2</mn></msup><msup><mi>a</mi><mn>2</mn></msup></mfrac>
    <mo> = </mo><mrow><mi>f</mi><mo>&times;</mo><mo>(</mo><mn>2</mn><mo>-</mo><mi>f</mi><mo>)</mo></mrow>
  </mrow></math>

  <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
    <mtext>Second eccentricity squared:</mtext><mspace width="3ex"/>
    <msup><mi>e</mi><mrow><mo>&prime;</mo><mn>2</mn></mrow></msup>
    <mo> = </mo><mfrac><msup><mi>a</mi><mn>2</mn></msup><msup><mi>b</mi><mn>2</mn></msup></mfrac><mo>-</mo><mn>1</mn>
    <mo> = </mo><mfrac><mrow><mi>f</mi><mo>&times;</mo><mo>(</mo><mn>2</mn><mo>-</mo><mi>f</mi><mo>)</mo></mrow><msup><mrow><mo>(</mo><mn>1</mn><mo>-</mo><mi>f</mi><mo>)</mo></mrow><mn>2</mn></mfrac>
  </mrow></math>
**/
struct Ellipsoid {
  private string _shortname;
  private string _name;
  private real _a; // Semi-major axis
  private real _b; // Semi-minor axis
  private real _f; // Flattening
  private string _comment;
  this (string shortname, string name, const real a, const real b, const real f, string comment) {
    this._shortname = shortname;
    this._name = name;
    this._a = a;
    this._b = b;
    this._f = f;
    this._comment = comment;
  }
  /** Get short name **/
  const string shortname () pure nothrow @safe @nogc { return this._shortname; }
  /** Get name **/
  const string name () pure nothrow @safe @nogc { return this._name; }
  /** Get comment **/
  const string comment () pure nothrow @safe @nogc { return this._comment; }
  /** Get semi-minor-axis **/
  const real a () pure nothrow @safe @nogc { return _a; }

  /** Get inverse flattening 1/f **/
  const real f () pure nothrow @safe @nogc { return (!_f.isNaN)? 1 / _f:1 / (_a-_b)/_a; }

  /** Get semi-minor-axis **/
  const real b () pure nothrow @safe @nogc { return (!_b.isNaN)? _b:_a * (1-_f); }

  /** Get first eccentricity squared **/
  const real e () pure nothrow @safe @nogc { return 1 / (_f * (2 - _f)); }

  /** Get second eccentricity squared **/
  const real e2 () pure nothrow @safe @nogc { import std.math: pow; return _f * (2-_f) / (1-_f).pow(2); }

  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    import std.uni: toUpper;
    sink("short: " ~ shortname ~ " name: " ~ name);
    sink(" a: " ~ _a.to!string);
    if (!_b.isNaN) sink(" b: " ~ _b.to!string);
    if (!_f.isNaN) sink(" 1/f: " ~ _f.to!string);
  }
  static auto opDispatch (string s) (string file = __FILE__, size_t line = __LINE__) {
    return Ellipsoid.name(s, file, line);
  }
  static auto name (string shortname, string file = __FILE__, size_t line = __LINE__) {
    return Ellipsoid.epsg(ellipsoidLookUp(shortname, file, line));
  }
  static auto epsg (long epsg, string file = __FILE__, size_t line = __LINE__) {
    import std.conv: to;
    return geoEllipsoid[epsg];
  }
}
/** **/
unittest {
  // Get ellipsoid
  auto wgs84 = Ellipsoid.epsg(7030);
  auto grs1967 = Ellipsoid.name("grs1967");
  auto clarke1880 = Ellipsoid.clarke1880;
  // Get details
  auto name = wgs84.name;
  auto a = wgs84.a;
}
/** Datums with associated ellipsoid
 **/
struct Datum {
  private string _shortname;
  private string _name;  /// Name of datum
  private size_t _epoch; /// Epoch of datum
  private long _ellipsoid;  /// epsg of reference ellipsoid
  private string _comment; /// Comment
  this(string shortname, string name, size_t epoch, long ellipsoid, string comment) {
    this._shortname = shortname;
    this._name = name;
    this._epoch = epoch;
    this._ellipsoid = ellipsoid;
    this._comment = comment;
  }
  /** Get short name **/
  const string shortname () pure nothrow @safe @nogc { return this._shortname; }
  /** Get name **/
  const string name () pure nothrow @safe @nogc { return this._name; }
  /** Get comment **/
  const string comment () pure nothrow @safe @nogc { return this._comment; }
  /** Get the reference ellipsoid **/
  Ellipsoid ellipsoid () pure nothrow @safe { return Ellipsoid.epsg(_ellipsoid); }
  /** **/
  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    import std.uni: toUpper;
    sink("shortname: " ~ this._shortname ~ " name: " ~ this._name );
    if (this._epoch != 0) sink(" epoch: " ~ this._epoch.to!string);
    sink(" ellipsoid: " ~ Ellipsoid.epsg(this._ellipsoid)._shortname ~ " (epsg:" ~ this._ellipsoid.to!string ~ ")");
  }
  /** Get datum by shortname (ufcs)


      Returns: Datum
      Throws: Throws DatumException if datum was not found.
  **/
  static auto opDispatch (string s) (string file = __FILE__, size_t line = __LINE__) {
    return Datum.name(s, file, line);
  }
  /** Get datum by shortname

      Params:
        shortname = Short name of datum
        file = File
        line = line
      Returns: Datum
      Throws: Throws DatumException if datum was not found.
  **/
  static auto name (string shortname, string file = __FILE__, size_t line = __LINE__) {
    import std.exception: enforce;
    enforce!DatumException(shortname in datumLUT, "Datum not found!", file, line);
    return geoDatum[datumLUT[shortname]];
  }
  /** Get datum by epsg code

    Params:
      epsg = The epsg code of the datum
      file = File
      line = line
    Returns: Datum
    Throws: Throws DatumException if datum was not found.
  **/
  static auto epsg (long epsg, string file = __FILE__, size_t line = __LINE__) {
    import std.exception: enforce;
    enforce!DatumException(epsg in geoDatum, "Ellipsoid not found!", file, line);
    return geoDatum[epsg];
  }
}
/** **/
unittest {
  writefln("wgs84 %s", Datum.epsg(6326));
  writefln("wgs84 %s", Datum.name("wgs84"));
  writefln("wgs84 %s", Datum.wgs84);
}

const Datum defaultDatum;

/** Get epsg code of an ellipsoid by its name

    Params:
      shortname = Short name of ellipsoid
      file = File
      line = Line 
    Returns: The epsg code of the ellipsoid
    Throws: Throws DatumException if name was not found.
**/
long ellipsoidLookUp (string shortname, string file = __FILE__, size_t line = __LINE__) {
  import std.exception;
  //long* epsg = (shortname in ellipsoidLUT);
  enforce!DatumException(shortname in ellipsoidLUT, "Name of ellipsoid not found in lookup table!", file, line);
  return ellipsoidLUT[shortname];
}

immutable Ellipsoid[long] geoEllipsoid;  /// Ellipsoids indexed by epsg
immutable Datum[long] geoDatum;          /// Datums indexed by epsg
immutable long[string] ellipsoidLUT;      /// Ellipsoid epsg indexed by name
immutable long[string] datumLUT;          /// Datum epsg indexed by name

// Read csv files at module start
shared static this() {
  import std.exception : assumeUnique;
  import std.array;
  import std.algorithm;
  import std.stdio;
  import std.csv;
  import std.range;
  import std.conv;
  static long idxEllipsoid = 0; // counter for ellipsoids without epsg code
  static long idxDatum = 0;     // counter for datums without epsg code
  // Ellipsoid
  Ellipsoid[long] tmpEllipsoid;
  foreach (eLines;import("ellipsoid.csv").parseCSV) {
    try{
      auto fields = eLines.convertCSV!(long, string, string, real, real, real, string);
      if (fields[0] <= 0) fields[0] = idxEllipsoid--;
      ellipsoidLUT[fields[1]] = fields[0];
      tmpEllipsoid[fields[0]] = Ellipsoid(fields[1], fields[2], fields[3], fields[4], fields[5], fields[6]);
    } catch (Exception e) {
      writefln("Failed to convert! " ~ e.msg);
    }
  }
  tmpEllipsoid.rehash;
  geoEllipsoid = assumeUnique(tmpEllipsoid);

  // Datums
  Datum[long] tmpDatum;
  foreach (eDatum;import("datum.csv").parseCSV) {
    try {
      auto fields = eDatum.convertCSV!(long, string, string, ulong, long,string);
      if (fields[0] <= 0) fields[0] = idxDatum--;
      datumLUT[fields[1]] = fields[0];
      tmpDatum[fields[0]] = Datum(fields[1], fields[2], fields[3], fields[4], fields[5]);
    } catch (Exception e) {
      writefln("Failed to convert! " ~ e.msg);
    }
  }
  // Check if reference ellipsoids are valid
  foreach (d; tmpDatum) {
    assert((d._ellipsoid in geoEllipsoid) != null, "Can't find an ellipsoid with the epsg code " ~ d._ellipsoid.to!string ~ " in datum " ~ d.name);
  }
  tmpDatum.rehash;
  geoDatum = assumeUnique(tmpDatum);

  defaultDatum = Datum.epsg(6326);
}

/** Reads unformatted csv string

  Params:
    csv = csv string
    fieldSeparator = Char  (default: comma)
    lineSeparator = Char (default: newline)
  Returns: 3D-Array of lines and fields
  Standards: The parser loosely follows the [RFC-4180](http://tools.ietf.org/html/rfc4180).

    - Lines are separated by a newline (customizable).
    - Fields are separated by a comma (customizable).
    - A final record may end with a newline
    - A field containing new lines, commas, or double quotes should be enclosed in quotes.
    - Each record must contain the same number of fields
    - Comments start with an asteriks.
    - Lines starting with an asteriks are comments end don't get parsed.
    - Comments can appear after the last field of a line.

  Throws: If number of fields differ.
**/
private auto parseCSV (string csv) pure @safe {
  enum char commaChar = 0x002c; // ,
  enum char eolChar = 0x000a;   // newline
  return parseCSV(csv, commaChar, eolChar);
}
/** ditto **/
private auto parseCSV (string csv, char fieldSeparator, char lineSeparator) pure @safe {
  import std.string: strip;
  import std.algorithm: map, filter, splitter;
  import std.range: empty;
  enum char numberChar = 0x0023;      // #
  auto lines = csv.splitter(lineSeparator)  // split lines
                  .map!(a => a.strip)
                  .filter!(a => (!a.empty && a[0] != numberChar));  // filter empty lines and comment lines
  return lines.map!(a => a.strip.parseCSVImpl(fieldSeparator)).filter!(a => !a.empty);
}
/** **/
unittest{
  import std.array;
  string csv =
  `#name,age,gender
  steven,15,male
  "maria",20,female
  snoopy,15,`;
  assert(csv.parseCSV.array == [["steven", "15", "male"],["maria", "20", "female"],["snoopy","15",""]]);
}
/** Parses a line of csv fields **/
private string[] parseCSVImpl (string csv, char fieldSeparator, string[] fields = []) pure @safe {
  import std.range: front, empty, array;
  import std.algorithm: canFind, findSplit, findSkip;
  import std.conv: to;
  import std.string: stripLeft, strip;
  enum dchar quotationChar = 0x0022;   // "
  enum dchar apostropheChar = 0x0027;  // '
  enum dchar[] quoteChars = [apostropheChar, quotationChar];
  string[3] split;
  csv = csv.stripLeft;
  // if field is quoted
  if (csv.empty) return fields ~ "";
  if (quoteChars.canFind(csv.front)) {
    // s[0]: before needle s[1]: needle s[2]: after needle
    split = csv[1..$].findSplit(csv.front.to!string).array;
    // is this the last field? if so we don't find another field separator
    if (split[2].findSkip(fieldSeparator.to!string) == false) {
      return fields ~ split[0];
    }
    // unquoted field
  } else {
    split = csv.findSplit(fieldSeparator.to!string).array;
    split[2] = split[2].stripLeft;
    // is this the last field? if so we don't find another field separator
    if (split[1].empty) {
      return fields ~ split[0];
    } else if (split[2].empty) {
      split[2] = "";
    }
    split[0] = split[0].strip;
  }
  return parseCSVImpl(split[2], fieldSeparator, fields ~ split[0]);
}
unittest {
  assert("tom, 4, true".parseCSVImpl(',') == ["tom", "4", "true"]);
  assert(`"tom", 4, true, `.parseCSVImpl(',') == ["tom", "4", "true", ""]);
  assert("tom\t 4\t true\t ".parseCSVImpl('\t') == ["tom", "4", "true", ""]);
}
/**
unittest {
  import std.typecons;
  // run-time
  string csv1 =
  `steven,15,male
  maria,20,female`;
  string csv2 =
  `"thomas",25,male
  'sybille', 30,female`;
  string csv3 =
  `"tom, jerry", 70, ''`;
  string csv4 =
  `# name, age, sex`;
  string csv5 =
  `shorty, 10, male # just a comment`;
  parseCSV(csv1);
  parseCSV(csv1 ~ "\n" ~ csv2);
  parseCSV(csv1 ~ "\n" ~ csv3);
  parseCSV(csv4 ~ "\n" ~ csv1);
  writefln ("commented line %s", parseCSV(csv1 ~ "\n" ~ csv5));
  // compile-time
  enum text = "a,1 ,true\n' b, b2 ',2,false\n# \n \n c,3,true\n";
  enum r = parseCSV(text);
  writefln ("ct csv %s", r);
}
**/
/** Convert csv line string to types

  Params:
    fields = csv line as field-strings
  Returns: Tuple
  Throws: Throws DatumException if conversion fails.
**/
private auto convertCSV (T...) (string[] fields) {
  import std.typecons;
  import std.conv;
  import std.array;
  import std.exception: enforce;
  alias Line = Tuple!T;
  Line line;
  if (!fields.length) return line;
  enforce!DatumException(T.length == fields.length, "Number of types doesn't match number of fields in line " ~ fields.join(", "));
  static foreach (i; 0..T.length) {
    try {
      if (fields[i].empty) line[i] = T[i].init;
      else line[i] = fields[i].to!(T[i]);
    } catch (Exception e) { throw new DatumException("Failed to convert! " ~ fields[i] ~ " " ~ e.msg); }
  }
  return line;
}
/**
unittest{
  auto csv = [
    ["steve", "10", "true"],
    ["marc", "20", "false"],
    ["snoopy", "nan", "false"]];
  //writefln("convert csv %s", convertCSV!(string, double, bool)(csv));
}
**/
