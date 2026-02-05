import 'dart:async';
import 'package:http/http.dart' as http;

Future<http.StreamedResponse> sendMultipartRequestWithProgress(
  http.MultipartRequest request,
  http.Client client, {
  required void Function(int sent, int total) onProgress,
}) {
  final completer = Completer<http.StreamedResponse>();
  final totalBytes = request.contentLength;
  int bytesSent = 0;

  final stream = request.finalize();

  final broadcastStream = stream.asBroadcastStream();

  final subscription = broadcastStream.listen(
    (chunk) {
      bytesSent += chunk.length;
      onProgress(bytesSent, totalBytes);
    },
    onDone: () {
      // The request stream is done, but we wait for the response.
    },
    onError: (error) {
      completer.completeError(error);
    },
    cancelOnError: true,
  );

  final newRequest = http.StreamedRequest(request.method, request.url)
    ..contentLength = request.contentLength
    ..headers.addAll(request.headers);

  // Manually pipe the stream to the request's sink to handle type mismatch
  broadcastStream.listen(
    newRequest.sink.add,
    onError: (error, stackTrace) {
      newRequest.sink.addError(error, stackTrace);
      completer.completeError(error, stackTrace);
    },
    onDone: newRequest.sink.close,
    cancelOnError: true,
  );

  client
      .send(newRequest)
      .then((response) {
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      })
      .catchError((error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      });

  // Cancel the progress subscription when the response is received or an error occurs
  completer.future.whenComplete(() => subscription.cancel());

  return completer.future;
}
