class Channel {
  final int? id;
  final String title;
  final String channelId; // usuário informa
  final bool isFavorite;

  Channel({
    this.id,
    required this.title,
    required this.channelId,
    required this.isFavorite,
  });

  Channel copyWith({int? id, String? title, String? channelId, bool? isFavorite}) {
    return Channel(
      id: id ?? this.id,
      title: title ?? this.title,
      channelId: channelId ?? this.channelId,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class FeedItem {
  final String videoId;
  final String channelTitle;
  final String title;
  final DateTime publishedAt;
  final String videoUrl;
  final bool isRead;

  FeedItem({
    required this.videoId,
    required this.channelTitle,
    required this.title,
    required this.publishedAt,
    required this.videoUrl,
    required this.isRead,
  });
}

class Article {
  final int? id;
  final String videoId;
  final String videoUrl;
  final String title;
  final String channelTitle;
  final DateTime createdAt;
  final String body;

  Article({
    this.id,
    required this.videoId,
    required this.videoUrl,
    required this.title,
    required this.channelTitle,
    required this.createdAt,
    required this.body,
  });
}
