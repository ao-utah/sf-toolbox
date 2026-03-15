# SF Toolbox V1 実装プラン

## Context

SF Toolbox は Salesforce 組織内のオブジェクト・項目メタデータを出力する個人用ユーティリティツール。
Unlocked Package として構築し、複数 org にインストールして使えることを目指す。
V1 は「オブジェクトを選択 → テキスト画面表示 → クリップボードコピー」方式。

> **LWS 制約**: Lightning Web Security が `<a>` タグによるブラウザファイルダウンロードを全面ブロックするため、CSV一括ダウンロード方式は廃止し、テキスト画面表示方式に変更。

---

## 命名規則

| 種別 | 規則 | 例 |
|---|---|---|
| Apex クラス | PascalCase / プレフィックスなし | `MetadataExportController` |
| LWC | camelCase / プレフィックスなし | `metadataExporter` |
| FlexiPage / Tab / PermSet | PascalCase / プレフィックスなし | `MetadataExporter` |

> **注意**: `sft` プレフィックスは当初の案だったが廃止。namespace `sftb` が Unlocked Package により自動付与されるため、クラス名・コンポーネント名への手動プレフィックスは不要。

---

## 作成ファイル一覧（13ファイル）

```
force-app/main/default/
├── applications/
│   └── SFToolbox.app-meta.xml                        # Lightning App（アプリランチャーにタイル表示）
├── classes/
│   ├── MetadataExportController.cls                  # メタデータ取得・CSV生成
│   ├── MetadataExportController.cls-meta.xml
│   ├── MetadataExportControllerTest.cls              # テストクラス（必須）
│   └── MetadataExportControllerTest.cls-meta.xml
├── lwc/
│   └── metadataExporter/
│       ├── metadataExporter.html                     # UI（オブジェクト選択・出力・コピー）
│       ├── metadataExporter.js                       # Apex呼び出し・状態管理
│       ├── metadataExporter.css                      # オブジェクトリストのスクロール
│       └── metadataExporter.js-meta.xml              # targets: AppPage / Tab
├── flexipages/
│   └── MetadataExporter.flexipage-meta.xml           # LWC を配置したページ
├── tabs/
│   └── MetadataExporter.tab-meta.xml                 # FlexiPage へのタブ（label: SF Toolbox）
└── permissionsets/
    └── ToolboxUser.permissionset-meta.xml            # Apex アクセス権 + タブ可視性
```

---

## 各ファイルの実装

### 1. MetadataExportController.cls

```apex
public with sharing class MetadataExportController {

    public class ObjectInfo implements Comparable {
        @AuraEnabled public String name;
        @AuraEnabled public String label;

        public ObjectInfo(String name, String label) {
            this.name = name;
            this.label = label;
        }

        public Integer compareTo(Object compareTo) {
            ObjectInfo other = (ObjectInfo) compareTo;
            if (this.label < other.label) return -1;
            if (this.label > other.label) return 1;
            return 0;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ObjectInfo> getObjectNames(Boolean includePackageObjects) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        List<ObjectInfo> result = new List<ObjectInfo>();
        Boolean includePackages = (includePackageObjects == true);
        for (String objName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult objDesc = globalDescribe.get(objName).getDescribe();
            if (!objDesc.isAccessible()) continue;
            if (objDesc.isCustomSetting()) continue;

            // getName() と getLocalName() が異なる → namespace付きマネージドパッケージオブジェクト
            Boolean isPackageObj = objName.endsWith('__c')
                && (objDesc.getName() != objDesc.getLocalName());
            Boolean isOrgCustomObj = objName.endsWith('__c') && !isPackageObj;

            if (isOrgCustomObj) {
                // 組織独自カスタムオブジェクト: isSearchable 不問で常に表示
                result.add(new ObjectInfo(objDesc.getName(), objDesc.getLabel()));
            } else if (isPackageObj) {
                // マネージドパッケージオブジェクト: toggle ON のときのみ表示
                if (!includePackages) continue;
                result.add(new ObjectInfo(objDesc.getName(), objDesc.getLabel()));
            } else {
                // 標準オブジェクト: isSearchable で AI系メタオブジェクトを除外
                if (!objDesc.isQueryable()) continue;
                if (!objDesc.isSearchable()) continue;
                result.add(new ObjectInfo(objDesc.getName(), objDesc.getLabel()));
            }
        }
        result.sort();  // label でソート（Comparable実装）
        return result;
    }

    @AuraEnabled
    public static String generateCsvForObjects(List<String> selectedObjects) {
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            List<String> csvLines = new List<String>();
            csvLines.add('Object Name,Object Label,Field Name,Field Label,Data Type');

            List<String> sorted = new List<String>(selectedObjects);
            sorted.sort();

            for (String objName : sorted) {
                if (!globalDescribe.containsKey(objName.toLowerCase())) continue;
                Schema.DescribeSObjectResult objDesc = globalDescribe.get(objName.toLowerCase()).getDescribe();
                if (!objDesc.isAccessible()) continue;

                Map<String, Schema.SObjectField> fieldsMap = objDesc.fields.getMap();
                List<String> fieldNames = new List<String>(fieldsMap.keySet());
                fieldNames.sort();

                for (String fieldName : fieldNames) {
                    Schema.DescribeFieldResult fieldDesc = fieldsMap.get(fieldName).getDescribe();
                    if (!fieldDesc.isAccessible()) continue;
                    csvLines.add(
                        escape(objDesc.getName()) + ',' +
                        escape(objDesc.getLabel()) + ',' +
                        escape(fieldDesc.getName()) + ',' +
                        escape(fieldDesc.getLabel()) + ',' +
                        escape(String.valueOf(fieldDesc.getType()))
                    );
                }
            }
            return String.join(csvLines, '\n');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String escape(String value) {
        if (value == null) return '';
        if (value.contains(',') || value.contains('"') || value.contains('\n')) {
            return '"' + value.replace('"', '""') + '"';
        }
        return value;
    }
}
```

