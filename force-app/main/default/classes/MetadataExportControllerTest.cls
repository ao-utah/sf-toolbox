@IsTest
private class MetadataExportControllerTest {

    @IsTest
    static void testGenerateCsv_returnsNonNull() {
        Test.startTest();
        String csv = MetadataExportController.generateCsvForObjects(new List<String>{'Account'}, 'csv');
        Test.stopTest();

        System.assertNotEquals(null, csv, 'CSV string should not be null');
    }

    @IsTest
    static void testGenerateCsv_hasHeaderRow() {
        Test.startTest();
        String csv = MetadataExportController.generateCsvForObjects(new List<String>{'Account'}, 'csv');
        Test.stopTest();

        List<String> lines = csv.split('\n');
        System.assertEquals(
            'Object Name,Object Label,Field Name,Field Label,Data Type',
            lines[0],
            'First line should be the header row'
        );
    }

    @IsTest
    static void testGenerateCsv_hasDataRows() {
        Test.startTest();
        String csv = MetadataExportController.generateCsvForObjects(new List<String>{'Account'}, 'csv');
        Test.stopTest();

        List<String> lines = csv.split('\n');
        System.assert(lines.size() > 1, 'CSV should have at least one data row');
    }

    @IsTest
    static void testGenerateCsv_dataRowHasFiveColumns() {
        Test.startTest();
        String csv = MetadataExportController.generateCsvForObjects(new List<String>{'Account'}, 'csv');
        Test.stopTest();

        List<String> lines = csv.split('\n');
        if (lines.size() > 1) {
            Boolean found = false;
            for (Integer i = 1; i < lines.size(); i++) {
                List<String> cols = lines[i].split(',');
                System.assert(cols.size() >= 5, 'Each data row should have 5 columns: ' + lines[i]);
                found = true;
                break;
            }
            System.assert(found, 'Should have at least one data row to validate');
        }
    }

    @IsTest
    static void testGenerateCsv_containsAccountIdField() {
        Test.startTest();
        String csv = MetadataExportController.generateCsvForObjects(new List<String>{'Account'}, 'csv');
        Test.stopTest();

        // Object Name は API 名（言語不変）、Field Name も API 名（言語不変）で検証
        // Object Label / Field Label は org の言語設定により変わるため比較しない
        Boolean hasAccountIdRow = false;
        for (String line : csv.split('\n')) {
            List<String> cols = line.split(',');
            if (cols.size() >= 5 && cols[0] == 'Account' && cols[2] == 'Id' && cols[4] == 'ID') {
                hasAccountIdRow = true;
                break;
            }
        }
        System.assert(hasAccountIdRow, 'CSV should contain a row for Account.Id field');
    }

    @IsTest
    static void testGetObjectNames_returnsNonEmpty() {
        Test.startTest();
        List<MetadataExportController.ObjectInfo> names = MetadataExportController.getObjectNames(false);
        Test.stopTest();

        System.assert(names != null && names.size() > 0, 'Object names list should not be empty');
    }

    @IsTest
    static void testGetObjectNames_containsAccount() {
        Test.startTest();
        List<MetadataExportController.ObjectInfo> names = MetadataExportController.getObjectNames(false);
        Test.stopTest();

        Boolean found = false;
        for (MetadataExportController.ObjectInfo obj : names) {
            if (obj.name == 'Account') {
                found = true;
                break;
            }
        }
        System.assert(found, 'Object names list should contain Account');
    }

    @IsTest
    static void testGetObjectNames_hasLabelField() {
        Test.startTest();
        List<MetadataExportController.ObjectInfo> names = MetadataExportController.getObjectNames(false);
        Test.stopTest();

        System.assert(names[0].label != null && names[0].label != '', 'ObjectInfo should have a label');
    }

    @IsTest
    static void testGenerateCsvForObjects_emptyList() {
        Test.startTest();
        String csv = MetadataExportController.generateCsvForObjects(new List<String>(), 'csv');
        Test.stopTest();

        System.assertEquals(
            'Object Name,Object Label,Field Name,Field Label,Data Type',
            csv,
            'Empty list should return only the header row'
        );
    }
}
