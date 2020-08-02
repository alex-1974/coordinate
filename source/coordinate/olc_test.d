module coordinate.olctest;

import std.csv;
import std.stdio;
import std.typecons;
import std.algorithm;
import std.exception: assertThrown;
import coordinate.openlocationcode;
import coordinate: geo;
import coordinate.exceptions;



// Encoding
unittest {

  auto file = File("test_data/olc_encoding.csv", "r");
  foreach (record; file.byLine.filter!(a => !a.startsWith("#")).joiner("\n").csvReader!(Tuple!(double, double, int, string))) {
    if (record[3] == "") {
      // TODO assertThrown
    } else {
      //writefln ("\n test: %s", record);
      auto result = encode(record[0], record[1], record[2]);
      if (record[0] >= 90 && record[2] >= 10) {
        //writefln ("encoded: %s expected: %s", result, record[3]);

      } else { assert(result == record[3]); }
    }
  }
}



// Decoding
unittest {
  import coordinate.mathematics: roundTo;
  auto file = File("test_data/olc_decoding.csv", "r");
  // format: code,length,latLo,lngLo,latHi,lngHi
  foreach (record; file.byLine.filter!(a => !a.startsWith("#")).joiner("\n").csvReader!(Tuple!(string, size_t, double, double, double, double))) {
    auto result = decode(record[0]);
    //writefln ("%s decoded ", record[0]);
    //writefln("  %.6f %.6f", result.southLatitude, record[2]);
    //writefln("  %.12f %.12f", result.westLongitude, record[3]);
    //writefln("  %.10f %.10f", result.northLatitude, record[4]);
    //writefln("  %.12f %.12f", result.eastLongitude.roundTo(10), record[5].roundTo(10));

    assert(result.southLatitude.roundTo(11) == record[2].roundTo(11)
        && result.northLatitude.roundTo(11) == record[4].roundTo(11));
    assert(result.westLongitude.roundTo(11) == record[3].roundTo(11)
        && result.eastLongitude.roundTo(10) == record[5].roundTo(10));

  }
}


// Shortening and extending codes
unittest {
  auto file = File("test_data/olc_shorten.csv", "r");
  foreach (record; file.byLine.filter!(a => !a.startsWith("#")).joiner("\n").csvReader!(Tuple!(string, double, double, string, char))) {
    //writefln ("%s", record);
    if (record[4] == 'B' || record[4] == 'S') {
      string actualShort = shorten(record[0], record[1], record[2]);
      //writefln ("shorten %s expected %s", actualShort, record[3]);
      assert(actualShort == record[3]);
    }
    if (record[4] == 'B' || record[4] == 'R') {
      if (record[3].isShort) {
        string actualFull = recoverNearest(record[3], record[1], record[2]);
        //writefln ("recoverNearest %s", actualFull);
        assert(actualFull == record[0]);
      } else {
        // Test exceptions
        assertThrown!OLCException(recoverNearest(record[3], record[1], record[2]));
      }
    }

  }
}
/++
// isValid
unittest {
  auto file = File("test_data/olc_valid.csv", "r");
  foreach (record; file.byLine.filter!(a => !a.startsWith("#")).joiner("\n").csvReader!(Tuple!(string, bool, bool, bool))) {
    writefln ("%s", record);
    writefln ("%s %s %s", isValid(record[0]), isShort(record[0]), isFull(record[0]));
  }
}
++/
