library sqljocky.use_db_handler;

import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:sqljocky5/constants.dart';
import 'package:typed_buffer/typed_buffer.dart';
import 'handler.dart';

class UseDbHandler extends Handler {
  final String _dbName;

  UseDbHandler(String this._dbName) : super(new Logger("UseDbHandler"));

  Uint8List createRequest() {
    List<int> encoded = utf8.encode(_dbName);
    var buffer = new FixedWriteBuffer(encoded.length + 1);
    buffer.byte = COM_INIT_DB;
    buffer.writeList(encoded);
    return buffer.data;
  }
}
