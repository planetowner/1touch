import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/user.dart';

// POSTS  (posts table)
//

const mockPosts = <Post>[
  Post(
      language: 'en',
      postId: 1,
      teamId: 83,
      userId: 1001,
      username: 'alexkim',
      displayName: 'Alex Kim',
      category: PostCategory.news,
      title: 'Barcelona clinch La Liga title with five games to spare',
      body:
          'FC Barcelona secured their 28th La Liga title on Tuesday night after a commanding 4-1 victory over Sevilla at the Estadio Olimpic. Lewandowski scored a hat-trick as the Catalans ran riot in the second half.',
      mediaUrl: 'https://picsum.photos/200',
      createdAt: '2025-04-07 21:30:00'),
  Post(
      language: 'en',
      postId: 2,
      teamId: 503,
      userId: 1002,
      username: 'mariaschmidt',
      displayName: 'Maria Schmidt',
      category: PostCategory.analysis,
      title: 'Why Bayern\'s pressing system is breaking records this season',
      body:
          'Harry Kane has been the fulcrum of Bayern Munich\'s record-breaking Bundesliga campaign. In this analysis we break down the numbers behind their 78-goal tally through 29 matchdays and how Kompany\'s high press has revolutionised their build-up play.',
      createdAt: '2025-04-06 14:00:00'),
  Post(
      language: 'en',
      postId: 3,
      teamId: 83,
      userId: 1001,
      username: 'alexkim',
      displayName: 'Alex Kim',
      category: PostCategory.general,
      title: 'Best XI of the week — RO 32',
      body:
          'Our community picks the standout performers from across all five major European leagues this weekend. Inter Milan\'s goalkeeper makes the cut after his stunning save denied Napoli a late equaliser.',
      createdAt: '2025-04-05 10:00:00'),
  Post(
      language: 'en',
      postId: 4,
      teamId: 9,
      userId: 1003,
      username: 'jwalker',
      displayName: 'James Walker',
      category: PostCategory.news,
      title: 'Man City confirm Haaland fit for Arsenal clash',
      body:
          'Pep Guardiola confirmed in his pre-match press conference that Erling Haaland has fully recovered from the hamstring issue that kept him out of last weekend\'s draw at Villa Park. The Norwegian is expected to lead the line tonight.',
      createdAt: '2025-04-08 11:00:00'),
  Post(
      language: 'en',
      postId: 5,
      teamId: 7980,
      userId: 1002,
      username: 'mariaschmidt',
      displayName: 'Maria Schmidt',
      category: PostCategory.analysis,
      title: 'Atletico\'s defensive structure under the microscope',
      body:
          'Simeone\'s side have conceded just 35 goals in 31 league games — only Barcelona and Real Madrid have better records. We examine the 4-4-2 mid-block that has frustrated Europe\'s top attacks all season.',
      createdAt: '2025-04-04 09:00:00'),
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
