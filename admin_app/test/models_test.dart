import 'package:eventbook_admin/core/format.dart';
import 'package:eventbook_admin/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses an admin booking with deleted user and event', () {
    final booking = Booking.fromJson({
      '_id': '6acdd1177f86e57a5e154905',
      'status': 'Cancelled',
      'tickets': [
        {'categoryId': 'tc-1', 'name': 'VIP', 'price': 3499, 'quantity': 2},
      ],
      'ticketCount': 2,
      'subtotal': 6998,
      'discount': 0,
      'taxesAndFees': 1259.64,
      'totalPaid': 8257.64,
      'refunded': true,
      'user': null,
      'event': null,
    });
    expect(booking.isCancelled, isTrue);
    expect(booking.userName, 'Deleted user');
    expect(booking.eventTitle, 'Deleted event');
    expect(booking.shortId, '5E154905');
    expect(booking.lines.single.quantity, 2);
  });

  test('promo availability reflects expiry and usage limits', () {
    Promo promo({bool active = true, int uses = 0, int maxUses = 0, DateTime? expiresAt}) => Promo.fromJson({
      'id': '1',
      'code': 'DIWALI25',
      'type': 'percent',
      'value': 25,
      'active': active,
      'uses': uses,
      'maxUses': maxUses,
      'expiresAt': expiresAt?.toIso8601String(),
    });
    expect(promo().isLive, isTrue);
    expect(promo(active: false).isLive, isFalse);
    expect(promo(uses: 5, maxUses: 5).isExhausted, isTrue);
    expect(promo(expiresAt: DateTime.now().subtract(const Duration(days: 1))).isExpired, isTrue);
    expect(promo().toJson()['code'], 'DIWALI25');
  });

  test('formats Indian currency and initials', () {
    expect(money(1499), '₹1,499');
    expect(money(150000), '₹1,50,000');
    expect(initials('Priya Shah'), 'PS');
    expect(initials(''), '?');
  });
}
