import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  final controllers = <FakeWebViewController>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    final controller = FakeWebViewController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
          PlatformNavigationDelegateCreationParams params) =>
      FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams params) =>
      _FakeWebViewWidget(params);
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();
  String? html;
  late JavaScriptChannelParams channel;
  late FakeNavigationDelegate delegate;
  void message(String value) =>
      channel.onMessageReceived(JavaScriptMessage(message: value));
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> enableZoom(bool enabled) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate value) async {
    delegate = value as FakeNavigationDelegate;
  }

  @override
  Future<void> loadHtmlString(String value, {String? baseUrl}) async {
    html = value;
  }
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();
  late NavigationRequestCallback navigate;
  late WebResourceErrorCallback error;
  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback callback) async {
    navigate = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    error = callback;
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
