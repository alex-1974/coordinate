/** Conversions between geographic coordinate systems **/
module coordinate.conv;

import mir.math.common: fastmath; // compiles both for dmd and ldc
public import coordinate.latlon: GEO, geo;
public import coordinate.utm: UTM, utm, MGRS, mgrs;
public import coordinate.ecef: ECEF, ecef;
public import coordinate.geohash: GeoHash, geohash;
public import coordinate.openlocationcode: PlusCode, CodeArea, pluscode;
import coordinate.utils: AltitudeType, AccuracyType, UTMType;
import coordinate.datums: Datum, defaultDatum;
debug import std.stdio;


/** Converts UTM zone/easting/northing coordinate to latitude/longitude.

  Implements Karney’s method, using Krüger series to order n⁶, giving results accurate to 5nm
  for distances up to 3900km from the central meridian.

  Prefixes: s, c are sin, cos. d is delta.
  Derivates: x' is x_dot, x" is x_dotdot
  Subscriptes:

  See: https://www.movable-type.co.uk/scripts/latlong-utm-mgrs.html
**/
GEO toLatLon (UTM utm) {
  import coordinate.latlon: LAT, LON;
  real[2] c = utmToLatLon(utm.hemisphere, utm.zone, utm.easting, utm.northing, utm.datum.ellipsoid.a, utm.datum.ellipsoid.f);
  return GEO (LAT(c[0]), LON(c[1]), utm.altitude, utm.accuracy, utm.altitudeAccuracy, utm.datum);
}
@fastmath auto utmToLatLon (const char hemisphere, const uint zone, const UTMType easting, const UTMType northing, const real a, const real f) {
  import std.math: sinh, cosh, tanh, atan, atanh, atan2, abs, tan;
  import mir.math;
  import coordinate.mathematics;
  import coordinate.utm: falseEasting, falseNorthing;
  //const real a = utm.datum.ellipsoid.a;
  //const real f = utm.datum.ellipsoid.f;

  enum real k0 = 0.9996;

  immutable real x = easting - falseEasting; // make x ± relative to central meridian
  immutable real y = (hemisphere == 's')? northing - falseNorthing:northing;  // make y ± relative to equator

  // ---- from Karney 2011 Eq 15-22, 36:
  immutable real e = (f*(2-f)).sqrt;  // eccentricity
  immutable real n = f/(2-f);         // 3rd flattening;
  immutable real n2 = n*n; immutable real n3 = n*n2;
  immutable real n4 = n*n3; immutable real n5 = n*n4; immutable real n6 = n*n5;

  immutable real A = a/(1+n) * (1 + 1/4*n2 + 1/64*n4 + 1/256*n6); // 2πA is the circumference of a meridian

  immutable real eta = x / (k0*A);  // η
  immutable real zeta = y / (k0*A); // ξ

  // note β is one-based array (6th order Krüger expressions)
  immutable real[7] beta = [ 0.0,
                 1/2*n - 2/3*n2 + 37/96*n3 -    1/360*n4 -   81/512*n5 +    96199/604800*n6,
                        1/48*n2 +  1/15*n3 - 437/1440*n4 +   46/105*n5 - 1118711/3870720*n6,
                                 17/480*n3 -   37/840*n4 - 209/4480*n5 +      5569/90720*n6,
                                          4397/161280*n4 -   11/504*n5 -  830251/7257600*n6,
                                                        4583/161280*n5 -  108847/3991680*n6,
                                                                      20648693/638668800*n6];

  real zeta_dot = zeta;
  for (uint j = 1; j <= 6; j++) {
    zeta_dot -= beta[j] * (2*j*zeta).sin * (2*j*eta).cosh;
  }
  real eta_dot = eta;
  for (uint j = 1; j <= 6; j++) {
    eta_dot -= beta[j] * (2*j*zeta).cos * (2*j*eta).sinh;
  }
  immutable real sinheta_dot = eta_dot.sinh;
  immutable real szeta_dot = zeta_dot.sin; const real czeta_dot = zeta_dot.cos;

  immutable tau_dot = szeta_dot / (sinheta_dot*sinheta_dot + czeta_dot*czeta_dot).sqrt;

  real dtau_i = 0.0;
  real tau_i = tau_dot;
  do {
    immutable real sigma_i = (e*atanh(e*tau_i/(1+tau_i*tau_i).sqrt)).sinh;
    immutable real tau_i_dot = tau_i * (1+sigma_i*sigma_i).sqrt - sigma_i * (1+tau_i*tau_i).sqrt;
    dtau_i = (tau_dot - tau_i_dot)/(1+tau_i_dot*tau_i_dot).sqrt
            * (1 + (1-e*e)*tau_i_dot*tau_i_dot) / ((1-e*e)*(1+tau_i_dot*tau_i_dot).sqrt);
    tau_i += dtau_i;
  } while (dtau_i.fabs > 1e-12);
  // note relatively large convergence test as δτi toggles on ±1.12e-16 for eg 31 N 400000 5000000
  immutable real tau = tau_i;
  immutable real phi = tau.atan;
  real lambda = atan2(sinheta_dot, czeta_dot);

  // ---- convergence: Karney 2011 Eq 26, 27
  real p = 1.0;
  for (int j = 1; j <= 6; j++) p -= 2*j*beta[j] * (2*j*zeta).cos * (2*j*eta).cosh;
  real q = 0;
  for (int j = 1; j <= 6; j++) q += 2*j*beta[j] * (2*j*zeta).sin * (2*j*eta).sinh;

  immutable real gamma_dot = atan(zeta_dot.tan*eta_dot.tanh);
  immutable real gamma_dotdot = atan2(q,p);

  immutable real gamma = gamma_dot + gamma_dotdot;

  // ---- scale: Karney 2011 Eq 28
  immutable real sphi = phi.sin;
  immutable real k1 = (1 - e*e*sphi*sphi).sqrt * (1 + tau*tau).sqrt * (sinheta_dot*sinheta_dot + czeta_dot*czeta_dot).sqrt;
  immutable real k2 = A / a / (p*p + q*q).sqrt;

  immutable real k = k0 * k1 * k2;

  immutable real lambda_0 = ((cast(real)zone-1)*6-180+3).toRadians(); // longitude of central meridian
  lambda += lambda_0; // move λ from zonal to global coordinates

  immutable real lat = phi.toDegree();
  immutable real lon = lambda.toDegree();
  immutable real convergence = gamma.toDegree();
  immutable real scale = k;

  //return GEO(LAT(lat), LON(lon), utm.altitude, utm.accuracy, utm.altitudeAccuracy, utm.datum);
  return [lat, lon];
}
/** **/
unittest {
  import coordinate: utm;
  auto mopti = utm(30, 'N', 370797, 1603103);
  //mopti.toLatLon;
}

