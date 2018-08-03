library sqljocky.connection;

import 'dart:async';

import '../results/results.dart';

import 'settings.dart';
import 'impl.dart';

export 'settings.dart';

/// A connection to MySql or MariaDb database.
///
/// Use [connect] to open a connection. You must call [close] when you are done.
abstract class MySqlConnection {
  Future<Results> execute(String sql);

  Future<StreamedResults> executeStreamed(String sql);

  Future<Results> query(String sql, Iterable values);

  Future<StreamedResults> queryStreamed(String sql, Iterable values);

  Future<List<Results>> queryMulti(String sql, Iterable<Iterable> values);

  Future<void> transaction(Future queryBlock(TransactionContext connection));

  Future<void> close();

  /// Connects to a MySQL server at the given [host] on [port], authenticates
  /// using [user] and [password] and connects to [db].
  static Future<MySqlConnection> connect(ConnectionSettings c) =>
      MySqlConnectionImpl.connect(c);
}

class TransactionContext {
  final MySqlConnection _conn;
  TransactionContext(this._conn);

  Future<Results> query(String sql, [List values]) => _conn.query(sql, values);
  Future<List<Results>> queryMulti(String sql, Iterable<List> values) =>
      _conn.queryMulti(sql, values);
  void rollback() => throw new RollbackError();
}

class RollbackError {}
