library sqljocky.my_sql_exception;

import 'package:sqljocky5/comm/buffer.dart';

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
  factory MySqlException(Buffer buffer) {
    buffer.seek(1);
    var errorNumber = buffer.readUint16();
    buffer.skip(1);
    var sqlState = buffer.readString(5);
    var message = buffer.readStringToEnd();

    return new MySqlException._raw(errorNumber, sqlState, message);
  }

  String toString() => "Error $errorNumber ($sqlState): $message";
}
