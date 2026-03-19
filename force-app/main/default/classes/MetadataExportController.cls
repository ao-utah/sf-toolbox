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

        for (String objName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult objDesc = globalDescribe.get(objName).getDescribe();
            if (!objDesc.isAccessible()) continue;
            if (objDesc.isCustomSetting()) continue;

            if (objName.endsWith('__c')) {
                // カスタムオブジェクト（組織独自 + パッケージ問わず）: isSearchable 不問で表示
                result.add(new ObjectInfo(objDesc.getName(), objDesc.getLabel()));
            } else {
                // 標準オブジェクト: isSearchable で AI系メタオブジェクトを除外
                if (!objDesc.isQueryable()) continue;
                if (!objDesc.isSearchable()) continue;
                result.add(new ObjectInfo(objDesc.getName(), objDesc.getLabel()));
            }
        }
        result.sort();
        return result;
    }

    @AuraEnabled
    public static String generateCsvForObjects(List<String> selectedObjects, String format) {
        try {
            Boolean isTsv = format == 'tsv';
            String delimiter = isTsv ? '\t' : ',';

            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            List<String> lines = new List<String>();
            lines.add(isTsv
                ? 'Object Name\tObject Label\tField Name\tField Label\tData Type'
                : 'Object Name,Object Label,Field Name,Field Label,Data Type'
            );

            if (selectedObjects == null || selectedObjects.isEmpty()) {
                return String.join(lines, '\n');
            }

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
                    String dataType = fieldDesc.isCalculated() ? 'FORMULA(' + String.valueOf(fieldDesc.getType()) + ')' : String.valueOf(fieldDesc.getType());
                    if (isTsv) {
                        lines.add(
                            escapeTsv(objDesc.getName()) + '\t' +
                            escapeTsv(objDesc.getLabel()) + '\t' +
                            escapeTsv(fieldDesc.getName()) + '\t' +
                            escapeTsv(fieldDesc.getLabel()) + '\t' +
                            escapeTsv(dataType)
                        );
                    } else {
                        lines.add(
                            escapeCsv(objDesc.getName()) + ',' +
                            escapeCsv(objDesc.getLabel()) + ',' +
                            escapeCsv(fieldDesc.getName()) + ',' +
                            escapeCsv(fieldDesc.getLabel()) + ',' +
                            escapeCsv(dataType)
                        );
                    }
                }
            }
            return String.join(lines, '\n');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String escapeCsv(String value) {
        if (value == null) return '';
        if (value.contains(',') || value.contains('"') || value.contains('\n')) {
            return '"' + value.replace('"', '""') + '"';
        }
        return value;
    }

    private static String escapeTsv(String value) {
        if (value == null) return '';
        return value.replace('\t', ' ').replace('\n', ' ');
    }
}
