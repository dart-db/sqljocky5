library sqljocky.handler;

import 'dart:async';
import 'dart:typed_data';

import 'package:sqljocky5/constants.dart';
import 'package:sqljocky5/public/exceptions/exceptions.dart';
import '../prepared_statement_handler/prepare_ok_packet.dart';
import 'ok_packet.dart';
import 'package:typed_buffer/typed_buffer.dart';
import 'package:sqljocky5/public/results/results.dart';

export 'dart:typed_data' show Uint8List;

/// Handlers are responsible for serializing a MySQL command and also processing
/// the response returned by MySQL server for the command.
abstract class Handler {
  /// Constructs and returns a request command packet.
  Uint8List createRequest();

  /// Parses the [response] containing the response to the command.
  /// Returns a [HandlerResponse].
  ///
  /// The default implementation returns a finished [HandlerResponse] with
  /// a result which is obtained by calling [checkResponse].
  HandlerResponse processResponse(ReadBuffer response) =>
      HandlerResponse(result: checkResponse(response));

  /// Parses the response packet to recognise Ok and Error packets.
  /// Returns an [OkPacket] if the packet was an Ok packet, throws
  /// a [MySqlException] if it was an Error packet, or returns [:null:]
  /// if the packet has not been handled by this method.
  dynamic checkResponse(ReadBuffer response,
      [bool prepareStmt = false, bool isHandlingRows = false]) {
    if (response[0] == PACKET_OK && !isHandlingRows) {
      if (prepareStmt) {
        var okPacket = PrepareOkPacket.fromBuffer(response);
        return okPacket;
      } else {
        var okPacket = OkPacket.fromBuffer(response);
        return okPacket;
      }
    } else if (response[0] == PACKET_ERROR) {
      throw MySqlException(response);
    }
    return null;
  }
}

/// [Handler] with [Results]
abstract class HandlerWithResult extends Handler {
  Future<StreamedResults> get streamedResults;
}

/// Represents the response from a [Handler] when [Handler.processResponse] is
/// called.
///
/// If the handler has finished processing the response, [finished] is true.
/// [nextHandler] is irrelevant and [result] contains the result to return to the
/// user.
///
/// If the handler needs another handler to process the response, [finished]
/// is false. [nextHandler] contains the next handler which should process the
/// next packet from the server, and [result] is [_no_result].
class HandlerResponse {
  final Handler nextHandler;
  final dynamic result;
  bool get hasFinished => result != _no_result;

  HandlerResponse({this.nextHandler = null, this.result = _no_result});
}

/// No result value for [HandlerResponse]
class _NoResult {
  const _NoResult();
}

const _no_result = const _NoResult();
