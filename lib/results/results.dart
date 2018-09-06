library sqljocky.results_impl;

import 'dart:async';
import 'dart:collection';

import 'field.dart';
import 'row.dart';

export 'field.dart';
export 'row.dart';

class Results extends IterableBase<Row> {
  final int insertId;
  final int affectedRows;
  final List<Field> fields;
  final List<Row> _rows;

  Results(this._rows, this.fields, this.insertId, this.affectedRows);

  static Future<Results> read(StreamedResults r) async {
    var rows = await r.toList();
    return Results(rows, r.fields, r.insertId, r.affectedRows);
  }

  @override
  Iterator<Row> get iterator => _rows.iterator;
}

class StreamedResults extends StreamView<Row> {
  final int insertId;
  final int affectedRows;

  final List<Field> fields;

  factory StreamedResults(int insertId, int affectedRows, List<Field> fields,
      {Stream<Row> stream = null}) {
    if (stream != null) {
      var newStream = stream.transform(
          new StreamTransformer.fromHandlers(handleDone: (EventSink<Row> sink) {
        sink.close();
      }));
      return new StreamedResults._fromStream(
          insertId, affectedRows, fields, newStream);
    } else {
      var newStream = new Stream.fromIterable(new List<Row>());
      return new StreamedResults._fromStream(
          insertId, affectedRows, fields, newStream);
    }
  }

  StreamedResults._fromStream(
      this.insertId, this.affectedRows, List<Field> fields, Stream<Row> stream)
      : this.fields = new UnmodifiableListView(fields),
        super(stream);

  /// Takes a _ResultsImpl and destreams it. That is, it listens to the stream, collecting
  /// all the rows into a list until the stream has finished. It then returns a new
  /// _ResultsImpl which wraps that list of rows.
  static Future<StreamedResults> destream(StreamedResults results) async {
    var rows = await results.toList();
    var newStream = new Stream<Row>.fromIterable(rows);
    return new StreamedResults._fromStream(
        results.insertId, results.affectedRows, results.fields, newStream);
  }
}
