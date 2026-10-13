import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';

enum EventSort { soonest, priceLow, priceHigh, popular, newest }

extension EventSortLabel on EventSort {
  String get label => switch (this) {
        EventSort.soonest => 'Date: soonest',
        EventSort.priceLow => 'Price: low to high',
        EventSort.priceHigh => 'Price: high to low',
        EventSort.popular => 'Most popular',
        EventSort.newest => 'Recently added',
      };
}

const dateFilters = ['All', 'Today', 'Tomorrow', 'This Weekend', 'This Week', 'Near Me'];

class AppState extends ChangeNotifier {
  AppState({bool autoInit = true}) {
    if (autoInit) unawaited(initialize());
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Startup + session
  // ---------------------------------------------------------------------------

  bool _initializing = true;
  bool get initializing => _initializing;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    await ApiService.loadSavedBaseUrl();
    _isDarkMode = preferences.getBool('darkMode') ?? false;
    final token = preferences.getString('authToken');
    final cachedUser = preferences.getString('cachedUser');
    if (token != null) {
      _authToken = token;
      if (cachedUser != null) {
        try {
          _user = AppUser.fromJson(jsonDecode(cachedUser) as Map<String, dynamic>);
        } catch (_) {}
      }
      try {
        _user = await ApiService.me(token);
        await _cacheSession();
      } on ApiException catch (error) {
        if (error.isAuthError) await _clearSession();
      }
    }
    _initializing = false;
    _notify();
    unawaited(loadEvents());
    if (isLoggedIn) unawaited(loadUserBookings());
  }

  String? _authToken;
  String? get authToken => _authToken;
  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _authToken != null && _user != null;

  String get _token {
    final token = _authToken;
    if (token == null) throw const ApiException('Sign in to continue.', statusCode: 401);
    return token;
  }

  Future<void> _cacheSession() async {
    final preferences = await SharedPreferences.getInstance();
    if (_authToken != null) await preferences.setString('authToken', _authToken!);
    if (_user != null) await preferences.setString('cachedUser', jsonEncode(_user!.toJson()));
  }

  Future<void> _clearSession() async {
    _authToken = null;
    _user = null;
    _userBookings.clear();
    _hostedEvents.clear();
    _latestBooking = null;
    _chatMessages.clear();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('authToken');
    await preferences.remove('cachedUser');
  }

  /// Runs an authenticated API call; signs out if the server says the session is invalid.
  Future<T> _authed<T>(Future<T> Function(String token) call) async {
    try {
      return await call(_token);
    } on ApiException catch (error) {
      if (error.isAuthError) {
        _sessionMessage = error.message;
        await _clearSession();
        _notify();
      }
      rethrow;
    }
  }

  String? _sessionMessage;

  /// A message explaining why the user was signed out (shown once on the login screen).
  String? takeSessionMessage() {
    final message = _sessionMessage;
    _sessionMessage = null;
    return message;
  }

  Future<void> _startSession(Map<String, dynamic> response) async {
    _authToken = response['token'] as String;
    _user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    _navIndex = 0;
    await _cacheSession();
    _notify();
    unawaited(loadUserBookings());
    unawaited(loadEvents());
  }

  Future<void> login({required String email, required String password}) async {
    await _startSession(await ApiService.login(email.trim(), password));
  }

  Future<void> register(String name, String email, String password) async {
    await _startSession(await ApiService.register(name.trim(), email.trim(), password));
  }

  Future<void> logout() async {
    await _clearSession();
    _notify();
  }

  Future<void> refreshUser() async {
    _user = await _authed(ApiService.me);
    await _cacheSession();
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    _notify();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('darkMode', _isDarkMode);
  }

