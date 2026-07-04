import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'dns_fallback.dart';

void configureDnsFallback(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    final resolver = DnsFallbackResolver();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.connectionFactory = resolver.connect;
      return client;
    };
  }
}
