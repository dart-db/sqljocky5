library sqljocky.result_set_header_packet;

import 'package:typed_buffer/typed_buffer.dart';

class ResultSetHeaderPacket {
  final int fieldCount;
  final int extra;

  ResultSetHeaderPacket(this.fieldCount, this.extra);

  factory ResultSetHeaderPacket.fromBuffer(ReadBuffer buffer) {
    int fieldCount = buffer.readLengthCodedBinary();
    int extra;
    if (buffer.canReadMore) extra = buffer.readLengthCodedBinary();
    return ResultSetHeaderPacket(fieldCount, extra);
  }

  String toString() => "Field count: $fieldCount, Extra: $extra";
}
