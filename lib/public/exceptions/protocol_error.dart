library sqljocky.mysql_protocol_error;

/// An error which is thrown when something unexpected is read from the the
/// MySQL protocol.
class MySqlProtocolError extends Error {
  final String message;

  /// Create a new [MySqlProtocolError]
  MySqlProtocolError(this.message);
}
