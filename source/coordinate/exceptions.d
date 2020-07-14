/** **/
module coordinate.exceptions;

/** Exceptions for the [spatial.coord](coord.html) module **/
class CoordException : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super(msg, file, line);
  }
}
final class LatLonException : CoordException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super(msg, file, line);
  }
}
final class UTMException : CoordException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super("Invalid utm coordinate! " ~ msg, file, line);
  }
}
final class MGRSException : CoordException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super("Invalid mgrs coordinate! " ~ msg, file, line);
  }
}
