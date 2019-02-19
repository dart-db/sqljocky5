library sqljocky.connection;

import 'dart:async';
import 'package:sqljocky5/public/results/future.dart';

import '../results/results.dart';

import 'settings.dart';
import 'package:sqljocky5/internal/connection/impl.dart';

export 'settings.dart';

/// [Querier] defines the interface to execute normal and prepared SQL statements.
///
/// Both [MySqlConnection] and [Transaction] implement [Querier] interface. This
/// enables to logic that works without guessing it would be a connection or a
/// transaction.
abstract class Querier {
  /// Executes the given [sql] statement and returns the result.
  StreamedFuture execute(String sql);

  Future<StreamedResults> prepared(String sql, Iterable values);

  Stream<StreamedResults> preparedWithAll(
      String sql, Iterable<Iterable> values);

  Future<Prepared> prepare(String sql);
}

/// A connection to MySql or MariaDb database.
///
/// Use [connect] to open a new connection. You must call [close] when you are
/// done.
abstract class MySqlConnection implements Querier {
  /// Creates and returns a new transaction.
  Future<Transaction> begin();

  /// Functional way to execute a transaction. This method takes care of creating
  /// and releasing the transaction.
  Future<void> transaction(Future<void> work(Transaction transaction));

  /// Closes the connection.
  Future<void> close();

  /// Connects to a MySQL server at the given [host] on [port], authenticates
  /// using [user] and [password] and connects to [db].
  static Future<MySqlConnection> connect(ConnectionSettings c) =>
      MySqlConnectionImpl.connect(c);
}

class Transaction implements Querier {
  final MySqlConnection _conn;
  Transaction._(this._conn);

  StreamedFuture execute(String sql) => _conn.execute(sql);

  Future<StreamedResults> prepared(String sql, Iterable values) =>
      _conn.prepared(sql, values);

  Stream<StreamedResults> preparedWithAll(
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

/// [Prepared] defines interface for a prepared SQL statement.
abstract class Prepared {
  /// Executes the statement with given [values].
  Future<StreamedResults> execute(Iterable values);

  /// Executes the statement multiple times with the given [values].
  Stream<StreamedResults> executeAll(Iterable<Iterable> values);

  /// Releases the prepared statement.
  Future<void> deallocate();
}

/// Error that shall be throw in `MySqlConnection.transaction` to request a
/// rollback
class RollbackError {}
