import os
import re

test_dir = 'test'

for root, dirs, files in os.walk(test_dir):
    for file in files:
        if not file.endswith('_test.dart'): continue
        path = os.path.join(root, file)
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        changed = False

        if 'ServiceDiscoveryController(' in content and 'SubServiceRepository' not in content:
            content = re.sub(r'ServiceDiscoveryController\((.*?)\)', r'ServiceDiscoveryController(\1, SubServiceRepository(ApiTransport(MockClient())))', content)
            changed = True
            
        if 'SubServiceCatalogScreen(' in content and 'api:' not in content:
            content = re.sub(r'SubServiceCatalogScreen\(', 'SubServiceCatalogScreen(api: ApiTransport(MockClient()), ', content)
            changed = True

        if changed:
            if 'import \'package:fixnow_mobile/features/services/sub_service_item.dart\';' not in content:
                content = 'import \'package:fixnow_mobile/features/services/sub_service_item.dart\';\n' + content
            if 'import \'package:fixnow_mobile/api/api_client.dart\';' not in content:
                content = 'import \'package:fixnow_mobile/api/api_client.dart\';\n' + content
                
            if 'class MockClient' not in content:
                content += "\n\nclass MockClient implements HttpClient {\n  @override\n  Future<HttpResponse> send(HttpRequest request) async => HttpResponse(200, {});\n}\n"
                
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Fixed {path}")
