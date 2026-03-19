# CLAUDE.md

## Review guidelines

- Review in Japanese.
- Focus on bugs, regressions, and missing tests.
- Be strict about Salesforce-specific risks (Apex governor limits, FLS, cacheable misuse, sharing settings).
- Be strict about GitHub Actions and CI changes.
- Ignore minor style-only comments unless they affect readability.

## Project overview

SFToolbox is a Salesforce Unlocked Package that exports object/field metadata as CSV or TSV.

- namespace: `sftb` (auto-applied by Salesforce — do NOT add `sft` prefix manually to class or LWC names)
- API version: 62.0

## Deploy rules

- Deploy target is `sftoolbox-dev` only.
- Never deploy to prod.
- Always use `--target-org sftoolbox-dev`.

## Key components

| Component | Path |
|---|---|
| Apex controller | `force-app/main/default/classes/MetadataExportController.cls` |
| Apex tests | `force-app/main/default/classes/MetadataExportControllerTest.cls` |
| LWC | `force-app/main/default/lwc/metadataExporter/` |
| Permission set | `force-app/main/default/permissionsets/ToolboxUser.permissionset-meta.xml` |

## Salesforce-specific cautions

- `@AuraEnabled(cacheable=true)` must not contain DML.
- All Apex classes use `with sharing`.
- `Schema.getGlobalDescribe()` consumes heap — be cautious with large orgs.
