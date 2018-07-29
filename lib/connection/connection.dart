library sqljocky.connection;

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import '../auth/handshake_handler.dart';
import '../comm/buffered_socket.dart';
import '../handlers/handler.dart';
import '../handlers/quit_handler.dart';

import '../prepared_statements/close_statement_handler.dart';
import '../prepared_statements/execute_query_handler.dart';
import '../prepared_statements/prepare_handler.dart';
import '../query/query_stream_handler.dart';
import '../results/row.dart';
import '../comm/req_resp.dart';
import '../common/logging.dart';

import 'settings.dart';

export 'settings.dart';

/// Represents a connection to the database. Use [connect] to open a connection. You
/// must call [close] when you are done.
class MySqlConnection {
  final Duration _timeout;

  ReqRespConnection _conn;
  bool _sentClose = false;

  MySqlConnection(this._timeout, this._conn);

  /// Close the connection
  ///
  /// This method will never throw
  Future<void> close() async {
    if (_sentClose) {
      return;
    }
    _sentClose = true;

    try {
      await _conn.processHandlerNoResponse(new QuitHandler(), _timeout);
    } catch (e) {
      logger.info("Error sending quit on connection");
    }

    _conn.close();
  }

  static Future<MySqlConnection> _connect(ConnectionSettings c) async {
    assert(!c.useSSL); // Not implemented
    assert(!c.useCompression);

    ReqRespConnection conn;
    Completer handshakeCompleter;

    logger.fine("opening connection to ${c.host}:${c.port}/${c.db}");

    BufferedSocket socket =
        await BufferedSocket.connect(c.host, c.port, onDataReady: () {
      conn?.readPacket();
    }, onDone: () {
      logger.fine("done");
    }, onError: (error) {
      logger.warning("socket error: $error");

      // If conn has not been connected there was a connection error.
      if (conn == null) {
        handshakeCompleter.completeError(error);
      } else {
        conn.handleError(error);
      }
    }, onClosed: () {
      conn.handleError(new SocketException.closed());
    });

    Handler handler = new HandshakeHandler(c.user, c.password, c.maxPacketSize,
        c.characterSet, c.db, c.useCompression, c.useSSL);
    handshakeCompleter = new Completer();
    conn = new ReqRespConnection(
        socket, handler, handshakeCompleter, c.maxPacketSize);

    await handshakeCompleter.future;
    return new MySqlConnection(c.timeout, conn);
  }

  /// Connects to a MySQL server at the given [host] on [port], authenticates
  /// using [user] and [password] and connects to [db].
  ///
  /// [timeout] is used as the connection timeout and the default timeout for
  /// all socket communication.
  static Future<MySqlConnection> connect(ConnectionSettings c) =>
      _connect(c).timeout(c.timeout);

  Future<Results> query(String sql, [List values]) async {
    if (values == null || values.isEmpty) {
      return _conn.processHandlerWithResults(
          new QueryStreamHandler(sql), _timeout);
    }

    return (await queryMulti(sql, [values])).first;
  }

  Future<List<Results>> queryMulti(String sql, Iterable<List> values) async {
    var prepared;
    var ret = <Results>[];
    try {
      prepared = await _conn.processHandler(new PrepareHandler(sql), _timeout);
      logger.fine("Prepared queryMulti query for: $sql");

      for (List v in values) {
        var handler =
            new ExecuteQueryHandler(prepared, false /* executed */, v);
        ret.add(await _conn.processHandlerWithResults(handler, _timeout));
      }
    } finally {
      if (prepared != null) {
        await _conn.processHandlerNoResponse(
            new CloseStatementHandler(prepared.statementHandlerId), _timeout);
      }
    }
    return ret;
  }

  Future transaction(Future queryBlock(TransactionContext connection)) async {
    await query("start transaction");
    try {
      await queryBlock(new TransactionContext._(this));
    } catch (e) {
      await query("rollback");
      if (e is! _RollbackError) rethrow;
      return e;
    }
    await query("commit");
  }
}

class TransactionContext {
  final MySqlConnection _conn;
  TransactionContext._(this._conn);

  Future<Results> query(String sql, [List values]) => _conn.query(sql, values);
  Future<List<Results>> queryMulti(String sql, Iterable<List> values) =>
      _conn.queryMulti(sql, values);
  void rollback() => throw new _RollbackError();
}

class _RollbackError {}
