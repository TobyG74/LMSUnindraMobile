class PertemuanDetail {
  final String title;
  final String subtitle;
  final List<MateriItem> materiList;

  PertemuanDetail({
    required this.title,
    required this.subtitle,
    required this.materiList,
  });

  factory PertemuanDetail.fromJson(Map<String, dynamic> json) {
    return PertemuanDetail(
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      materiList: (json['materiList'] as List<dynamic>?)
              ?.map((item) => MateriItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class MateriItem {
  final String type;
  final String icon;
  final String title;
  final String description;
  final String? url;
  final String? viewUrl;
  final String? downloadUrl;
  final String date;

  MateriItem({
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
    this.url,
    this.viewUrl,
    this.downloadUrl,
    required this.date,
  });

  factory MateriItem.fromJson(Map<String, dynamic> json) {
    return MateriItem(
      type: json['type'] ?? '',
      icon: json['icon'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      url: json['url'],
      viewUrl: json['viewUrl'],
      downloadUrl: json['downloadUrl'],
      date: json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'icon': icon,
      'title': title,
      'description': description,
      'url': url,
      'viewUrl': viewUrl,
      'downloadUrl': downloadUrl,
      'date': date,
    };
  }
}
