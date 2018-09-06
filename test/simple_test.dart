import 'dart:async';

import 'package:sqljocky5/sqljocky.dart';
import 'package:test/test.dart';

void main() async {
  group("Simple tests", () {
    MySqlConnection conn;

    setUpAll(() async {
      // create a connection
      var s = ConnectionSettings(
        user: "root",
        password: "dart_jaguar",
        host: "localhost",
        port: 3306,
        db: "example",
      );
      conn = await MySqlConnection.connect(s);
    });

    test('connection test', () async {
      await conn.execute("DROP TABLE IF EXISTS t1");
      await conn.execute("CREATE TABLE IF NOT EXISTS t1 (a INT)");
      var r = await conn.prepared("INSERT INTO `t1` (a) VALUES (?)", [1]);

      r = await conn.prepared("SELECT * FROM `t1` WHERE a = ?", [1]);
      expect(await r.length, 1);

      r = await conn.prepared("SELECT * FROM `t1` WHERE a = ?", [2]);
      expect(await r.length, 0);

      // Drop a table which doesn't exist. This should cause an error.
      try {
        await conn.execute("DROP TABLE doesnotexist");
        expect(true, false); // not reached
      } on MySqlException catch (e) {
        expect(e.errorNumber, 1051);
      }

      // Check the conn is still ok after the error
      r = await conn.prepared("SELECT * FROM `t1` WHERE a = ?", [1]);
      expect(await r.length, 1);
    });
  });
}
