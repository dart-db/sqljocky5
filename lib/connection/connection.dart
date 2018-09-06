library sqljocky.connection;

import 'dart:async';

import '../results/results.dart';

import 'settings.dart';
import 'impl.dart';

export 'settings.dart';

abstract class Querier {
  Future<StreamedResults> execute(String sql);

  Future<StreamedResults> prepared(String sql, Iterable values);

  Future<Stream<StreamedResults>> preparedWithAll(
      String sql, Iterable<Iterable> values);

  Future<Prepared> prepare(String sql);
}

/// A connection to MySql or MariaDb database.
///
/// Use [connect] to open a connection. You must call [close] when you are done.
abstract class MySqlConnection implements Querier {
  Future<Transaction> begin();

  Future<void> transaction(Future<void> work(Transaction transaction));

  Future<void> close();

  /// Connects to a MySQL server at the given [host] on [port], authenticates
  /// using [user] and [password] and connects to [db].
  static Future<MySqlConnection> connect(ConnectionSettings c) =>
      MySqlConnectionImpl.connect(c);
}

class Transaction implements Querier {
  final MySqlConnection _conn;
  Transaction._(this._conn);

  Future<StreamedResults> execute(String sql) => _conn.execute(sql);

  Future<StreamedResults> prepared(String sql, Iterable values) =>
      _conn.prepared(sql, values);

  Future<Stream<StreamedResults>> preparedWithAll(
          String sql, Iterable<Iterable> values) =>
      _conn.preparedWithAll(sql, values);

  Future<Prepared> prepare(String sql) => _conn.prepare(sql);

  Future<void> commit() => _conn.execute("commit");

  Future<void> rollback() => _conn.execute("rollback");

  static Future<Transaction> begin(MySqlConnection conn) async {
    await conn.execute("start transaction");
    return Transaction._(conn);
  }
}

/// Error throw in `MySqlConnection.transaction` to request a rollback
class RollbackError {}

abstract class Prepared {
  Future<StreamedResults> execute(Iterable values);
  Stream<StreamedResults> executeAll(Iterable<Iterable> values);
  Future<void> deallocate();
}
