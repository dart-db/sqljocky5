library sqljocky.row;

import 'dart:async';
import 'dart:collection';
import 'package:collection/collection.dart';

import 'field.dart';
import 'results_impl.dart';

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

class Results extends IterableBase<Row> {
  final int insertId;
  final int affectedRows;
  final List<Field> fields;
  final List<Row> _rows;

  Results(this._rows, this.fields, this.insertId, this.affectedRows);

  static Future<Results> read(ResultsStream r) async {
    var rows = await r.toList();
    return new Results(rows, r.fields, r.insertId, r.affectedRows);
  }

  @override
  Iterator<Row> get iterator {
    return _rows.iterator;
  }
}
