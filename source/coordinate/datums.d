/** Definitions of geographic datums **/
module coordinate.datums;

import std.math: isNaN;

debug import std.stdio;


/** Ellipsoid parameters

    An ellipsoid is defined by its semi-major axis (*a*), semi-minor axis (*b*), and flattening (*f*).
    <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
        <mi>f</mi><mo> = </mo>
        <mfrac bevelled="true"><mrow><mo>(</mo><mi>a</mi><mo>-</mo><mi>b</mi><mo>)</mo></mrow><mi>a</mi></mfrac>
    </mrow></math>
**/
struct Ellipsoid {
   string name;
   real _a; // Semi-major axis
   real _b; // Semi-minor axis
   real _f; // Flattening
   string comment;
  this (string name, const real a, const real b, const real f, string comment) {
    this.name = name;
    this._a = a;
    this._b = b;
    this._f = f;
    this.comment = comment;
  }

  /** Semi-minor-axis

    <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
      <mi>b</mi><mo> = </mo><mi>a</mi><mo>*</mo><mo>(</mo><mn>1</mn><mo>-</mo><mi>f</mi><mo>)</mo>
    </mrow></math>
  **/
  const real a () { return _a; }

  /** Flattening

    <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
        <mi>f</mi><mo> = </mo>
        <mfrac bevelled="true"><mrow><mo>(</mo><mi>a</mi><mo>-</mo><mi>b</mi><mo>)</mo></mrow><mi>a</mi></mfrac>
    </mrow></math>
    Returns: Inverse flattening 1/f
  **/
  const real f () { return (!_f.isNaN)? 1 / _f:1 / (_a-_b)/_a; }

  /** Semi-minor-axis

    <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
      <mi>b</mi><mo> = </mo><mi>a</mi><mo>&times;</mo><mo>(</mo><mn>1</mn><mo>-</mo><mi>f</mi><mo>)</mo>
    </mrow></math>
  **/
  const real b () { return (!_b.isNaN)? _b:_a * (1-_f); }

  /** First eccentricity squared

    <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
      <msup><mi>e</mi><mn>2</mn></msup><mo> = </mo><mn>1</mn><mo>-</mo>
      <mfrac><msup><mi>b</mi><mn>2</mn></msup><msup><mi>a</mi><mn>2</mn></msup></mfrac>
      <mo> = </mo><mrow><mi>f</mi><mo>&times;</mo><mo>(</mo><mn>2</mn><mo>-</mo><mi>f</mi><mo>)</mo></mrow>
    </mrow></math>
  **/
  const real e () { return 1 / (_f * (2 - _f)); }

  /** Second eccentricity squared

      <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
        <msup><mi>e</mi><mrow><mo>&prime;</mo><mn>2</mn></mrow></msup>
        <mo> = </mo><mfrac><msup><mi>a</mi><mn>2</mn></msup><msup><mi>b</mi><mn>2</mn></msup></mfrac><mo>-</mo><mn>1</mn>
        <mo> = </mo><mfrac><mrow><mi>f</mi><mo>&times;</mo><mo>(</mo><mn>2</mn><mo>-</mo><mi>f</mi><mo>)</mo></mrow><msup><mrow><mo>(</mo><mn>1</mn><mo>-</mo><mi>f</mi><mo>)</mo></mrow><mn>2</mn></mfrac>
      </mrow></math>
  **/
  const real e2 () { import std.math: pow; return _f * (2-_f) / (1-_f).pow(2); }

  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    import std.uni: toUpper;
    sink("name: " ~ name ~ " " ~ "a: " ~ _a.to!string);
    if (!_b.isNaN) sink(" b: " ~ _b.to!string);
    if (!_f.isNaN) sink(" 1/f: " ~ _f.to!string);
  }
}

/** Datums with associated ellipsoid
 **/
