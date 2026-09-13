import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/data/services/npi_lookup.dart';

// Fixture captured live from
// https://npiregistry.cms.hhs.gov/api/?version=2.1&number=1851408082
// It is deliberately awkward: the MAILING address comes first, there is a
// decoy secondary site in practiceLocations, and the taxonomy desc is longer
// than the grouping the registry website shows.
const _vimal = {
  'number': '1851408082',
  'enumeration_type': 'NPI-1',
  'basic': {
    'first_name': 'VIMAL',
    'last_name': 'NANAVATI',
    'middle_name': 'I',
    'credential': 'M.D.',
    'name_prefix': 'Dr.',
    'status': 'A',
  },
  'addresses': [
    {
      'address_purpose': 'MAILING',
      'address_1': 'PO BOX 1734',
      'city': 'POWAY',
      'state': 'CA',
      'postal_code': '920741734',
      'telephone_number': '619-585-0476',
    },
    {
      'address_purpose': 'LOCATION',
      'address_1': '180 OTAY LAKES RD STE 110',
      'city': 'BONITA',
      'state': 'CA',
      'postal_code': '919022444',
      'telephone_number': '619-585-0476',
    },
  ],
  'practiceLocations': [
    {
      'address_purpose': 'LOCATION',
      'address_1': '2510 AIRPARK DR STE 205',
      'city': 'REDDING',
      'state': 'CA',
      'postal_code': '960012461',
    },
  ],
  'taxonomies': [
    {
      'code': '207RI0011X',
      'primary': true,
      'state': 'CA',
      'desc': 'Internal Medicine, Interventional Cardiology',
    },
  ],
};

