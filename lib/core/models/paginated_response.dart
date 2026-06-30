class PaginationMeta {
  const PaginationMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int limit;
  final int totalPages;

  factory PaginationMeta.fromJson(Map<String, dynamic> j) => PaginationMeta(
        total: j['total'] as int,
        page: j['page'] as int,
        limit: j['limit'] as int,
        totalPages: j['totalPages'] as int,
      );
}

class PaginatedResponse<T> {
  const PaginatedResponse({required this.data, required this.meta});

  final List<T> data;
  final PaginationMeta meta;

  // `j` is the value of `response.data['data']` — the inner paginated object.
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      PaginatedResponse(
        data: (j['data'] as List).map((e) => fromJson(e as Map<String, dynamic>)).toList(),
        meta: PaginationMeta.fromJson(j['meta'] as Map<String, dynamic>),
      );
}
