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

    test('NoThrow', () async {
      await conn.execute("DROP TABLE IF EXISTS t1");
      await conn.execute("CREATE TABLE IF NOT EXISTS t1 (a INT)");
      await conn.prepared("INSERT INTO `t1` (a) VALUES (?)", [1]);
      await conn.prepared("INSERT INTO `t1` (a) VALUES (?)", [2]);

      Future f1 = conn.execute('SELECT * FROM t1');
      Future f2 = conn.execute('SELECT * FROM t1');

      await Future.wait([f1, f2]);
    });

    test('Order', () async {
      // Even though we do not await these queries they should be queued.
      Future f1 = conn.execute("DROP TABLE IF EXISTS t1");
      Future f2 = conn.execute("CREATE TABLE IF NOT EXISTS t1 (a INT)");
      Future<StreamedResults> f3 = conn.execute("SELECT * FROM `t1`");
      Future<StreamedResults> f4 =
          conn.execute("INSERT INTO t1 (a) VALUES (1)");
      Future<StreamedResults> f5 = conn.execute("SELECT * FROM `t1`");
      Future<StreamedResults> f6 =
          conn.execute("INSERT INTO t1 (a) VALUES (2)");
      Future<StreamedResults> f8 = conn.execute("SELECT * FROM `t1`");

      await Future.wait([f1, f2, f3, f4, f5, f6, f8]);

      StreamedResults r3 = await f3;
      StreamedResults r5 = await f5;
      StreamedResults r8 = await f8;

      expect(await r3.length, 0);
      expect(await r5.length, 1);
      expect(await r8.length, 2);
    });
  });
}
