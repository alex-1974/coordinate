/** **/
module coordinate.exceptions;

/** Exceptions for the [spatial.coord](coord.html) module **/
class CoordException : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super(msg, file, line);
  }
}
/** **/
final class LatLonException : CoordException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super(msg, file, line);
  }
}
/** **/
final class ECEFException : CoordException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super(msg, file, line);
  }
}
/** Exceptions for the [utm](utm.html#UTM) module **/
final class UTMException : CoordException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super("Invalid utm coordinate! " ~ msg, file, line);
  }
}
/** Exceptions for the [mgrs](utm.html#MGRS) module **/
final class MGRSException : CoordException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super("Invalid mgrs coordinate! " ~ msg, file, line);
  }
}
/** Exceptions for the [geohash](geohash.html) module **/
final class GeohashException : CoordException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super("Invalid geohash! " ~ msg, file, line);
  }
}
/** Exceptions for the [open location code](openlocationcode.html) module **/
final class OLCException : CoordException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super("Invalid open location code! " ~ msg, file, line);
  }
}
