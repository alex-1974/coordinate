/** **/
module coordinate.exceptions;

/** Exceptions for the [spatial.coord](coord.html) module **/
final class CoordException : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
      super(msg, file, line);
  }
}
