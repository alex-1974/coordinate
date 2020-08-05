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
  AltitudeType altitude = AltitudeType.nan;         /// Altitude in meters
  AccuracyType accuracy = AccuracyType.nan;         /// Accuracy in meters
  AccuracyType altitudeAccuracy = AccuracyType.nan; /// Altitude accuracy in meters
}
