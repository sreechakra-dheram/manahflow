class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? invoiceId;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.invoiceId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromSupabase(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'],
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        invoiceId: json['invoice_id'],
        isRead: json['is_read'] ?? false,
        createdAt: json['created_at'] ?? '',
      );

  String get timeAgo {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}
