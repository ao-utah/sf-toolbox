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
    public static String generateCsvForObjects(List<String> selectedObjects) {
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            List<String> csvLines = new List<String>();
            csvLines.add('Object Name,Object Label,Field Name,Field Label,Data Type');

            if (selectedObjects == null || selectedObjects.isEmpty()) {
                return String.join(csvLines, '\n');
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
