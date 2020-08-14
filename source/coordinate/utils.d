/** **/
module coordinate.utils;

import coordinate.datums;

alias AltitudeType = float;   ///
alias AccuracyType = float;   ///
alias UTMType = float;        ///
alias LatLonType = double;    /// TODO
alias ECEFType = float;       ///

mixin template ExtendDatum () {
  import coordinate.datums: Datum;
  Datum datum;                              /// [Datum](datums.html#Datum)
}

mixin template ExtendCoordinate () {
  AltitudeType altitude = AltitudeType.init;         /// Altitude in meters
  AccuracyType accuracy = AccuracyType.init;         /// Accuracy in meters
  AccuracyType altitudeAccuracy = AccuracyType.init; /// Altitude accuracy in meters
}
