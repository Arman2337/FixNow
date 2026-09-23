import os

# 1. lib/app/app.dart
path = 'lib/app/app.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'import \'package:fixnow_mobile/features/services/sub_service_item.dart\';' not in content:
    content = 'import \'package:fixnow_mobile/features/services/sub_service_item.dart\';\n' + content

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. test/customer_discovery_test.dart & test/universal_search_test.dart
for path in ['test/customer_discovery_test.dart', 'test/universal_search_test.dart']:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    content = content.replace('SubServiceRepository(api: MockApiTransport(), accessToken: () async => "")', 'SubServiceRepository(MockApiTransport())')

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
        
print("Fixed app and tests")
