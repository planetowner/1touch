import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/user.dart';
import 'package:onetouch/models/user_following_team.dart';
import 'package:onetouch/models/user_profile.dart';

// POSTS  (posts table)
//

const mockPosts = <Post>[
  Post(
      postId: 1,
      userId: 1001,
      category: PostCategory.news,
      title: 'Barcelona clinch La Liga title with five games to spare',
      body:
          'FC Barcelona secured their 28th La Liga title on Tuesday night after a commanding 4-1 victory over Sevilla at the Estadio Olimpic. Lewandowski scored a hat-trick as the Catalans ran riot in the second half.',
      mediaUrl: 'https://picsum.photos/200',
      createdAt: '2025-04-07 21:30:00',
      updatedAt: '2025-04-07 21:30:00'),
  Post(
      postId: 2,
      userId: 1002,
      category: PostCategory.analysis,
      title: 'Why Bayern\'s pressing system is breaking records this season',
      body:
          'Harry Kane has been the fulcrum of Bayern Munich\'s record-breaking Bundesliga campaign. In this analysis we break down the numbers behind their 78-goal tally through 29 matchdays and how Kompany\'s high press has revolutionised their build-up play.',
      createdAt: '2025-04-06 14:00:00',
      updatedAt: '2025-04-06 14:00:00'),
  Post(
      postId: 3,
      userId: 1001,
      category: PostCategory.general,
      title: 'Best XI of the week — RO 32',
      body:
          'Our community picks the standout performers from across all five major European leagues this weekend. Inter Milan\'s goalkeeper makes the cut after his stunning save denied Napoli a late equaliser.',
      createdAt: '2025-04-05 10:00:00',
      updatedAt: '2025-04-05 10:00:00'),
  Post(
      postId: 4,
      userId: 1003,
      category: PostCategory.news,
      title: 'Man City confirm Haaland fit for Arsenal clash',
      body:
          'Pep Guardiola confirmed in his pre-match press conference that Erling Haaland has fully recovered from the hamstring issue that kept him out of last weekend\'s draw at Villa Park. The Norwegian is expected to lead the line tonight.',
      createdAt: '2025-04-08 11:00:00',
      updatedAt: '2025-04-08 11:00:00'),
  Post(
      postId: 5,
      userId: 1002,
      category: PostCategory.analysis,
      title: 'Atletico\'s defensive structure under the microscope',
      body:
          'Simeone\'s side have conceded just 35 goals in 31 league games — only Barcelona and Real Madrid have better records. We examine the 4-4-2 mid-block that has frustrated Europe\'s top attacks all season.',
      createdAt: '2025-04-04 09:00:00',
      updatedAt: '2025-04-04 09:00:00'),
];

//
// USERS  (users table)
//

const mockUsers = <User>[
  User(
      userId: 1001,
      displayName: 'Alex Kim',
      username: 'alexkim',
      email: 'alexkim@gmail.com',
      avatarAsset: 'assets/profileAvatar.png',
      createdAt: '2024-08-15 09:00:00'), // Barcelona fan
  User(
      userId: 1002,
      displayName: 'Maria Schmidt',
      username: 'mariaschmidt',
      email: 'maria.schmidt@web.de',
      avatarAsset: 'assets/profileAvatar.png',
      createdAt: '2024-09-01 12:30:00'), // Bayern fan
  User(
      userId: 1003,
      displayName: 'James Walker',
      username: 'jwalker',
      email: 'jwalker@outlook.com',
      avatarAsset: 'assets/profileAvatar.png',
      createdAt: '2024-10-20 18:45:00'), // Man City fan
  User(
      userId: 1004,
      displayName: 'Sophie Martin',
      username: 'sophiem',
      email: 'sophie.martin@laposte.fr',
      avatarAsset: 'assets/profileAvatar.png',
      createdAt: '2025-01-05 11:00:00'), // PSG fan
  User(
      userId: 1005,
      displayName: 'Lucas Santos',
      username: 'lsantos',
      email: 'lucas.santos@bol.com.br',
      avatarAsset: 'assets/profileAvatar.png',
      createdAt: '2025-02-14 08:00:00'), // Liverpool fan
];

User mockUserById(int id) =>
    mockUsers.firstWhere((u) => u.userId == id, orElse: () => mockUsers.first);

//
// USER PROFILES  (user_profiles table)
//

const mockUserProfiles = <UserProfile>[
  UserProfile(
      userId: 1001,
      favoriteTeamId: 83,
      pts: 1420,
      postCount: 8,
      commentCount: 54,
      createdAt: '2024-08-15 09:01:00',
      updatedAt: '2025-04-07 21:30:00'), // Barcelona
  UserProfile(
      userId: 1002,
      favoriteTeamId: 503,
      pts: 870,
      postCount: 5,
      commentCount: 31,
      createdAt: '2024-09-01 12:31:00',
      updatedAt: '2025-04-06 14:00:00'), // Bayern
  UserProfile(
      userId: 1003,
      favoriteTeamId: 9,
      pts: 310,
      postCount: 2,
      commentCount: 12,
      createdAt: '2024-10-20 18:46:00',
      updatedAt: '2025-04-08 11:00:00'), // Man City
  UserProfile(
      userId: 1004,
      favoriteTeamId: 591,
      pts: 2250,
      postCount: 19,
      commentCount: 88,
      createdAt: '2025-01-05 11:01:00',
      updatedAt: '2025-04-05 10:00:00'), // PSG
  UserProfile(
      userId: 1005,
      favoriteTeamId: 8,
      pts: 540,
      postCount: 3,
      commentCount: 27,
      createdAt: '2025-02-14 08:01:00',
      updatedAt: '2025-04-04 09:00:00'), // Liverpool
];

UserProfile mockUserProfileById(int id) => mockUserProfiles
    .firstWhere((p) => p.userId == id, orElse: () => mockUserProfiles.first);

//
// USER FOLLOWING TEAMS  (user_following_teams table)
//

const mockUserFollowingTeams = <UserFollowingTeam>[
  // 1001 Alex Kim: Barcelona + Bayern
  UserFollowingTeam(userId: 1001, teamId: 83, createdAt: '2024-08-15 09:01:00'),
  UserFollowingTeam(
      userId: 1001, teamId: 503, createdAt: '2024-08-15 09:02:00'),
  // 1002 Maria Schmidt: Bayern + Dortmund
  UserFollowingTeam(
      userId: 1002, teamId: 503, createdAt: '2024-09-01 12:31:00'),
  UserFollowingTeam(userId: 1002, teamId: 68, createdAt: '2024-09-01 12:32:00'),
  // 1003 James Walker: Man City + Inter Milan
  UserFollowingTeam(userId: 1003, teamId: 9, createdAt: '2024-10-20 18:46:00'),
  UserFollowingTeam(
      userId: 1003, teamId: 2930, createdAt: '2024-10-20 18:47:00'),
  // 1004 Sophie Martin: PSG + Marseille
  UserFollowingTeam(
      userId: 1004, teamId: 591, createdAt: '2025-01-05 11:01:00'),
  UserFollowingTeam(userId: 1004, teamId: 44, createdAt: '2025-01-05 11:02:00'),
  // 1005 Lucas Santos: Liverpool + Arsenal
  UserFollowingTeam(userId: 1005, teamId: 8, createdAt: '2025-02-14 08:01:00'),
  UserFollowingTeam(userId: 1005, teamId: 19, createdAt: '2025-02-14 08:02:00'),
];

List<int> followingTeamIds(int userId) => mockUserFollowingTeams
    .where((f) => f.userId == userId)
    .map((f) => f.teamId)
    .toList();

//
