import 'package:sqljocky5/auth/character_set.dart';

export 'package:sqljocky5/auth/character_set.dart';

class ConnectionSettings {
  String host;
  int port;
  String user;
  String password;
  String db;
  bool useCompression;
  bool useSSL;
  int maxPacketSize;
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
