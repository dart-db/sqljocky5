import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import '../handlers/handler.dart';
import 'package:pool/pool.dart';
import 'buffer.dart';
import 'buffered_socket.dart';
import '../auth/ssl_handler.dart';
import '../comm/buffer.dart';
import 'package:sqljocky5/exceptions/exceptions.dart';
import '../common/logging.dart';
import '../results/results_impl.dart';
import '../results/row.dart';
import '../auth/handshake_handler.dart';

class ReqRespSocket {
  /// Underlying socket
  final BufferedSocket _socket;

  Handler _handler;

  /// Completes when the handshake is done.
  Completer _completer;

  final _largePacketBuffers = <Buffer>[];

  final Buffer _headerBuffer;
  final Buffer _compressedHeaderBuffer;
  Buffer _dataBuffer;
  bool _readyForHeader = true;

  int _packetNumber = 0;

  int _compressedPacketNumber = 0;
  bool _useCompression = false;
  bool _useSSL = false;

  /// Sets the maximum packet size limit
  final int maxPacketSize;

  final pool = new Pool(1);

  ReqRespSocket(
      this._socket, this._handler, this._completer, this.maxPacketSize)
      : _headerBuffer = new Buffer(headerSize),
        _compressedHeaderBuffer = new Buffer(compressionHeaderSize);

  void close() => _socket.close();

  void handleError(e, {bool keepOpen = false, st}) {
    if (_completer != null) {
      if (_completer.isCompleted) {
        logger.warning("Ignoring error because no response", e, st);
      } else {
        _completer.completeError(e, st);
      }
    }
    if (!keepOpen) {
      close();
    }
  }

  Future<void> readPacket() async {
    logger.fine("readPacket readyForHeader=${_readyForHeader}");
    if (_readyForHeader) {
      _readyForHeader = false;
      var buffer = await _socket.readBuffer(_headerBuffer);
      _handleHeader(buffer);
    }
  }

  _handleHeader(buffer) async {
    int _dataSize = buffer[0] + (buffer[1] << 8) + (buffer[2] << 16);
    _packetNumber = buffer[3];
    logger.fine("about to read $_dataSize bytes for packet ${_packetNumber}");
    _dataBuffer = new Buffer(_dataSize);
    logger.fine("buffer size=${_dataBuffer.length}");
    if (_dataSize == 0xffffff || _largePacketBuffers.isNotEmpty) {
      var buffer = await _socket.readBuffer(_dataBuffer);
      _handleMoreData(buffer);
    } else {
      var buffer = await _socket.readBuffer(_dataBuffer);
      _handleData(buffer);
    }
  }

  void _handleMoreData(buffer) {
    _largePacketBuffers.add(buffer);
    if (buffer.length < 0xffffff) {
      var length = _largePacketBuffers.fold(0, (length, buf) {
        return length + buf.length;
      });
      var combinedBuffer = new Buffer(length);
      var start = 0;
      _largePacketBuffers.forEach((aBuffer) {
        combinedBuffer.list
            .setRange(start, start + aBuffer.length, aBuffer.list);
        start += aBuffer.length;
      });
      _largePacketBuffers.clear();
      _handleData(combinedBuffer);
    } else {
      _readyForHeader = true;
      _headerBuffer.reset();
      readPacket();
    }
  }

  _handleData(buffer) async {
    _readyForHeader = true;
    _headerBuffer.reset();

    try {
      var response = _handler.processResponse(buffer);
      if (_handler is HandshakeHandler) {
        _useCompression = (_handler as HandshakeHandler).useCompression;
        _useSSL = (_handler as HandshakeHandler).useSSL;
      }
      if (response.nextHandler != null) {
        // if handler.processResponse() returned a Handler, pass control to that handler now
        _handler = response.nextHandler;
        await sendBuffer(_handler.createRequest());
        if (_useSSL && _handler is SSLHandler) {
          logger.fine("Use SSL");
          await _socket.startSSL();
          _handler = (_handler as SSLHandler).nextHandler;
          await sendBuffer(_handler.createRequest());
          logger.fine("Sent buffer");
          return;
        }
      }

      if (response.finished) {
        logger.fine("Finished $_handler");
        _finishAndReuse();
      }
      if (response.hasResult) {
        if (_completer.isCompleted) {
          _completer
              .completeError(new StateError("Request has already completed"));
        }
        _completer.complete(response.result);
      }
    } on MySqlException catch (e, st) {
      // This clause means mysql returned an error on the wire. It is not a fatal error
      // and the connection can stay open.
      logger.fine("completing with MySqlException: $e");
      _finishAndReuse();
      handleError(e, st: st, keepOpen: true);
    } catch (e, st) {
      // Errors here are fatal_finishAndReuse();
      handleError(e, st: st);
    }
  }

