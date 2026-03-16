# SF Toolbox

SF Toolbox is a personal Salesforce utility toolkit created and maintained by Yuta Aoki.
Salesforce 組織のオブジェクト・項目メタデータを手軽に CSV 出力できる Unlocked Package です。

---

## インストール

以下の URL からインストールしてください。

**v0.2.0（最新）**
`https://login.salesforce.com/packaging/installPackage.apexp?p0=04tIg000000osEnIAI`

インストール後、権限セット「**Toolbox User**」を使用するユーザーに付与してください。

---

## 使い方

1. App Launcher（アプリケーションランチャー）から「**SF Toolbox**」を開く
2. 検索ボックスでオブジェクト名（API 名または表示ラベル）を絞り込む
3. 出力したいオブジェクトにチェックを入れる（複数選択可）
4. 「**出力**」ボタンをクリック
5. CSV テキストが画面に表示されたら「**クリップボードにコピー**」で Excel 等に貼り付け

**CSV の列構成**
```
Object Name, Object Label, Field Name, Field Label, Data Type
```

---

## 注意事項

### 一部の項目が出力されない場合

以下の理由により、Object Manager に存在する項目でも出力されないことがあります。

**1. 項目レベルセキュリティ（FLS）で非表示の項目**
実行ユーザーのプロファイルまたは権限セットで「参照可能」になっていない項目は出力されません。出力したい項目がある場合は、Salesforce 管理者に FLS の設定変更を依頼してください。

### その他の制限事項

- 選択オブジェクト数が多い場合、処理に時間がかかることがあります
- 大規模な組織（項目数が非常に多い org）ではヒープ制限に達する可能性があります（V2 で非同期処理対応予定）

---

## バージョン履歴

| バージョン | 内容 |
|---|---|
| v0.2.0 | マネージドパッケージオブジェクト含めるトグルを削除（常に全オブジェクトを表示） |
| v0.1.0 | 初回リリース |

---

## 動作環境

- Salesforce Enterprise / Developer / Sandbox 組織
- API バージョン: 62.0
- namespace: `sftb`
