import os
import re

files_to_fix = [
    'lib/design_system/fix_address_selector.dart',
    'lib/features/profile/customer_profile_screen.dart',
    'lib/features/bookings/service_request_screen.dart',
    'lib/features/ai/ai_diagnostic_screen.dart',
    'lib/app/app.dart'
]

for file_path in files_to_fix:
    path = os.path.join(file_path)
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Revert in ServiceRequestScreen
    if 'ServiceRequestScreen' in content:
        content = re.sub(r'required this\.addressRepository,\n\s*', '', content)
        content = re.sub(r'final SavedAddressRepository addressRepository;\n\s*', '', content)
        content = content.replace('widget.addressRepository', 'SavedAddressRepository.instance')

    # Revert in CustomerProfileScreen
    if 'CustomerProfileScreen' in content:
        content = re.sub(r'required this\.addressRepository,\n\s*', '', content)
        content = re.sub(r'final SavedAddressRepository addressRepository;\n\s*', '', content)
        content = re.sub(r'required this\.addressRepository', '', content)
        content = content.replace('addressRepository: widget.addressRepository', '')
        content = content.replace('addressRepository: addressRepository', '')
        content = content.replace('widget.addressRepository', 'SavedAddressRepository.instance')
        content = content.replace('addressRepository.', 'SavedAddressRepository.instance.')

    # Revert in AddEditAddressModalSheet
    if 'AddEditAddressModalSheet' in content:
        content = re.sub(r'required this\.addressRepository,\n\s*', '', content)
        content = re.sub(r'final SavedAddressRepository addressRepository;\n\s*', '', content)
        content = re.sub(r', SavedAddressRepository repository', '', content)
        content = re.sub(r'addressRepository: repository, ', '', content)
        content = content.replace('widget.addressRepository', 'SavedAddressRepository.instance')
        
    # Revert in SavedAddressSelectorCard
    if 'SavedAddressSelectorCard' in content:
        content = re.sub(r'required this\.addressRepository,\n\s*', '', content)
        content = re.sub(r'final SavedAddressRepository addressRepository;\n\s*', '', content)
        content = content.replace('widget.addressRepository', 'SavedAddressRepository.instance')
        content = re.sub(r'AddEditAddressModalSheet\.show\(context, widget\.addressRepository\)', 'AddEditAddressModalSheet.show(context)', content)

    # Revert in AiDiagnosticScreen
    if 'AiDiagnosticScreen' in content:
        content = re.sub(r'this\.addressRepository,\n\s*', '', content)
        content = re.sub(r'final SavedAddressRepository\? addressRepository;\n\s*', '', content)
        content = re.sub(r'addressRepository: widget\.addressRepository!,\n\s*', '', content)
        
    # Revert app.dart usage
    if 'app.dart' in file_path:
        content = re.sub(r'addressRepository: _addressRepository,\n\s*', '', content)
        content = re.sub(r'addressRepository: _addressRepository', '', content)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Reverted {path}")
