import '../data/default_articles.dart';
import 'firestore_repository.dart';

class ArticleItem {
  const ArticleItem({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  factory ArticleItem.fromMap(Map<String, dynamic> m) {
    return ArticleItem(
      id: m['id'] as String? ?? '',
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
    );
  }
}

class ArticlesService {
  ArticlesService._();
  static final ArticlesService instance = ArticlesService._();

  Future<List<ArticleItem>> loadAll() async {
    final remote = await FirestoreRepository.instance.loadArticles();
    final source = remote.isNotEmpty ? remote : defaultArticles;
    return source.map(ArticleItem.fromMap).toList();
  }
}
