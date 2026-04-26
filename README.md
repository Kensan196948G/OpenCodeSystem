# OpenCodeSystem (ClaudeOS v8 互換)

OpenCode + DeepSeek V4 を利用した完全自律開発システム。

## 必須合格条件

1. `~/OpenCodeSystem` 配下だけで制御可能
2. `/home/kensan/Projects` 配下のプロジェクトを選択可能
3. 選択したプロジェクトに対して OpenCode + DeepSeek V4 を実行
4. 8時間で必ず停止
5. `state/state.json` に現在状態を保存
6. `logs/` に全Agentログを保存
7. main ブランチへ直接 push しない
8. 作業ブランチを自動作成
9. commit / push / PR 作成が可能
10. GitHub Actions の CI 状態を `gh pr checks` で確認
11. CI 失敗時は最大15回まで修復
12. 15回失敗したら停止し、人間レビュー待ち
13. 秘密情報・トークン・認証情報をログに出さない
14. PR マージは自動実行しない
15. README.md に実行手順を記載

## 禁止事項

- main/master への直接 push
- force push
- 認証情報の生成・保存・表示
- 無限ループ
- CI 修復の無制限リトライ
- 複数プロジェクトへの同時破壊的変更
- ユーザー確認なしの PR マージ

## ディレクトリ構成

```
OpenCodeSystem/
├ launcher.sh              # エントリポイント
├ selector.sh              # プロジェクト選択
├ loop.sh                  # 8時間制御ループ
├ orchestrator.sh          # フェーズ状態遷移管理
├ config.sh                # 共有設定・ユーティリティ
├ README.md
├ agents/
│  ├ cto.md                # CTO: 要件定義
│  ├ manager.md            # Manager: タスク分解
│  ├ dev.md                # Dev: 実装
│  ├ qa.md                 # QA: テスト生成
│  ├ tester.md             # Tester: テスト実行
│  ├ cimanager.md          # CIManager: エラー修復
│  └ ci_repair.md          # CI修復エージェント
├ scripts/
│  ├ monitor.sh            # Monitor フェーズ
│  ├ plan.sh               # Plan フェーズ
│  ├ dev.sh                # Dev フェーズ
│  ├ qa.sh                 # QA フェーズ
│  ├ test.sh               # Test フェーズ
│  ├ fix.sh                # Fix フェーズ
│  ├ pr.sh                 # PR 作成
│  ├ git_prepare.sh        # Git ブランチ作成・push
│  ├ github_pr.sh          # GitHub PR 作成
│  ├ ci_check.sh           # CI 状態確認
│  └ ci_repair_loop.sh     # CI 修復ループ
├ state/
│  └ state.json            # 状態管理
├ logs/                    # 実行ログ
└ .github/workflows/
   └ ci.yml                # GitHub Actions テンプレート
```

## 開発ループ

```
Monitor → Plan → Dev → QA → Test → (Fix) → GitHub → Done
                                          ↓ (失敗時)
                                        Fix ループ
```

- **Monitor**: CTO エージェントがプロジェクト分析・要件定義
- **Plan**: Manager エージェントがタスク分解
- **Dev**: Dev エージェントが実装
- **QA**: QA エージェントがテスト生成・実行
- **Test**: Tester エージェントがテスト検証
- **Fix**: CIManager エージェントが修復 (最大15回)
- **GitHub**: ブランチ作成 → PR → CI確認 → 必要に応じて修復

## モデル使い分け

| 役割 | モデル |
|---|---|
| CTO / Manager / Dev | `deepseek/deepseek-v4-pro` |
| QA / Tester / CIManager | `deepseek/deepseek-v4-flash` |

## 前提条件

- Node.js 環境 (opencode CLI がインストール済み)
- DeepSeek API 認証済み (`opencode auth list` で確認)
- GitHub CLI (`gh`) 認証済み (`gh auth status` で確認)
- jq インストール済み

## 実行手順

```bash
cd ~/OpenCodeSystem
chmod +x launcher.sh selector.sh loop.sh orchestrator.sh scripts/*.sh
./launcher.sh
```

プロジェクト選択画面が表示されるので、開発対象のプロジェクト番号を入力します。以降は自動で開発サイクルが実行されます。

## 環境変数

| 変数 | 説明 |
|---|---|
| `OPENCODE_SYSTEM` | OpenCodeSystem のルートパス (自動設定) |
| `TARGET_PROJECT` | 現在のターゲットプロジェクト名 (自動設定) |
