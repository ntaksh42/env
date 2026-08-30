<#
.HOOK
{
  "event": "PreToolUse",
  "matcher": "Edit|Write|MultiEdit"
}
#>
# advisor-reminder.ps1
# 実装変更前のadvisor()呼び出しを促すリマインダ（PreToolUse/Edit|Write|MultiEdit）。
# 反復注入によるトークン浪費と指示の希釈を避けるため、セッション初回のEdit系ツール使用時のみ注入する。
# （advisor強制の本体は Stop フックが担うため、ここでの注入を1回に減らしても enforcement は不変）

param()

$raw = $input | Out-String
try {
    $data = $raw | ConvertFrom-Json
} catch {
    exit 0
}

$reminder = "実装変更前に必ずadvisor()を呼んでセルフレビュー/設計確認を行うこと。未呼出ならまずadvisor()を実行してから本ツールを使ってください。"

# セッション毎に1回だけ注入（マーカーファイルで判定）
$sessionId = $data.session_id
if ($sessionId) {
    $safeId = $sessionId -replace '[^a-zA-Z0-9_-]', '_'
    $marker = Join-Path $env:TEMP "claude-advisor-reminder-$safeId.flag"
    if (Test-Path $marker) {
        exit 0
    }
    New-Item -ItemType File -Path $marker | Out-Null
}

$out = [PSCustomObject]@{
    hookSpecificOutput = [PSCustomObject]@{
        hookEventName     = "PreToolUse"
        additionalContext = $reminder
    }
}
$out | ConvertTo-Json -Compress -Depth 5
exit 0
