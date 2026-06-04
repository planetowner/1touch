import 'package:onetouch/models/transfer.dart';
import 'package:onetouch/models/bestXI.dart';

// ═══════════════════════════════════════════════════════════
// TRANSFERS  (team_transfers table)
// FC Barcelona (team_id = 83) — 2026 January window (window_id = 3)
// IN:  Marcus Rashford (loan), Dani Olmo (re-registered)
// OUT: Ferran Torres (loan), Ansu Fati (loan), Íñigo Martínez
// ═══════════════════════════════════════════════════════════

const mockTransfers = <TeamTransfer>[
  // ── INCOMING ─────────────────────────────────────────────

  TeamTransfer(
    transferId:   541100,
    playerId:     220858,
    playerName:   'Marcus Rashford',
    playerImage:  'https://cdn.sportmonks.com/images/soccer/players/26/220858.png',
    fromTeamId:   15,
    fromTeamName: 'Manchester United',
    toTeamId:     83,
    toTeamName:   'FC Barcelona',
    typeId:       218,
    typeName:     TransferType.loan,
    amount:       null,
    transferDate: '2026-01-22',
    windowId:     3,
    createdAt:    '2026-04-09 03:49:26',
    updatedAt:    '2026-04-09 03:49:26',
  ),

  TeamTransfer(
    transferId:   541380,
    playerId:     37362,
    playerName:   'Dani Olmo',
    playerImage:  'https://cdn.sportmonks.com/images/soccer/players/26/37362.png',
    fromTeamId:   83,
    fromTeamName: 'FC Barcelona',
    toTeamId:     83,
    toTeamName:   'FC Barcelona',
    typeId:       219,
    typeName:     TransferType.transfer,
    amount:       0,
    transferDate: '2026-01-03',
    windowId:     3,
    createdAt:    '2026-04-09 03:49:26',
    updatedAt:    '2026-04-09 03:49:26',
  ),

  // ── OUTGOING ──────────────────────────────────────────────

  TeamTransfer(
    transferId:   540760,
    playerId:     451864,
    playerName:   'Ferran Torres',
    playerImage:  'https://cdn.sportmonks.com/images/soccer/players/8/451864.png',
    fromTeamId:   83,
    fromTeamName: 'FC Barcelona',
    toTeamId:     87,
    toTeamName:   'Atletico Madrid',
    typeId:       218,
    typeName:     TransferType.loan,
    amount:       null,
    transferDate: '2026-01-15',
    windowId:     3,
    createdAt:    '2026-04-09 03:49:26',
    updatedAt:    '2026-04-09 03:49:26',
  ),

  TeamTransfer(
    transferId:   541050,
    playerId:     2094517,
    playerName:   'Ansu Fati',
    playerImage:  'https://cdn.sportmonks.com/images/soccer/players/5/2094517.png',
    fromTeamId:   83,
    fromTeamName: 'FC Barcelona',
    toTeamId:     92,
    toTeamName:   'Villarreal',
    typeId:       218,
    typeName:     TransferType.loan,
    amount:       null,
    transferDate: '2026-01-20',
    windowId:     3,
    createdAt:    '2026-04-09 03:49:26',
    updatedAt:    '2026-04-09 03:49:26',
  ),

  TeamTransfer(
    transferId:   543210,
    playerId:     23848,
    playerName:   'Íñigo Martínez',
    playerImage:  'https://cdn.sportmonks.com/images/soccer/players/8/23848.png',
    fromTeamId:   83,
    fromTeamName: 'FC Barcelona',
    toTeamId:     90,
    toTeamName:   'Sevilla FC',
    typeId:       219,
    typeName:     TransferType.transfer,
    amount:       4500000,
    transferDate: '2026-01-28',
    windowId:     3,
    createdAt:    '2026-04-09 03:49:26',
    updatedAt:    '2026-04-09 03:49:26',
  ),
];

/// Filter helpers
List<TeamTransfer> transfersByTeam(int teamId) => mockTransfers
    .where((t) => t.fromTeamId == teamId || t.toTeamId == teamId)
    .toList();

List<TeamTransfer> incomingTransfers(int teamId) =>
    mockTransfers.where((t) => t.toTeamId == teamId).toList();

List<TeamTransfer> outgoingTransfers(int teamId) =>
    mockTransfers.where((t) => t.fromTeamId == teamId).toList();


// ═══════════════════════════════════════════════════════════
// BEST ELEVEN  (team_best_eleven table)
// FC Barcelona (team_id = 83), season_id = 23686 (2024/25 La Liga)
// Formation: 4-3-3
// slot_key → 'row:col'
//   1:1       = GK
//   2:1–2:4   = DEF (RB, CB, CB, LB)
//   3:1–3:3   = MID
//   3:4        = n/a (4-3-3 has 3 mids)
//   4:1–4:3   = ATT (RW, ST, LW)
// ═══════════════════════════════════════════════════════════

