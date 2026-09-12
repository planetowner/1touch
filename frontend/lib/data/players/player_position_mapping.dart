const Map<int, String> playerPositionAbbreviations = {
  24: 'GK',
  148: 'CB',
  149: 'DM',
  150: 'AM',
  151: 'ST',
  152: 'LW',
  153: 'CM',
  154: 'RB',
  155: 'LB',
  156: 'RW',
  157: 'LM',
  158: 'RM',
  163: 'SS',
};

String normalizePlayerPositionAbbreviation(String abbreviation) {
  final normalized = abbreviation.trim().toUpperCase();

  // SportsMonks calls the central-forward position CF; OneTouch uses ST.
  return normalized == 'CF' ? 'ST' : normalized;
}

String? playerPositionAbbreviationFromId(int positionId) {
  final abbreviation = playerPositionAbbreviations[positionId];
  return abbreviation == null
      ? null
      : normalizePlayerPositionAbbreviation(abbreviation);
}
