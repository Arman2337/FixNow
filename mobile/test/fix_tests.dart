import 'dart:io';

void main() async {
  final dir = Directory('.');
  if (!dir.existsSync()) return;

  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'));

  for (final file in files) {
    var content = await file.readAsString();
    bool changed = false;

    // ServiceRequestScreen
    if (content.contains('ServiceRequestScreen(') &&
        !content.contains('addressRepository:')) {
      content = content.replaceAll(
        'ServiceRequestScreen(',
        'ServiceRequestScreen(addressRepository: SavedAddressRepository(api: ApiTransport(MockClient()), accessToken: () async => \'\'), ',
      );
      changed = true;
    }

    // CustomerProfileScreen
    if (content.contains('CustomerProfileScreen(') &&
        !content.contains('addressRepository:')) {
      content = content.replaceAll(
        'CustomerProfileScreen(',
        'CustomerProfileScreen(addressRepository: SavedAddressRepository(api: ApiTransport(MockClient()), accessToken: () async => \'\'), ',
      );
      changed = true;
    }

    // SavedAddressSelectorCard
    if (content.contains('SavedAddressSelectorCard(') &&
        !content.contains('addressRepository:')) {
      content = content.replaceAll(
        'SavedAddressSelectorCard(',
        'SavedAddressSelectorCard(addressRepository: SavedAddressRepository(api: ApiTransport(MockClient()), accessToken: () async => \'\'), ',
      );
      changed = true;
    }

    // SubServiceCatalogScreen
    if (content.contains('SubServiceCatalogScreen(') &&
        !content.contains('api:')) {
      content = content.replaceAll(
        'SubServiceCatalogScreen(',
        'SubServiceCatalogScreen(api: ApiTransport(MockClient()), ',
      );
      changed = true;
    }

    // ServiceDiscoveryController
    if (content.contains('ServiceDiscoveryController(') &&
        !content.contains('SubServiceRepository')) {
      content = content.replaceAll(
        'ServiceDiscoveryController(',
        'ServiceDiscoveryController(ApiServiceCategoryRepository(ApiTransport(MockClient())), SubServiceRepository(ApiTransport(MockClient()))//',
      );
      // Actually it's better to just do this:
      content = content.replaceAll(
        'ServiceDiscoveryController(repo)',
        'ServiceDiscoveryController(repo, SubServiceRepository(ApiTransport(MockClient())))',
      );
      content = content.replaceAll(
        'ServiceDiscoveryController(ApiServiceCategoryRepository(ApiTransport(MockClient())))',
        'ServiceDiscoveryController(ApiServiceCategoryRepository(ApiTransport(MockClient())), SubServiceRepository(ApiTransport(MockClient())))',
      );
      content = content.replaceAll(
        'ServiceDiscoveryController(mockRepo)',
        'ServiceDiscoveryController(mockRepo, SubServiceRepository(ApiTransport(MockClient())))',
      );
      changed = true;
    }

    // SavedAddressRepository.instance
    if (content.contains('SavedAddressRepository.instance')) {
      content = content.replaceAll(
        'SavedAddressRepository.instance',
        'SavedAddressRepository(api: ApiTransport(MockClient()), accessToken: () async => \'\')',
      );
      changed = true;
    }

    // AddEditAddressModalSheet.show
    if (content.contains('AddEditAddressModalSheet.show(ctx)')) {
      content = content.replaceAll(
        'AddEditAddressModalSheet.show(ctx)',
        'AddEditAddressModalSheet.show(ctx, SavedAddressRepository(api: ApiTransport(MockClient()), accessToken: () async => \'\'))',
      );
      changed = true;
    }
    if (content.contains('AddEditAddressModalSheet.show(context)')) {
      content = content.replaceAll(
        'AddEditAddressModalSheet.show(context)',
        'AddEditAddressModalSheet.show(context, SavedAddressRepository(api: ApiTransport(MockClient()), accessToken: () async => \'\'))',
      );
      changed = true;
    }

    if (changed) {
      if (!content.contains(
        'import \'package:fixnow_mobile/api/api_client.dart\';',
      )) {
        content =
            'import \'package:fixnow_mobile/api/api_client.dart\';\n' + content;
      }
      if (!content.contains(
        'import \'package:fixnow_mobile/features/services/sub_service_item.dart\';',
      )) {
        content =
            'import \'package:fixnow_mobile/features/services/sub_service_item.dart\';\n' +
            content;
      }
      if (!content.contains('class MockClient')) {
        content =
            content +
            '\n\nclass MockClient implements HttpClient {\n  @override\n  Future<HttpResponse> send(HttpRequest request) async => HttpResponse(200, {});\n}\n';
      }
      await file.writeAsString(content);
      print('Updated \${file.path}');
    }
  }
}
