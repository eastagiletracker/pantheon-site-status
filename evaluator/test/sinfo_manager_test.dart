import 'dart:convert';
import 'dart:io';

import 'package:sinfo/models/site.dart';
import 'package:sinfo/models/wordpress_plugin.dart';
import 'package:sinfo/pantheon.dart';
import 'package:sinfo/sinfo_manager.dart';
import 'package:test/test.dart';

void main() {
  group('resultsPayload', () {
    test('wraps sites with a UTC generated_at timestamp', () {
      final site = Site(pantheonName: 'alpha');
      final at = DateTime.utc(2026, 8, 20, 6);

      final payload = resultsPayload([site], generatedAt: at);

      expect(payload['generated_at'], '2026-08-20T06:00:00.000Z');
      expect(payload['sites'], hasLength(1));

      final decoded = json.decode(json.encode(payload)) as Map<String, dynamic>;
      expect(decoded['sites'][0]['name'], 'alpha');
    });

    test('converts a local generatedAt to UTC', () {
      final local = DateTime(2026, 8, 20, 1);
      final payload = resultsPayload(const [], generatedAt: local);

      expect(
        DateTime.parse(payload['generated_at'] as String).isUtc,
        isTrue,
      );
    });
  });

  group('SinfoManager with a site that has no WordPress installation', () {
    test('skips the remaining WordPress fetches and reports one distinct '
        'issue', () async {
      final dir = await Directory.systemTemp.createTemp('sinfo_test');
      addTearDown(() => dir.delete(recursive: true));
      final pantheon = _NoWordPressPantheon();
      final manager = SinfoManager(resultsPath: '${dir.path}/sites.json')
        ..pantheon = pantheon;

      final file = await manager.sitesFile();

      expect(pantheon.pluginFetches, 0);
      final payload =
          json.decode(await file!.readAsString()) as Map<String, dynamic>;
      final site = (payload['sites'] as List).single as Map<String, dynamic>;
      expect(site['cms_version'], '');
      expect(site['cms_version_status'], 'not installed');
      expect(site['issues'], [
        {
          'level': 'warning',
          'related_field': 'cms_version_status',
          'description':
              'No WordPress installation found on the live environment',
          'url': '',
        }
      ]);
    });
  });
}

/// Pantheon stand-in for one WordPress site whose live environment has no
/// WordPress installation.
class _NoWordPressPantheon extends Pantheon {
  int pluginFetches = 0;

  _NoWordPressPantheon() : super(pantheonOrgId: 'org');

  @override
  Future<bool> isTerminusInstalled() async => true;

  @override
  Future<List<Site>> fetchSites() async => [
        Site(
          cmsName: 'wordpress',
          pantheonName: 'empty-site',
          pantheonPlanName: 'Performance Small',
        ),
      ];

  @override
  Future<String> fetchPhpVersion(String siteName) async => '8.4';

  @override
  Future<String> fetchLiveUrl(String siteName) async => 'https://example.com';

  @override
  Future<String> fetchNewRelicStatus(String siteName) async => 'active';

  @override
  Future<String> fetchUpstreamStatus(String siteName) async => 'current';

  @override
  Future<String> fetchWordPressVersion(String siteName, {String? url}) async =>
      throw WordPressNotInstalledException(siteName);

  @override
  Future<List<WordPressPlugin>?> fetchWordPressPlugins(String siteName,
      {String? url}) async {
    pluginFetches++;
    return [];
  }
}