/** Converts latitude/longitude to UTM coordinate.

  Implements Karney’s method, using Krüger series to order n⁶, giving results accurate to 5nm
  for distances up to 3900km from the central meridian.

**/
UTM toUTM (GEO geo) {
  auto u = geoToUTM(geo.lat, geo.lon, geo.datum.ellipsoid.a, geo.datum.ellipsoid.f);
  return UTM(u[0], u[1], u[2], u[3], geo.altitude, geo.altitudeAccuracy, geo.accuracy, geo.datum);
}
auto geoToUTM (T) (const T lat, const T lon, const real a, const real f) {
  import std.math: sinh, cosh, tanh, atan, atanh, atan2, abs, tan, asinh;
  import mir.math;
  import std.conv: to;
  import std.typecons: tuple;
  import coordinate.mathematics;
  import coordinate.utm: mgrsBands, falseEasting, falseNorthing;
  //const real lat = geo.lat.lat;
  //const real lon = geo.lon.lon;
  //const real a = geo.datum.ellipsoid.a;
  //const real f = geo.datum.ellipsoid.f;
  uint zone = cast(uint)floor((lon+180)/6.0) + 1; // longitudinal zone
  real lambda_0 = ((zone-1)*6.0 - 180 + 3).toRadians(); // longitude of central meridian
  // handle Norway/Svalbard exceptions
  // grid zones are 8° tall; 0°N is offset 10 into latitude bands array
  immutable char latBand = mgrsBands[floor(lat/8.0 + 10).to!size_t];
  // adjust zone & central meridian for Norway
  if (zone==31 && latBand=='v' && lon>= 3) { zone++; lambda_0 += (6.0).toRadians(); }
  // adjust zone & central meridian for Svalbard
  if (zone==32 && latBand=='x' && lon<  9) { zone--; lambda_0 -= (6.0).toRadians(); }
  if (zone==32 && latBand=='x' && lon>= 9) { zone++; lambda_0 += (6.0).toRadians(); }
  if (zone==34 && latBand=='x' && lon< 21) { zone--; lambda_0 -= (6.0).toRadians(); }
  if (zone==34 && latBand=='x' && lon>=21) { zone++; lambda_0 += (6.0).toRadians(); }
  if (zone==36 && latBand=='x' && lon< 33) { zone--; lambda_0 -= (6.0).toRadians(); }
  if (zone==36 && latBand=='x' && lon>=33) { zone++; lambda_0 += (6.0).toRadians(); }

  immutable real phi = lat.toRadians(); // latitude ± from equator
  immutable real lambda = lon.toRadians() - lambda_0; // longitude ± from central meridian

  enum real k0 = 0.9996; // UTM scale on the central meridian

  // easting, northing: Karney 2011 Eq 7-14, 29, 35:
  immutable real e = (f*(2.0-f)).sqrt;  // eccentricity
  immutable real n = f / (2-f); // 3rd flattening
  immutable real n2 = n*n; immutable real n3 = n*n2; immutable real n4 = n*n3;
  immutable real n5 = n*n4; immutable real n6 = n*n5;
  immutable real clambda = lambda.cos; immutable real slambda = lambda.sin; immutable real tlambda = lambda.tan;
  immutable real tau = phi.tan;  // τ ≡ tanφ, τʹ ≡ tanφʹ; prime (ʹ) indicates angles on the conformal sphere
  immutable real sigma = (e*atanh(e*tau/(1+tau*tau).sqrt)).sinh;
  immutable real tau_dot = tau*(1+sigma*sigma).sqrt - sigma*(1+tau*tau).sqrt;
  immutable real zeta_dot = atan2(tau_dot, clambda); // ξʹ
  immutable real eta_dot = asinh(slambda / (tau_dot*tau_dot + clambda*clambda).sqrt); // ηʹ

  immutable real A = a/(1+n) * (1 + 1/4*n2 + 1/64*n4 + 1/256*n6); // 2πA is the circumference of a meridian

  // note α is one-based array (6th order Krüger expressions)
  immutable real[7] alpha = [ 0.0,
            1/2*n - 2/3*n2 + 5/16*n3 +   41/180*n4 -     127/288*n5 +      7891/37800*n6,
                  13/48*n2 -  3/5*n3 + 557/1440*n4 +     281/630*n5 - 1983433/1935360*n6,
                           61/240*n3 -  103/140*n4 + 15061/26880*n5 +   167603/181440*n6,
                                   49561/161280*n4 -     179/168*n5 + 6601661/7257600*n6,
                                                     34729/80640*n5 - 3418889/1995840*n6,
                                                                  212378941/319334400*n6 ];

  real zeta = zeta_dot;
  for (uint j = 1; j <= 6; j++) { zeta += alpha[j] * (2.0*j*zeta_dot).sin * (2.0*j*eta_dot).cosh; }
  real eta = eta_dot;
  for (uint j = 1; j <= 6; j++) { eta += alpha[j] * (2.0*j*zeta_dot).cos * (2.0*j*eta_dot).sinh; }

  real x = k0 * A * eta;
  real y = k0 * A * zeta;

  // convergence: Karney 2011 Eq 23, 24

  real p_dot = 1;
  for (uint j = 1; j <= 6; j++) p_dot += 2*j*alpha[j] * (2*j*zeta_dot).cos * (2*j*eta_dot).cosh;
  real q_dot = 0;
  for (uint j = 1; j <= 6; j++) q_dot += 2*j*alpha[j] * (2*j*zeta_dot).sin * (2*j*eta_dot).sinh;

  immutable real gamma_dot = atan(tau_dot / (1+tau_dot*tau_dot).sqrt * tlambda);
  immutable real gamma_dotdot = atan2(q_dot, p_dot);

  immutable real gamma = gamma_dot + gamma_dotdot;

   // scale: Karney 2011 Eq 25
   immutable real sphi = phi.sin;
   immutable real k_dot = (1 - e*e*sphi*sphi).sqrt * (1 + tau*tau).sqrt / (tau_dot*tau_dot + clambda*clambda).sqrt;
   immutable real k_dotdot = A / a * (p_dot*p_dot + q_dot*q_dot).sqrt;
   immutable real k = k0 * k_dot * k_dotdot;

   // shift x/y to false origins
   x = x + falseEasting;  // make x relative to false easting
   if (y < 0) y = y + falseNorthing; // make y in southern hemisphere relative to false northing

   immutable real convergence = gamma.toDegree();
   immutable real scale = k;
   immutable char hemisphere = (lat >= 0)? 'N':'S';  // Hemisphere
   return tuple(zone, hemisphere, x, y);
}
/** **/
unittest {
  import coordinate.latlon: geo;
  auto a = geo(52.2, 0.12);
  writefln ("toUTM %s", toUTM(a));
}

