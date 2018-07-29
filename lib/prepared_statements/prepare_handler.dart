library sqljocky.prepare_handler;

import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:sqljocky5/constants.dart';
import 'package:typed_buffer/typed_buffer.dart';
import 'package:sqljocky5/exceptions/exceptions.dart';
import '../handlers/handler.dart';
import '../results/field.dart';

import 'prepared_query.dart';
import 'prepare_ok_packet.dart';

class PrepareHandler extends Handler {
  final String _sql;
  PrepareOkPacket _okPacket;
  int _parametersToRead;
  int _columnsToRead;
  List<Field> _parameters;
  List<Field> _columns;

  String get sql => _sql;
  PrepareOkPacket get okPacket => _okPacket;
  List<Field> get parameters => _parameters;
  List<Field> get columns => _columns;

  PrepareHandler(String this._sql) : super(new Logger("PrepareHandler"));

  Uint8List createRequest() {
    List<int> encoded = utf8.encode(_sql);
    var buffer = new FixedWriteBuffer(encoded.length + 1);
    buffer.byte = COM_STMT_PREPARE;
    buffer.writeList(encoded);
    return buffer.data;
  }

  HandlerResponse processResponse(ReadBuffer response) {
    log.fine("Prepare processing response");
    var packet = checkResponse(response, true);
    if (packet == null) {
      log.fine('Not an OK packet, params to read: $_parametersToRead');
      if (_parametersToRead > -1) {
        if (response[0] == PACKET_EOF) {
          log.fine("EOF");
          if (_parametersToRead != 0) {
            throw MySqlProtocolError(
                "Unexpected EOF packet; was expecting another $_parametersToRead parameter(s)");
          }
        } else {
          var fieldPacket = new Field.fromBuffer(response);
          log.fine("field packet: $fieldPacket");
          _parameters[_okPacket.parameterCount - _parametersToRead] =
              fieldPacket;
        }
        _parametersToRead--;
      } else if (_columnsToRead > -1) {
        if (response[0] == PACKET_EOF) {
          log.fine("EOF");
          if (_columnsToRead != 0) {
            throw MySqlProtocolError(
                "Unexpected EOF packet; was expecting another $_columnsToRead column(s)");
          }
        } else {
          var fieldPacket = new Field.fromBuffer(response);
          log.fine("field packet (column): $fieldPacket");
          _columns[_okPacket.columnCount - _columnsToRead] = fieldPacket;
        }
        _columnsToRead--;
      }
    } else if (packet is PrepareOkPacket) {
      log.fine(packet.toString());
      _okPacket = packet;
      _parametersToRead = packet.parameterCount;
      _columnsToRead = packet.columnCount;
      _parameters = new List<Field>(_parametersToRead);
      _columns = new List<Field>(_columnsToRead);
      if (_parametersToRead == 0) {
        _parametersToRead = -1;
      }
      if (_columnsToRead == 0) {
        _columnsToRead = -1;
      }
    }

    if (_parametersToRead == -1 && _columnsToRead == -1) {
      log.fine("finished");
      return new HandlerResponse(
          finished: true, result: new PreparedQuery(this));
    }
    return HandlerResponse.notFinished;
  }
}