  int _navIndex = 0;
  int get navIndex => _navIndex;
  void setNavIndex(int index) {
    _navIndex = index;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Future<void> _setUser(AppUser user) async {
    _user = user;
    await _cacheSession();
    _notify();
  }

  Future<void> updateProfile({required String name, required String email, required String phone, required String city}) async {
    await _setUser(await _authed((token) => ApiService.updateProfile(token, {
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'city': city.trim(),
        })));
  }

  Future<void> setPreferredCategories(List<String> categories) async {
    await _setUser(await _authed((token) => ApiService.updateProfile(token, {'preferredCategories': categories})));
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _setUser(await _authed((token) => ApiService.updateProfile(token, {'notificationsEnabled': enabled})));
  }

  Future<void> changePassword(String current, String next) =>
      _authed((token) => ApiService.changePassword(token, current, next));

  Future<void> uploadAvatar(ImageUpload image) async {
    await _setUser(await _authed((token) => ApiService.uploadAvatar(token, image)));
  }

  Future<void> removeAvatar() async {
    await _setUser(await _authed(ApiService.removeAvatar));
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  final List<Event> _events = [];
  List<Event> get events => List.unmodifiable(_events);
  bool _eventsLoading = false;
  bool get eventsLoading => _eventsLoading;
  bool _eventsLoaded = false;
  bool get eventsLoaded => _eventsLoaded;
  String? _eventLoadError;
  String? get eventLoadError => _eventLoadError;

  Future<void> loadEvents() async {
    _eventsLoading = true;
    _notify();
    try {
      final loaded = await ApiService.getEvents();
      _events
        ..clear()
        ..addAll(loaded);
      _eventLoadError = null;
      _eventsLoaded = true;
      if (_activeEvent != null) {
        final fresh = _events.where((event) => event.id == _activeEvent!.id);
        if (fresh.isNotEmpty) _activeEvent = fresh.first;
      }
    } on ApiException catch (error) {
      _eventLoadError = error.message;
    } finally {
      _eventsLoading = false;
      _notify();
    }
  }

  Event? eventById(String id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  List<String> get categories {
    final fromEvents = _events.map((event) => event.category).toSet();
    return [...eventCategories, ...fromEvents.where((c) => !eventCategories.contains(c))];
  }

  /// Match score used by "AI For You": category preference, city and popularity.
  int matchScore(Event event) {
    final preferences = _user?.preferredCategories ?? const [];
    var score = event.matchPercentage - 10;
    if (preferences.contains(event.category)) score += 12;
    final city = _user?.city.trim().toLowerCase() ?? '';
    if (city.isNotEmpty && event.location.toLowerCase().contains(city)) score += 5;
    if (event.isTrending) score += 2;
    return score.clamp(50, 99);
  }

  List<Event> get recommendedEvents {
    final list = List.of(_events)..sort((a, b) => matchScore(b).compareTo(matchScore(a)));
    return list;
  }

  // Wishlist
  bool isWishlisted(String eventId) => _user?.wishlist.contains(eventId) ?? false;
  List<Event> get wishlistEvents => _events.where((event) => isWishlisted(event.id)).toList();

  Future<void> toggleWishlist(String eventId) async {
    final current = _user;
    if (current == null) return;
    final optimistic = Set.of(current.wishlist);
    optimistic.contains(eventId) ? optimistic.remove(eventId) : optimistic.add(eventId);
    _user = current.copyWith(wishlist: optimistic);
    _notify();
    try {
      await _setUser(await _authed((token) => ApiService.toggleWishlist(token, eventId)));
    } on ApiException {
      if (_user != null) _user = current;
      _notify();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Explore filters
  // ---------------------------------------------------------------------------

  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _dateFilter = 'All';
  EventSort _sort = EventSort.soonest;
  bool _freeOnly = false;

  String get searchQuery => _searchQuery;
  String get selectedCategoryFilter => _categoryFilter;
  String get selectedDateFilter => _dateFilter;
  EventSort get sort => _sort;
  bool get freeOnly => _freeOnly;

  void setSearchQuery(String query) {
    _searchQuery = query;
    _notify();
  }

  void setCategoryFilter(String category) {
    _categoryFilter = category;
    _notify();
  }

  void setDateFilter(String filter) {
    _dateFilter = filter;
    _notify();
  }

  void setSort(EventSort sort) {
    _sort = sort;
    _notify();
  }

  void setFreeOnly(bool value) {
    _freeOnly = value;
    _notify();
  }

  void clearFilters() {
    _searchQuery = '';
    _categoryFilter = 'All';
    _dateFilter = 'All';
    _freeOnly = false;
    _sort = EventSort.soonest;
    _notify();
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty || _categoryFilter != 'All' || _dateFilter != 'All' || _freeOnly;

  /// Opens the Explore tab with a category pre-selected.
  void exploreCategory(String category) {
    _categoryFilter = category;
    _navIndex = 1;
    _notify();
  }

  bool _matchesDate(Event event, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (_dateFilter) {
      case 'Today':
        return event.overlaps(today, today.add(const Duration(days: 1)));
      case 'Tomorrow':
        final tomorrow = today.add(const Duration(days: 1));
        return event.overlaps(tomorrow, tomorrow.add(const Duration(days: 1)));
      case 'This Weekend':
        // Saturday 00:00 to Monday 00:00 of the current week (or today if it is already the weekend).
        final daysToSaturday = (DateTime.saturday - today.weekday) % 7;
        final saturday = today.weekday == DateTime.sunday
            ? today.subtract(const Duration(days: 1))
            : today.add(Duration(days: daysToSaturday));
        return event.overlaps(saturday, saturday.add(const Duration(days: 2)));
      case 'This Week':
        return event.overlaps(today, today.add(const Duration(days: 7)));
      case 'Near Me':
        final city = _user?.city.trim().toLowerCase() ?? '';
        if (city.isEmpty) return true;
        return event.location.toLowerCase().contains(city) || event.venue.toLowerCase().contains(city);
      default:
        return true;
    }
  }

  List<Event> get filteredEvents {
    final now = DateTime.now();
    final query = _searchQuery.trim().toLowerCase();
    final result = _events.where((event) {
      final matchesSearch = query.isEmpty ||
          [event.title, event.category, event.venue, event.location, event.hostName, ...event.lineup]
              .any((field) => field.toLowerCase().contains(query));
      final matchesCategory = _categoryFilter == 'All' || event.category.toLowerCase() == _categoryFilter.toLowerCase();
      return matchesSearch && matchesCategory && _matchesDate(event, now) && (!_freeOnly || event.priceStarting == 0);
    }).toList();
    switch (_sort) {
      case EventSort.soonest:
        result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      case EventSort.priceLow:
        result.sort((a, b) => a.priceStarting.compareTo(b.priceStarting));
      case EventSort.priceHigh:
        result.sort((a, b) => b.priceStarting.compareTo(a.priceStarting));
      case EventSort.popular:
        result.sort((a, b) => b.goingCount.compareTo(a.goingCount));
      case EventSort.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Hosting
  // ---------------------------------------------------------------------------

  final List<Event> _hostedEvents = [];
  List<Event> get hostedEvents => List.unmodifiable(_hostedEvents);
  bool _hostedLoading = false;
  bool get hostedLoading => _hostedLoading;
  String? _hostedError;
  String? get hostedError => _hostedError;

  bool isHost(Event event) => _user != null && event.hostId == _user!.id;

  Future<void> loadHostedEvents() async {
    _hostedLoading = true;
    _notify();
    try {
      final events = await _authed(ApiService.getHostedEvents);
      _hostedEvents
        ..clear()
        ..addAll(events);
      _hostedError = null;
    } on ApiException catch (error) {
      _hostedError = error.message;
    } finally {
      _hostedLoading = false;
      _notify();
    }
  }

  Future<Event> createEvent(EventDraft draft, ImageUpload? image) async {
    final created = await _authed((token) => ApiService.createEvent(token, draft, image));
    _events
      ..add(created)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    _notify();
    unawaited(loadHostedEvents());
    return created;
  }

  Future<Event> updateEvent(String id, EventDraft draft, ImageUpload? image) async {
    final updated = await _authed((token) => ApiService.updateEvent(token, id, draft, image));
    final index = _events.indexWhere((event) => event.id == id);
    if (index != -1) _events[index] = updated;
    if (_activeEvent?.id == id) _activeEvent = updated;
    _notify();
    unawaited(loadHostedEvents());
    return updated;
  }

  Future<void> deleteEvent(String id) async {
    await _authed((token) => ApiService.deleteEvent(token, id));
    _events.removeWhere((event) => event.id == id);
    _hostedEvents.removeWhere((event) => event.id == id);
    _notify();
  }

  Future<List<Attendee>> loadAttendees(String eventId) => _authed((token) => ApiService.getAttendees(token, eventId));

  // ---------------------------------------------------------------------------
  // Ticket selection + checkout
  // ---------------------------------------------------------------------------

  Event? _activeEvent;
  Event? get activeEvent => _activeEvent;

  void setActiveEvent(Event event) {
    _activeEvent = event;
    _resetTicketSelection();
    _notify();
    unawaited(loadPaymentConfig());
  }

  final Map<String, int> _selectedTickets = {};
  Map<String, int> get selectedTickets => Map.unmodifiable(_selectedTickets);

  void updateTicketCount(String tierId, int delta) {
    final current = _selectedTickets[tierId] ?? 0;
    var capacity = 10;
    for (final category in _activeEvent?.ticketCategories ?? const <TicketCategory>[]) {
      if (category.id == tierId) {
        capacity = category.remaining < 10 ? category.remaining : 10;
        break;
      }
    }
    final next = (current + delta).clamp(0, capacity);
    if (next == 0) {
      _selectedTickets.remove(tierId);
    } else {
      _selectedTickets[tierId] = next;
    }
    _notify();
  }

  int get totalTicketsSelected => _selectedTickets.values.fold(0, (sum, qty) => sum + qty);

  double get ticketsSubtotal {
    var total = 0.0;
    for (final category in _activeEvent?.ticketCategories ?? const <TicketCategory>[]) {
      total += category.price * (_selectedTickets[category.id] ?? 0);
    }
    return total;
  }

  void _resetTicketSelection() {
    _selectedTickets.clear();
    _appliedPromoCode = '';
    _serverDiscount = null;
  }

  String _appliedPromoCode = '';
  String get appliedPromoCode => _appliedPromoCode;
  double? _serverDiscount;

  double get discountAmount {
    if (_appliedPromoCode.isEmpty) return 0;
    final subtotal = ticketsSubtotal;
    final discount = _serverDiscount ?? 200;
    return subtotal < discount ? subtotal : discount;
  }

  double get taxes => ((ticketsSubtotal - discountAmount) * 0.18 * 100).roundToDouble() / 100;
  double get grandTotal => ((ticketsSubtotal - discountAmount + taxes) * 100).roundToDouble() / 100;

  /// Asks the server to price the order with the promo code. Returns the discount, or throws.
  Future<double> applyPromoCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw const ApiException('Enter a promo code.');
    final event = _activeEvent;
    if (event == null || _selectedTickets.isEmpty) throw const ApiException('Select tickets first.');
    final response = await _authed((token) => ApiService.quote(token,
        eventId: event.id, quantities: Map.of(_selectedTickets), promoCode: normalized));
    final order = response['order'] as Map<String, dynamic>;
    final discount = (order['discount'] as num?)?.toDouble() ?? 0;
    if (discount <= 0) throw const ApiException('This promo code is not valid for this order.');
    _appliedPromoCode = normalized;
    _serverDiscount = discount;
    _notify();
    return discount;
  }

  void removePromoCode() {
    _appliedPromoCode = '';
    _serverDiscount = null;
    _notify();
  }

  Booking? _latestBooking;
  Booking? get latestBooking => _latestBooking;

  Future<CheckoutStart> startCheckout() async {
    final event = _activeEvent;
    if (event == null || _selectedTickets.isEmpty) {
      throw const ApiException('Select at least one ticket before continuing to checkout.');
    }
    final result = await _authed((token) => ApiService.startCheckout(token,
        eventId: event.id, quantities: Map.of(_selectedTickets), promoCode: _appliedPromoCode));
    if (result.booking != null) _recordBooking(result.booking!);
    return result;
  }

  bool _testPaymentsEnabled = false;
  bool get testPaymentsEnabled => _testPaymentsEnabled;

  Future<void> loadPaymentConfig() async {
    try {
      _testPaymentsEnabled = await ApiService.testPaymentsEnabled();
    } on ApiException {
      _testPaymentsEnabled = false;
    }
    _notify();
  }

  /// Books the selected tickets through the demo "test payment" route (no card is charged).
  Future<Booking> testCheckout() async {
    final event = _activeEvent;
    if (event == null || _selectedTickets.isEmpty) {
      throw const ApiException('Select at least one ticket before continuing to checkout.');
    }
    final booking = await _authed((token) => ApiService.testCheckout(token,
        eventId: event.id, quantities: Map.of(_selectedTickets), promoCode: _appliedPromoCode));
    _recordBooking(booking);
    return booking;
  }

  Future<CheckoutStatus> checkCheckout(String sessionId) async {
    final status = await _authed((token) => ApiService.checkoutStatus(token, sessionId));
    if (status.status == 'paid' && status.booking != null) _recordBooking(status.booking!);
    return status;
  }

  void _recordBooking(Booking booking) {
    _userBookings.removeWhere((existing) => existing.id == booking.id);
    _userBookings.insert(0, booking);
    _latestBooking = booking;
    _resetTicketSelection();
    _notify();
    unawaited(loadEvents()); // refresh remaining ticket counts
  }

  // ---------------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------------

  final List<Booking> _userBookings = [];
  List<Booking> get userBookings => List.unmodifiable(_userBookings);
  List<Booking> get upcomingBookings => _userBookings.where((b) => b.isUpcoming).toList()
    ..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
  List<Booking> get pastBookings => _userBookings.where((b) => b.isPast).toList();
  List<Booking> get cancelledBookings => _userBookings.where((b) => b.isCancelled).toList();

  bool _bookingsLoading = false;
  bool get bookingsLoading => _bookingsLoading;
  String? _bookingLoadError;
  String? get bookingLoadError => _bookingLoadError;

  Future<void> loadUserBookings() async {
    if (_authToken == null) return;
    _bookingsLoading = true;
    _notify();
    try {
      final bookings = await _authed(ApiService.getBookings);
      _userBookings
        ..clear()
        ..addAll(bookings);
      _bookingLoadError = null;
    } on ApiException catch (error) {
      _bookingLoadError = error.message;
    } finally {
      _bookingsLoading = false;
      _notify();
    }
  }

  Future<Booking> cancelBooking(String bookingId) async {
    final cancelled = await _authed((token) => ApiService.cancelBooking(token, bookingId));
    final index = _userBookings.indexWhere((booking) => booking.id == bookingId);
    if (index != -1) _userBookings[index] = cancelled;
    _notify();
    unawaited(loadEvents());
    return cancelled;
  }

  // ---------------------------------------------------------------------------
  // EventAI assistant (searches the live event catalogue)
  // ---------------------------------------------------------------------------

  final List<ChatMessage> _chatMessages = [];
  List<ChatMessage> get chatMessages {
    if (_chatMessages.isEmpty) {
      _chatMessages.add(ChatMessage(
        id: 'welcome',
        text:
            'Hello ${_user?.name.split(' ').first ?? 'there'}! I\'m your EventAI assistant. Ask me about events by city, category, budget or date, e.g. "music in Mumbai under ₹2000" or "free events this weekend".',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }
    return List.unmodifiable(_chatMessages);
  }

  void sendChatMessage(String userQuery) {
    final query = userQuery.trim();
    if (query.isEmpty) return;
    chatMessages; // ensure welcome message exists
    _chatMessages.add(ChatMessage(id: 'u-${DateTime.now().microsecondsSinceEpoch}', text: query, isUser: true, timestamp: DateTime.now()));
    _notify();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_disposed) return;
      final (text, results) = _answer(query.toLowerCase());
      _chatMessages.add(ChatMessage(
        id: 'a-${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        recommendedEvents: results,
      ));
      _notify();
    });
  }

  (String, List<Event>) _answer(String query) {
    if (_events.isEmpty) return ('I could not load any events yet. Pull to refresh on the Home screen and ask again.', const []);
    var results = List.of(_events);
    final reasons = <String>[];

    const synonyms = {
      'Festival': ['garba', 'dandiya', 'navratri', 'festival', 'fest'],
      'Music': ['music', 'concert', 'techno', 'edm', 'dj', 'gig', 'electronic'],
      'Networking': ['tech', 'summit', 'networking', 'conference', 'startup', 'business'],
      'Food': ['food', 'culinary', 'dinner', 'tasting', 'dining'],
      'Cultural': ['art', 'exhibition', 'culture', 'cultural', 'museum', 'gallery'],
      'Sports': ['sport', 'cricket', 'football', 'marathon', 'run'],
      'Comedy': ['comedy', 'standup', 'stand-up', 'funny'],
      'Workshop': ['workshop', 'class', 'learn', 'course'],
    };
    final matchedCategories = synonyms.entries
        .where((entry) => entry.value.any(query.contains) || query.contains(entry.key.toLowerCase()))
        .map((entry) => entry.key)
        .toSet();
    if (matchedCategories.isNotEmpty) {
      results = results.where((event) => matchedCategories.contains(event.category) ||
          (matchedCategories.contains('Festival') && event.isGarbaSpecial)).toList();
      reasons.add(matchedCategories.join(' / ').toLowerCase());
    }

    final cities = _events.map((event) => event.location.toLowerCase()).where((city) => city.isNotEmpty).toSet();
    final city = cities.where(query.contains).firstOrNull ??
        (query.contains('near me') && (_user?.city.isNotEmpty ?? false) ? _user!.city.toLowerCase() : null);
    if (city != null) {
      results = results.where((event) => event.location.toLowerCase().contains(city)).toList();
      reasons.add('in ${city[0].toUpperCase()}${city.substring(1)}');
    }

    final budget = RegExp(r'(?:under|below|less than|<|upto|up to)\s*(?:₹|rs\.?|inr)?\s*(\d[\d,]*)').firstMatch(query);
    if (budget != null) {
      final limit = double.parse(budget.group(1)!.replaceAll(',', ''));
      results = results.where((event) => event.priceStarting <= limit).toList();
      reasons.add('under ${formatPrice(limit)}');
    }
    if (query.contains('free')) {
      results = results.where((event) => event.priceStarting == 0).toList();
      reasons.add('free');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (query.contains('today') || query.contains('tonight')) {
      results = results.where((e) => e.overlaps(today, today.add(const Duration(days: 1)))).toList();
      reasons.add('today');
    } else if (query.contains('tomorrow')) {
      final tomorrow = today.add(const Duration(days: 1));
      results = results.where((e) => e.overlaps(tomorrow, tomorrow.add(const Duration(days: 1)))).toList();
      reasons.add('tomorrow');
    } else if (query.contains('weekend')) {
      final saturday = today.add(Duration(days: (DateTime.saturday - today.weekday) % 7));
      results = results.where((e) => e.overlaps(saturday, saturday.add(const Duration(days: 2)))).toList();
      reasons.add('this weekend');
    }

    if (reasons.isEmpty) {
      final words = query.split(RegExp(r'\s+')).where((word) => word.length > 3);
      final textMatches = _events.where((event) => words.any((word) =>
          '${event.title} ${event.description} ${event.venue}'.toLowerCase().contains(word))).toList();
      if (textMatches.isNotEmpty) {
        return ('Here is what I found for "$query":', textMatches.take(5).toList());
      }
      final picks = recommendedEvents.take(3).toList();
      return ('Here are my top picks for you based on your preferences:', picks);
    }

    results.sort((a, b) => matchScore(b).compareTo(matchScore(a)));
    if (results.isEmpty) {
      return ('I couldn\'t find events ${reasons.join(', ')} right now. Try widening your search, or check Explore for everything that\'s on.', const []);
    }
    return (
      'I found ${results.length} event${results.length == 1 ? '' : 's'} ${reasons.join(', ')}. ${results.first.title} looks like your best match (${matchScore(results.first)}%).',
      results.take(5).toList(),
    );
  }
}