### 2. MetadataExportControllerTest.cls

```apex
@IsTest
private class MetadataExportControllerTest {

    @IsTest
    static void testGenerateCsv_returnsNonNull() { ... }

    @IsTest
    static void testGenerateCsv_hasHeaderRow() { ... }  // header: Object Name,Object Label,Field Name,Field Label,Data Type

    @IsTest
    static void testGenerateCsv_hasDataRows() { ... }

    @IsTest
    static void testGenerateCsv_dataRowHasFiveColumns() { ... }

    @IsTest
    static void testGenerateCsv_containsAccountIdField() { ... }  // 英語org: Account,Account,Id,Id,ID / 日本語org: Account,取引先,Id,取引先 ID,ID

    @IsTest
    static void testGetObjectNames_returnsNonEmpty() { ... }

    @IsTest
    static void testGetObjectNames_containsAccount() { ... }

    @IsTest
    static void testGetObjectNames_hasLabelField() { ... }

    @IsTest
    static void testGenerateCsvForObjects_emptyList() { ... }  // ヘッダー行のみ返る
}
```

### 3. metadataExporter.html

UI構成:
- `lightning-card title="メタデータエクスポート" icon-name="utility:settings"`
- 検索ボックス（API名・表示ラベル両方で絞り込み）
- チェックボックス「マネージドパッケージ内のオブジェクトも含める」
- すべて選択 / すべて解除ボタン（絞り込み結果に作用）
- オブジェクト一覧（max-height: 300px スクロール）: `表示ラベル (API名)` 形式
- 出力ボタン（選択数0のとき disabled）
- スピナー
- readonly textarea（CSV出力結果）
- クリップボードにコピーボタン
- エラーメッセージ（赤文字）

### 4. metadataExporter.js

主要プロパティ:
- `_allObjects`: `[{ name, label, checked }]` — `@wire getObjectNames` で初期化
- `includePackageObjects`: マネージドパッケージオブジェクト含めるトグル（`@wire` の reactive parameter）
- `filteredObjects` getter: 検索キーワードでフィルタ後に `checkboxLabel` を付与して返す
  - **注意**: `checkboxLabel` は reactive proxy のスプレッドで消えるため getter 内で都度生成
- `renderedCallback`: native `<textarea>` に `csvOutput` をセット（テンプレートバインド不可のため）
- `selectedCount`, `isOutputDisabled`: 出力ボタン制御
- `handleIncludePackageObjects`: トグル変更時に `isLoadingObjects=true` + `_allObjects=[]` してから wire re-fetch
- `handleCheck`: `findIndex` で更新（スプレッドは明示的に `{name, label, checked}` のみ）
- `handleSelectAll/Deselect`: 絞り込み結果の範囲のみに作用
- `handleOutput`: `generateCsvForObjects` imperative 呼び出し
- `handleCopy`: `navigator.clipboard.writeText`

