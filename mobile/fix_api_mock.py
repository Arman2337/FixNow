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

        if 'ApiTransport(MockClient())' in content:
            content = content.replace('ApiTransport(MockClient())', 'MockApiTransport()')
            changed = True
            
        if 'class MockClient implements HttpClient' in content:
            content = re.sub(r'class MockClient implements HttpClient \{.*?\n\}', 
                'class MockApiTransport implements ApiTransport {\n  @override\n  Future<ApiResponse> send(ApiRequest request) async => const ApiResponse(statusCode: 200, body: []);\n}', 
                content, flags=re.DOTALL)
            changed = True
            
        if changed:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Fixed {path}")
