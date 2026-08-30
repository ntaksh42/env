<#
.HOOK
{
  "event": "PreToolUse",
  "matcher": "Bash"
}
#>
# filter-test-output.ps1
# テストランナーの出力を「失敗行＋サマリ」だけに絞り、コンテキスト消費を削減するhook（PreToolUse/Bash）。
# 仕組み: tool_input.command を updatedInput で grep フィルタ付きに書き換える。
#
# 安全設計:
# - 対象は許可リスト済みのランナーのみ（permissionDecision=allow で権限を広げない）
# - ${PIPESTATUS[0]} でランナーの終了コードを保持（pass/fail を隠さない）
# - 複合コマンド（| & ; < > など）は書き換えない（壊さない）
# - コマンドに #nofilter を含む場合は素通し（全文が必要なときのバイパス）

param()

$raw = $input | Out-String
try {
    $data = $raw | ConvertFrom-Json
} catch {
    exit 0
}

$cmd = $data.tool_input.command
if (-not $cmd) { exit 0 }

# バイパス: 全文出力が必要なときは #nofilter を付ける
if ($cmd -match '#nofilter') { exit 0 }

# 複合コマンド/リダイレクト/コマンド置換は書き換えない（出力構造を壊さないため）
if ($cmd -match '[|&;<>`]' -or $cmd -match '\$\(') { exit 0 }

# 対象ランナー（いずれも settings の allow リストに含まれるもののみ）
$runner = '(\bpytest\b|\bjest\b|\bvitest\b|dotnet\s+test|go\s+test|cargo\s+test|(npm|yarn|pnpm)\s+(run\s+)?test\b)'
if ($cmd -notmatch $runner) { exit 0 }

# 失敗・エラー・サマリ行を抽出するパターン（grep -i 前提）
$pattern = 'FAIL|ERROR|error:|assertion|assert |panic|exception|traceback|[0-9]+ (passed|failed|skipped|errored|error)|test result|passed!|failed!|tests:|✕|✗|×'

# ${PIPESTATUS[0]} でランナー本体の終了コードを保持する（grep/head の exit で上書きしない）
$newCmd = "{ $cmd ; } 2>&1 | grep -E -i -A2 '$pattern' | head -200; exit `${PIPESTATUS[0]}"

$out = [PSCustomObject]@{
    hookSpecificOutput = [PSCustomObject]@{
        hookEventName      = "PreToolUse"
        permissionDecision = "allow"
        updatedInput       = [PSCustomObject]@{ command = $newCmd }
    }
}
$out | ConvertTo-Json -Compress -Depth 5
exit 0
