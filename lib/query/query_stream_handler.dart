library sqljocky.query_stream_handler;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:sqljocky5/constants.dart';
import 'package:typed_buffer/typed_buffer.dart';

import '../handlers/handler.dart';
import '../handlers/ok_packet.dart';

import '../results/row.dart';
import '../results/field.dart';
import '../results/results.dart';

import 'result_set_header_packet.dart';
import 'package:sqljocky5/results/standard_data_packet.dart';

class QueryStreamHandler extends Handler {
  final String sql;
  int _state = stateHeaderPacket;

  OkPacket _okPacket;
  ResultSetHeaderPacket _resultSetHeaderPacket;
  final fieldPackets = <Field>[];

  Map<String, int> _fieldIndex;

  StreamController<Row> _streamController;

  QueryStreamHandler(String this.sql) : super(new Logger("QueryStreamHandler"));

  Uint8List createRequest() {
    var encoded = utf8.encode(sql);
    var buffer = new FixedWriteBuffer(encoded.length + 1);
    buffer.byte = COM_QUERY;
    buffer.writeList(encoded);
    return buffer.data;
  }

  HandlerResponse processResponse(ReadBuffer response) {
    log.fine("Processing query response");
    var packet = checkResponse(response, false, _state == stateRowPacket);
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        if (_state == stateFieldPacket) {
          return _handleEndOfFields();
        } else if (_state == stateRowPacket) {
          return _handleEndOfRows();
        }
      } else {
        switch (_state) {
          case stateHeaderPacket:
            _handleHeaderPacket(response);
            break;
          case stateFieldPacket:
            _handleFieldPacket(response);
            break;
          case stateRowPacket:
            _handleRowPacket(response);
            break;
        }
      }
    } else if (packet is OkPacket) {
      return _handleOkPacket(packet);
    }
    return HandlerResponse.notFinished;
  }

  _handleEndOfFields() {
    _state = stateRowPacket;
    _streamController = new StreamController<Row>(onCancel: () {
      _streamController.close();
    });
    this._fieldIndex = createFieldIndex();
    return new HandlerResponse(
        result: new ResultsStream(null, null, fieldPackets,
            stream: _streamController.stream));
  }

  _handleEndOfRows() {
    // the connection's _handler field needs to have been nulled out before the stream is closed,
    // otherwise the stream will be reused in an unfinished state.
    // TODO: can we use Future.delayed elsewhere, to make reusing connections nicer?
    //    new Future.delayed(new Duration(seconds: 0), _streamController.close);
    _streamController.close();
    return new HandlerResponse(finished: true);
  }

  _handleHeaderPacket(ReadBuffer response) {
    _resultSetHeaderPacket = new ResultSetHeaderPacket.fromBuffer(response);
    log.fine(_resultSetHeaderPacket.toString());
    _state = stateFieldPacket;
  }

  _handleFieldPacket(ReadBuffer response) {
    var fieldPacket = new Field.fromBuffer(response);
    log.fine(fieldPacket.toString());
    fieldPackets.add(fieldPacket);
  }

  _handleRowPacket(ReadBuffer response) {
    List<dynamic> values = parseStandardDataResponse(response, fieldPackets);
    var row = new Row(values, _fieldIndex);
    log.fine(row.toString());
    _streamController.add(row);
  }

  _handleOkPacket(packet) {
    _okPacket = packet;
    var finished = false;
    // TODO: I think this is to do with multiple queries. Will probably break.
    if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
      finished = true;
    }

    //TODO is this finished value right?
    return new HandlerResponse(
        finished: finished,
        result: new ResultsStream(
            _okPacket.insertId, _okPacket.affectedRows, fieldPackets));
  }

  Map<String, int> createFieldIndex() {
    var identifierPattern = new RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');
    var fieldIndex = new Map<String, int>();
    for (var i = 0; i < fieldPackets.length; i++) {
      var name = fieldPackets[i].name;
      if (identifierPattern.hasMatch(name)) {
        fieldIndex[name] = i;
      }
    }
    return fieldIndex;
  }

  @override
  String toString() => "QueryStreamHandler($sql)";

  static const int stateHeaderPacket = 0;
  static const int stateFieldPacket = 1;
  static const int stateRowPacket = 2;
}