/** Converts ECEF to latitude/longitude coordinates **/
GEO toLatLon (ECEF ecef, Datum datum = defaultDatum) {
  import std.math;
  import coordinate.datums: Ellipsoid;
  import coordinate.latlon: geo, LAT, LON;
  import coordinate.mathematics: toDegree;
  const real x = ecef.x; const real y = ecef.y; const real z = ecef.z;
  const Ellipsoid ellipsoid = datum.ellipsoid;
  const real a = ellipsoid.a;
  const real b = ellipsoid.b;
  const real f = ellipsoid.f;

  const real e2 = ellipsoid.e; // e2 = 2*f - f*f;
  const real eps2 = ellipsoid.e2;
  const p = (x*x + y*y).sqrt;
  const R = (p*p + z*z).sqrt;

  // parametric latitude (Bowring eqn.17, replacing tanβ = z·a / p·b)
  const real tbeta = (b*z)/(a*p) * (1+eps2*b/R);
  const real sbeta = tbeta / (1+tbeta*tbeta).sqrt;
  const real cbeta = sbeta / tbeta;

  // geodetic latitude (Bowring eqn.18: tanφ = z+ε²⋅b⋅sin³β / p−e²⋅cos³β)
  const real phi = (cbeta.isNaN) ? 0 : atan2(z + eps2*b*sbeta*sbeta*sbeta, p - e2*a*cbeta*cbeta*cbeta);
  // longitude
  const real lambda = atan2(y, x);

  // height above ellipsoid (Bowring eqn.7)
  const real sphi = phi.sin, cphi = phi.cos;
  const real ny = a / (1-e2*sphi*sphi).sqrt; // length of the normal terminated by the minor axis
  const real h = p*cphi + z*sphi - (a*a/ny);
  return geo(LAT(phi.toDegree()), LON(lambda.toDegree()), h, AccuracyType.init, AccuracyType.init, datum);
}

