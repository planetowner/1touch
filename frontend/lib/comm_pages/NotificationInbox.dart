import 'package:onetouch/l10n/date_labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/l10n/app_localizations.dart';

//
// Data model
//

enum _Filter { all, team, player, posts, betting }

enum _NotifCategory { reaction, comment, team, player, betting }

class _MockNotif {
  final _NotifCategory category;
  final String title;
  final String bodyPrefix;
  final Map<String, Object> arguments;
  final String? bodyBold; // bolded segment immediately after bodyPrefix
  final Duration age;
  final String? imageAsset;
  final String? destination;

  const _MockNotif({
    required this.category,
    required this.title,
    this.bodyPrefix = '',
    this.arguments = const {},
    this.bodyBold,
    required this.age,
    this.imageAsset,
    this.destination,
  });

  bool matchesFilter(_Filter f) {
    if (f == _Filter.all) return true;
    switch (f) {
      case _Filter.team:
        return category == _NotifCategory.team;
      case _Filter.player:
        return category == _NotifCategory.player;
      case _Filter.posts:
        return category == _NotifCategory.reaction ||
            category == _NotifCategory.comment;
      case _Filter.betting:
        return category == _NotifCategory.betting;
      default:
        return true;
    }
  }
}

const _mockNotifications = <_MockNotif>[
  _MockNotif(
    category: _NotifCategory.reaction,
    title: 'Reaction',
    bodyPrefix: '{user} and {count} more users liked your post.',
    arguments: {'user': 'Username121', 'count': 2},
    age: Duration(hours: 2),
    destination: '/notifications/post/1',
  ),
  _MockNotif(
    category: _NotifCategory.comment,
    title: 'Comment',
    bodyPrefix: "{user} commented on your post: ",
    arguments: {'user': 'Username144'},
    bodyBold: "can't agree more",
    age: Duration(hours: 3),
    destination: '/notifications/post/1',
  ),
  _MockNotif(
    category: _NotifCategory.team,
    title: 'FC Barcelona',
    bodyPrefix: 'Full time 3-1 — Big win for Barcelona!',
    age: Duration(hours: 5),
    imageAsset: 'TeamLogos/Barcelona.png',
    destination: '/match/19300016?status=past',
  ),
  _MockNotif(
    category: _NotifCategory.player,
    title: 'Kang-In Lee',
    bodyPrefix: 'Kang-In is in the XI 👕',
    age: Duration(hours: 6),
    destination: '/players/9967153',
  ),
  _MockNotif(
    category: _NotifCategory.team,
    title: 'Bayern Munich',
    bodyPrefix: 'Kane scored twice! Bayern lead 2-0 Leipzig.',
    age: Duration(days: 1),
    imageAsset: 'TeamLogos/BayernMunich.png',
    destination: '/match/19500003?status=live',
  ),
  _MockNotif(
    category: _NotifCategory.betting,
    title: 'New Bet Available',
    bodyPrefix: 'Barcelona vs Real Madrid — place your prediction.',
    age: Duration(days: 1),
    destination: '/match/19300005?status=upcoming',
  ),
  _MockNotif(
    category: _NotifCategory.reaction,
    title: 'Reaction',
    bodyPrefix: '{user} liked your comment.',
    arguments: {'user': 'Username88'},
    age: Duration(days: 2),
    destination: '/notifications/post/3',
  ),
  _MockNotif(
    category: _NotifCategory.player,
    title: 'Pedri',
    bodyPrefix: 'Pedri scored! Barcelona lead 1-0.',
    age: Duration(days: 2),
    destination: '/players/37288001',
  ),
  _MockNotif(
    category: _NotifCategory.betting,
    title: 'Post-match Result',
    bodyPrefix: 'Your prediction was correct — Bayern won 3-0.',
    age: Duration(days: 3),
    destination: '/match/19500001?status=past',
  ),
  _MockNotif(
    category: _NotifCategory.comment,
    title: 'Comment',
    bodyPrefix: '{user} replied to your comment: ',
    arguments: {'user': 'Username203'},
    bodyBold: 'totally agree with you!',
    age: Duration(days: 3),
    destination: '/notifications/post/3',
  ),
];