struct Datum {
  string name;  /// Name of datum
  size_t epoch; /// Epoch of datum
  private size_t _ellipsoid;  /// epsg of reference ellipsoid
  string comment; /// Comment
  this(string name, size_t epoch, size_t ellipsoid, string comment) {
    this.name = name;
    this.epoch = epoch;
    this._ellipsoid = ellipsoid;
    this.comment = comment;
  }
  /** Get the reference ellipsoid **/
  Ellipsoid ellipsoid () { return geoEllipsoid[_ellipsoid]; }
  /** **/
  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    import std.uni: toUpper;
    sink("name: " ~ this.name );
    if (epoch != 0) sink(" epoch: " ~ epoch.to!string);
    sink(" ellipsoid: " ~ getEllipsoid(this._ellipsoid).name);
  }
}

const Datum defaultDatum;
/** Get ellipsoid by name or epsg code

  Params:
    name = Name of the ellipsoid
    epsg = Epsg Code of the ellipsoid
  Returns: Ellipsoid
**/
Ellipsoid getEllipsoid (string name) {
  return getEllipsoid(ellipsoidLUT[name]);
}
/** ditto **/
Ellipsoid getEllipsoid (size_t epsg) {
  return geoEllipsoid[epsg];
}
size_t ellipsoidLookUp (string name, string file = __FILE__, size_t line = __LINE__) {
  import std.exception;
  size_t* epsg = (name in ellipsoidLUT);
  enforce!Exception(epsg !is null, "Name of ellipsoid not found in lookup table!", file, line);
  return *epsg;
}
immutable Ellipsoid[size_t] geoEllipsoid;  /// Ellipsoids indexed by epsg
immutable Datum[size_t] geoDatum;          /// Datums indexed by epsg
private size_t[string] ellipsoidLUT;      /// Ellipsoid epsg indexed by name
private size_t[string] datumLUT;          /// Datum epsg indexed by name

/** Get a Datum

  Params:
    name = Name of the datum
    epsg = Epsg Code of the datum
  Returns: Datum
**/
Datum getDatum (string name) {
  return getDatum(datumLUT[name]);
}
/** ditto **/
Datum getDatum (size_t epsg) {
  return geoDatum[epsg];
}