/** Converts latitude/longitude to ECEF coordinates **/
@fastmath ECEF toECEF (GEO geo) {
  //import std.math;
  import mir.math;
  import coordinate.mathematics: toRadians;
  // x = (ν+h)⋅cosφ⋅cosλ, y = (ν+h)⋅cosφ⋅sinλ, z = (ν⋅(1-e²)+h)⋅sinφ
  // where ν = a/√(1−e²⋅sinφ⋅sinφ), e² = (a²-b²)/a² or (better conditioned) 2⋅f-f²
  immutable real phi = geo.lat.lat.toRadians();
  immutable real lambda = geo.lon.lon.toRadians();
  immutable real h = geo.altitude;
  immutable real a = geo.datum.ellipsoid.a;
  immutable real f = geo.datum.ellipsoid.f;

  immutable real sphi = phi.sin; const real cphi = phi.cos;
  immutable real slambda = lambda.sin; const real clambda = lambda.cos;

  immutable real eSq = 2*f - f*f;
  immutable real ny = a / (1 - eSq*sphi*sphi).sqrt; // radius of curvature in prime vertical
  immutable real x = (ny+h) * cphi * clambda;
  immutable real y = (ny+h) * cphi * slambda;
  immutable real z = (ny*(1-eSq)+h) * sphi;
  return ECEF(x,y,z);
}

/** Converts MGRS to UTM **/
UTM toUTM (MGRS mgrs) {
  import std.uni: toUpper;
  import std.string: indexOf;
  import std.math: floor;
  import coordinate.utm: e100kLetters, n100kLetters, mgrsBands;
  import coordinate.latlon: geo, LAT, LON;
  const char hemisphere = (mgrs.band.toUpper >= 'N') ? 'N' : 'S';
  // get easting specified by e100k (note +1 because eastings start at 166e3 due to 500km false origin)
  const size_t col = e100kLetters[(mgrs.zone-1)%3].indexOf(mgrs.grid[0]) + 1;
  const real e100kNum = col * 100e3; // e100k in metres

  // get northing specified by n100k
  const size_t row = n100kLetters[(mgrs.zone-1)%2].indexOf(mgrs.grid[1]);
  const real n100kNum = row * 100e3; // n100k in metres

  // get latitude of (bottom of) band
  const real latBand = (mgrsBands.indexOf(mgrs.band)-10)*8.0;
  // get northing of bottom of band, extended to include entirety of bottom-most 100km square
  const real nBand = floor(geo(LAT(latBand), LON(3.0)).toUTM().northing/100e3)*100e3;
  // 100km grid square row letters repeat every 2,000km north; add enough 2,000km blocks to get into required band
  real n2M = 0.0; // northing of 2,000km block
  while (n2M + n100kNum + mgrs.northing < nBand) n2M += 2000e3;
  return UTM(mgrs.zone, hemisphere, e100kNum+mgrs.easting, n2M+n100kNum+mgrs.northing, mgrs.altitude, mgrs.accuracy, mgrs.altitudeAccuracy, mgrs.datum);
}
/** **/
unittest {
  import coordinate.utm: mgrs;
  auto a = mgrs(31, 'U',  "DQ", 48251, 11932);
  writefln ("to utm %s", a.toUTM());
}

