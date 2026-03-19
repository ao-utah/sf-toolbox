# SF Toolbox V1 リリース・検証手順書

---

## 前提・Assumption

- プロジェクト名: SF Toolbox V1
- Salesforce DX プロジェクト構成済み
- Unlocked Package: Package Alias/Name/Id は <PACKAGE_ALIAS> / <PACKAGE_NAME> / <PACKAGE_ID>
- Dev Hub org: <DEV_HUB_ALIAS>
- 開発/検証 org: <DEV_ORG_ALIAS>
- 別組織（検証用 org）: <TEST_ORG_ALIAS>
- sf CLI（新コマンド体系）を利用
- API バージョン: 62.0
- すべてのファイル・メタデータは最新状態でコミット済み

---

## 手順

### 1) リリース準備

1.1 認証・環境チェック  
```bash
# Dev Hub 認証
sf org login web --set-default-dev-hub --alias <DEV_HUB_ALIAS>

# 開発 org 認証
sf org login web --alias <DEV_ORG_ALIAS>

# デフォルト org 設定
sf config set target-org <DEV_ORG_ALIAS>
sf config set target-dev-hub <DEV_HUB_ALIAS>

# package directory, api version 確認
cat sfdx-project.json
```

1.2 静的チェック・テスト実行  
```bash
# 静的解析
sf apex run test --test-level RunLocalTests --target-org <DEV_ORG_ALIAS>

# コードカバレッジ確認
sf apex run test --code-coverage --target-org <DEV_ORG_ALIAS>
```

1.3 失敗時の切り分け観点  
- 認証エラー: org alias, dev hub 設定ミス
- テスト失敗: Apex テストクラスのエラー内容確認
- カバレッジ不足: テストクラス追加・修正
- メタデータ未反映: force-app ディレクトリの内容確認

---

### 2) Unlocked Package のバージョン作成

2.1 バージョン作成  
```bash
sf package version create \
  --package <PACKAGE_ALIAS> \
  --installation-key-bypass \
  --wait 20 \
  --code-coverage \
  --target-dev-hub <DEV_HUB_ALIAS>
```

2.2 バージョンID/URL取得  
```bash
# バージョン作成結果の 04t... ID を控える
sf package version list --packages <PACKAGE_ALIAS> --target-dev-hub <DEV_HUB_ALIAS>
# インストールURL例: https://login.salesforce.com/packaging/installPackage.apexp?p0=<04tID>
```

2.3 リリースノート雛形  
- 変更点: FLS対応、テスト追加、ファイル数修正
- 既知課題: 大規模 org でのヒープ超過リスク（V2で非同期化予定）
- 対象 org: Salesforce Enterprise/Developer/Sandbox

---

### 3) インストール検証（同一 org）

3.1 インストール  
```bash
sf package install \
  --package <04tID> \
  --target-org <DEV_ORG_ALIAS> \
  --wait 10
```

3.2 権限セット付与  
```bash
sf org assign permset --name ToolboxUser --target-org <DEV_ORG_ALIAS>
```

3.3 UI・機能確認
- App Launcher で「SF Toolbox」アプリタイル表示・起動
- LWC 画面起動・オブジェクト選択後「出力」ボタン押下
- textarea に CSV テキストが表示されること
- 「クリップボードにコピー」ボタンで Excel 等に貼り付け確認
- CSV に "Account,取引先,Id,取引先 ID,ID" 行が含まれること（日本語 org の場合）

3.4 失敗時のログ確認  
```bash
sf apex log tail --target-org <DEV_ORG_ALIAS>
```

---

### 4) 別組織インストール検証

4.1 検証用 org 準備  
```bash
# Scratch org 作成例
sf org create scratch --definition-file config/project-scratch-def.json --alias <TEST_ORG_ALIAS> --set-default
```
または Sandbox/Developer org を利用

4.2 インストール  
```bash
sf package install \
  --package <04tID> \
  --target-org <TEST_ORG_ALIAS> \
  --wait 10
```

4.3 権限セット付与  
```bash
sf org assign permset --name ToolboxUser --target-org <TEST_ORG_ALIAS>
```

4.4 UI/E2E 検証チェックリスト
- App Launcher で「SF Toolbox」アプリタイル表示・起動
- LWC 画面起動・オブジェクト選択後「出力」ボタン押下
- textarea に CSV テキストが表示されること
- CSV に "Account,取引先,Id,取引先 ID,ID" 行が含まれること（日本語 org の場合）
- 画面エラー・権限エラーがないこと

4.5 アンインストール検証（必要時）  
```bash
sf package uninstall --package <04tID> --target-org <TEST_ORG_ALIAS> --wait 10
```

---

### 5) Go/No-Go 判定基準

- テスト全件パス・カバレッジ75%以上
- 開発 org／別 org で正常動作（CSV出力・UI・権限）
- CSVに必須行（Account,取引先,Id,取引先 ID,ID）が含まれる（日本語 org の場合）
- 既知課題（ヒープ超過）はV1では許容、V2で非同期化を引き継ぐ
- 重大なUI/権限/データ不整合がない

---

## チェックリスト

- [ ] Dev Hub/開発 org 認証・設定済み
- [ ] 静的解析・テスト・カバレッジOK
- [ ] パッケージバージョン作成・04tID取得
- [ ] 開発 org でインストール・動作確認
- [ ] 別 org でインストール・動作確認
- [ ] 既知課題・V2引き継ぎ事項を記録

---

## ロールバック案

- インストール済み org でアンインストール  
  ```bash
  sf package uninstall --package <04tID> --target-org <ORG_ALIAS> --wait 10
  ```
- 旧バージョンへ戻す場合は、旧 04tID で再インストール
- 重大障害時は org のバックアップ/リストア手順に従う

---

変数例:
- <PACKAGE_ALIAS>: SF Toolbox
- <PACKAGE_NAME>: SF Toolbox
- <DEV_HUB_ALIAS>: （DevHub の org alias）
- <DEV_ORG_ALIAS>: （開発・検証 org の alias）
- <TEST_ORG_ALIAS>: （別検証 org の alias）
- <04tID>: 04tXXXXXXXXXXXXXXX
