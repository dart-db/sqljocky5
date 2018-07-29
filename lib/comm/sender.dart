import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'buffered_socket.dart';
import 'package:typed_buffer/typed_buffer.dart';
import 'package:sqljocky5/exceptions/exceptions.dart';

import 'common.dart';

const int compressionHeaderSize = 7;

class Sender {
  /// Underlying socket.
  final BufferedSocket _socket;

  /// Buffer globalized for performance.
  final FixedWriteBuffer _header;
  final FixedWriteBuffer _compressedHeader;
  final int maxPacketSize;

  Sender(this._socket, this.maxPacketSize)
      : _header = new FixedWriteBuffer(headerSize),
        _compressedHeader = new FixedWriteBuffer(compressionHeaderSize);

  Future<void> send(Uint8List buffer, PacketNumber packetNum,
      {bool compress = false}) async {
    if (buffer.length > maxPacketSize) {
      throw MySqlClientError("Buffer length exceeds limit!");
    }

    if (compress) {
      _header[0] = buffer.length & 0xFF;
      _header[1] = (buffer.length & 0xFF00) >> 8;
      _header[2] = (buffer.length & 0xFF0000) >> 16;
      _header[3] = ++packetNum.packNum;
      var encodedHeader = zlib.encode(_header.data);
      var encodedBuffer = zlib.encode(buffer);
      _compressedHeader.uint24 = encodedHeader.length + encodedBuffer.length;
      _compressedHeader.byte = ++packetNum.compressedPackNum;
      _compressedHeader.uint24 = 4 + buffer.length;
      return _socket.writeBuffer(_compressedHeader.data);
    } else {
      return _sendBufferPart(buffer, 0, packetNum);
    }
  }

  Future<void> _sendBufferPart(
      Uint8List buffer, int start, PacketNumber packetNum) async {
    int len = math.min(buffer.length - start, 0xFFFFFF);

    _header[0] = len & 0xFF;
    _header[1] = (len & 0xFF00) >> 8;
    _header[2] = (len & 0xFF0000) >> 16;
    _header[3] = ++packetNum.packNum;
    await _socket.writeBuffer(_header.data);
    await _socket.writeBufferPart(buffer, start, len);
    if (len == 0xFFFFFF) return _sendBufferPart(buffer, start + len, packetNum);
  }
}
