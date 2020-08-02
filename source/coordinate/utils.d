/** **/
module coordinate.utils;

import coordinate.datums;

alias AltitudeType = float;   ///
alias AccuracyType = float;   ///
alias UTMType = float;        ///
alias LatLonType = double;    /// TODO
alias ECEFType = float;       ///

mixin template ExtendCoordinate () {
  import coordinate.datums: Datum;
  AltitudeType altitude = AltitudeType.nan;         /// Altitude in meters
  AccuracyType accuracy = AccuracyType.nan;         /// Accuracy in meters
  AccuracyType altitudeAccuracy = AccuracyType.nan; /// Altitude accuracy in meters
  Datum datum;                              /// [Datum](datums.html#Datum)
}
