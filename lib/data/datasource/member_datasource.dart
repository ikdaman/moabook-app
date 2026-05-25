import 'package:dio/dio.dart';

class MemberDataSource {
  final Dio _dio;
  MemberDataSource(this._dio);

  Future<String> getNickname() async {
    final r = await _dio.get<Map<String, dynamic>>('/members/me');
    return r.data?['nickname'] as String? ?? '';
  }

  Future<String> updateNickname(String nickname) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/members/me',
      data: {'nickname': nickname},
    );
    return r.data?['nickname'] as String? ?? nickname;
  }

  Future<bool> checkNickname(String nickname) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/members/check',
      queryParameters: {'nickname': nickname},
    );
    return r.data?['isAvailable'] as bool? ?? false;
  }

  Future<void> withdraw() async {
    await _dio.delete<void>('/members/me');
  }
}
