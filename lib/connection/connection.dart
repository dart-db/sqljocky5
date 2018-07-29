library sqljocky.connection;

import 'dart:async';
import 'dart:io';

import '../auth/handshake_handler.dart';
import '../comm/buffered_socket.dart';
import '../handlers/handler.dart';
import '../handlers/quit_handler.dart';

import '../prepared_statements/close_statement_handler.dart';
import '../prepared_statements/execute_query_handler.dart';
import '../prepared_statements/prepare_handler.dart';
import '../query/query_stream_handler.dart';
import '../results/results.dart';
import '../comm/comm.dart';
import '../common/logging.dart';

import 'settings.dart';

export 'settings.dart';

/// Represents a connection to the database. Use [connect] to open a connection. You
/// must call [close] when you are done.
class MySqlConnection {
  final Duration _timeout;

  final Comm _socket;
  bool _sentClose = false;

  MySqlConnection(this._timeout, this._socket);

  /// Closes the connection
  ///
  /// This method will never throw
  Future<void> close() async {
    if (_sentClose) return;
    _sentClose = true;

    // TODO peacefully close the current handler!

    try {
      await _socket.execHandlerNoResponse(new QuitHandler(), _timeout);
    } catch (e) {
      logger.info("Error sending quit on connection");
    }

    _socket.close();
  }

  static Future<MySqlConnection> _connect(ConnectionSettings c) async {
    assert(!c.useSSL); // Not implemented
    assert(!c.useCompression);

    Comm comm;
    Completer handshakeCompleter;

    logger.fine("Opening connection to ${c.host}:${c.port}/${c.db}");

    final socket =
        await BufferedSocket.connect(c.host, c.port, onDataReady: () {
      comm?.readPacket();
    }, onDone: () {
      logger.fine("Done");
    }, onError: (error) {
      logger.warning("Socket error: $error");

      // If conn has not been connected there was a connection error.
      if (comm == null) {
        handshakeCompleter.completeError(error);
      } else {
        comm.forwardError(error);
      }
    }, onClosed: () {
      comm.forwardError(new SocketException.closed());
    });

    Handler handler = new HandshakeHandler(c.user, c.password, c.maxPacketSize,
        c.characterSet, c.db, c.useCompression, c.useSSL);
    handshakeCompleter = new Completer();
    comm = new Comm(socket, handler, handshakeCompleter, c.maxPacketSize);

    return handshakeCompleter.future
        .then((_) => new MySqlConnection(c.timeout, comm));
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
      return _socket.execHandlerWithResults(
          new QueryStreamHandler(sql), _timeout);
    }

    return (await queryMulti(sql, [values])).first;
  }

  Future<StreamedResults> queryStreamed(String sql, [List values]) async {
    if (values == null || values.isEmpty) {
      return _socket.execHandlerWithResultsStreamed(
          new QueryStreamHandler(sql), _timeout);
    }

    PreparedQuery prepared;
    try {
      prepared = await _socket.execHandler(new PrepareHandler(sql), _timeout);
      logger.fine("Prepared queryMulti query for: $sql");

      var handler =
          new ExecuteQueryHandler(prepared, false /* executed */, values);
      return _socket.execHandlerWithResultsStreamed(handler, _timeout);
    } finally {
      if (prepared != null) {
        await _socket.execHandlerNoResponse(
            new CloseStatementHandler(prepared.statementHandlerId), _timeout);
      }
      // TODO throw?
    }
    return null;
  }

  Future<List<Results>> queryMulti(String sql, Iterable<List> values) async {
    PreparedQuery prepared;
    var ret = new List<Results>()..length = values.length;
    try {
      prepared = await _socket.execHandler(new PrepareHandler(sql), _timeout);
      logger.fine("Prepared queryMulti query for: $sql");

      for (int i = 0; i < values.length; i++) {
        List v = values.elementAt(i);
        var handler =
            new ExecuteQueryHandler(prepared, false /* executed */, v);
        ret[i] = await _socket.execHandlerWithResults(handler, _timeout);
      }
    } finally {
      if (prepared != null) {
        await _socket.execHandlerNoResponse(
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
