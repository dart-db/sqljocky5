interface Connection {
  Dynamic connect([String host, int port, String user, String password, String db]);
  Dynamic useDatabase(String dbName);
  Dynamic query(String sql);
  Dynamic update(String sql);
  Dynamic prepare(String sql);
  void close();
  Dynamic ping();
  Dynamic debug();
}

interface SyncConnection extends Connection {
  Future connect([String host, int port, String user, String password, String db]);
  void useDatabase(String dbName);
  Results query(String sql);
  int update(String sql);
  SyncQuery prepare(String sql);
  void close();
  void ping();
  void debug();
}

interface AsyncConnection extends Connection {
  Future connect([String host, int port, String user, String password, String db]);
  Future useDatabase(String dbName);
  Future<Results> query(String sql);
  Future<int> update(String sql);
  Future<AsyncQuery> prepare(String sql);
  void close();
  Future ping();
  Future debug();
}

interface Query {
  Dynamic execute();
  Dynamic executeUpdate();
  Dynamic close();
  Dynamic operator [](int pos);
  void operator []=(int index, Dynamic value);
}

interface SyncQuery extends Query {
  Results execute();
  int executeUpdate();
  void close();
}

interface AsyncQuery extends Query {
  Future<Results> execute();
  Future<int> executeUpdate();
  Future close();
}

interface Field {
  String get name();
  String get table();
  String get catalog();
  String get orgName();
  String get orgTable();
  String get db();
  int get characterSet();
  int get length();
  int get type();
  int get flags();
  int get decimals();
  int get defaultValue();
}

interface Results extends Iterable default ResultsImpl {
  int get insertId();
  int get affectedRows();
  int get count();
  List<Field> get fields();
  List<Dynamic> operator [](int pos);
}