/// Swaps Dio's transport so no test touches the network.
class _FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Object Function(RequestOptions options) respond;

  _FakeAdapter(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final result = respond(options);
    if (result is Exception) throw result;
    return ResponseBody.fromString(
      result as String,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

NpiLookup _lookupWith(_FakeAdapter adapter) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return NpiLookup(dio: dio);
}

String _body(List<Map<String, dynamic>> results) =>
    jsonEncode({'result_count': results.length, 'results': results});

void main() {
  group('parsing a single match', () {
    late NpiMatch match;

    setUp(() {
      final result = NpiLookup.parseResponse({
        'result_count': 1,
        'results': [_vimal],
      });
      expect(result.outcome, NpiLookupOutcome.matched);
      match = result.match!;
    });

    test('pulls the NPI and title-cases the SHOUTED registry name', () {
      expect(match.npi, '1851408082');
      expect(match.displayName, 'Vimal Nanavati, M.D.');
    });

    test('uses the LOCATION address, not the MAILING one listed first', () {
      expect(match.addressLine, '180 Otay Lakes Rd Ste 110');
      expect(match.cityStateZip, 'Bonita, CA 91902-2444');
      expect(match.city, 'Bonita');
      expect(match.state, 'CA');
    });

    test('ignores practiceLocations — those are secondary sites', () {
      expect(match.addressLine, isNot(contains('Airpark')));
      expect(match.cityStateZip, isNot(contains('Redding')));
    });

    test('takes the primary taxonomy description verbatim', () {
      expect(match.taxonomy, 'Internal Medicine, Interventional Cardiology');
    });
  });

  group('parsing outcomes', () {
    test('two results is ambiguous — limit=2 makes this the whole test', () {
      final result = NpiLookup.parseResponse(_body([_vimal, _vimal]));
      expect(result.outcome, NpiLookupOutcome.ambiguous);
      expect(result.match, isNull);
    });

    test('zero results is none', () {
      expect(NpiLookup.parseResponse(_body([])).outcome, NpiLookupOutcome.none);
    });

    test('a CMS Errors payload (HTTP 200!) is none, not a crash', () {
      final body = jsonEncode({
        'Errors': [
          {'description': 'NPI must be 10 digits', 'field': 'number', 'number': '06'}
        ]
      });
      expect(NpiLookup.parseResponse(body).outcome, NpiLookupOutcome.none);
    });

    test('a raw JSON string body parses the same as a decoded map', () {
      final result = NpiLookup.parseResponse(_body([_vimal]));
      expect(result.match!.npi, '1851408082');
    });

    test('garbage bodies are none, not exceptions', () {
      expect(NpiLookup.parseResponse('<html>down for maintenance</html>').outcome,
          NpiLookupOutcome.none);
      expect(NpiLookup.parseResponse(null).outcome, NpiLookupOutcome.none);
      expect(NpiLookup.parseResponse(42).outcome, NpiLookupOutcome.none);
      expect(NpiLookup.parseResponse({'results': 'nope'}).outcome, NpiLookupOutcome.none);
      expect(NpiLookup.parseResponse({'results': ['nope']}).outcome, NpiLookupOutcome.none);
    });
  });

  group('sparse registry records', () {
    Map<String, dynamic> variant(Map<String, dynamic> overrides) => {
          ..._vimal,
          ...overrides,
        };

    test('no credential leaves the name clean', () {
      final m = NpiLookup.parseResponse(_body([
        variant({
          'basic': {'first_name': 'ANA', 'last_name': 'DIAZ'}
        })
      ])).match!;
      expect(m.displayName, 'Ana Diaz');
    });

    test('no primary flag falls back to the first taxonomy', () {
      final m = NpiLookup.parseResponse(_body([
        variant({
          'taxonomies': [
            {'desc': 'Pediatrics', 'primary': false},
            {'desc': 'Neurology', 'primary': false},
          ]
        })
      ])).match!;
      expect(m.taxonomy, 'Pediatrics');
    });

    test('a later primary wins over an earlier non-primary', () {
      final m = NpiLookup.parseResponse(_body([
        variant({
          'taxonomies': [
            {'desc': 'Pediatrics', 'primary': false},
            {'desc': 'Neurology', 'primary': true},
          ]
        })
      ])).match!;
      expect(m.taxonomy, 'Neurology');
    });

    test('no taxonomies at all is still a match, just without a specialty', () {
      final m = NpiLookup.parseResponse(_body([
        variant({'taxonomies': <Map<String, dynamic>>[]})
      ])).match!;
      expect(m.taxonomy, isNull);
      expect(m.npi, '1851408082');
    });

    test('mailing-only records still yield an address', () {
      final m = NpiLookup.parseResponse(_body([
        variant({
          'addresses': [
            {
              'address_purpose': 'MAILING',
              'address_1': 'PO BOX 1734',
              'city': 'POWAY',
              'state': 'CA',
              'postal_code': '92074',
            }
          ]
        })
      ])).match!;
      expect(m.addressLine, 'Po Box 1734');
      expect(m.cityStateZip, 'Poway, CA 92074');
      expect(m.city, 'Poway');
    });

    test('no addresses at all is still a match, just without one', () {
      final m = NpiLookup.parseResponse(_body([
        variant({'addresses': <Map<String, dynamic>>[]})
      ])).match!;
      expect(m.addressLine, isNull);
      expect(m.cityStateZip, isNull);
      expect(m.city, isNull);
      expect(m.state, isNull);
    });

    test('address_2 is appended to the street line', () {
      final m = NpiLookup.parseResponse(_body([
        variant({
          'addresses': [
            {
              'address_purpose': 'LOCATION',
              'address_1': '1 MAIN ST',
              'address_2': 'FLOOR 3',
              'city': 'BOSTON',
              'state': 'MA',
              'postal_code': '021150001',
            }
          ]
        })
      ])).match!;
      expect(m.addressLine, '1 Main St, Floor 3');
      expect(m.cityStateZip, 'Boston, MA 02115-0001');
    });
  });

  group('formatting helpers', () {
    test('titleCase handles apostrophes, hyphens and slashes', () {
      expect(NpiMatch.titleCase("O'BRIEN"), "O'Brien");
      expect(NpiMatch.titleCase('MARY-JANE'), 'Mary-Jane');
      expect(NpiMatch.titleCase('SMITH/JONES'), 'Smith/Jones');
      expect(NpiMatch.titleCase('180 OTAY LAKES RD'), '180 Otay Lakes Rd');
      expect(NpiMatch.titleCase('  vimal  '), 'Vimal');
      expect(NpiMatch.titleCase(''), '');
    });

    test('formatZip splits ZIP+4 and leaves anything else alone', () {
      expect(NpiMatch.formatZip('919022444'), '91902-2444');
      expect(NpiMatch.formatZip('91902'), '91902');
      expect(NpiMatch.formatZip('91902-2444'), '91902-2444');
      expect(NpiMatch.formatZip(''), '');
    });
  });

  group('requests', () {
    test('byName asks for individuals only, two at a time', () async {
      final adapter = _FakeAdapter((_) => _body([_vimal]));
      await _lookupWith(adapter).byName('Vimal', 'Nanavati');

      final q = adapter.requests.single.queryParameters;
      expect(adapter.requests.single.uri.toString(), startsWith(NpiLookup.baseUrl));
      expect(q['version'], '2.1');
      expect(q['first_name'], 'Vimal');
      expect(q['last_name'], 'Nanavati');
      expect(q['enumeration_type'], 'NPI-1');
      // Load-bearing: result_count is capped by limit, so 2 is exactly enough
      // to tell "one match" from "more than one".
      expect(q['limit'], '2');
    });

    test('byNumber asks for the number and nothing else', () async {
      final adapter = _FakeAdapter((_) => _body([_vimal]));
      await _lookupWith(adapter).byNumber('1851408082');

      final q = adapter.requests.single.queryParameters;
      expect(q['version'], '2.1');
      expect(q['number'], '1851408082');
      expect(q.containsKey('limit'), isFalse);
      expect(q.containsKey('enumeration_type'), isFalse);
    });

    test('repeat queries are served from memory, case-insensitively', () async {
      final adapter = _FakeAdapter((_) => _body([_vimal]));
      final lookup = _lookupWith(adapter);

      await lookup.byName('Vimal', 'Nanavati');
      await lookup.byName('VIMAL', 'nanavati');
      await lookup.byNumber('1851408082');
      await lookup.byNumber('1851408082');

      expect(adapter.requests.length, 2); // one per distinct query
    });

    test('a network failure is silent, and is never cached', () async {
      var calls = 0;
      final adapter = _FakeAdapter((options) {
        calls++;
        if (calls == 1) return Exception('offline');
        return _body([_vimal]);
      });
      final lookup = _lookupWith(adapter);

      final first = await lookup.byName('Vimal', 'Nanavati');
      expect(first.outcome, NpiLookupOutcome.none);

      // Same query again — CMS may be back, so we must ask again.
      final second = await lookup.byName('Vimal', 'Nanavati');
      expect(second.outcome, NpiLookupOutcome.matched);
      expect(calls, 2);
    });

    test('a timeout is silent too', () async {
      final adapter = _FakeAdapter((options) => DioException.connectionTimeout(
            timeout: const Duration(seconds: 5),
            requestOptions: options,
          ));
      final result = await _lookupWith(adapter).byName('Vimal', 'Nanavati');
      expect(result.outcome, NpiLookupOutcome.none);
    });
  });
}
