library buffered_socket;

import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:typed_buffer/typed_buffer.dart';

typedef ErrorHandler(err);
typedef DoneHandler();
typedef DataReadyHandler();
typedef ClosedHandler();

typedef Future<RawSocket> SocketFactory(host, int port);
typedef OnConnection(BufferedSocket socket);

class BufferedSocket {
  ErrorHandler onError;
  DoneHandler onDone;
  ClosedHandler onClosed;

  /// When data arrives and there is no read currently in progress, the
  /// [onDataReady] handler is called.
  DataReadyHandler onDataReady;

  RawSocket _socket;

  Uint8List _writingBuffer;
  int _writeOffset;
  int _writeLength;
  Completer<void> _writeCompleter;

  ReadBuffer _readingBuffer;
  int _readOffset;
  Completer<ReadBuffer> _readCompleter;
  StreamSubscription _subscription;
  bool _closed = false;

  bool get closed => _closed;

  BufferedSocket._(this._socket, this.onDataReady, this.onDone, this.onError,
      this.onClosed) {
    _subscription = _socket.listen(_onData,
        onError: _onSocketError, onDone: _onSocketDone, cancelOnError: true);
  }

  _onSocketError(error) {
    if (onError != null) {
      onError(error);
    }
  }

  _onSocketDone() {
    if (onDone != null) {
      onDone();
      _closed = true;
    }
  }

  static Future<RawSocket> defaultSocketFactory(host, int port) =>
      RawSocket.connect(host, port);

  static Future<BufferedSocket> connect(
    String host,
    int port, {
    DataReadyHandler onDataReady,
    DoneHandler onDone,
    ErrorHandler onError,
    ClosedHandler onClosed,
    SocketFactory socketFactory = defaultSocketFactory,
  }) async {
    var socket;
    socket = await socketFactory(host, port);
    socket.setOption(SocketOption.tcpNoDelay, true);
    return new BufferedSocket._(socket, onDataReady, onDone, onError, onClosed);
  }

  void _onData(RawSocketEvent event) {
    if (_closed) {
      return;
    }

    if (event == RawSocketEvent.read) {
      if (_readingBuffer == null) {
        if (onDataReady != null) {
          onDataReady();
        }
      } else {
        _readBuffer();
      }
    } else if (event == RawSocketEvent.readClosed) {
      if (this.onClosed != null) {
        this.onClosed();
      }
    } else if (event == RawSocketEvent.closed) {
    } else if (event == RawSocketEvent.write) {
      if (_writingBuffer != null) {
        _writeBuffer();
      }
    }
  }

  /**
   * Writes [buffer] to the socket, and returns the same buffer in a [Future] which
   * completes when it has all been written.
   */
  Future<void> writeBuffer(Uint8List buffer) {
    return writeBufferPart(buffer, 0, buffer.length);
  }

  Future<void> writeBufferPart(Uint8List buffer, int start, int length) {
    if (_closed) {
      throw new StateError("Cannot write to socket, it is closed");
    }
    if (_writingBuffer != null) {
      throw new StateError("Cannot write to socket, already writing");
    }
    _writingBuffer = buffer;
    _writeCompleter = new Completer<void>();
    _writeOffset = start;
    _writeLength = length + start;

    _writeBuffer();

    return _writeCompleter.future;
  }

  void _writeBuffer() {
    int bytesWritten = _socket.write(
        _writingBuffer, _writeOffset, _writeLength - _writeOffset);
    _writeOffset += bytesWritten;
    if (_writeOffset == _writeLength) {
      _writeCompleter.complete(_writingBuffer);
      _writingBuffer = null;
    } else {
      _socket.writeEventsEnabled = true;
    }
  }

  /**
   * Reads into [buffer] from the socket, and returns the same buffer in a [Future] which
   * completes when enough bytes have been read to fill the buffer.
   *
   * This must not be called while there is still a read ongoing, but may be called before
   * onDataReady is called, in which case onDataReady will not be called when data arrives,
   * and the read will start instead.
   */
  Future<ReadBuffer> readBuffer(ReadBuffer buffer) {
    if (_closed) throw new StateError("Cannot read from a closed socket!");

    if (_readingBuffer != null)
      throw new StateError("Cannot read from socket, already reading!");

    _readingBuffer = buffer;
    _readOffset = 0;
    _readCompleter = new Completer<ReadBuffer>();

    if (_socket.available() > 0) _readBuffer();

    return _readCompleter.future;
  }

  void _readBuffer() {
    List<int> bytes = _socket.read(_readingBuffer.length - _readOffset);
    int bytesRead = bytes.length;
    _readingBuffer.data.setRange(_readOffset, _readOffset + bytesRead, bytes);
    _readOffset += bytesRead;

    if (_readOffset == _readingBuffer.length) {
      _readCompleter.complete(_readingBuffer);
      _readingBuffer = null;
    }
  }

  void close() {
    _socket.close();
    _closed = true;
  }

  Future<void> startSSL() async {
    var socket = await RawSecureSocket.secure(_socket,
        subscription: _subscription, onBadCertificate: (cert) => true);
    _socket = socket;
    _socket.setOption(SocketOption.tcpNoDelay, true);
    _subscription = _socket.listen(_onData,
        onError: _onSocketError, onDone: _onSocketDone, cancelOnError: true);
    _socket.writeEventsEnabled = true;
    _socket.readEventsEnabled = true;
  }
}
