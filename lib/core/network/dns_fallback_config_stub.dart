import 'package:dio/dio.dart';

// No-op on web: browsers handle DNS/connection resolution themselves, so
// there's no `dart:io` socket layer to hook a DoH fallback into.
void configureDnsFallback(Dio dio) {}