const mockBestEleven = <BestElevenPlayer>[
  // GK
  BestElevenPlayer(
    id: 83001, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '1:1', slotIndex: 0,
    playerId: 539685, playerName: 'Wojciech Szczęsny',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/13/539685.png',
    positionName: 'Goalkeeper', detailedPositionName: 'Goalkeeper',
    starts: 24, totalMinutes: 2160, updatedAt: '2026-04-09 03:49:26',
  ),

  // DEF — Right Back
  BestElevenPlayer(
    id: 83002, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '2:1', slotIndex: 1,
    playerId: 400148, playerName: 'Jules Koundé',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/4/400148.png',
    positionName: 'Defender', detailedPositionName: 'Right Back',
    starts: 27, totalMinutes: 2350, updatedAt: '2026-04-09 03:49:26',
  ),

  // DEF — Centre Back
  BestElevenPlayer(
    id: 83003, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '2:2', slotIndex: 2,
    playerId: 272040, playerName: 'Ronald Araújo',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/8/272040.png',
    positionName: 'Defender', detailedPositionName: 'Centre Back',
    starts: 20, totalMinutes: 1760, updatedAt: '2026-04-09 03:49:26',
  ),

  // DEF — Centre Back
  BestElevenPlayer(
    id: 83004, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '2:3', slotIndex: 3,
    playerId: 37619283, playerName: 'Pau Cubarsí',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/11/37619283.png',
    positionName: 'Defender', detailedPositionName: 'Centre Back',
    starts: 26, totalMinutes: 2280, updatedAt: '2026-04-09 03:49:26',
  ),

  // DEF — Left Back
  BestElevenPlayer(
    id: 83005, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '2:4', slotIndex: 4,
    playerId: 3321079, playerName: 'Alejandro Balde',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/7/3321079.png',
    positionName: 'Defender', detailedPositionName: 'Left Back',
    starts: 25, totalMinutes: 2100, updatedAt: '2026-04-09 03:49:26',
  ),

  // MID — Defensive Midfield
  BestElevenPlayer(
    id: 83006, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '3:1', slotIndex: 5,
    playerId: 37619070, playerName: 'Marc Casado',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/22/37619070.png',
    positionName: 'Midfielder', detailedPositionName: 'Defensive Midfield',
    starts: 28, totalMinutes: 2380, updatedAt: '2026-04-09 03:49:26',
  ),

  // MID — Central Midfield
  BestElevenPlayer(
    id: 83007, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '3:2', slotIndex: 6,
    playerId: 2083, playerName: 'Pedri',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/3/2083.png',
    positionName: 'Midfielder', detailedPositionName: 'Central Midfield',
    starts: 22, totalMinutes: 1870, updatedAt: '2026-04-09 03:49:26',
  ),

  // MID — Attacking Midfield (Dani Olmo, re-registered Jan window)
  BestElevenPlayer(
    id: 83008, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '3:3', slotIndex: 7,
    playerId: 37362, playerName: 'Dani Olmo',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/26/37362.png',
    positionName: 'Midfielder', detailedPositionName: 'Attacking Midfield',
    starts: 19, totalMinutes: 1560, updatedAt: '2026-04-09 03:49:26',
  ),

  // ATT — Right Wing
  BestElevenPlayer(
    id: 83009, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '4:1', slotIndex: 8,
    playerId: 37783904, playerName: 'Lamine Yamal',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/16/37783904.png',
    positionName: 'Attacker', detailedPositionName: 'Right Wing',
    starts: 29, totalMinutes: 2460, updatedAt: '2026-04-09 03:49:26',
  ),

  // ATT — Striker
  BestElevenPlayer(
    id: 83010, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '4:2', slotIndex: 9,
    playerId: 1268651, playerName: 'Robert Lewandowski',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/11/1268651.png',
    positionName: 'Attacker', detailedPositionName: 'Attacker',
    starts: 28, totalMinutes: 2380, updatedAt: '2026-04-09 03:49:26',
  ),

  // ATT — Left Wing (Rashford, Jan loan signing)
  BestElevenPlayer(
    id: 83011, teamId: 83, seasonId: 23686, formation: '4-3-3',
    slotKey: '4:3', slotIndex: 10,
    playerId: 220858, playerName: 'Marcus Rashford',
    playerImage: 'https://cdn.sportmonks.com/images/soccer/players/26/220858.png',
    positionName: 'Attacker', detailedPositionName: 'Left Wing',
    starts: 12, totalMinutes: 980, updatedAt: '2026-04-09 03:49:26',
  ),
];

/// Filter helper — later swap with API call
List<BestElevenPlayer> bestElevenByTeam(int teamId) =>
    mockBestEleven.where((p) => p.teamId == teamId).toList();