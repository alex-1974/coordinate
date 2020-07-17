/** ECEF (Eart-centered, earth fixed)

  > ECEF (earth-centered, earth-fixed) is a geographic and Cartesian coordinate system.
  It represents positions as X, Y, and Z coordinates. The point (0, 0, 0) is defined as the center of mass of Earth, hence the term geocentric coordinates.
  The distance from a given point of interest to the center of Earth is called the geocentric radius or geocentric distance. --- [Wikipedia](https://en.wikipedia.org/wiki/ECEF)

  The origin is the center of mass of the whole Earth including oceans and atmosphere, the geocenter.
  The x-axis intersects the sphere of the earth at 0° latitude (the equator) and 0° longitude (prime meridian in Greenwich).
  The y-axis is perpendicular to that at 90 degrees longitude east and west.
  The polar axis is the z-axis and extends through true north, which is known as the International Reference Pole (IRP).
**/
module coordinate.ecef;

import coordinate.utils: ECEFType;

struct ECEF {
  ECEFType x;
  ECEFType y;
  ECEFType z;
}
