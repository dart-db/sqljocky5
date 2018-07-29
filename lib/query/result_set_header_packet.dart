library sqljocky.result_set_header_packet;

import 'package:sqljocky5/comm/buffer.dart';

class ResultSetHeaderPacket {
  final int fieldCount;
  final int extra;

  ResultSetHeaderPacket(this.fieldCount, this.extra);

  factory ResultSetHeaderPacket.fromBuffer(Buffer buffer) {
    int fieldCount = buffer.readLengthCodedBinary();
    int extra;
    if (buffer.canReadMore()) extra = buffer.readLengthCodedBinary();
    return new ResultSetHeaderPacket(fieldCount, extra);
  }

  String toString() => "Field count: $fieldCount, Extra: $extra";
}