shared static this() {
  import std.exception : assumeUnique;
  import std.array;
  import std.algorithm;
  import std.stdio;
  import std.csv;
  import std.range;
  import std.conv;
  Ellipsoid[size_t] tmpEllipsoid;
  //ellipsoidLUT["wgs1984"] = 0;
  //tmpEllipsoid[0] = Ellipsoid("wgs1984", 0, 0, 0, "");
  foreach (eLines;import("ellipsoid.csv").parseCSV) {
    //writefln ("line %s", eLines);

    auto fields = eLines.convertCSV!(ulong, string,real,real,real,string);
    //writefln ("\nfields: %s %s", fields[0], fields[1]);
    ellipsoidLUT[fields[1]] = fields[0];
    tmpEllipsoid[fields[0]] = Ellipsoid(fields[1], fields[2], fields[3], fields[4], fields[5]);
  }
  tmpEllipsoid.rehash;
  geoEllipsoid = assumeUnique(tmpEllipsoid);
  foreach (e; geoEllipsoid) writefln("geoEllipsoid: %s", e);
  //writefln ("ellipsoidLUT %s", ellipsoidLUT);

  Datum[size_t] tmpDatum;
  //datumLUT["wgs1984"] = 0;
  //tmpDatum[0] = Datum("wgs1984", ellipsoidLookUp("wgs1984", __FILE__, __LINE__), 0, "");
  foreach (eDatum;import("datum.csv").parseCSV) {
    //writefln ("try converting %s", eDatum);
    try {
      auto fields = eDatum.convertCSV!(ulong, string, ulong, ulong,string);
      datumLUT[fields[1]] = fields[0];
      tmpDatum[fields[0]] = Datum(fields[1], fields[2], fields[3], fields[4]);
    }
    catch (Exception e) {
      //writefln("Failed to convert!");
    }
  }
  foreach (d; tmpDatum) {
    assert((d._ellipsoid in geoEllipsoid) != null, "Can't find an ellipsoid with the epsg code " ~ d._ellipsoid.to!string ~ " in datum " ~ d.name);
  }
  tmpDatum.rehash;
  geoDatum = assumeUnique(tmpDatum);

  defaultDatum = getDatum(6326);
  /++
  Ellipsoid undefinedEllipsoid = Ellipsoid(real.nan, real.nan, real.nan, 0);
  Ellipsoid[string] tmpEllipsoid = [
  "undefined":      Ellipsoid(real.nan, real.nan, real.nan, 0),    // undefined ellipsoid
  "grs1980authalic":  Ellipsoid(6370997.0, 6370997.0, real.nan, 7048),  // GRS 1980 authalic sphere (r=6370997)
  // --- A ---
  "airy1830":       Ellipsoid(6377563.396, 6356256.909, 1/299.3249646, 7001), // Airy 1830
  "airyModified":   Ellipsoid(6377340.189, 6356034.448, 1/299.3249646, 7002), // Modified Airy
  "andrae":         Ellipsoid(6377104.43, real.nan, 1/300.0, 0), // Andrae 1876 (Den., Iclnd.)
  "apl4.9":         Ellipsoid(6378137.0, real.nan, 1/298.25, 0), // Appl. Physics. 1965
  "ats1977":        Ellipsoid(6378135.0, real.nan, 1/298.257, 7041),  // Average Terrestrial System of 1977
  "australian":     Ellipsoid(6378160, real.nan, 1/298.25, 7003), // Australian National & S. Amer. 1969
  // --- B ---
  "bessel1841":     Ellipsoid(6377397.155, 6356078.962818, 1/299.1528128, 7004),
  "besselMod":      Ellipsoid(6377492.018, real.nan, 1/299.1528128, 7005),  // Bessel Modified
  "besselNamibia":  Ellipsoid(6377483.865, real.nan, 1/299.1528128, 7046),  // Bessel Namibia (GLM)
  // --- C ---
  "clarke1858":     Ellipsoid(6378293.639, real.nan, 1/294.2606764, 7007),
  "clarke1866":     Ellipsoid(6378206.4, 6356583.8, real.nan, 7008),
  "clarke1880":     Ellipsoid(6378249.145, real.nan, 1/293.465, 7034),  // Clarke 1880
  "clarke1880mod":  Ellipsoid(6378249.145, real.nan, 1/293.4663, 7012), // Clarke 1880 mod (Clarke 1880 RGS)
  "clarke1980ign":  Ellipsoid(6378249.2, real.nan, 1/293.4660212936269, 7011),  // Clarke 1880 (IGN).
  "cpm1799":        Ellipsoid(6375738.7, real.nan, 1/334.29, 0),  // Comm. des Poids et Mesures 1799
  // --- D ---
  "danish":         Ellipsoid(6377019.2563, real.nan, 1/300.0, 7051), // Andrae 1876 (Denmark, Iceland)
  "delmbr":         Ellipsoid(6376428, real.nan, 1/311.5, 0),  // Delambre 1810 (Belgium)
  // --- E ---
  "engelis":        Ellipsoid(6378136.05, real.nan, 1/298.2566, 0),  // Engelis 1985
  "everest1830":    Ellipsoid(6377276.345, real.nan, 1/300.8017, 7042),  // Everest 1830 Definition
  "everest1830mod": Ellipsoid(6377304.063, real.nan, 1/300.8017, 7018), // Everest 1830 Modified
  "everest1937":    Ellipsoid(6377276.345, real.nan, 1/300.8017, 7015), // Everest 1830 (1937 Adjustement) India
  "everest1962":    Ellipsoid(6377301.243, real.nan, 1/300.8017255, 7044), // Everest 1830 (1962 Definition) Pakistan
  "everest1967":    Ellipsoid(6377298.556, real.nan, 1/300.8017, 7016), // Everest 1830 (1967 Definition Sabah & Sarawak)
  "everest1969":    Ellipsoid(6377295.664, real.nan, 1/300.8017, 7056), // Everest 1830 RSO 1969 (Modified 1969) Malaysia
  "everest1975":    Ellipsoid(6377299.151, real.nan, 1/300.8017255, 7045),  // Everest definition 1975
  // --- F ---
  "fischer1960":    Ellipsoid(6378166, real.nan, 1/298.3, 107002),  // Fischer (Mercury Datum) 1960
  "fischer1960mod": Ellipsoid(6378155, real.nan, 1/298.3, 0),  // Modified Fischer 1960
  "fischer1968":    Ellipsoid(6378150, real.nan, 1/298.3, 107003),  // Fischer 1968
  // --- G ---
  "gem10c":         Ellipsoid(6378137, real.nan, 1/298.257223563, 7031),  // Goddard Earth Model (Gravitational field models) Used for GEM 10C Gravity Potential Model
  "grs1967":        Ellipsoid(6378160, real.nan, 1/298.247167427, 7036),  // grs1967 = intl1967
  "grs1967trunc":   Ellipsoid(6378160, real.nan, 1/298.25, 107036), // grs 1967 truncated
  "grs1980":        Ellipsoid(6378137.0, real.nan, 1/298.257222101, 7019),  // GRS 1980(IUGG, 1980)
  "gsk2011":        Ellipsoid(6378136.5, real.nan, 1/298.2564151, 1025),
  // --- H ---
  "helmert1906":    Ellipsoid(6378200, real.nan, 1/298.3, 7020),
  "hough1960":      Ellipsoid(6378270, real.nan, 1/297, 7053),
  // --- I ---
  "iau1976":        Ellipsoid(6378140.0, real.nan, 1/298.257, 0),  // IAU 1976
  "indonesianNational": Ellipsoid(6378160, real.nan, 1/298.247, 7021),  // Indonesian 1974
  "intl1924":       Ellipsoid(6378388.0, 6356911.946, 1/297, 7022), // International 1924
  "intl1967":       Ellipsoid(6378160.0, real.nan, 1/298.25, 7023),  // International 1967
  // --- K ---
  "kaula":          Ellipsoid(6378163, real.nan, 1/298.24, 0),  // Kaula 1961
  "krassowsky1940": Ellipsoid(6378245.0, 6356750.5, 1/298.3, 7024), // Krassovsky 1942
  // --- L ---
  "lerch":          Ellipsoid(6378139, real.nan, 1/298.257, 0),  // Lerch 1979
  // --- M ---
  "maupertius":     Ellipsoid(6397300, real.nan, 1/191, 0),  // Maupertius 1738
  "merit":          Ellipsoid(6378137.0, real.nan, 1/298.257, 0),  // Merit 1983
  // --- N ---
  "nwl9d":          Ellipsoid(6378145.0, real.nan, 1/298.25, 7025), // Naval Weapons Lab., 1965
  // --- O ---
  "osu1986":        Ellipsoid(6378136.2, real.nan, 1/298.25722, 7032),  // OSU 86 geoidal model
  "osu1991":        Ellipsoid(6378136.3, real.nan, 1/298.25722, 7033),  // OSU 91 geoidal model
  // --- P ---
  "plessis1817":    Ellipsoid(6376523, real.nan, 1/308.64, 7027),
  "pz90":           Ellipsoid(6378136.0, real.nan, 1/298.25784, 7054),  // PZ-90
  // --- S ---
  "seasia":         Ellipsoid(6378155.0, 6356773.3205, real.nan, 0), // Southeast Asia
  "sgs1985":        Ellipsoid(6378136.0, real.nan, 1/298.257, 0),  // Soviet Geodetic System 1985
  "struve1860":     Ellipsoid(6378298.3, real.nan, 1/294.73, 7028),
  // --- W ---
  "walbeck":        Ellipsoid(6376896, real.nan, 1/302.78, 107007),
  "wgs1960":        Ellipsoid(6378165.0, real.nan, 1/298.3, 0),
  "wgs1966":        Ellipsoid(6378145, real.nan, 1/298.25, 107001),
  "wgs1972":        Ellipsoid(6378135.0, real.nan, 1/298.26, 7043),
  "wgs1984":        Ellipsoid(6378137.0, real.nan, 1/298.257223563, 7030),

  ];
  ++/



  /++
  Datum[string] tmpDatum = [
  "osgb36":     Datum(6277, geoEllipsoid["airy1830"],     [-446.448, 125.157,-542.060, -0.1502,-0.2470,-0.8421, 20.4894]),
  "irl1975":    Datum(0, geoEllipsoid["airyModified"], [-482.530,130.596,-564.557, -1.042,-0.214,-0.631, -8.150]),
  "tokyoJapan": Datum(0, geoEllipsoid["bessel1841"],   [148.0,-507.0,-685.0, 0.0,0.0,0.0, 0.0]),
    // --- A ---
    "adindan":    Datum(6201, geoEllipsoid["clarke1880"],   [-165.0,-11.0,206.0,0.0,0.0,0.0,0.0]),
    "afgooye":    Datum(6205, geoEllipsoid["krassowsky1940"],[-43.0,-163.0,45.0,0.0,0.0,0.0,0.0]),
    "agadez":     Datum(6206, geoEllipsoid["clarke1880"], []),
    "ainelabd":   Datum(0, geoEllipsoid["intl1924"], []),
    "australianGeod1966":     Datum(6202, geoEllipsoid["australian"], [-124.133,-42.003,137.4,-0.008,-0.557,-0.178,-0.3824149507821167]),
    "australianGeod1984":     Datum(6203, geoEllipsoid["australian"], [-117.763,-51.51,139.061,0.292,-0.443,-0.277,-0.03939657799319541]),
    "alaskanIslands":     Datum(0, geoEllipsoid["clarke1866"], []),
    "americanSamoa1962":  Datum(0, geoEllipsoid["clarke1866"], []),
    "amersfoort":     Datum(0, geoEllipsoid["bessel1841"], []),
    "anguilla1957":     Datum(0, geoEllipsoid["clarke1880"], []),
    "anna1965":     Datum(0, geoEllipsoid["australian"], []),
    "antigua1943":     Datum(0, geoEllipsoid["clarke1880"], []),
    "aratu":     Datum(0, geoEllipsoid["intl1924"], []),
    "arc1950":     Datum(6209, geoEllipsoid["clarke1880"], [-138.0,-105.0,-289.0,0.0,0.0,0.0,0.0]),
    "arc1960":     Datum(6210, geoEllipsoid["clarke1880"], [-157.0,-2.0,-299.0,0.0,0.0,0.0,0.0]),
    "ascensionIsland1958":     Datum(0, geoEllipsoid["intl1924"], []),
    "astro1952":     Datum(0, geoEllipsoid["intl1924"], []),
    "ayabelle":     Datum(6713, geoEllipsoid["clarke1880"], [-79,-129,145,0,0,0,0]),  // Ayabelle_Lighthouse
    // --- B ---
    // --- E ---
    "ed1950":       Datum(0, geoEllipsoid["intl1924"],     [89.5,93.8,123.1, 0.0,0.0,0.156, -1.2]),
    "ed1977":       Datum(0, geoEllipsoid["intl1924"],     []),
    "ed1987":       Datum(0, geoEllipsoid["intl1924"],     []),

    "etrf1989":     Datum(0, geoEllipsoid["wgs1984"], []),
    "european1979":     Datum(0, geoEllipsoid["intl1924"], []),
    "europeanLibyan1979":    Datum(0, geoEllipsoid["intl1924"], []),
    "everestBangladesh":     Datum(0, geoEllipsoid["everest1830"], []),
    "everestIndiaNepal":     Datum(0, geoEllipsoid["everest1975"], []),
    // --- N ---
    "nad1927":      Datum(0, geoEllipsoid["clarke1866"],   [8.0,-160.0,-176.0, 0.0,0.0,0.0, 0.0]),
    "nad1983":      Datum(0, geoEllipsoid["grs1980"],        [1.004,-1.910,-0.515, 0.0267,0.00034,0.011, -0.0015]),
    // --- W ---
    "wgs1972":      Datum(0, geoEllipsoid["wgs1972"],        [0.0,0.0,-4.5, 0.0,0.0,0.554, -0.22]),
    "wgs1984":      Datum(0, geoEllipsoid["wgs1984"],        [0.0,0.0,0.0, 0.0,0.0,0.0, 0.0])
  ];

  tmpDatum.rehash;
  geoDatum = assumeUnique(tmpDatum);
  ++/
}
unittest {
  //writefln ("Ellipsoid list %s", geoEllipsoid);
  //writefln ("Datum list %s", geoDatum);
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
auto parseCSV (string csv) {
  enum char commaChar = 0x002c; // ,
  enum char eolChar = 0x000a;   // newline
  return parseCSV(csv, commaChar, eolChar);
}
/** ditto **/
auto parseCSV (string csv, char fieldSeparator, char lineSeparator) {
  import std.string: strip, stripLeft, stripRight, splitLines;
  import std.algorithm: map, filter, splitter, canFind, countUntil, substitute;
  import std.array: empty, split;
  import std.range;
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
string[] parseCSVImpl (string csv, char fieldSeparator, string[] fields = []) {
  import std.range;
  import std.algorithm;
  import std.conv;
  import std.exception;
  import std.string;
  enum dchar quotationChar = 0x0022;   // "
  enum dchar apostropheChar = 0x0027;  // '
  enum dchar[] quoteChars = [apostropheChar, quotationChar];
  string[3] split;
  csv = csv.stripLeft;
  //writefln ("csv <%s>", csv);
  // if field is quoted
  if (csv.empty) return fields ~ "";
  if (quoteChars.canFind(csv.front)) {
    //writefln ("quoted field");
    // s[0]: before needle s[1]: needle s[2]: after needle
    split = csv[1..$].findSplit(csv.front.to!string).array;
    // is this the last field? if so we don't find another field separator
    if (split[2].findSkip(fieldSeparator.to!string) == false) {
      //writefln ("end of fields");
      return fields ~ split[0];
    } else {
      //writefln ("next char <%s>", split[2].front);
    }
    // unquoted field
  } else {
    //writefln("unquoted field");
    split = csv.findSplit(fieldSeparator.to!string).array;
    split[2] = split[2].stripLeft;
    //writefln ("split 0: <%s> 1: <%s>", split[0], split[1]);
    // is this the last field? if so we don't find another field separator
    if (split[1].empty) {
      //writefln ("end of fields");
      return fields ~ split[0];
    } else if (split[2].empty) {
      //writefln ("trailing comma");
      split[2] = "";
    } else {
      //writefln ("not the last field");
      //if (!split[2].empty) writefln ("next char <%s>", split[2].front);
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
auto convertCSV (T...) (string[] csv) {
  import std.typecons;
  import std.conv;
  alias Line = Tuple!T;
  Line line;
  //writefln("convertCSV %s", csv);
  if (!csv.length) return line;
  assert(T.length == csv.length, "Number of types doesn't match number of fields!");
  static foreach (i; 0..T.length) {
    line[i] = csv[i].to!(T[i]);
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