### 5. metadataExporter.css

```css
.object-list {
    max-height: 300px;
    overflow-y: auto;
    border: 1px solid #dddbda;
    border-radius: 4px;
    padding: 0.5rem;
}
```

### 6. MetadataExporter.flexipage-meta.xml

```xml
<masterLabel>メタデータエクスポート</masterLabel>
<template><name>flexipage:defaultAppHomeTemplate</name></template>
<type>AppPage</type>
```

> App Page の masterLabel がページ内に見出しとして表示されるため、カード title と一致させる。

### 7. MetadataExporter.tab-meta.xml

```xml
<label>SF Toolbox</label>
<motif>Custom87: Toolbox</motif>
```

> タブラベル = `SF Toolbox`、アイコン = `Custom87: Toolbox`（工具箱）

### Permission Set の tabSettings は `Visible` が必須

`Available` ではアプリを開いたときに「項目なし」エラーになる。必ず `Visible` を指定すること。

```xml
<tabSettings>
    <tab>MetadataExporter</tab>
    <visibility>Visible</visibility>
</tabSettings>
```

### 8. SFToolbox.app-meta.xml

```xml
<label>SF Toolbox</label>
<description>Salesforce管理用の便利ツール by YutaAoki</description>
<navType>Standard</navType>
<uiType>Lightning</uiType>
<formFactors>Large</formFactors>
<defaultLandingTab>MetadataExporter</defaultLandingTab>
<tabs>MetadataExporter</tabs>
```

> Lightning App 定義。アプリケーションランチャーに「SF Toolbox」がアイコン付きタイルとして表示される。`SftMetadataExporter` タブをデフォルトランディングページとして設定。

---

## デプロイ

```bash
sf project deploy start \
  --source-dir force-app/main/default/classes \
  --source-dir force-app/main/default/lwc \
  --source-dir force-app/main/default/tabs \
  --source-dir force-app/main/default/flexipages \
  --source-dir force-app/main/default/applications \
  --target-org <DEV_ORG_ALIAS> \
  --api-version 62.0
```

> `--api-version 62.0` を明示しないと SOAP API バージョン不整合エラーが発生する場合がある。

## 動作確認手順

1. ブラウザリロード → オブジェクト一覧が「表示ラベル (API名)」形式でチェックボックス表示
2. 検索ボックスに日本語ラベルまたは API 名を入力 → 絞り込み
3. 数件チェック → 「出力」ボタンが active になる
4. 「出力」クリック → スピナー → textarea に CSV テキスト表示
5. 「クリップボードにコピー」→ Excel に貼り付けて確認
6. CSV 列: `Object Name, Object Label, Field Name, Field Label, Data Type`

---

## CSV出力フォーマット

```
Object Name,Object Label,Field Name,Field Label,Data Type
Account,取引先,Id,取引先 ID,ID
Account,取引先,Name,取引先名,STRING
...
```

---

## オブジェクト絞り込みロジック

オブジェクト種別によってフィルタ条件を分岐する。

### 組織独自カスタムオブジェクト（namespace なし `__c`）
- `isAccessible()` = true かつ `isCustomSetting()` = false
- `isSearchable()` は不問（Object Manager に表示されるが検索無効のオブジェクトも含める）
- **常に表示**

### マネージドパッケージオブジェクト（namespace付き `__c`、`getName() != getLocalName()`）
- 「マネージドパッケージ内のオブジェクトも含める」トグル ON のときのみ表示

### 標準オブジェクト
- `isAccessible()` = true、`isQueryable()` = true、`isCustomSetting()` = false
- `isSearchable()` = true（AI系内部オブジェクト AIApplication 等を除外）

> **アンマネージドパッケージ**（namespace なし）のカスタムオブジェクトは組織独自オブジェクトと区別不能なため、常に表示される。

---

## ガバナ制限の注意点

- 選択オブジェクト数に比例して処理量が増加（全件一括よりも安全）
- 標準的な Developer / Enterprise 組織では問題ない想定

---

## V2 以降の拡張候補（今は実装しない）

- Queueable/Batch Apex による非同期処理（大規模 org 対応）
- org 間差分比較機能
- カスタムオブジェクトのみフィルタオプション
- 選択状態の保存（localStorage）
