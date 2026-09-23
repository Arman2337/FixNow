import os
import re

# 1. lib/design_system/fix_address_selector.dart
path = 'lib/design_system/fix_address_selector.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('widget.existingAddress', 'widget.initialAddress')
content = content.replace('const BorderRadius.vertical(top: AppRadius.modal)', 'BorderRadius.vertical(top: AppRadius.modal)')
content = re.sub(r'AddEditAddressModalSheet\.show\(context(,\s*.*?)*?\)', 'AddEditAddressModalSheet.show(context)', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. lib/features/ai/ai_diagnostic_screen.dart
path = 'lib/features/ai/ai_diagnostic_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'addressRepository: .*?,', '', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# 3. lib/features/profile/customer_profile_controller.dart
path = 'lib/features/profile/customer_profile_controller.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'import \'package:fixnow_mobile/features/profile/customer_profile.dart\';' not in content:
    content = 'import \'package:fixnow_mobile/features/profile/customer_profile.dart\';\n' + content

content = content.replace('CustomerStats', 'CustomerProfileStats')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
    
# 4. test/customer_discovery_test.dart
path = 'test/customer_discovery_test.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'ServiceDiscoveryController\((.*?)\)', r'ServiceDiscoveryController(\1, SubServiceRepository(api: MockApiTransport(), accessToken: () async => ""))', content)
content = content.replace(', SubServiceRepository(api: MockApiTransport(), accessToken: () async => ""), SubServiceRepository(api: MockApiTransport(), accessToken: () async => "")', ', SubServiceRepository(api: MockApiTransport(), accessToken: () async => "")')
content = content.replace('SubServiceRepository(ApiTransport(MockClient()))', 'SubServiceRepository(api: MockApiTransport(), accessToken: () async => "")')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# 5. test/universal_search_test.dart
path = 'test/universal_search_test.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'ServiceDiscoveryController\((.*?)\)', r'ServiceDiscoveryController(\1, SubServiceRepository(api: MockApiTransport(), accessToken: () async => ""))', content)
content = content.replace(', SubServiceRepository(api: MockApiTransport(), accessToken: () async => ""), SubServiceRepository(api: MockApiTransport(), accessToken: () async => "")', ', SubServiceRepository(api: MockApiTransport(), accessToken: () async => "")')
content = content.replace('SubServiceRepository(ApiTransport(MockClient()))', 'SubServiceRepository(api: MockApiTransport(), accessToken: () async => "")')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done fixing")
