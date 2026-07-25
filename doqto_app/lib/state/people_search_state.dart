import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../data/models/network_profile.dart';

/// One render state for the people-search screen.
sealed class PeopleSearchState {
  const PeopleSearchState();
}

/// Nothing typed yet — show the "search for colleagues" prompt.
class PeopleSearchIdle extends PeopleSearchState {
  const PeopleSearchIdle();
}

/// A query is in flight (first page).
class PeopleSearchLoading extends PeopleSearchState {
  final String query;
  const PeopleSearchLoading(this.query);
}

/// Results (possibly empty → the "no people found" empty state).
class PeopleSearchResults extends PeopleSearchState {
  final String query;
  final List<PersonCard> people;
  const PeopleSearchResults(this.query, this.people);
}

/// The query failed.
class PeopleSearchError extends PeopleSearchState {
  final String query;
  final Object error;
  const PeopleSearchError(this.query, this.error);
}

/// Debounced people search with a latest-wins guard: every [search] bumps a
/// monotonic token; a slow response whose token is stale is dropped, so the
/// UI never flashes results from an earlier query. Debounce lives in the
/// [AppSearchBar]; this notifier only guards ordering.
class PeopleSearchNotifier extends Notifier<PeopleSearchState> {
  int _token = 0;

  @override
  PeopleSearchState build() => const PeopleSearchIdle();

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    final token = ++_token; // newest wins
    if (query.isEmpty) {
      state = const PeopleSearchIdle();
      return;
    }
    state = PeopleSearchLoading(query);
    try {
      final page =
          await ref.read(networkRepositoryProvider).searchPeople(q: query);
      if (token != _token) return; // a newer query superseded us
      state = PeopleSearchResults(query, page.data);
    } catch (e) {
      if (token != _token) return;
      state = PeopleSearchError(query, e);
    }
  }
}

final peopleSearchProvider =
    NotifierProvider<PeopleSearchNotifier, PeopleSearchState>(
        PeopleSearchNotifier.new);
