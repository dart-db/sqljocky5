library sqljocky.my_sql_exception;

import 'package:typed_buffer/typed_buffer.dart';

/// An exception returned by the MySQL server itself.
class MySqlException implements Exception {
  /// The MySQL error number
  final int errorNumber;

  /// A five character ANSI SQLSTATE value
  final String sqlState;

  /// A textual description of the error
  final String message;

  MySqlException._raw(this.errorNumber, this.sqlState, this.message);

  /// Creates a [MySqlException] based on an error response from the mysql
  /// server
  factory MySqlException(ReadBuffer buffer) {
    buffer.seek(1);
    var errorNumber = buffer.uint16;
    buffer.skip(1);
    var sqlState = buffer.readString(5);
    var message = buffer.stringToEnd;

    return new MySqlException._raw(errorNumber, sqlState, message);
  }

  String toString() => "Error $errorNumber ($sqlState): $message";
}