//
// Page
//

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key});

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  _Filter _selected = _Filter.all;

  static const _filters = <_Filter, String>{
    _Filter.all: 'ALL',
    _Filter.team: 'TEAM',
    _Filter.player: 'PLAYER',
    _Filter.posts: 'POSTS',
    _Filter.betting: 'BETTING',
  };

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final visible =
        _mockNotifications.where((n) => n.matchesFilter(_selected)).toList();

    return Scaffold(
      key: const ValueKey('notification-inbox-scaffold'),
      backgroundColor: mainPageBackground(context),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              appBarContentTop(context),
              24,
              0,
            ),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 32,
                      icon: Icon(Icons.arrow_back_ios_new, color: foreground),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tr(context, 'Notifications'),
                      textAlign: TextAlign.center,
                      style: Body1.style.copyWith(color: foreground),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 32,
                      onPressed: () => context.push('/search'),
                      icon: Icon(Icons.search, color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 42,
            child: ListView.separated(
              key: const ValueKey('notification-filter-scroll'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = _filters.entries.elementAt(index);
                final isSelected = _selected == entry.key;
                return GestureDetector(
                  onTap: () => setState(() => _selected = entry.key),
                  child: AnimatedContainer(
                    key: ValueKey(
                      'notification-filter-${entry.value.toLowerCase()}',
                    ),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: appPillBackground(context, selected: isSelected),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tr(context, entry.value).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Body2_b.style.copyWith(
                        color: appPillForeground(
                          context,
                          selected: isSelected,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: visible.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _NotifTile(notif: visible[index]),
              ),
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Divider(
                  color: AppColors.of(context).divider,
                  height: 1,
                  thickness: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//
// Single notification tile
//

class _NotifTile extends StatelessWidget {
  final _MockNotif notif;
  const _NotifTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: notif.destination == null
          ? null
          : () => context.push(notif.destination!),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 74),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(notif: notif),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, notif.title),
                    style: Body1_b.style.copyWith(color: foreground),
                  ),
                  _BodyText(notif: notif),
                  const SizedBox(height: 8),
                  Text(
                    relativeTimeLabel(DateTime.now().subtract(notif.age),
                        locale: Localizations.localeOf(context)),
                    style: Body2.style.copyWith(
                      color: appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//
// Avatar with optional badge
//

class _Avatar extends StatelessWidget {
  final _MockNotif notif;
  const _Avatar({required this.notif});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: 64,
            height: 64,
            child: notif.imageAsset == null
                ? Image.asset('assets/profileAvatar.png')
                : Image.asset(notif.imageAsset!, fit: BoxFit.contain),
          ),
          if (notif.category == _NotifCategory.reaction)
            _badge(Icons.thumb_up_outlined, isDark),
          if (notif.category == _NotifCategory.comment)
            _badge(Icons.chat_bubble_outline, isDark),
          if (notif.category == _NotifCategory.betting)
            _badge(Icons.sports_soccer_outlined, isDark),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, bool isDark) {
    return Positioned(
      top: 34,
      left: 34,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? AppPalette.lightGrey : AppPalette.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDark ? AppPalette.white : AppPalette.black,
          size: 24,
        ),
      ),
    );
  }
}

//
// Body text — supports optional bold segment
//

class _BodyText extends StatelessWidget {
  final _MockNotif notif;
  const _BodyText({required this.notif});

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    if (notif.bodyBold == null) {
      return Text(
        tr(context, notif.bodyPrefix, notif.arguments),
        style: Body1.style.copyWith(color: foreground),
      );
    }
    return RichText(
      text: TextSpan(
        style: Body1.style.copyWith(color: foreground),
        children: [
          TextSpan(text: tr(context, notif.bodyPrefix, notif.arguments)),
          TextSpan(
            text: notif.bodyBold,
            style: Body1_b.style.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
