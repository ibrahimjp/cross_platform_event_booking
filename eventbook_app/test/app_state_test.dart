import 'package:eventbook_app/models/models.dart';
import 'package:eventbook_app/providers/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Event _event({
  required String id,
  required DateTime startsAt,
  DateTime? endsAt,
  String category = 'Music',
  double price = 1000,
  String location = 'Mumbai',
  int remaining = 50,
}) {
  return Event(
    id: id,
    title: 'Event $id',
    category: category,
    startsAt: startsAt,
    endsAt: endsAt ?? startsAt.add(const Duration(hours: 3)),
    time: '7:00 PM',
    location: location,
    venue: 'Venue $id',
    priceStarting: price,
    imageUrl: '',
    description: 'A great event for everyone.',
    lineup: const [],
    ticketCategories: [TicketCategory(id: 't-$id', name: 'General', price: price, description: '', remaining: remaining)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ticket selection respects the per-order limit and remaining stock', () {
    final state = AppState(autoInit: false);
    final event = _event(id: '1', startsAt: DateTime.now().add(const Duration(days: 2)), remaining: 4);
    state.setActiveEvent(event);

    state.updateTicketCount('t-1', 99);
    expect(state.selectedTickets['t-1'], 4);
    expect(state.ticketsSubtotal, 4000);
    expect(state.taxes, 720);
    expect(state.grandTotal, 4720);

    state.updateTicketCount('t-1', -4);
    expect(state.totalTicketsSelected, 0);
    state.dispose();
  });

  test('event JSON from the API is parsed with real dates and host info', () {
    final event = Event.fromJson({
      '_id': 'abc',
      'title': 'Sunburn',
      'category': 'Music',
      'startsAt': '2030-01-01T14:30:00.000Z',
      'endsAt': '2030-01-01T21:30:00.000Z',
      'time': '8:00 PM - 3:00 AM',
      'location': 'Mumbai',
      'venue': 'Dome',
      'priceStarting': 1499,
      'description': 'desc',
      'ticketCategories': [
        {'id': 'tc-1', 'name': 'GA', 'price': 1499, 'remaining': 0},
      ],
      'host': {'id': 'h1', 'name': 'Host'},
      'hostId': 'h1',
    });
    expect(event.startsAt.toUtc(), DateTime.utc(2030, 1, 1, 14, 30));
    expect(event.hostName, 'Host');
    expect(event.isSoldOut, isTrue);
    expect(formatPrice(event.priceStarting), '₹1,499');
  });

  test('date filters match events by real dates', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEvent = _event(id: 'today', startsAt: today.add(const Duration(hours: 23)));
    final tomorrowEvent = _event(id: 'tomorrow', startsAt: today.add(const Duration(days: 1, hours: 12)));
    final ongoing = _event(id: 'ongoing', startsAt: today.subtract(const Duration(days: 3)), endsAt: today.add(const Duration(days: 10)));

    expect(todayEvent.overlaps(today, today.add(const Duration(days: 1))), isTrue);
    expect(tomorrowEvent.overlaps(today, today.add(const Duration(days: 1))), isFalse);
    expect(ongoing.overlaps(today.add(const Duration(days: 1)), today.add(const Duration(days: 2))), isTrue);
  });

  test('bookings parse ticket lines and derive status tabs', () {
    final booking = Booking.fromJson({
      '_id': '6acdcd1ad51547729aa98e02',
      'eventId': {
        '_id': 'e1',
        'title': 'Past show',
        'category': 'Music',
        'startsAt': '2020-01-01T10:00:00.000Z',
        'endsAt': '2020-01-01T12:00:00.000Z',
        'ticketCategories': [],
      },
      'tickets': [
        {'categoryId': 'a', 'name': 'GA', 'price': 100, 'quantity': 2},
      ],
      'subtotal': 200,
      'discount': 0,
      'taxesAndFees': 36,
      'totalPaid': 236,
      'status': 'Confirmed',
      'createdAt': '2019-12-01T10:00:00.000Z',
    });
    expect(booking.ticketCount, 2);
    expect(booking.isPast, isTrue);
    expect(booking.isUpcoming, isFalse);
    expect(booking.bookingRef, '#EB-9AA98E02');
  });

  test('user initial is used when there is no profile photo', () {
    const user = AppUser(id: '1', name: 'amit pamnani', email: 'a@b.co');
    expect(user.initial, 'A');
    expect(user.avatarUrl, isEmpty);
  });
}
