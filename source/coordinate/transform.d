module coordinate.transform;

import mir.ndslice;
import std.typecons: Flag, Yes, No;
import coordinate.ecef: ECEF;
import mir.math.common: fastmath; // compiles both for dmd and ldc
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

auto cross (Slice!(double*, 2) a, Slice!(double*, 2) b) pure @safe @nogc nothrow {
  auto m = a.length;
  auto n = a.length!1;
  auto p = b.length!0;
  //writefln("m %s n %s n %s p %s", a.length!0, a.length!1, b.length!0,b.length!1);
  double[3] slice;
  auto result = slice.sliced.sliced(m,p);
  foreach (size_t mm; 0 .. a.length) {
    foreach (size_t pp; 0 .. b.length) {
      result[mm][pp] = reduce!"a + b * c"(0.0,a[mm], b[pp]);
    }
  }
  return result.transposed;
}
unittest {
  writefln("cross test");
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
/** ditto **/
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
/** **/
auto cartesian3p (T, U) (T[] source, U[] transformation) {
  auto s = source.sliced(1,3);
  auto t = transformation.sliced(1,3);      // (x,y,z)-shift in metrers
  return s + t;
}
/** **/
@fastmath auto cartesian7p (T, U) (T[] source, U[] transformation, U[] rotation, U scale)  {
  import coordinate.mathematics;
  import std.algorithm: map;
  auto rx = (rotation[0]/3600.0).toRadians;   // x-rotation: normalise arcseconds to radians
  auto ry = (rotation[1]/3600.0).toRadians;   // y-rotation: normalise arcseconds to radians
  auto rz = (rotation[2]/3600.0).toRadians;   // z-rotation: normalise arcseconds to radians
  return [ transformation[0] + scale * (source[0] + rz * source[1] - ry * source[2]),
           transformation[1] + scale * (-rz * source[0] + source[1] + rx * source[2]),
           transformation[2] + scale * (ry * source[0] - rx * source[1] + source[2])];
}
unittest {
  import std.math: pow;
  writefln("cartesian7p test");
  auto source = [4156305.34, 671404.31, 4774508.25];  // Potsdam (xyz in meter)
  auto shift = [-581.99, -105.01, -414.00]; // in meters
  auto rotation = [1.04, 0.35, -3.08];  // in arc seconds
  auto scale = 1.0-(8.3 * 10.pow(-6.0));  // unitless in ppm
  writefln("t7p %s", source.cartesian7p(shift, rotation, scale) );
}

/** Molodensky-Badekas transformation

  To eliminate the coupling between the rotations and translations of the Helmert transform,
  three additional parameters can be introduced to give a new XYZ center of rotation
  closer to coordinates being transformed.
  Unlike the Helmert transform, the Molodensky-Badekas transform is not reversible
  due to the rotational origin being associated with the original datum

  Note: It should not be confused with the Molodensky transformation
        which operates directly in the geodetic coordinates.
        Molodensky-Badekas can rather be seen as a variation of Helmert transform
  Params:
    source = Cartesian source coordinates
    transformation = Transformation parameter
    rotation = Rotation parameter
    origin = Origin for the rotation
    scale = Scale factor
**/
@fastmath auto cartesian10p (T, U) (T[3] source, U[3] transformation, U[3] rotation, U[3] origin, U scale) {
  import coordinate.mathematics;
  auto rx = (rotation[0]/3600.0).toRadians;   // x-rotation: normalise arcseconds to radians
  auto ry = (rotation[1]/3600.0).toRadians;   // y-rotation: normalise arcseconds to radians
  auto rz = (rotation[2]/3600.0).toRadians;   // z-rotation: normalise arcseconds to radians
  return [ (transformation[0] + origin[0]) + scale * ((source[0] - origin[0]) + rz * (source[1] - origin[1]) - ry * (source[2] - origin[2])),
           (transformation[1] + origin[1]) + scale * (-rz * (source[0] - origin[0]) + (source[1] - origin[1]) + rx * (source[2] - origin[2])),
           (transformation[2] + origin[2]) + scale * (ry * (source[0] - origin[0]) - rx * (source[1] - origin[1]) + (source[2] - origin[2]))];
}
/** Molodensky 5-parameter transformation

  The Molodensky transformation converts directly between geodetic coordinate systems of different datums
  without the intermediate step of converting to geocentric coordinates (ECEF).
  It requires the three shifts between the datum centers and the differences between
  the reference ellipsoid semi-major axes and flattening parameters.

  Params:
    source = Source coordinates
    transformation = Transformation shifts for x, y, z
    deltaA = Difference in semi-major-axis between source and target ellipsoid
    deltaF = Difference in flattening between source and target ellipsoid
**/
@fastmath auto geodetic5p (T, U) (T[3] source, U[3] transformation, U deltaA, U deltaF) {

}
