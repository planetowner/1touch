param(
    [switch]$Preview,
    [ValidateRange(1, 23)]
    [int]$StartStep = 1
)

$ErrorActionPreference = 'Stop'
$seasonName = '2026/2027'
$competitionIds = @('2', '5', '8', '24', '27', '82', '301', '384', '390', '564', '570', '2286')
$big5Ids = @('8', '82', '301', '384', '564')

# 시즌 지정이 가능한 재설계 명령만 기존 의존 순서대로 실행해요.
$commands = [System.Collections.Generic.List[string[]]]::new()
$commands.Add(@('teams', $seasonName) + $competitionIds)
$commands.Add(@('team-seasons', $seasonName))
foreach ($competitionId in $competitionIds) {
    # fixtures는 대회 ID를 하나씩 받아요.
    $commands.Add(@('fixtures', $seasonName, $competitionId))
}
$commands.Add(@('players', $seasonName) + $big5Ids)
$commands.Add(@('squads', $seasonName) + $big5Ids)
# 컵·유럽대항전도 갱신해야 같은 시즌 전체를 쓰는 Best Eleven과 입력이 맞아요.
$commands.Add(@('fixture-details', $seasonName) + $competitionIds)
$commands.Add(@('capology-team-slugs', $seasonName) + $big5Ids)
$commands.Add(@('capology-player-ids', $seasonName) + $big5Ids)
$commands.Add(@('wages', $seasonName) + $big5Ids)
$commands.Add(@('standings', $seasonName) + $big5Ids)
$commands.Add(@('best-eleven', $seasonName))
$commands.Add(@('best-eleven', 'validate', $seasonName))

Push-Location $PSScriptRoot
try {
    # 중단 뒤 완료 로그를 확인한 단계까지 건너뛰어, 끝난 적재를 반복하지 않아요.
    for ($index = $StartStep - 1; $index -lt $commands.Count; $index++) {
        $commandArguments = $commands[$index]
        Write-Host ('[{0}/{1}] python -X utf8 -u -m one_touch_loader.cli {2}' -f ($index + 1), $commands.Count, ($commandArguments -join ' '))
        if ($Preview) { continue }
        # PowerShell 5.1의 로그 리디렉션이 stderr 첫 줄에서 중단되지 않게 해요.
        # Python 오류는 끝까지 출력한 뒤 종료 코드로 판정해요.
        $ErrorActionPreference = 'Continue'
        try {
            & python -X utf8 -u -m one_touch_loader.cli @commandArguments
        }
        finally {
            $ErrorActionPreference = 'Stop'
        }
        # 앞 단계가 실패하면 그 결과를 사용하는 다음 적재를 시작하지 않아요.
        if ($LASTEXITCODE -ne 0) {
            throw ('Step {0} failed (exit {1}): {2}' -f ($index + 1), $LASTEXITCODE, ($commandArguments -join ' '))
        }
    }
}
finally {
    Pop-Location
}
