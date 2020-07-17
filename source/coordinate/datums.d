/** Definitions of geographic datums **/
module coordinate.datums;

import std.math: isNaN;
debug import std.stdio;

/** Ellipsoid parameters

    An ellipsoid is defined by its semi-major axis (*a*), semi-minor axis (*b*), and flattening (*f*).

**/
struct Ellipsoid {
  const real a; // Semi-major axis
  const real _b; // Semi-minor axis
  const real _f; // Flattening
  const ulong epsg; // EPSG Code
  this (const real a, const real b, const real f, ulong epsg) {
    this.a = a;
    this._b = b;
    this._f = f;
    this.epsg = epsg;
  }
  /** Flattening

    <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
        <mi>f</mi><mo> = </mo>
        <mfrac bevelled="true"><mrow><mo>(</mo><mi>a</mi><mo>-</mo><mi>b</mi><mo>)</mo></mrow><mi>a</mi></mfrac>
    </mrow></math>
  **/
  const real f () { return (!_f.isNaN)? _f:(a-b)/a; }

  /** Semi-minor-axis

    <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
      <mi>b</mi><mo> = </mo><mi>a</mi><mo>&times;</mo><mo>(</mo><mn>1</mn><mo>-</mo><mi>f</mi><mo>)</mo>
    </mrow></math>
  **/
  const real b () { return (!_b.isNaN)? _b:a * (1-f); }

  /** First eccentricity squared

    <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
      <msup><mi>e</mi><mn>2</mn></msup><mo> = </mo><mn>1</mn><mo>-</mo>
      <mfrac><msup><mi>b</mi><mn>2</mn></msup><msup><mi>a</mi><mn>2</mn></msup></mfrac>
      <mo> = </mo><mrow><mi>f</mi><mo>&times;</mo><mo>(</mo><mn>2</mn><mo>-</mo><mi>f</mi><mo>)</mo></mrow>
    </mrow></math>
  **/
  real e () { return f * (2 - f); }

  /** Second eccentricity squared

      <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
        <msup><mi>e</mi><mrow><mo>&prime;</mo><mn>2</mn></mrow></msup>
        <mo> = </mo><mfrac><msup><mi>a</mi><mn>2</mn></msup><msup><mi>b</mi><mn>2</mn></msup></mfrac><mo>-</mo><mn>1</mn>
        <mo> = </mo><mfrac><mrow><mi>f</mi><mo>&times;</mo><mo>(</mo><mn>2</mn><mo>-</mo><mi>f</mi><mo>)</mo></mrow><msup><mrow><mo>(</mo><mn>1</mn><mo>-</mo><mi>f</mi><mo>)</mo></mrow><mn>2</mn></mfrac>
      </mrow></math>
  **/
  real e2 () { import std.math: pow; return f * (2-f) / (1-f).pow(2); }
  void toString(scope void delegate(const(char)[]) sink) const {
    import std.conv: to;
    import std.uni: toUpper;
    sink("epsg: " ~ epsg.to!string ~ " " ~ "a: " ~ a.to!string);
    if (!_b.isNaN) sink(" b: " ~ _b.to!string);
    if (!_f.isNaN) sink(" 1/f: " ~ _f.to!string);
  }
}



/** Datums with associated ellipsoid, and Helmert transform parameters to convert from WGS-84 into given datum.
 **/
struct Datum {
  const ulong epsg;
  immutable Ellipsoid ellipsoid;  ///
  const real[] transform;  ///
  this(ulong epsg, Ellipsoid e, real[] t) {
    this.epsg = epsg;
    this.ellipsoid = e;
    this.transform = t;
  }
}

immutable Ellipsoid[string] geoEllipsoid;  ///
const Datum[string] geoDatum;          ///
shared static this() {
  Ellipsoid undefinedEllipsoid = Ellipsoid(real.nan, real.nan, real.nan, 0);
  geoEllipsoid = [
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

  geoDatum = [
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
}
unittest {
  foreach (e; geoEllipsoid.byKeyValue) {
    if (e.key == "undefined") continue;
      assert(!e.value.a.isNaN);
      assert(!e.value.b.isNaN || !e.value.f.isNaN);
  }

  //writefln ("Ellipsoid list %s", geoEllipsoid);
  //writefln ("Datum list %s", geoDatum);
}
