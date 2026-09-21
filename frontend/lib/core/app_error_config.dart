import 'package:flutter/foundation.dart';

@immutable
class AppErrorConfig {
  const AppErrorConfig({
    required this.title,
    required this.message,
    required this.action,
  });

  final String title;
  final String message;
  final String? action;
}

const Map<int, AppErrorConfig> appErrorConfigs = {
  404: AppErrorConfig(
    title: '오프사이드!',
    message: '찾고 있는 페이지를 찾을 수 없어요.',
    action: '홈으로',
  ),
  401: AppErrorConfig(
    title: '다시 입장해주세요',
    message: '로그인 세션이 만료됐어요.',
    action: '다시 로그인',
  ),
  403: AppErrorConfig(
    title: '레드카드!',
    message: '이 페이지에 접근할 권한이 없어요.',
    action: '돌아가기',
  ),
  429: AppErrorConfig(
    title: '잠시 벤치에서 쉬어가요',
    message: '요청이 너무 많아요. 잠시 후 다시 시도해주세요.',
    action: null,
  ),
  500: AppErrorConfig(
    title: 'VAR 확인 중',
    message: '서버에 문제가 생겼어요. 잠시 후 다시 시도해주세요.',
    action: '다시 시도',
  ),
  502: AppErrorConfig(
    title: '패스 연결에 실패했어요',
    message: '서버 간 연결에 문제가 생겼어요. 잠시 후 다시 시도해주세요.',
    action: null,
  ),
  503: AppErrorConfig(
    title: '잠시 경기 중단',
    message: '현재 서비스를 이용할 수 없어요. 잠시 후 다시 시도해주세요.',
    action: null,
  ),
  504: AppErrorConfig(
    title: '추가시간을 넘겼어요',
    message: '서버 응답이 지연되고 있어요. 다시 시도해주세요.',
    action: null,
  ),
};

AppErrorConfig appErrorConfigFor(int statusCode) =>
    appErrorConfigs[statusCode] ?? appErrorConfigs[500]!;
