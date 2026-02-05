import 'package:equatable/equatable.dart';

class Sutra extends Equatable {
  final String id;
  final String title;
  final String content;
  final String category;
  final int size;

  const Sutra({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.size,
  });

  @override
  List<Object> get props => [id, title, content, category, size];
}
