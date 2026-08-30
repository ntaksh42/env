# AGENTS.md

このファイルは Codex CLI がこのリポジトリで作業する際のガイダンスを提供する。

## リポジトリ概要

Windows環境のClaude Code dotfiles・開発環境構成リポジトリ。Claude Codeのhooks、skills、agents、settings、PowerShellプロファイル、ユーティリティツールを一元管理する。

## アーキテクチャ

```
claude/              Claude Code 設定の管理元（~/.claude へインストール）
  install.ps1        インストーラ（hooks・skills・agents・settingsを ~/.claude に展開）
  settings.template.json  settings.json テンプレート（{{CLAUDE_DIR}} プレースホルダ）
  CLAUDE.global.md   グローバル CLAUDE.md の管理元（~/.claude/CLAUDE.md へ展開、既存はバックアップ）
  hooks/             フック用PowerShellスクリプト（.HOOKブロックでメタデータ定義）
  skills/            Claude Code スキル（各サブディレクトリが1スキル）
  agents/            サブエージェント定義（.md、~/.claude/agents へインストール）
app-settings/        アプリ設定ファイルのバックアップ・管理
tools/               汎用PowerShellユーティリティ
```

### hooks の仕組み

- 各 `.ps1` ファイル先頭の `<# .HOOK { "event": "...", "matcher": "..." } #>` ブロックからメタデータを抽出
- `install.ps1` がメタデータを読み取り、`settings.json` の `hooks` セクションに自動登録
- stdinからJSON形式のコンテキスト（session_id, cwd, transcript_path等）を受け取る

### skills の仕組み

- `claude/skills/` 配下のサブディレクトリが個別スキル
- 各スキルは `SKILL.md`（プロンプト定義）と `references/`（参照資料）で構成

### settings.template.json

- プレースホルダ: `{{CLAUDE_DIR}}` → `~/.claude`
- インストーラがプレースホルダを実際のパスに置換して `~/.claude/settings.json` を生成

## コマンド

```bash
# Claude Code 環境のインストール（hooks, skills, agents, settings を ~/.claude に展開）
powershell.exe -ExecutionPolicy Bypass -File claude/install.ps1

# 複数gitリポジトリの一括pull
powershell.exe -File tools/Update-GitRepositories.ps1 -Path "C:\Projects"

# app-settings/ の設定ファイルと実環境の配置先を同期
pwsh -File tools/Sync-AppSettings.ps1                  # repo -> 実環境（既定）
pwsh -File tools/Sync-AppSettings.ps1 -Direction Pull  # 実環境 -> repo
```

## 開発規約

- hookスクリプトには必ず `.HOOK` メタデータブロックを含める（install.ps1の自動登録に必要）
- スキルはサブディレクトリ形式（`SKILL.md` + `references/`）を使用する（`*.skill` 単一ファイル形式は install.ps1 がコピーしないため展開されない）
- PowerShellスクリプトは `$ErrorActionPreference = "Stop"` を使用
- settings.template.json のパスは JSON 文字列としての `\\` エスケープを使用（`\\\\` は過剰）
