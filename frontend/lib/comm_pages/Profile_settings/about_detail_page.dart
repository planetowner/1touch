import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/detail_navigation.dart';
import 'package:onetouch/core/legal_document_content.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/community/community_linked_text.dart';
import 'package:onetouch/l10n/app_localizations.dart';

enum AboutSection {
  legal('Legal'),
  terms('Terms of Service'),
  privacy('Privacy Policy');

  const AboutSection(this.titleKey);

  final String titleKey;

  String get path => '/about/$name';

  static AboutSection? fromPath(String? name) {
    for (final section in values) {
      if (section.name == name) return section;
    }
    return null;
  }
}

class AboutDetailPage extends StatefulWidget {
  const AboutDetailPage({
    super.key,
    required this.section,
    this.showSearch = false,
    this.bottomNavigationBar,
  });

  final AboutSection section;
  final bool showSearch;
  final Widget? bottomNavigationBar;

  @override
  State<AboutDetailPage> createState() => _AboutDetailPageState();
}

class _AboutDetailPageState extends State<AboutDetailPage> {
  // 가입 화면과 설정에서 같은 공개 문서를 기존 상세 화면으로 보여줘요.
  late final _sections = legalDocumentContent[widget.section.name]!;
  late final _sectionKeys = List.generate(_sections.length, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final background = AppColors.of(context).pageBackground;
    final divider =
        isDark ? AppPalette.lightGrey : AppPalette.lightModeDarkGrey;
    const bodySize = 15.0;
    final bodyStyle = TextStyle(
      color: foreground,
      fontSize: bodySize,
      fontWeight: FontWeight.w400,
      height: 1.30,
    );

    return Scaffold(
      key: const ValueKey('about-detail-page'),
      backgroundColor: background,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                    24, MediaQuery.paddingOf(context).top, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      isDark
                          ? AppPalette.darkGrey
                          : AppPalette.lightModeDarkGrey,
                      background,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          key: const ValueKey('about-detail-back'),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(Icons.arrow_back_ios_new,
                              color: foreground, size: 28),
                        ),
                        if (widget.showSearch)
                          IconButton(
                            key: const ValueKey('about-detail-search'),
                            onPressed: () => openDetailPage(context, '/search'),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(32, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon:
                                Icon(Icons.search, color: foreground, size: 32),
                          ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    SvgPicture.asset(
                      'assets/app_logo.svg',
                      width: 120,
                      height: 26,
                      colorFilter:
                          ColorFilter.mode(foreground, BlendMode.srcIn),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(context, widget.section.titleKey),
                      style: TextStyle(
                        color: foreground,
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        height: 1.20,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Contents'),
                      style: bodyStyle.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 20),
                    for (var index = 0; index < _sections.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_sections[index].number.isNotEmpty)
                              Text('${_sections[index].number}. ',
                                  style: bodyStyle),
                            Expanded(
                              child: InkWell(
                                key: ValueKey('about-content-link-$index'),
                                onTap: () => Scrollable.ensureVisible(
                                  _sectionKeys[index].currentContext!,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                ),
                                child: Text(
                                  _sections[index].title,
                                  style: bodyStyle.copyWith(
                                      decoration: TextDecoration.underline,
                                      decorationColor: foreground),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Divider(height: 2, thickness: 2, color: divider),
                    for (var index = 0; index < _sections.length; index++) ...[
                      Padding(
                        key: _sectionKeys[index],
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_sections[index].number.isEmpty ? '' : '${_sections[index].number}. '}${_sections[index].title}',
                              style: bodyStyle.copyWith(
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 24),
                            SelectionArea(
                              child: CommunityLinkedText(
                                text: _sections[index].body,
                                style: bodyStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < _sections.length - 1)
                        Divider(height: 2, thickness: 2, color: divider),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
