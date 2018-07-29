import 'dart:async';

import 'buffered_socket.dart';
import 'common.dart';
import 'package:typed_buffer/typed_buffer.dart';

class RxPacket {
  final int packetNum;

  final ReadBuffer data;

  RxPacket(this.packetNum, this.data);
}

class Receiver {
  /// Underlying socket.
  final BufferedSocket _socket;

  /// Buffer globalized for performance.
  final ReadBuffer _header;

  /// Reading state of the receiver.
  bool _isReading = true;

  Receiver(this._socket) : _header = new ReadBuffer(headerSize);

  Future<RxPacket> receive() async {
    if (!_isReading) return null;

    _isReading = false;

    await _socket.readBuffer(_header);
    int dataSize = _header[0] + (_header[1] << 8) + (_header[2] << 16);
    int packetNumber = _header[3];
    var data = new ReadBuffer(dataSize);
    await _socket.readBuffer(data);

    if (dataSize == 0xffffff) {
      final buffers = <ReadBuffer>[data];
      while (data.length == 0xffffff) {
        await _socket.readBuffer(_header);
        int dataSize = _header[0] + (_header[1] << 8) + (_header[2] << 16);
        packetNumber = _header[3];
        var buf = new ReadBuffer(dataSize);
        await _socket.readBuffer(buf);
        buffers.add(buf);
      }

      int length = 0;
      for (ReadBuffer buf in buffers) length += buf.length;
      data = new ReadBuffer(length);
      int start = 0;
      for (ReadBuffer buf in buffers) {
        data.data.setRange(start, start + buf.length, buf.data);
        start += buf.length;
      }
    }

    _isReading = true;

    return new RxPacket(packetNumber, data);
  }
}
