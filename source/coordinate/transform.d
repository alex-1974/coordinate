module coordinate.transform;

import mir.ndslice;
import std.typecons: Flag, Yes, No;
import coordinate: ECEF;
debug import std.stdio;

/**


mir is row-major-order

**/
auto dotProduct () {

}
/** Calculate dot product

  To multiply an *m×n* matrix by an *n×p* matrix, the *n*s must be the same,
  and the result is an *m×p* matrix.

  Params:
   a = matrix A (row-order)
   b = matrix B (column order)
  Returns: Matrix
**/

auto cross (Slice!(double*, 2) a, Slice!(double*, 2) b) {
  auto m = a.length;
  auto n = a.length!1;
  auto p = b.length!0;
  //writefln("m %s n %s n %s p %s", a.length!0, a.length!1, b.length!0,b.length!1);
  auto s = slice!double(m,p);
  foreach (size_t mm; 0 .. a.length) {
    foreach (size_t pp; 0 .. b.length) {
      s[mm][pp] = reduce!"a + b * c"(0.0,a[mm], b[pp]);
    }
  }
  return s.transposed;
}
/** Transform cartesian coordinates to new datum

  Params:
    source = Cartesian coordinate to transform
    transformation = Transformation parameters
  Returns : Transformed cartesian coordinate
**/
auto cartesianTransform (U) (ECEF source, U[] transformation) {
  return ECEF(cartesian3p(source, transformation));
}
auto cartesianTransform (U, string Rotation = "positionVector") (ECEF source, U[] transformation, U[] rotation, U scale, Flag!"inverse" inverse = Yes.inverse) {
  static if (Rotation == "coordinateFrame")
    rotation = rotation.map!(a => -a);
  else static if (Rotation != "positionVector") static assert(0, "Unknown rotation sense!");
  if (inverse) {
    transformation = transformation.map!(a => -a);
    rotation = rotation.map!(a => -a);
    scale = -scale;
  }
  return ECEF(cartesian7p (source, transformation, rotation, scale));
}
auto cartesian3p (T, U) (T[] source, U[] transformation) {
  auto s = source.sliced(1,3);
  auto t = transformation.sliced(1,3);      // (x,y,z)-shift in metrers
  return s + t;
}
auto cartesian7p (T, U) (T[] source, U[] transformation, U[] rotation, U scale) {
  import coordinate.mathematics;
  import std.algorithm: map;
  auto s = source.sliced(1,3);
  auto t = transformation.sliced(1,3);      // (x,y,z)-shift in metrers
  auto rx = (rotation[0]/3600).toRadians;   // x-rotation: normalise arcseconds to radians
  auto ry = (rotation[1]/3600).toRadians;   // y-rotation: normalise arcseconds to radians
  auto rz = (rotation[2]/3600).toRadians;   // z-rotation: normalise arcseconds to radians
  auto m = [scale, rz, -ry,
            -rz, scale, rx,
            ry, -rx, scale].sliced(3,3);
  writefln("source %s", s);
  writefln("shift %s", t);
  writefln("rotation %s", m);
  auto c = m.cross(s).slice;
  writefln ("cross %s", c);
  //auto sc = (c * scale).slice;
  //writefln ("scale %s", sc);
  auto tr = c + t;
  writefln ("translated %s", tr);
  writefln ("x %s", transformation[0] + scale * (source[0] + rz * source[1] - ry * source[2]));
  writefln ("y %s", transformation[1] + scale * (-rz * source[0] + source[1] + rx * source[2]));
  writefln ("z %s", transformation[2] + scale * (ry * source[0] - rx * source[1] + source[2]));

  return tr;
}
unittest {
  import std.math: pow;
  auto source = [4156305.34, 671404.31, 4774508.25];  // Potsdam (xyz in meter)
  auto shift = [-581.99, -105.01, -414.00]; // in meters
  auto rotation = [1.04, 0.35, -3.08];  // in arc seconds
  auto scale = 1-(8.3 * 10.pow(-6));  // unitless in ppm
  writefln("t7p %s", source.cartesian7p(shift, rotation, scale) );
}
