/** Definitions of geographic datums **/
module coordinate.datums;

debug import std.stdio;

/** Ellipsoid parameters

    An ellipsoid is defined by its semi-major axis (*a*), semi-minor axis (*b*), and flattening (*f*).
    <math xmlns = "http://www.w3.org/1998/Math/MathML"><mrow>
        <mi>f</mi><mo> = </mo>
        <mfrac bevelled="true"><mrow><mo>(</mo><mi>a</mi><mo>-</mo><mi>b</mi><mo>)</mo></mrow><mi>a</mi></mfrac>
    </mrow></math>
**/
struct Ellipsoid {
  const real a; // Semi-major axis
  const real b; // Semi-minor axis
  const real f; // Flattening
  this (const real a, const real b, const real f) {
    this.a = a;
    this.b = b;
    this.f = f;
  }
}

/** Datums with associated ellipsoid, and Helmert transform parameters to convert from WGS-84 into given datum.
 **/
struct Datum {
  const Ellipsoid ellipsoid;  ///
  const real[] transform;  ///
  this(Ellipsoid e, real[] t) {
    this.ellipsoid = e;
    this.transform = t;
  }
}

const Ellipsoid[string] geoEllipsoid;  ///
const Datum[string] geoDatum;          ///
shared static this() {
  Ellipsoid undefinedEllipsoid = Ellipsoid(real.nan, real.nan, real.nan);
  geoEllipsoid = [
    "undefined":      Ellipsoid(real.nan, real.nan, real.nan),
    "airy1830":       Ellipsoid(6377563.396, 6356256.909, 1/299.3249646),
    "airyModified":   Ellipsoid(6377340.189, 6356034.448, 1/299.3249646),
    "ats1977":        Ellipsoid(6378135.0, real.nan, 1/298.257),  // Average Terrestrial System of 1977
    "australian":     Ellipsoid(6378160, real.nan, 1/298.25), // Australian National
    "bessel1841":     Ellipsoid(6377397.155, 6356078.962818, 1/299.1528128),
    "besselNamibia":  Ellipsoid(6377483.865, real.nan, 1/299.1528128),
    "clarke1858":     Ellipsoid(6378293.639, real.nan, 1/294.2606764),
    "clarke1866":     Ellipsoid(6378206.4, 6356583.8, 1/294.978698214),
    "clarke1880":     Ellipsoid(6378249.145, real.nan, 1/293.465),
    "everest1830":    Ellipsoid(6377276.345, real.nan, 1/300.8017),
    "everest1969":    Ellipsoid(6377295.664, real.nan, 1/300.8017), // Everest modified 1969
    "everest1975":    Ellipsoid(6377299.299, real.nan, 1/300.8017255),  // Everest definition 1975
    "fischer1960":    Ellipsoid(6378166, real.nan, 1/298.3),
    "fischer1968":    Ellipsoid(6378150, real.nan, 1/298.3),
    "fischerModified":  Ellipsoid(6378155, real.nan, 1/298.3),
    "gem2":           Ellipsoid(6378137, real.nan, 1/298.2572221),  // Goddard Earth Model (Gravitational field models)
    "grs1967":        Ellipsoid(6378160, real.nan, 1/298.247167427),  // grs1967 = intl1967
    "grs1967trunc":   Ellipsoid(6378160, real.nan, 1/298.25), // grs 1967 truncated
    "grs1980":        Ellipsoid(6378137.0, 6356752.314140, 1/298.257222101),
    "helmert1906":    Ellipsoid(6378200, real.nan, 1/298.3),
    "hough1960":      Ellipsoid(6378270, real.nan, 1/297),
    "indonesianNational": Ellipsoid(6378160, real.nan, 1/298.247),
    "intl1924":       Ellipsoid(6378388.0, 6356911.946, 1/297), // International 1924
    "intl1967":       Ellipsoid(6378160.0, real.nan, 1/298.25),  // International 1967
    "osu1986":        Ellipsoid(6378136.2, real.nan, 1/298.25722),  // OSU 86 geoidal model
    "osu1991":        Ellipsoid(6378136.3, real.nan, 1/298.25722),  // OSU 91 geoidal model
    "plessis1817":    Ellipsoid(6376523, real.nan, 1/308.64),
    "struve1860":     Ellipsoid(6378298.3, real.nan, 1/294.73),
    "walbeck":        Ellipsoid(6376896, real.nan, 1/302.78),
    "wgs1966":        Ellipsoid(6378145, real.nan, 1/298.25),
    "wgs1972":        Ellipsoid(6378135.0, 6356750.5, 1/298.26),
    "wgs1984":        Ellipsoid(6378137.0, 6356752.314245, 1/298.257223563),
    "krassowsky1940": Ellipsoid(6378245.0, 6356750.5, 1/298.3)

  ];

  geoDatum = [
    "osgb36":     Datum(geoEllipsoid["airy1830"],     [-446.448, 125.157,-542.060, -0.1502,-0.2470,-0.8421, 20.4894]),
    "irl1975":    Datum(geoEllipsoid["airyModified"], [-482.530,130.596,-564.557, -1.042,-0.214,-0.631, -8.150]),
    "tokyoJapan": Datum(geoEllipsoid["bessel1841"],   [148.0,-507.0,-685.0, 0.0,0.0,0.0, 0.0]),
    // --- A ---
    "adindan":    Datum(geoEllipsoid["clarke1880"],   []),
    "afgooye":    Datum(geoEllipsoid["krassowsky1940"],[]),
    "agadez":     Datum(geoEllipsoid["clarke1880"], []),
    "australianGeod1966":     Datum(geoEllipsoid["australian"], []),
    "australianGeod1984":     Datum(geoEllipsoid["australian"], []),
    "alaskanIslands":     Datum(geoEllipsoid["clarke1866"], []),
    "amersfoort":     Datum(geoEllipsoid["bessel1841"], []),
    "anguilla1957":     Datum(geoEllipsoid["clarke1880"], []),
    "anna1965":     Datum(geoEllipsoid["australian"], []),
    "antigua1943":     Datum(geoEllipsoid["clarke1880"], []),
    "aratu":     Datum(geoEllipsoid["intl1924"], []),
    "arc1950":     Datum(geoEllipsoid["clarke1880"], []),
    "arc1960":     Datum(geoEllipsoid["clarke1880"], []),
    "ascensionIsland1958":     Datum(geoEllipsoid["intl1924"], []),
    "astro1952":     Datum(geoEllipsoid["intl1924"], []),
    "ayabelle":     Datum(geoEllipsoid["clarke1880"], []),
    // --- B ---
    // --- E ---
    "ed1950":       Datum(geoEllipsoid["intl1924"],     [89.5,93.8,123.1, 0.0,0.0,0.156, -1.2]),
    "ed1977":       Datum(geoEllipsoid["intl1924"],     []),
    "ed1987":       Datum(geoEllipsoid["intl1924"],     []),

    "etrf1989":     Datum(geoEllipsoid["wgs1984"], []),
    "european1979":     Datum(geoEllipsoid["intl1924"], []),
    "europeanLibyan1979":     Datum(geoEllipsoid["intl1924"], []),
    "everestBangladesh":     Datum(geoEllipsoid["everest1830"], []),
    "everestIndiaNepal":     Datum(geoEllipsoid["everest1975"], []),
    // --- N ---
    "nad1927":      Datum(geoEllipsoid["clarke1866"],   [8.0,-160.0,-176.0, 0.0,0.0,0.0, 0.0]),
    "nad1983":      Datum(geoEllipsoid["grs1980"],        [1.004,-1.910,-0.515, 0.0267,0.00034,0.011, -0.0015]),
    // --- W ---
    "wgs1972":      Datum(geoEllipsoid["wgs1972"],        [0.0,0.0,-4.5, 0.0,0.0,0.554, -0.22]),
    "wgs1984":      Datum(geoEllipsoid["wgs1984"],        [0.0,0.0,0.0, 0.0,0.0,0.0, 0.0])

  ];
}
unittest {
  writefln ("Ellipsoid list %s", geoEllipsoid);
  writefln ("Datum list %s", geoDatum);
}
