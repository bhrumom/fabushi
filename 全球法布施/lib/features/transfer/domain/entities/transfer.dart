import 'package:equatable/equatable.dart';

class Transfer extends Equatable {
  final String id;
  final String fileName;
  final int fileSize;
  final String targetCountry;
  final TransferStatus status;
  final DateTime startTime;

  const Transfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.targetCountry,
    required this.status,
    required this.startTime,
  });

  @override
  List<Object> get props => [id, fileName, fileSize, targetCountry, status, startTime];
}

enum TransferStatus { pending, inProgress, completed, failed }

class TransferStats extends Equatable {
  final int totalTransfers;
  final int successfulTransfers;
  final int totalBytes;

  const TransferStats({
    required this.totalTransfers,
    required this.successfulTransfers,
    required this.totalBytes,
  });

  @override
  List<Object> get props => [totalTransfers, successfulTransfers, totalBytes];
}
