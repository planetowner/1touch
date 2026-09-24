import 'package:flutter/material.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/features/app_error_view.dart';
import 'package:onetouch/l10n/football_name_labels.dart';

class FootballNamesLoader extends StatefulWidget {
  const FootballNamesLoader({
    super.key,
    required this.repository,
    required this.enabled,
    required this.child,
  });

  final FootballNamesRepository repository;
  final bool enabled;
  final Widget child;

  @override
  State<FootballNamesLoader> createState() => _FootballNamesLoaderState();
}

class _FootballNamesLoaderState extends State<FootballNamesLoader> {
  String? _language;
  Future<FootballNames>? _request;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_language != language) {
      _language = language;
      _load();
    }
  }

  @override
  void didUpdateWidget(FootballNamesLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled ||
        widget.repository != oldWidget.repository) _load();
  }

  void _load() {
    _request = widget.enabled ? widget.repository.load(_language!) : null;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FootballNames>(
        future: _request,
        builder: (context, snapshot) {
          final ready = widget.enabled &&
              snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData;
          return FootballNamesScope(
            names: ready ? snapshot.data! : const FootballNames(),
            // 로그인 응답에서 화면을 이동할 수 있도록 라우터는 유지해요.
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                if (widget.enabled && !ready)
                  Material(
                    child: snapshot.hasError
                        ? AppErrorView(
                            statusCode: 500,
                            onAction: () => setState(_load),
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
      );
}
