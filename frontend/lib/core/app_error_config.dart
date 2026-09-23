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
    title: "Offside!",
    message: "The page could not be found.",
    action: "Go home",
  ),
  401: AppErrorConfig(
    title: "Please join again",
    message: "Your session expired. Please sign in again.",
    action: "Sign in again",
  ),
  403: AppErrorConfig(
    title: "Red card!",
    message: "You don't have permission to access this page.",
    action: "Go back",
  ),
  429: AppErrorConfig(
    title: "You're on the bench for a moment",
    message: "Too many requests. Please try again later.",
    action: null,
  ),
  500: AppErrorConfig(
    title: "VAR check",
    message: "There is a server problem. Please try again later.",
    action: "Retry",
  ),
  502: AppErrorConfig(
    title: "Pass incomplete",
    message: "Servers could not connect. Please try again later.",
    action: null,
  ),
  503: AppErrorConfig(
    title: "Match interrupted",
    message: "The service is currently unavailable. Please try again later.",
    action: null,
  ),
  504: AppErrorConfig(
    title: "Beyond added time",
    message: "The server is taking too long to respond. Please try again.",
    action: null,
  ),
};

AppErrorConfig appErrorConfigFor(int statusCode) =>
    appErrorConfigs[statusCode] ?? appErrorConfigs[500]!;
