# OpenCodeSystem

OpenCode + DeepSeek V4 を利用した完全自律開発システム。
Cron による時間制御・多重起動防止・モデル使い分けに対応。

## ディレクトリ構成

```
OpenCodeSystem/
├ launcher.sh              # エントリポイント
├ selector.sh              # プロジェクト選択（手動）
├ loop.sh                  # 8時間制御ループ
├ orchestrator.sh          # フェーズ状態遷移管理（Monitor→Plan→Dev→QA→Test→Fix→GitHub→Done）
├ config.sh                # 共有設定・ユーティリティ
├ config/
│  └ project.conf          # プロジェクト設定（FIXED / AUTO モード切替）
├ scripts/
│  ├ cron_start.sh         # Cron 起動スクリプト（多重起動防止 + PID管理）
│  ├ cron_stop.sh          # Cron 停止スクリプト（2段階強制停止）
│  ├ project_selector.sh   # プロジェクト選択（相対パス/絶対パス対応）
│  ├ monitor.sh → Pro      # CTO: 要件定義
│  ├ plan.sh → Pro         # Manager: タスク分解
│  ├ dev.sh → Flash        # Dev: 実装
│  ├ qa.sh → Flash         # QA: テスト生成
│  ├ test.sh → Flash       # Tester: テスト実行
│  ├ fix.sh → Flash        # CIManager: エラー修復
│  ├ ci_check.sh           # CI 状態確認
│  ├ ci_repair_loop.sh     # CI 修復ループ（最大15回）
│  ├ git_prepare.sh        # Git ブランチ作成・push
│  ├ github_pr.sh          # GitHub PR 作成
│  └ pr.sh                 # PR 作成（旧）
├ agents/
│  ├ cto.md                # CTO エージェントプロンプト
│  ├ manager.md            # Manager エージェントプロンプト
│  ├ dev.md                # Dev エージェントプロンプト
│  ├ qa.md                 # QA エージェントプロンプト
│  ├ tester.md             # Tester エージェントプロンプト
│  ├ cimanager.md          # CIManager エージェントプロンプト
│  └ ci_repair.md          # CI修復エージェントプロンプト
├ state/
│  ├ state.json            # 状態管理（phase/task/retry/status）
│  └ pid.txt               # 実行PID（Cron運用時に自動生成）
├ logs/
│  ├ cron.log              # Cron 実行ログ
│  ├ start.log             # 起動ログ
│  ├ stop.log              # 停止ログ
│  ├ monitor.log           # Monitor フェーズログ
│  ├ plan.log              # Plan フェーズログ
│  ├ dev.log               # Dev フェーズログ
│  └ qa.log                # QA フェーズログ
└ .github/workflows/
   └ ci.yml                # GitHub Actions テンプレート
```

## 開発ループ

```
Monitor → Plan → Dev → QA → Test → (Fix) → GitHub → Done
                                          ↓ (失敗時)
                                        Fix ループ (最大15回)
```

## モデル使い分け

| フェーズ | モデル | 役割 |
|---|---|---|
| Monitor | Pro | プロジェクト分析・要件定義 |
| Plan | Pro | タスク分解・計画立案 |
| Dev | Flash | 実装 |
| QA | Flash | テスト生成 |
| Test | Flash | テスト実行 |
| Fix | Flash | エラー修復 |
| GitHub | Flash | PR作成・CI確認 |

## Cron スケジュール運用

月〜土の 08:30〜16:30（8時間）で自動起動・停止。

### Cron 登録

```bash
crontab -e
```

```
# OpenCodeSystem: 月〜土 08:30 起動
30 8 * * 1-6 /home/kensan/OpenCodeSystem/scripts/cron_start.sh

# OpenCodeSystem: 月〜土 16:30 停止
30 16 * * 1-6 /home/kensan/OpenCodeSystem/scripts/cron_stop.sh
```

### プロジェクト設定

`config/project.conf` でモード切替。

```ini
# 固定プロジェクト
MODE=FIXED
PROJECT=ITIL-Management-System

# または自動選択（最終更新順）
MODE=AUTO
```

`PROJECT` は相対パス（`/home/kensan/Projects/` 基準）または絶対パスに対応。

### 多重起動防止

- `state/pid.txt` に実行中PIDを保存
- 起動時に既存PIDの生存確認を行い、生きていれば起動しない

### 強制停止

1. `kill <PID>` (SIGTERM) → 5秒待機
2. 生存確認 → `kill -9 <PID>` (SIGKILL)

## 前提条件

- Node.js 環境（opencode CLI がインストール済み）
- DeepSeek API 認証済み（`opencode auth list` で確認）
- GitHub CLI（`gh`）認証済み（`gh auth status` で確認）
- `jq` インストール済み

## 実行手順

### 手動実行

```bash
cd ~/OpenCodeSystem
./launcher.sh
```

プロジェクト選択画面が表示されるので番号を入力。以降は自動で開発サイクルが実行される。

### Cron 自動実行（推奨）

```bash
# Cron 登録
crontab -e
# 上記 Cron 設定を追記

# ログ確認
tail -f ~/OpenCodeSystem/logs/cron.log
tail -f ~/OpenCodeSystem/logs/start.log
tail -f ~/OpenCodeSystem/logs/stop.log

# 状態確認
cat ~/OpenCodeSystem/state/state.json | jq
cat ~/OpenCodeSystem/state/pid.txt
ps -p $(cat ~/OpenCodeSystem/state/pid.txt)
```

### 単体テスト

```bash
# プロジェクト選択テスト
bash ~/OpenCodeSystem/scripts/project_selector.sh

# 起動テスト
bash ~/OpenCodeSystem/scripts/cron_start.sh

# 停止テスト
bash ~/OpenCodeSystem/scripts/cron_stop.sh
```

## 環境変数

| 変数 | 説明 |
|---|---|
| `OPENCODE_SYSTEM` | OpenCodeSystem ルートパス（自動設定） |
| `TARGET_PROJECT` | 現在のターゲットプロジェクト（自動設定） |
| `OPENCODE_MODEL` | 現在のフェーズ用モデル（Orchestrator が自動設定） |

## 禁止事項

- main/master への直接 push
- force push
- 認証情報の生成・保存・表示
- 無限ループ
- CI 修復の無制限リトライ（上限15回）
- 複数プロジェクトへの同時破壊的変更
- ユーザー確認なしの PR マージ