  void _finishAndReuse() {
    _handler = null;
  }

  Future sendBuffer(Buffer buffer) {
    if (buffer.length > maxPacketSize) {
      throw MySqlClientError(
          "Buffer length (${buffer.length}) bigger than maxPacketSize ($maxPacketSize)");
    }
    if (_useCompression) {
      _headerBuffer[0] = buffer.length & 0xFF;
      _headerBuffer[1] = (buffer.length & 0xFF00) >> 8;
      _headerBuffer[2] = (buffer.length & 0xFF0000) >> 16;
      _headerBuffer[3] = ++_packetNumber;
      var encodedHeader = zlib.encode(_headerBuffer.list);
      var encodedBuffer = zlib.encode(buffer.list);
      _compressedHeaderBuffer
          .writeUint24(encodedHeader.length + encodedBuffer.length);
      _compressedHeaderBuffer.writeByte(++_compressedPacketNumber);
      _compressedHeaderBuffer.writeUint24(4 + buffer.length);
      return _socket.writeBuffer(_compressedHeaderBuffer);
    } else {
      logger.fine("sendBuffer header");
      return _sendBufferPart(buffer, 0);
    }
  }

  Future<Buffer> _sendBufferPart(Buffer buffer, int start) async {
    var len = math.min(buffer.length - start, 0xFFFFFF);

    _headerBuffer[0] = len & 0xFF;
    _headerBuffer[1] = (len & 0xFF00) >> 8;
    _headerBuffer[2] = (len & 0xFF0000) >> 16;
    _headerBuffer[3] = ++_packetNumber;
    logger.fine("sending header, packet $_packetNumber");
    await _socket.writeBuffer(_headerBuffer);
    logger.fine(
        "sendBuffer body, buffer length=${buffer.length}, start=$start, len=$len");
    await _socket.writeBufferPart(buffer, start, len);
    if (len == 0xFFFFFF) {
      return _sendBufferPart(buffer, start + len);
    } else {
      return buffer;
    }
  }

  /// This method just sends the handler data.
  Future _processHandlerNoResponse(Handler handler) {
    if (_handler != null) {
      throw MySqlClientError(
          "Connection cannot process a request for $handler while a request is already in progress for $_handler");
    }
    _packetNumber = -1;
    _compressedPacketNumber = -1;
    return sendBuffer(handler.createRequest());
  }

  /// Processes a handler, from sending the initial request to handling any
  /// packets returned from mysql
  Future _processHandler(Handler handler) async {
    if (_handler != null) {
      throw MySqlClientError(
          "Connection cannot process a request for $handler while a request is already in progress for $_handler");
    }
    logger.fine("start handler $handler");
    _packetNumber = -1;
    _compressedPacketNumber = -1;
    _completer = new Completer<dynamic>();
    _handler = handler;
    await sendBuffer(handler.createRequest());
    return _completer.future;
  }

  Future<dynamic> processHandler(Handler handler, Duration timeout) {
    return pool.withResource(() => _processHandler(handler).timeout(timeout));
  }

  Future<Results> processHandlerWithResults(Handler handler, Duration timeout) {
    return pool.withResource(() async {
      ResultsStream results = await _processHandler(handler).timeout(timeout);

      // Read all of the results. This is so we can close the handler before returning to the
      // user. Obviously this is not super efficient but it guarantees correct api use.
      Results ret = await Results.read(results).timeout(timeout);

      return ret;
    });
  }

  Future<void> processHandlerNoResponse(Handler handler, Duration timeout) {
    return pool.withResource(
        () => _processHandlerNoResponse(handler).timeout(timeout));
  }

  static const int headerSize = 4;
  static const int compressionHeaderSize = 7;
  static const int statePacketHeader = 0;
  static const int statePacketData = 1;
}
