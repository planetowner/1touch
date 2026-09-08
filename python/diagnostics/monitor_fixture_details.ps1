param(
    [string]$LogDirectory = 'C:\dev\terminal-logs'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
$activity = 'Fixture details 시즌별 5대 리그 적재'
$reader = $null
$buffer = ''
$completed = 0
$total = 0
$fixtureId = ''
$succeeded = $false

function Open-CommandLogReader([string]$Path) {
    # 명령이 끝나면 프로필이 .pending을 .log로 바꾸므로 이름 변경을 허용해요.
    $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
    # 현재 Windows PowerShell 프로필은 터미널 로그를 UTF-16으로 기록해요.
    return [IO.StreamReader]::new($stream, [Text.Encoding]::Unicode)
}

Write-Host "첫 번째 터미널에서 fixture-details '2017/2018'처럼 시즌을 지정해 실행하세요."
Write-Host '실행 중인 시즌 적재가 있으면 해당 로그에 연결합니다.'
Write-Host 'Ctrl+C로 모니터만 종료할 수 있습니다.'

try {
    while ($null -eq $reader) {
        Write-Progress -Activity $activity -Status '실행 로그를 기다리고 있어요.'
        $candidates = Get-ChildItem -LiteralPath $LogDirectory -Filter '*.pending' -File |
            Sort-Object CreationTime -Descending
        foreach ($candidate in $candidates) {
            try {
                $candidateReader = Open-CommandLogReader $candidate.FullName
            }
            catch [IO.FileNotFoundException] {
                # 목록을 읽은 직후 종료된 명령의 로그는 이미 .log로 바뀔 수 있어요.
                continue
            }
            $text = $candidateReader.ReadToEnd()
            # 시즌만 지정한 명령은 CLI가 5대 리그를 선택하므로 합산 진행률을 표시해요.
            if ($text -match '(?m)^.*> python(?: -u)? -m one_touch_loader\.cli fixture-details [''"]?(?<season>\d{4}/\d{4})[''"]?\r?$') {
                $seasonName = $Matches.season
                $activity = "Fixture details $seasonName | 5대 리그"
                $completionPattern = '(?m)^Fixture details season done: season=' + [regex]::Escape($seasonName) + ' '
                $reader = $candidateReader
                $buffer = $text
                $startedAt = $candidate.CreationTime
                $finishedLog = [IO.Path]::ChangeExtension($candidate.FullName, '.log')
                Write-Host ('로그: ' + $candidate.FullName)
                break
            }
            $candidateReader.Dispose()
        }
        if ($null -eq $reader) {
            Start-Sleep -Seconds 1
        }
    }

    while ($true) {
        # 종료 여부를 먼저 읽고 마지막 출력까지 읽어야 완료 문구를 놓치지 않아요.
        $commandEnded = Test-Path -LiteralPath $finishedLog
        $buffer += $reader.ReadToEnd()
        $lastNewline = $buffer.LastIndexOf("`n")
        if ($lastNewline -ge 0) {
            # 아직 쓰는 중인 줄은 다음 갱신 때 이어 읽어요.
            $lines = $buffer.Substring(0, $lastNewline + 1)
            $buffer = $buffer.Substring($lastNewline + 1)
            foreach ($match in [regex]::Matches($lines, '(?m)^\[fixture-details (\d+)/(\d+)\] fixture_id=(\d+) ')) {
                $completed = [int]$match.Groups[1].Value
                $total = [int]$match.Groups[2].Value
                $fixtureId = $match.Groups[3].Value
            }
            if ($lines -match $completionPattern) {
                $succeeded = $true
            }
        }

        $elapsed = (Get-Date) - $startedAt
        $elapsedText = '{0:00}:{1:00}:{2:00}' -f [math]::Floor($elapsed.TotalHours), $elapsed.Minutes, $elapsed.Seconds
        if ($total -gt 0) {
            $percent = 100.0 * $completed / $total
            $remaining = [TimeSpan]::FromSeconds($elapsed.TotalSeconds / $completed * ($total - $completed))
            $remainingText = '{0:00}:{1:00}:{2:00}' -f [math]::Floor($remaining.TotalHours), $remaining.Minutes, $remaining.Seconds
            $status = '{0:N0} / {1:N0} 경기 ({2:F2}%)' -f $completed, $total, $percent
            $operation = "최근 저장 fixture_id=$fixtureId | 경과 $elapsedText | 예상 남은 시간 $remainingText"
            Write-Progress -Activity $activity -Status $status -PercentComplete ([int][math]::Floor($percent)) -CurrentOperation $operation
        }
        else {
            $status = '첫 경기의 저장 완료를 기다리고 있어요.'
            Write-Progress -Activity $activity -Status $status -CurrentOperation "경과 $elapsedText"
        }

        if ($succeeded -or $commandEnded) {
            Write-Progress -Activity $activity -Completed
            if ($succeeded) {
                Write-Host "$seasonName 완료: $status | 경과 $elapsedText"
            }
            else {
                Write-Host "$seasonName 명령 종료: $status | 경과 $elapsedText"
                Write-Host '완료 문구가 없습니다. 첫 번째 터미널에서 오류나 중단 여부를 확인하세요.'
            }
            break
        }
        Start-Sleep -Seconds 1
    }
}
finally {
    if ($null -ne $reader) {
        $reader.Dispose()
    }
    Write-Progress -Activity $activity -Completed
}
