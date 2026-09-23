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
  final String? imageUrl; // team logo or player photo URL

  const _MockNotif({
    required this.category,
    required this.title,
    this.bodyPrefix = '',
    this.arguments = const {},
    this.bodyBold,
    required this.age,
    this.imageUrl,
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
  ),
  _MockNotif(
    category: _NotifCategory.comment,
    title: 'Comment',
    bodyPrefix: "{user} commented on your post: ",
    arguments: {'user': 'Username144'},
    bodyBold: "can't agree more",
    age: Duration(hours: 3),
  ),
  _MockNotif(
    category: _NotifCategory.team,
    title: 'FC Barcelona',
    bodyPrefix: 'Full time 3-1 — Big win for Barcelona!',
    age: Duration(hours: 5),
    imageUrl: 'https://cdn.sportmonks.com/images/soccer/teams/83/83.png',
  ),
  _MockNotif(
    category: _NotifCategory.player,
    title: 'Kang-In Lee',
    bodyPrefix: 'Kang-In is in the XI 👕',
    age: Duration(hours: 6),
  ),
  _MockNotif(
    category: _NotifCategory.team,
    title: 'Bayern Munich',
    bodyPrefix: 'Kane scored twice! Bayern 2-0 Dortmund.',
    age: Duration(days: 1),
    imageUrl: 'https://cdn.sportmonks.com/images/soccer/teams/183/183.png',
  ),
  _MockNotif(
    category: _NotifCategory.betting,
    title: 'New Bet Available',
    bodyPrefix: 'Barcelona vs Real Madrid — place your prediction.',
    age: Duration(days: 1),
  ),
  _MockNotif(
    category: _NotifCategory.reaction,
    title: 'Reaction',
    bodyPrefix: '{user} liked your comment.',
    arguments: {'user': 'Username88'},
    age: Duration(days: 2),
  ),
  _MockNotif(
    category: _NotifCategory.player,
    title: 'R. Lewandowski',
    bodyPrefix: 'Lewandowski scored! Barcelona lead 1-0.',
    age: Duration(days: 2),
  ),
  _MockNotif(
    category: _NotifCategory.betting,
    title: 'Post-match Result',
    bodyPrefix: 'Your prediction was correct — Bayern won 3-1.',
    age: Duration(days: 3),
  ),
  _MockNotif(
    category: _NotifCategory.comment,
    title: 'Comment',
    bodyPrefix: '{user} replied to your comment: ',
    arguments: {'user': 'Username203'},
    bodyBold: 'totally agree with you!',
    age: Duration(days: 3),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final appColors = AppColors.of(context);
    final pageBackground = isDark ? Colors.black : AppPalette.lightModeDarkGrey;
    final selectedSurface = isDark ? AppPalette.white : AppPalette.black;
    final selectedForeground = isDark ? AppPalette.black : AppPalette.white;
    final unselectedSurface = isDark ? AppPalette.lightGrey : AppPalette.white;
    final visible =
        _mockNotifications.where((n) => n.matchesFilter(_selected)).toList();

    return Scaffold(
      key: const ValueKey('notification-inbox-scaffold'),
      backgroundColor: pageBackground,
      body: CustomScrollView(
        slivers: [
          //   AppBar
          SliverAppBar(
            centerTitle: true,
            automaticallyImplyLeading: false,
            backgroundColor: pageBackground,
            elevation: 0,
            floating: true,
            snap: true,
            toolbarHeight: 80,
            title: Text(tr(context, 'Notifications'), style: Body1.style),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: foreground),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                onPressed: () => context.push('/search'),
                icon: Icon(Icons.search, color: foreground),
              ),
            ],
          ),

          //   Filter pills
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: SingleChildScrollView(
                key: const ValueKey('notification-filter-scroll'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.entries.map((e) {
                    final isSelected = _selected == e.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = e.key),
                        child: AnimatedContainer(
                          key: ValueKey(
                            'notification-filter-${e.value.toLowerCase()}',
                          ),
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedSurface
                                : unselectedSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tr(context, e.value),
                            style: Body2_b.style.copyWith(
                              color:
                                  isSelected ? selectedForeground : foreground,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          //   Notification list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final notif = visible[index];
                return Column(
                  children: [
                    _NotifTile(notif: notif),
                    Divider(
                      color: isDark ? AppPalette.darkGrey : appColors.divider,
                      height: 1,
                      thickness: 1,
                    ),
                  ],
                );
              },
              childCount: visible.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(notif: notif),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, notif.title), style: Body1_b.style),
                const SizedBox(height: 4),
                _BodyText(notif: notif),
                const SizedBox(height: 6),
                Text(
                  relativeTimeLabel(DateTime.now().subtract(notif.age),
                      locale: Localizations.localeOf(context)),
                  style: Eyebrow.style.copyWith(
                    color: appColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main circle
        CircleAvatar(
          radius: 28,
          backgroundColor: isDark ? AppPalette.darkGrey : AppPalette.white,
          backgroundImage: notif.imageUrl != null
              ? NetworkImage(notif.imageUrl!) as ImageProvider
              : const AssetImage('assets/profileAvatar.png'),
          onBackgroundImageError: notif.imageUrl != null ? (_, __) {} : null,
        ),

        // Badge for reaction
        if (notif.category == _NotifCategory.reaction)
          _badge(
            context,
            Icons.thumb_up_rounded,
            const Color(0xFF1565C0),
          ),

        // Badge for comment
        if (notif.category == _NotifCategory.comment)
          _badge(
            context,
            Icons.chat_bubble_rounded,
            const Color(0xFF424242),
          ),

        // Badge for betting
        if (notif.category == _NotifCategory.betting)
          _badge(
            context,
            Icons.monetization_on_rounded,
            const Color(0xFF2E7D32),
          ),
      ],
    );
  }

  Widget _badge(BuildContext context, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      bottom: -2,
      right: -4,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.black : AppPalette.lightModeDarkGrey,
            width: 1.5,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 11),
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
    final mutedForeground = AppColors.of(context).mutedForeground;
    if (notif.bodyBold == null) {
      return Text(
        tr(context, notif.bodyPrefix, notif.arguments),
        style: Body2.style.copyWith(color: mutedForeground),
      );
    }
    return RichText(
      text: TextSpan(
        style: Body2.style.copyWith(color: mutedForeground),
        children: [
          TextSpan(text: tr(context, notif.bodyPrefix, notif.arguments)),
          TextSpan(
            text: notif.bodyBold,
            style: Body2_b.style.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
