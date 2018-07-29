library sqljocky.execute_query_handler;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:sqljocky5/constants.dart';
import 'package:typed_buffer/typed_buffer.dart';
import '../handlers/handler.dart';
import '../handlers/ok_packet.dart';

import 'package:sqljocky5/results/binary_data_packet.dart';
import 'prepared_query.dart';

import '../results/results.dart';
import '../results/field.dart';
import '../results/row.dart';
import 'package:sqljocky5/results/blob.dart';
import 'package:sqljocky5/utils/buffer.dart';

class ExecuteQueryHandler extends HandlerWithResult {
  final PreparedQuery preparedQuery;
  final List _values;

  int _state = STATE_HEADER_PACKET;

  List<Field> fieldPackets;
  Map<String, int> _fieldIndex;
  StreamController<Row> _streamController;

  List preparedValues;
  OkPacket _okPacket;
  bool _executed;
  bool _cancelled = false;

  final _resultsCompleter = Completer<StreamedResults>();

  ExecuteQueryHandler(
      this.preparedQuery, bool this._executed, List this._values)
      : super(new Logger("ExecuteQueryHandler")) {
    fieldPackets = <Field>[];
  }

  Uint8List createRequest() {
    var length = 0;
    var types = new List<int>(_values.length * 2);
    var nullMap = createNullMap();
    preparedValues = new List(_values.length);
    for (var i = 0; i < _values.length; i++) {
      types[i * 2] = _getType(_values[i]);
      types[i * 2 + 1] = 0;
      preparedValues[i] = prepareValue(_values[i]);
      length += measureValue(_values[i], preparedValues[i]);
    }

    var buffer = writeValuesToBuffer(nullMap, length, types);
    return buffer;
  }

  dynamic prepareValue(value) {
    if (value != null) {
      if (value is int) {
        return _prepareInt(value);
      } else if (value is double) {
        return _prepareDouble(value);
      } else if (value is DateTime) {
        return _prepareDateTime(value);
      } else if (value is bool) {
        return _prepareBool(value);
      } else if (value is List<int>) {
        return _prepareList(value);
      } else if (value is Blob) {
        return _prepareBlob(value);
      } else {
        return _prepareString(value);
      }
    }
    return value;
  }

  int measureValue(value, preparedValue) {
    if (value != null) {
      if (value is int) {
        return _measureInt(value, preparedValue);
      } else if (value is double) {
        return _measureDouble(value, preparedValue);
      } else if (value is DateTime) {
        return _measureDateTime(value, preparedValue);
      } else if (value is bool) {
        return _measureBool(value, preparedValue);
      } else if (value is List<int>) {
        return _measureList(value, preparedValue);
      } else if (value is Blob) {
        return _measureBlob(value, preparedValue);
      } else {
        return _measureString(value, preparedValue);
      }
    }
    return 0;
  }

  int _getType(value) {
    if (value != null) {
      if (value is int) {
        return FIELD_TYPE_LONGLONG;
      } else if (value is double) {
        return FIELD_TYPE_VARCHAR;
      } else if (value is DateTime) {
        return FIELD_TYPE_DATETIME;
      } else if (value is bool) {
        return FIELD_TYPE_TINY;
      } else if (value is List<int>) {
        return FIELD_TYPE_BLOB;
      } else if (value is Blob) {
        return FIELD_TYPE_BLOB;
      } else {
        return FIELD_TYPE_VARCHAR;
      }
    } else {
      return FIELD_TYPE_NULL;
    }
  }

  void _writeValue(value, preparedValue, FixedWriteBuffer buffer) {
    if (value != null) {
      if (value is int) {
        _writeInt(value, preparedValue, buffer);
      } else if (value is double) {
        _writeDouble(value, preparedValue, buffer);
      } else if (value is DateTime) {
        _writeDateTime(value, preparedValue, buffer);
      } else if (value is bool) {
        _writeBool(value, preparedValue, buffer);
      } else if (value is List<int>) {
        _writeList(value, preparedValue, buffer);
      } else if (value is Blob) {
        _writeBlob(value, preparedValue, buffer);
      } else {
        _writeString(value, preparedValue, buffer);
      }
    }
  }

  int _prepareInt(value) => value;

  int _measureInt(value, preparedValue) {
    return 8;
  }

  _writeInt(value, preparedValue, FixedWriteBuffer buffer) {
    buffer.byte = value >> 0x00 & 0xFF;
    buffer.byte = value >> 0x08 & 0xFF;
    buffer.byte = value >> 0x10 & 0xFF;
    buffer.byte = value >> 0x18 & 0xFF;
    buffer.byte = value >> 0x20 & 0xFF;
    buffer.byte = value >> 0x28 & 0xFF;
    buffer.byte = value >> 0x30 & 0xFF;
    buffer.byte = value >> 0x38 & 0xFF;
  }

  List<int> _prepareDouble(value) => utf8.encode(value.toString());

  int _measureDouble(value, preparedValue) {
    return measureLengthCodedBinary(preparedValue.length) +
        preparedValue.length;
  }

  void _writeDouble(value, preparedValue, FixedWriteBuffer buffer) {
    buffer.writeLengthCodedBinary(preparedValue.length);
    buffer.writeList(preparedValue);
    // TODO: if you send a double value for a decimal field, it doesn't like it
    //          types.add(FIELD_TYPE_FLOAT);
    //          types.add(0);
    //          values.addAll(doubleToList(value));
  }

  _prepareDateTime(value) {
    return value;
  }

  int _measureDateTime(value, preparedValue) {
    return 8;
  }

