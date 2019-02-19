import 'dart:async';
import 'package:test/test.dart';
import 'package:sqljocky5/sqljocky.dart';

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

    test('InsertStatement', () async {
      await conn.execute("DROP TABLE IF EXISTS t1");
      await conn.execute("CREATE TABLE IF NOT EXISTS t1 (a INT)");
      Results ir = await conn
          .prepared("INSERT INTO `t1` (a) VALUES (?)", [5]).then(deStream);
      expect(ir.affectedRows, 1);
      Results sr = await conn.execute("SELECT * FROM t1").deStream();
      expect(sr.length, 1);
      expect(sr.first.byName("a"), 5);
    });
  });
}
