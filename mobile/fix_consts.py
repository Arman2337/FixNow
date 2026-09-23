import os

# 1. lib/features/bookings/customer_bookings_screen.dart
path = 'lib/features/bookings/customer_bookings_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
    
content = content.replace('child: const Row(', 'child: Row(')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. lib/features/provider/provider_home_screen.dart
path = 'lib/features/provider/provider_home_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
    
content = content.replace('children: const [', 'children: [')
content = content.replace('const Text(\n                        \'Gross Earnings\',', 'Text(\n                        \'Gross Earnings\',')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
    
print("Fixed constants")