  void _writeDateTime(value, preparedValue, FixedWriteBuffer buffer) {
    // TODO remove Date eventually
    log.fine("DATE: $value");
    buffer.byte = 7;
    buffer.byte = value.year >> 0x00 & 0xFF;
    buffer.byte = value.year >> 0x08 & 0xFF;
    buffer.byte = value.month;
    buffer.byte = value.day;
    buffer.byte = value.hour;
    buffer.byte = value.minute;
    buffer.byte = value.second;
  }

  bool _prepareBool(bool value) => value;

  int _measureBool(value, preparedValue) => 1;

  void _writeBool(value, preparedValue, FixedWriteBuffer buffer) {
    buffer.byte = value ? 1 : 0;
  }

  List<int> _prepareList(List<int> value) => value;

  int _measureList(value, preparedValue) {
    return measureLengthCodedBinary(value.length) + value.length;
  }

  void _writeList(value, preparedValue, FixedWriteBuffer buffer) {
    buffer.writeLengthCodedBinary(value.length);
    buffer.writeList(value);
  }

  List<int> _prepareBlob(Blob value) => value.toBytes();

  int _measureBlob(value, preparedValue) {
    return measureLengthCodedBinary(preparedValue.length) +
        preparedValue.length;
  }

  void _writeBlob(value, preparedValue, FixedWriteBuffer buffer) {
    buffer.writeLengthCodedBinary(preparedValue.length);
    buffer.writeList(preparedValue);
  }

  List<int> _prepareString(value) => utf8.encode(value.toString());

  int _measureString(value, preparedValue) {
    return measureLengthCodedBinary(preparedValue.length) +
        preparedValue.length;
  }

  void _writeString(value, preparedValue, FixedWriteBuffer buffer) {
    buffer.writeLengthCodedBinary(preparedValue.length);
    buffer.writeList(preparedValue);
  }

  List<int> createNullMap() {
    var bytes = ((_values.length + 7) / 8).floor().toInt();
    var nullMap = new List<int>(bytes);
    var byte = 0;
    var bit = 0;
    for (var i = 0; i < _values.length; i++) {
      if (nullMap[byte] == null) {
        nullMap[byte] = 0;
      }
      if (_values[i] == null) {
        nullMap[byte] = nullMap[byte] + (1 << bit);
      }
      bit++;
      if (bit > 7) {
        bit = 0;
        byte++;
      }
    }

    return nullMap;
  }

  Uint8List writeValuesToBuffer(
      List<int> nullMap, int length, List<int> types) {
    var buffer =
        new FixedWriteBuffer(10 + nullMap.length + 1 + types.length + length);
    buffer.byte = COM_STMT_EXECUTE;
    buffer.uint32 = preparedQuery.statementHandlerId;
    buffer.byte = 0;
    buffer.uint32 = 1;
    buffer.writeList(nullMap);
    if (!_executed) {
      buffer.byte = 1;
      buffer.writeList(types);
      for (int i = 0; i < _values.length; i++) {
        _writeValue(_values[i], preparedValues[i], buffer);
      }
    } else {
      buffer.byte = 0;
    }
    return buffer.data;
  }

  HandlerResponse processResponse(ReadBuffer response) {
    var packet;
    if (_cancelled) {
      _streamController.close();
      return new HandlerResponse(finished: true);
    }
    if (_state == STATE_HEADER_PACKET) {
      packet = checkResponse(response);
    }
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        log.fine('Got an EOF');
        if (_state == STATE_FIELD_PACKETS) {
          return _handleEndOfFields();
        } else if (_state == STATE_ROW_PACKETS) {
          return _handleEndOfRows();
        }
      } else {
        switch (_state) {
          case STATE_HEADER_PACKET:
            _handleHeaderPacket(response);
            break;
          case STATE_FIELD_PACKETS:
            _handleFieldPacket(response);
            break;
          case STATE_ROW_PACKETS:
            _handleRowPacket(response);
            break;
        }
      }
    } else if (packet is OkPacket) {
      _okPacket = packet;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        var stream =
            new StreamedResults(_okPacket.insertId, _okPacket.affectedRows, null);
        _resultsCompleter.complete(stream);
        return new HandlerResponse(finished: true, result: stream);
      }
    }
    return HandlerResponse.notFinished;
  }

  HandlerResponse _handleEndOfFields() {
    _state = STATE_ROW_PACKETS;
    _streamController = new StreamController<Row>();
    _streamController.onCancel = () {
      _cancelled = true;
    };
    this._fieldIndex = createFieldIndex();
    var stream = new StreamedResults(null, null, fieldPackets,
        stream: _streamController.stream);
    _resultsCompleter.complete(stream);
    return new HandlerResponse(result: stream);
  }

  HandlerResponse _handleEndOfRows() {
    _streamController.close();
    return new HandlerResponse(finished: true);
  }

  _handleHeaderPacket(ReadBuffer response) {
    // var resultSetHeaderPacket = new ResultSetHeaderPacket.fromBuffer(response);
    _state = STATE_FIELD_PACKETS;
  }

  void _handleFieldPacket(ReadBuffer response) {
    var fieldPacket = new Field.fromBuffer(response);
    fieldPackets.add(fieldPacket);
  }

  void _handleRowPacket(ReadBuffer response) {
    List<dynamic> values = parseBinaryDataResponse(response, fieldPackets);
    var dataPacket = new Row(values, _fieldIndex);
    _streamController.add(dataPacket);
  }

  Map<String, int> createFieldIndex() {
    var identifierPattern = new RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');
    var fieldIndex = <String, int>{};
    for (var i = 0; i < fieldPackets.length; i++) {
      var name = fieldPackets[i].name;
      if (identifierPattern.hasMatch(name)) {
        fieldIndex[name] = i;
      }
    }
    return fieldIndex;
  }

  @override
  Future<StreamedResults> get streamedResults => _resultsCompleter.future;

  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;
}
