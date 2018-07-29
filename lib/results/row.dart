library sqljocky.row;

import 'dart:async';
import 'dart:collection';
import 'package:collection/collection.dart';

import 'field.dart';
import 'results.dart';

/// A row of data. Fields can be retrieved by index, or by name.
///
/// When retrieving a field by name, only fields which are valid Dart
/// identifiers, and which aren't part of the List object, can be used.
class Row extends DelegatingList<dynamic> {
  final Map<String, int> _fieldIndex;

  Row(List inner, this._fieldIndex) : super(inner);

  T byName<T>(String name) {
    int i = _fieldIndex[name];
    if (i == null)
      throw new Exception("Field named $name not found in this row!");
    return this[i];
  }
}
