"""팀 특성의 고정 항목을 집계·학습·점수 계산에서 함께 사용해요."""

# 통계 하나는 경기당 평균, 통계 두 개는 합계끼리 나눈 비율이에요.
# 같은 영역의 모든 원본 통계가 있는 경기만 써서 항목별 경기 범위가 달라지지 않게 해요.
FEATURE_STAT_SPECS = {
    "possession_build_up": {
        "ball_possession_avg": ("ball-possession",),
        "ball_safe_per_match": ("ball-safe",),
        "passes_per_match": ("passes",),
        "pass_accuracy": ("successful-passes", "passes"),
    },
    "attacking_threat": {
        "dangerous_attacks_per_match": ("dangerous-attacks",),
        "total_crosses_per_match": ("total-crosses",),
        "cross_accuracy": ("accurate-crosses", "total-crosses"),
        "dribble_attempts_per_match": ("dribble-attempts",),
        "dribble_success_rate": ("successful-dribbles", "dribble-attempts"),
    },
    "chance_creation": {
        "corners_per_match": ("corners",),
        "key_passes_per_match": ("key-passes",),
        "big_chances_created_per_match": ("big-chances-created",),
    },
    "finishing": {
        "shots_insidebox_per_match": ("shots-insidebox",),
        "conversion_rate": ("goals", "shots-total"),
        "shots_on_target_per_match": ("shots-on-target",),
        "shot_accuracy": ("shots-on-target", "shots-total"),
    },
    "defending": {
        "goals_against_per_match": ("goals",),
        "shots_on_target_against_per_match": ("shots-on-target",),
        "shots_insidebox_against_per_match": ("shots-insidebox",),
        "big_chances_against_per_match": ("big-chances-created",),
        "dangerous_attacks_against_per_match": ("dangerous-attacks",),
    },
}

# 미제공 항목을 빼고 남은 항목만으로 점수를 만들지 않도록 비교 항목을 고정해요.
FEATURE_GROUPS = {group: list(specs) for group, specs in FEATURE_STAT_SPECS.items()}
ALL_FEATURES = [feature for features in FEATURE_GROUPS.values() for feature in features]

# 수비는 상대에게 허용한 값이라 낮을수록 좋아요. 상대 통계를 우리 팀에 연결해 집계해요.
LOWER_IS_BETTER_FEATURES = set(FEATURE_GROUPS["defending"])
