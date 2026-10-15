import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// 버튼의 모양과 크기는 OS에 맡기고, 제목은 앱의 공통 서체를 사용해요.
class NativeAvatarHeader extends StatefulWidget {
  const NativeAvatarHeader({
    super.key,
    required this.onCancel,
    required this.onDone,
    required this.saving,
    this.onCloseIconLeftMeasured,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onDone;
  final bool saving;
  final ValueChanged<double>? onCloseIconLeftMeasured;

  @override
  State<NativeAvatarHeader> createState() => _NativeAvatarHeaderState();
}

class _NativeAvatarHeaderState extends State<NativeAvatarHeader> {
  MethodChannel? _channel;
  double _height = kToolbarHeight;
  double _titleCenterY = kToolbarHeight / 2;

  Map<String, Object> get _configuration => {
        'cancel': tr(context, 'Cancel'),
        'done': tr(context, 'Done'),
        'cancelEnabled': widget.onCancel != null,
        'doneEnabled': widget.onDone != null,
        'dark': Theme.of(context).brightness == Brightness.dark,
        'background': AppColors.of(context).pageBackground.toARGB32(),
      };

  void _created(int id) {
    _channel?.setMethodCallHandler(null);
    _channel = MethodChannel('onetouch/avatar_header/$id')
      ..setMethodCallHandler((call) async {
        if (call.method == 'cancel') widget.onCancel?.call();
        if (call.method == 'done') widget.onDone?.call();
        if (call.method == 'layout') {
          final layout = call.arguments as Map;
          final height = (layout['height'] as num).toDouble();
          final centerY = (layout['titleCenterY'] as num).toDouble();
          if (mounted && (height != _height || centerY != _titleCenterY)) {
            setState(() {
              _height = height;
              _titleCenterY = centerY;
            });
          }
          final closeIconLeft = layout['closeIconLeft'] as num?;
          if (mounted && closeIconLeft != null) {
            widget.onCloseIconLeftMeasured?.call(closeIconLeft.toDouble());
          }
        }
      });
    _channel!.invokeMethod<void>('update', _configuration);
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _channel?.invokeMethod<void>('update', _configuration);
    final platform = Theme.of(context).platform;
    return SizedBox(
      key: const ValueKey('avatar-picker-header'),
      height: _height,
      child: Stack(alignment: Alignment.center, children: [
        if (platform == TargetPlatform.iOS)
          UiKitView(
            key: ValueKey(Theme.of(context).brightness),
            viewType: 'onetouch/avatar_header',
            creationParams: _configuration,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _created,
          )
        else if (platform == TargetPlatform.android)
          AndroidView(
            key: ValueKey(Theme.of(context).brightness),
            viewType: 'onetouch/avatar_header',
            creationParams: _configuration,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _created,
          ),
        // 바 전체의 중앙이 아니라 OS가 버튼과 함께 배치한 제목 중심을 따라요.
        Positioned(
          top: _titleCenterY,
          left: 80,
          right: 80,
          child: FractionalTranslation(
            translation: const Offset(0, -.5),
            child: IgnorePointer(
              child: Center(
                heightFactor: 1,
                child: widget.saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr(context, 'Profile photo'),
                        style: Heading5.style,
                        // 글꼴 토큰은 유지하고, 한 줄 바깥의 행간만 정렬에서 제외해요.
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
