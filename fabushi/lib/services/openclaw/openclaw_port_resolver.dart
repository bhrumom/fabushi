import 'dart:io';

class OpenClawPortCandidate {
  final int port;
  final bool isFallback;
  final String? reason;

  const OpenClawPortCandidate({
    required this.port,
    required this.isFallback,
    this.reason,
  });
}

class OpenClawPortResolver {
  const OpenClawPortResolver({this.address, this.fallbackAttempts = 20});

  final InternetAddress? address;
  final int fallbackAttempts;

  Future<OpenClawPortCandidate> resolve(int requestedPort) async {
    final bindable = await isBindable(requestedPort);
    if (bindable) {
      return OpenClawPortCandidate(port: requestedPort, isFallback: false);
    }

    final fallbackPort = await findFallbackPort();
    return OpenClawPortCandidate(
      port: fallbackPort,
      isFallback: true,
      reason: 'port $requestedPort is not bindable on loopback',
    );
  }

  Future<bool> isBindable(int port) async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(
        address ?? InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
      return true;
    } on SocketException {
      return false;
    } finally {
      await socket?.close();
    }
  }

  Future<int> findFallbackPort() async {
    for (var attempt = 0; attempt < fallbackAttempts; attempt += 1) {
      ServerSocket? socket;
      try {
        socket = await ServerSocket.bind(
          address ?? InternetAddress.loopbackIPv4,
          0,
          shared: false,
        );
        return socket.port;
      } on SocketException {
        continue;
      } finally {
        await socket?.close();
      }
    }

    throw const SocketException(
      'Could not find a bindable loopback port for OpenClaw Gateway',
    );
  }
}
