library sqljocky.connection;

import 'dart:async';

import '../results/results.dart';

import 'settings.dart';
import 'impl.dart';

export 'settings.dart';

abstract class Querier {
  Future<Results> execute(String sql);

  Future<StreamedResults> executeStreamed(String sql);

  Future<Results> prepared(String sql, Iterable values);

  Future<StreamedResults> preparedStreamed(String sql, Iterable values);

  Future<List<Results>> preparedMulti(String sql, Iterable<Iterable> values);

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

  Future<Results> execute(String sql) => _conn.execute(sql);

  Future<StreamedResults> executeStreamed(String sql) =>
      _conn.executeStreamed(sql);

  Future<Results> prepared(String sql, Iterable values) =>
      _conn.prepared(sql, values);

  Future<StreamedResults> preparedStreamed(String sql, Iterable values) =>
      _conn.preparedStreamed(sql, values);

  Future<List<Results>> preparedMulti(String sql, Iterable<Iterable> values) =>
      _conn.preparedMulti(sql, values);

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

class Prepared {
  Future<Results> execute(Iterable values) => throw UnimplementedError();
  Future<StreamedResults> executeStreamed(Iterable values) =>
      throw UnimplementedError();
  Future<Results> executeMulti(Iterable<Iterable> values) =>
      throw UnimplementedError();
}
