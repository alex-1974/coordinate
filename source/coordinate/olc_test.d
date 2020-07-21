module coordinate.olctest;

import std.csv;
import std.stdio;
import std.typecons;
import std.algorithm;
import coordinate.openlocationcode;
import coordinate: geo;

// Encoding
unittest {
  auto file = File("test_data/olc_encoding.csv", "r");
  foreach (record; file.byLine.filter!(a => !a.startsWith("#")).joiner("\n").csvReader!(Tuple!(double, double, size_t, string))) {
    writefln ("%s", record);
    writefln ("%s %s", encode(record[0], record[1], record[2]), record[3]);
  }
}

// Decoding
unittest {
  auto file = File("test_data/olc_decoding.csv", "r");
  foreach (record; file.byLine.filter!(a => !a.startsWith("#")).joiner("\n").csvReader!(Tuple!(string, size_t, double, double, double, double))) {
    writefln ("%s", record);
    writefln ("%s", decode(record[0]));
  }
}
