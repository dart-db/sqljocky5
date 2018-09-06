import 'dart:async';

import '../handlers/quit_handler.dart';

import '../prepared_statements/close_statement_handler.dart';
import '../prepared_statements/execute_query_handler.dart';
import '../prepared_statements/prepare_handler.dart';
import '../query/query_stream_handler.dart';
import '../results/results.dart';
import '../comm/comm.dart';

import 'connection.dart';

class MySqlConnectionImpl implements MySqlConnection {
  final Duration _timeout;

  final Comm _socket;
  bool _sentClose = false;

  MySqlConnectionImpl(this._timeout, this._socket);

  Future<Results> execute(String sql) =>
      _socket.execHandlerWithResults(QueryStreamHandler(sql), _timeout);

  Future<StreamedResults> executeStreamed(String sql) =>
      _socket.execHandlerStreamed(QueryStreamHandler(sql), _timeout);

  Future<Results> prepared(String sql, [Iterable values]) async {
    PreparedQuery prepared;
    try {
      prepared = await _socket.execHandler(PrepareHandler(sql), _timeout);
      var handler = ExecuteQueryHandler(prepared, false, values);
      return _socket.execHandlerWithResults(handler, _timeout);
    } catch (e) {
      if (prepared != null) {
        _socket.execHandlerNoResponse(
            CloseStatementHandler(prepared.statementHandlerId), _timeout);
      }
      rethrow;
    }
  }

  Future<StreamedResults> preparedStreamed(String sql, Iterable values) async {
    PreparedQuery prepared;
    try {
      prepared = await _socket.execHandler(new PrepareHandler(sql), _timeout);
      var handler = new ExecuteQueryHandler(prepared, false, values);
      return _socket.execHandlerStreamed(handler, _timeout);
    } catch (e) {
      if (prepared != null) {
        await _socket.execHandlerNoResponse(
            CloseStatementHandler(prepared.statementHandlerId), _timeout);
      }
      rethrow;
    }
  }

  Future<List<Results>> preparedMulti(
      String sql, Iterable<Iterable> values) async {
    PreparedQuery prepared;
    var ret = List<Results>()..length = values.length;
    try {
      prepared = await _socket.execHandler(new PrepareHandler(sql), _timeout);
      for (int i = 0; i < values.length; i++) {
        Iterable v = values.elementAt(i);
        var handler = new ExecuteQueryHandler(prepared, false, v);
        ret[i] = await _socket.execHandlerWithResults(handler, _timeout);
      }
      return ret;
    } catch (e) {
      if (prepared != null) {
        _socket.execHandlerNoResponse(
            new CloseStatementHandler(prepared.statementHandlerId), _timeout);
      }
      rethrow;
    }
  }

  @override
  Future<Prepared> prepare(String sql) => throw UnimplementedError();

  Future<Transaction> begin() => Transaction.begin(this);

  Future<void> transaction(Future<void> work(Transaction transaction)) async {
    Transaction trans = await Transaction.begin(this);
    try {
      await work(trans);
    } catch (e) {
      await trans.rollback();
      if (e is! RollbackError) rethrow;
      return e;
    }
    await trans.commit();
  }

  /// Closes the connection
  ///
  /// This method will never throw
  Future<void> close() async {
    if (_sentClose) return;
    _sentClose = true;

    // TODO peacefully close the current handler!

    try {
      await _socket.execHandlerNoResponse(new QuitHandler(), _timeout);
    } catch (e) {}

    _socket.close();
  }

  static Future<MySqlConnection> connect(ConnectionSettings c) async {
    var comm = await Comm.connect(c);
    return MySqlConnectionImpl(c.timeout, comm);
  }
}
