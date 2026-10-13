import 'package:flutter/material.dart';
import 'package:onetouch/core/app_close_header.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/app_segmented_toggle.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/profile/profile_follow_repository.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/profile_follow.dart';

class ProfileFollowsSheet extends StatefulWidget {
  const ProfileFollowsSheet({
    super.key,
    required this.repository,
    required this.initialTab,
    required this.onChanged,
    this.avatarRequestHeaders = const {},
  });

  final ProfileFollowRepository repository;
  final ProfileFollowTab initialTab;
  final VoidCallback onChanged;
  final Map<String, String> avatarRequestHeaders;

  @override
  State<ProfileFollowsSheet> createState() => _ProfileFollowsSheetState();
}

class _ProfileFollowsSheetState extends State<ProfileFollowsSheet> {
  static const _pageSize = 50;
  late ProfileFollowTab _tab = widget.initialTab;
  ProfileFollowSort _sort = ProfileFollowSort.newest;
  List<ProfileFollowUser> _users = const [];
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;
  int _request = 0;
  final Set<int> _removing = {};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    if (!_hasMore && !reset) return;
    final request = reset ? ++_request : _request;
    final offset = reset ? 0 : _users.length;
    setState(() {
      if (reset) {
        _users = const [];
        _hasMore = true;
      }
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.repository.loadUsers(
        tab: _tab,
        sort: _sort,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _users = [..._users, ...page];
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } on Object {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _setTab(ProfileFollowTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _load(reset: true);
  }

  void _setSort(ProfileFollowSort sort) {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    _load(reset: true);
  }

  Future<void> _remove(ProfileFollowUser user) async {
    if (_removing.contains(user.userId)) return;
    setState(() => _removing.add(user.userId));
    try {
      await widget.repository.unfollow(user.userId);
      if (!mounted) return;
      setState(() {
        _removing.remove(user.userId);
        _users = _users.where((item) => item.userId != user.userId).toList();
      });
      widget.onChanged();
      // 삭제 후 남은 목록은 서버 목록으로 다시 맞춰요.
      _load(reset: true);
    } on Object {
      if (!mounted) return;
      setState(() => _removing.remove(user.userId));
      showAppSnackBar(context, tr(context, 'Unable to update following.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    return DraggableScrollableSheet(
      initialChildSize: .84,
      minChildSize: .48,
      maxChildSize: .94,
      builder: (context, controller) => Material(
        key: const ValueKey('profile-follows-sheet'),
        color: appColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
              _load();
            }
            return false;
          },
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCloseHeader(
                        closeKey: const ValueKey('profile-follows-close'),
                        onClose: () => Navigator.pop(context),
                      ),
                      const SizedBox(height: 12),
                      AppSegmentedToggle<ProfileFollowTab>(
                        containerKey: const ValueKey('profile-follows-toggle'),
                        indicatorSurfaceKey:
                            const ValueKey('profile-follows-toggle-indicator'),
                        value: _tab,
                        lightTrackColor: AppPalette.lightModeDarkGrey,
                        lightSelectedColor: AppPalette.white,
                        options: [
                          AppSegmentedToggleOption(
                            value: ProfileFollowTab.followers,
                            label: trUpper(context, 'Followers'),
                            tapKey:
                                const ValueKey('profile-follows-followers-tab'),
                          ),
                          AppSegmentedToggleOption(
                            value: ProfileFollowTab.following,
                            label: trUpper(context, 'Following'),
                            tapKey:
                                const ValueKey('profile-follows-following-tab'),
                          ),
                        ],
                        onChanged: _setTab,
                      ),
                      const SizedBox(height: 24),
                      AppDropdown<ProfileFollowSort>(
                        triggerKey: const ValueKey('profile-follows-sort'),
                        value: _sort,
                        selectedLabel: trUpper(context, 'Sort By'),
                        triggerHeight: 48,
                        triggerPadding:
                            const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        options: [
                          AppDropdownOption(
                            value: ProfileFollowSort.newest,
                            label: trUpper(context, 'Newest'),
                            optionKey:
                                const ValueKey('profile-follows-sort-newest'),
                          ),
                          AppDropdownOption(
                            value: ProfileFollowSort.oldest,
                            label: trUpper(context, 'Oldest'),
                            optionKey:
                                const ValueKey('profile-follows-sort-oldest'),
                          ),
                        ],
                        onChanged: _setSort,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (_users.isEmpty && _loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_users.isEmpty && _failed)
                SliverFillRemaining(
                  child: Center(
                    child: TextButton(
                      onPressed: () => _load(reset: true),
                      child: Text(tr(context, 'Retry')),
                    ),
                  ),
                )
              else if (_users.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Text(tr(context, 'No users yet.'))),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      24, 0, 24, MediaQuery.paddingOf(context).bottom + 24),
                  sliver: SliverList.builder(
                    itemCount: _users.length + (_loading || _failed ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _users.length) {
                        return Center(
                          child: _failed
                              ? TextButton(
                                  onPressed: _load,
                                  child: Text(tr(context, 'Retry')),
                                )
                              : const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                        );
                      }
                      final user = _users[index];
                      return Container(
                        key: ValueKey('profile-follow-user-${user.userId}'),
                        height: 72,
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: appColors.divider)),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: foreground,
                            foregroundImage: user.avatarUri == null
                                ? null
                                : NetworkImage(user.avatarUri.toString(),
                                    headers: widget.avatarRequestHeaders),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Heading5.style.copyWith(height: 1.1)),
                          ),
                          if (_tab == ProfileFollowTab.following)
                            IconButton(
                              key: ValueKey(
                                  'profile-follow-remove-${user.userId}'),
                              tooltip: tr(context, 'Remove'),
                              onPressed: _removing.contains(user.userId)
                                  ? null
                                  : () => _remove(user),
                              icon: const Icon(Icons.remove_circle,
                                  color: Color(0xFFFF5B66), size: 22),
                            ),
                        ]),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