/** Converts UTM to MGRS **/
MGRS toMGRS (UTM utm) {
  import std.math;
  import coordinate.utm: e100kLetters, n100kLetters, mgrsBands;
  // convert UTM to lat/long to get latitude to determine band
  GEO latlong = utm.toLatLon();
  // grid zones are 8° tall, 0°N is 10th band
  const char band = mgrsBands[cast(size_t)(floor(latlong.lat/8+10))]; // latitude band

  // columns in zone 1 are A-H, zone 2 J-R, zone 3 S-Z, then repeating every 3rd zone
  const size_t col = cast(size_t)floor(utm.easting / 100e3);
  // (note -1 because eastings start at 166e3 due to 500km false origin)
  const char e100k = e100kLetters[(utm.zone-1)%3][col-1];

  // rows in even zones are A-V, in odd zones are F-E
  const size_t row = cast(size_t)(floor(utm.northing / 100e3) % 20);
  const char n100k = n100kLetters[(utm.zone-1)%2][row];

  // truncate easting/northing to within 100km grid square
  real easting = utm.easting % 100e3;
  real northing = utm.northing % 100e3;

  return MGRS(utm.zone, band, [e100k, n100k], easting, northing, utm.altitude, utm.accuracy, utm.altitudeAccuracy, utm.datum);
}
/** **/
unittest {
  auto utm = utm(31, 'N', 448251, 5411932);
  writefln("toMGRS %s", toMGRS(utm));
}

/** Converts latitude/longitude coordinates to MGRS **/
MGRS toMGRS (GEO geo) {
  return geo.toUTM.toMGRS;
}

/** Converts MGRS to latitude/longitude coordinates **/
GEO toLatLon (MGRS mgrs) {
  return mgrs.toUTM.toLatLon;
}

/** Converts geohash to latitude/longitude coordinates **/
GEO toLatLon (GeoHash geohash) {
  import coordinate.geohash: decode;
  import coordinate.latlon: LAT, LON;
  auto coord = decode(geohash.hash);
  return GEO(LAT(coord[0]), LON(coord[1]), geohash.altitude, geohash.accuracy, geohash.altitudeAccuracy, geohash.datum);
}
/** **/
unittest {
  auto hash = geohash("u120fxw");
  writefln ("toLatLon %s", toLatLon(hash));
}
/** Converts latitude/longitude coordinates to geohash **/
GeoHash toGeoHash (GEO geo, size_t precision = 0) {
  import coordinate.geohash: encode;
  auto hash = encode(geo.lat.lat, geo.lon.lon, precision);
  return GeoHash(hash, geo.altitude, geo.accuracy, geo.altitudeAccuracy, geo.datum);
}
/** **/
unittest {
  auto geo = geo(52.205, 0.119);
  writefln ("toGeoHash %s", toGeoHash(geo));

}

/** Converts latitude/longitude coordinates to pluscode **/
PlusCode toPlusCode (GEO geo, string file = __FILE__, size_t line = __LINE__) {
  import std.exception: enforce;
  import coordinate.openlocationcode: encode;
  import coordinate.exceptions: OLCException;
  enforce!OLCException(geo.datum == Datum.epsg(6326), "Open location codes must be in wgs1984 (epsg:6326) datum", file, line);
  return PlusCode(encode(geo.lat, geo.lon, file, line), geo.altitude, geo.accuracy, geo.altitudeAccuracy);
}
/** ditto **/
PlusCode toPlusCode (GEO geo, int codeLength, string file = __FILE__, size_t line = __LINE__) {
  import std.exception: enforce;
  import coordinate.openlocationcode: encode;
  import coordinate.exceptions: OLCException;
  enforce!OLCException(geo.datum == Datum.epsg(6326), "Open location codes must be in wgs1984 (epsg:6326) datum", file, line);
  return PlusCode(encode(geo.lat, geo.lon, codeLength, file, line), geo.altitude, geo.accuracy, geo.altitudeAccuracy);
}
/** Converts pluscode to code area **/
CodeArea toCodeArea (PlusCode code, string file = __FILE__, size_t line = __LINE__) {
  import coordinate.openlocationcode: decode;
  return decode(code, file, line);
}
