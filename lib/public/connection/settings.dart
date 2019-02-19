import 'package:sqljocky5/internal/auth/character_set.dart';

export 'package:sqljocky5/internal/auth/character_set.dart' show CharacterSet;

/// [ConnectionSettings] contains information to connect to MySQL database.
///
///     var s = ConnectionSettings(
///       user: "root",
///       password: "dart_jaguar",
///       host: "localhost",
///       port: 3306,
///       db: "example",
///       useSSL: true,
///     );
///
///     // Establish connection
///     final conn = await MySqlConnection.connect(s);
class ConnectionSettings {
  /// Host of the MySQL server to connect to.
  String host;

  /// Port of the MySQL server to connect to.
  int port;

  /// User of the MySQL server to connect to.
  String user;

  /// Password of the MySQL server to connect to.
  String password;

  /// Database name to connect to.
  String db;

  /// Should compression be enabled for communication with the MySQL server?
  bool useCompression;

  /// Should communication with MySQL be secure?
  bool useSSL;

  /// Sets the maximum packet size of each communication with MySQL server.
  int maxPacketSize;

  /// Sets charset for communication with MySQL server.
  int characterSet;

  /// The timeout for connecting to the database and for all database operations.
  Duration timeout;

  ConnectionSettings(
      {String this.host = 'localhost',
      int this.port = 3306,
      String this.user,
      String this.password,
      String this.db,
      bool this.useCompression = false,
      bool this.useSSL = false,
      int this.maxPacketSize = 16 * 1024 * 1024,
      Duration this.timeout = const Duration(seconds: 30),
      int this.characterSet = CharacterSet.UTF8MB4});

  ConnectionSettings.copy(ConnectionSettings o) {
    host = o.host;
    port = o.port;
    user = o.user;
    password = o.password;
    db = o.db;
    useCompression = o.useCompression;
    useSSL = o.useSSL;
    maxPacketSize = o.maxPacketSize;
    timeout = o.timeout;
    characterSet = o.characterSet;
  }
}
