part of integrationtests;

void runCharset4Tests(
    String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('charset utf8mb4_general_ci tests:', () {
    test('setup', () {
      pool = new ConnectionPool(
          user: user,
          password: password,
          db: db,
          characterSet: CharacterSet.UTF8MB4,
          port: port,
          host: host,
          max: 1);
      return setup(
          pool,
          "cset4",
          "create table cset4 (stuff4 text character set utf8mb4)",
          "insert into cset4 (stuff4) values ('utf8 テスト 💯😏')");
    });

    test('read data', () async {
      var c = new Completer();
      var results = await pool.query('select * from cset4');
      results.listen((row) {
        expect(row[0].toString(), equals("utf8 テスト 💯😏"));
      }, onDone: () {
        c.complete();
      });
      return c.future;
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}
