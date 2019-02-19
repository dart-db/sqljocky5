library sqljocky.mysql_client_error;

/// An error thrown when the client is used improperly.
class MySqlClientError extends Error {
  final String message;

  /// Creates a new [MySqlClientError]
  MySqlClientError(this.message);

  String toString() => "MySQL Client Error: $message";
}
