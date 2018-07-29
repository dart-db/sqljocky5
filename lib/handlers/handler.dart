library sqljocky.handler;

import 'dart:async';
import 'dart:typed_data';
import 'package:logging/logging.dart';

import 'package:sqljocky5/constants.dart';
import 'package:sqljocky5/exceptions/exceptions.dart';
import '../prepared_statements/prepare_ok_packet.dart';
import 'ok_packet.dart';
import 'package:typed_buffer/typed_buffer.dart';
import '../results/results.dart';

export 'dart:typed_data' show Uint8List;

/**
 * Each command which the mysql protocol implements is handled with a [_Handler] object.
 * A handler is created with the appropriate parameters when the command is invoked
 * from the connection. The transport is then responsible for sending the
 * request which the handler creates, and then parsing the result returned by
 * the mysql server, either synchronously or asynchronously.
 */
abstract class Handler {
  final Logger log;

  Handler(this.log);

  /// Constructs and returns a request command packet.
  Uint8List createRequest();

  /**
   * Parses a [Buffer] containing the response to the command.
   * Returns a [_HandlerResponse]. The default
   * implementation returns a finished [_HandlerResponse] with
   * a result which is obtained by calling [checkResponse]
   */
  HandlerResponse processResponse(ReadBuffer response) =>
      new HandlerResponse(finished: true, result: checkResponse(response));

  /**
   * Parses the response packet to recognise Ok and Error packets.
   * Returns an [_OkPacket] if the packet was an Ok packet, throws
   * a [MySqlException] if it was an Error packet, or returns [:null:]
   * if the packet has not been handled by this method.
   */
  dynamic checkResponse(ReadBuffer response,
      [bool prepareStmt = false, bool isHandlingRows = false]) {
    if (response[0] == PACKET_OK && !isHandlingRows) {
      if (prepareStmt) {
        var okPacket = new PrepareOkPacket.fromBuffer(response);
        return okPacket;
      } else {
        var okPacket = new OkPacket.fromBuffer(response);
        return okPacket;
      }
    } else if (response[0] == PACKET_ERROR) {
      throw MySqlException(response);
    }
    return null;
  }
}

abstract class HandlerWithResult extends Handler {
  Future<StreamedResults> get streamedResults;

  HandlerWithResult(Logger log): super(log);
}

/**
 * Represents the response from a [_Handler] when [_Handler.processResponse] is
 * called. If the handler has finished processing the response, [finished] is true,
 * [nextHandler] is irrelevant and [result] contains the result to return to the
 * user. If the handler needs another handler to process the response, [finished]
 * is false, [nextHandler] contains the next handler which should process the
 * next packet from the server, and [result] is [_NO_RESULT].
 */
class HandlerResponse {
  final bool finished;
  final Handler nextHandler;
  final dynamic result;

  bool get hasResult => result != _NO_RESULT;

  HandlerResponse(
      {this.finished = false,
        this.nextHandler = null,
        this.result = _NO_RESULT});

  static final HandlerResponse notFinished = new HandlerResponse();
}

class _NoResult {
  const _NoResult();
}

const _NO_RESULT = const _NoResult();
