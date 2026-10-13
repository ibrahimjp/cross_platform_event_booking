import 'package:intl/intl.dart';

DateTime _date(Object? value, [DateTime? fallback]) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal() ?? (fallback ?? DateTime.now());
  }
  return fallback ?? DateTime.now();
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

double _num(Object? value) => value is num ? value.toDouble() : 0;
int _int(Object? value) => value is num ? value.toInt() : 0;

String formatPrice(double value) {
  if (value == 0) return 'Free';
  final hasPaise = value != value.roundToDouble();
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: hasPaise ? 2 : 0).format(value);
}

String formatAmount(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(value);

class TicketCategory {
  final String id;
  final String name;
  final double price;
  final String description;
  final int remaining;

  const TicketCategory({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.remaining,
  });

  factory TicketCategory.fromJson(Map<String, dynamic> json) => TicketCategory(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Ticket',
        price: _num(json['price']),
        description: json['description'] as String? ?? '',
        remaining: _int(json['remaining']),
      );

  Map<String, Object> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'price': price,
        'description': description,
        'remaining': remaining,
      };
}

class HostStats {
  final int ticketsSold;
  final int bookings;
  final double revenue;

  const HostStats({this.ticketsSold = 0, this.bookings = 0, this.revenue = 0});

  factory HostStats.fromJson(Map<String, dynamic>? json) => HostStats(
        ticketsSold: _int(json?['ticketsSold']),
        bookings: _int(json?['bookings']),
        revenue: _num(json?['revenue']),
      );
}

class Event {
  final String id;
  final String title;
  final String category;
  final DateTime startsAt;
  final DateTime endsAt;
  final String time;
  final String location;
  final String venue;
  final double priceStarting;
  final String imageUrl;
  final String description;
  final List<String> lineup;
  final List<TicketCategory> ticketCategories;
  final int matchPercentage;
  final String aiReason;
  final bool isGarbaSpecial;
  final bool isTrending;
  final int attendeeCount;
  final int ticketsSold;
  final String hostId;
  final String hostName;
  final DateTime createdAt;
  final HostStats? stats;

  Event({
    required this.id,
    required this.title,
    required this.category,
    required this.startsAt,
    required this.endsAt,
    required this.time,
    required this.location,
    required this.venue,
    required this.priceStarting,
    required this.imageUrl,
    required this.description,
    required this.lineup,
    required this.ticketCategories,
    this.matchPercentage = 90,
    this.aiReason = '',
    this.isGarbaSpecial = false,
    this.isTrending = false,
    this.attendeeCount = 0,
    this.ticketsSold = 0,
    this.hostId = '',
    this.hostName = '',
    DateTime? createdAt,
    this.stats,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Event.fromJson(Map<String, dynamic> json) {
    final tickets = (json['ticketCategories'] as List<dynamic>? ?? const [])
        .map((ticket) => TicketCategory.fromJson(ticket as Map<String, dynamic>))
        .toList();
    final startsAt = _date(json['startsAt']);
    final host = json['host'] as Map<String, dynamic>?;
    final hostId = json['hostId'];
    return Event(
      id: (json['_id'] ?? json['id']).toString(),
      title: json['title'] as String? ?? 'Untitled event',
      category: json['category'] as String? ?? 'Other',
      startsAt: startsAt,
      endsAt: _date(json['endsAt'], startsAt.add(const Duration(hours: 3))),
      time: json['time'] as String? ?? DateFormat.jm().format(startsAt),
      location: json['location'] as String? ?? '',
      venue: json['venue'] as String? ?? '',
      priceStarting: json['priceStarting'] is num
          ? _num(json['priceStarting'])
          : (tickets.isEmpty ? 0 : tickets.map((ticket) => ticket.price).reduce((a, b) => a < b ? a : b)),
      imageUrl: json['imageUrl'] as String? ?? '',
      description: json['description'] as String? ?? '',
      lineup: (json['lineup'] as List<dynamic>? ?? const []).map((item) => item.toString()).toList(),
      ticketCategories: tickets,
      matchPercentage: json['matchPercentage'] is num ? _int(json['matchPercentage']) : 90,
      aiReason: json['aiReason'] as String? ?? '',
      isGarbaSpecial: json['isGarbaSpecial'] == true,
      isTrending: json['isTrending'] == true,
      attendeeCount: _int(json['attendeeCount']),
      ticketsSold: _int(json['ticketsSold']),
      hostId: host?['id']?.toString() ?? (hostId is Map ? hostId['_id'].toString() : hostId?.toString() ?? ''),
      hostName: host?['name'] as String? ?? '',
      createdAt: _date(json['createdAt']),
      stats: json['stats'] is Map<String, dynamic> ? HostStats.fromJson(json['stats'] as Map<String, dynamic>) : null,
    );
  }

  bool get isMultiDay => !isSameDay(startsAt, endsAt) && endsAt.difference(startsAt).inHours >= 24;

  String get dateLabel {
    final now = DateTime.now();
    if (isMultiDay) {
      if (startsAt.isBefore(now) && endsAt.isAfter(now)) {
        return 'Ongoing until ${DateFormat('MMM d').format(endsAt)}';
      }
      return '${DateFormat('MMM d').format(startsAt)} - ${DateFormat('MMM d').format(endsAt)}';
    }
    if (isSameDay(startsAt, now)) return 'Today, ${DateFormat('MMM d').format(startsAt)}';
    if (isSameDay(startsAt, now.add(const Duration(days: 1)))) {
      return 'Tomorrow, ${DateFormat('MMM d').format(startsAt)}';
    }
    return DateFormat('EEE, MMM d').format(startsAt);
  }

  String get fullDateLabel => isMultiDay
      ? '${DateFormat('EEE, MMM d').format(startsAt)} - ${DateFormat('EEE, MMM d, y').format(endsAt)}'
      : DateFormat('EEEE, MMM d, y').format(startsAt);

  bool get hasEnded => endsAt.isBefore(DateTime.now());
  int get totalRemaining => ticketCategories.fold(0, (sum, ticket) => sum + ticket.remaining);
  bool get isSoldOut => ticketCategories.isNotEmpty && totalRemaining == 0;
  int get goingCount => attendeeCount + ticketsSold;

  /// True if the event runs at any point inside [from, to).
  bool overlaps(DateTime from, DateTime to) => startsAt.isBefore(to) && endsAt.isAfter(from);
}


class BookingLine {
  final String categoryId;
  final String name;
  final double price;
  final int quantity;

  const BookingLine({required this.categoryId, required this.name, required this.price, required this.quantity});

  factory BookingLine.fromJson(Map<String, dynamic> json) => BookingLine(
        categoryId: json['categoryId'] as String? ?? '',
        name: json['name'] as String? ?? 'Ticket',
        price: _num(json['price']),
        quantity: _int(json['quantity']),
      );
}

class Booking {
  final String id;
  final Event event;
  final List<BookingLine> lines;
  final double subtotal;
  final double discount;
  final double taxesAndFees;
  final double totalPaid;
  final DateTime bookingDate;
  final String status;
  final bool testPayment;

  Booking({
    required this.id,
    required this.event,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.taxesAndFees,
    required this.totalPaid,
    required this.bookingDate,
    required this.status,
    this.testPayment = false,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final eventJson = json['eventId'] as Map<String, dynamic>;
    return Booking(
      id: json['_id'].toString(),
      event: Event.fromJson(eventJson),
      lines: (json['tickets'] as List<dynamic>? ?? const [])
          .map((line) => BookingLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      subtotal: _num(json['subtotal']),
      discount: _num(json['discount']),
      taxesAndFees: _num(json['taxesAndFees']),
      totalPaid: _num(json['totalPaid']),
      bookingDate: _date(json['createdAt']),
      status: json['status'] as String? ?? 'Confirmed',
      testPayment: json['testPayment'] == true,
    );
  }

  String get bookingRef => '#EB-${id.substring(id.length - 8).toUpperCase()}';
  String get qrData => 'EVENTBOOK-PASS-$id';
  int get ticketCount => lines.fold(0, (sum, line) => sum + line.quantity);
  bool get isCancelled => status == 'Cancelled';
  bool get isPast => !isCancelled && event.hasEnded;
  bool get isUpcoming => !isCancelled && !event.hasEnded;
  String get ticketSummary => lines.map((line) => '${line.quantity} × ${line.name}').join(', ');
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String avatarUrl;
  final Set<String> wishlist;
  final List<String> preferredCategories;
  final bool notificationsEnabled;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.city = '',
    this.avatarUrl = '',
    this.wishlist = const {},
    this.preferredCategories = const [],
    this.notificationsEnabled = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        city: json['city'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String? ?? '',
        wishlist: (json['wishlist'] as List<dynamic>? ?? const []).map((id) => id.toString()).toSet(),
        preferredCategories:
            (json['preferredCategories'] as List<dynamic>? ?? const []).map((item) => item.toString()).toList(),
        notificationsEnabled: json['notificationsEnabled'] != false,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'city': city,
        'avatarUrl': avatarUrl,
        'wishlist': wishlist.toList(),
        'preferredCategories': preferredCategories,
        'notificationsEnabled': notificationsEnabled,
      };

  AppUser copyWith({Set<String>? wishlist}) => AppUser(
        id: id,
        name: name,
        email: email,
        phone: phone,
        city: city,
        avatarUrl: avatarUrl,
        wishlist: wishlist ?? this.wishlist,
        preferredCategories: preferredCategories,
        notificationsEnabled: notificationsEnabled,
      );

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class Attendee {
  final String bookingId;
  final String name;
  final String email;
  final String avatarUrl;
  final String status;
  final double totalPaid;
  final List<BookingLine> lines;
  final DateTime createdAt;

  const Attendee({
    required this.bookingId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.status,
    required this.totalPaid,
    required this.lines,
    required this.createdAt,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    final attendee = json['attendee'] as Map<String, dynamic>? ?? const {};
    return Attendee(
      bookingId: json['_id'].toString(),
      name: attendee['name'] as String? ?? '',
      email: attendee['email'] as String? ?? '',
      avatarUrl: attendee['avatarUrl'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalPaid: _num(json['totalPaid']),
      lines: (json['tickets'] as List<dynamic>? ?? const [])
          .map((line) => BookingLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      createdAt: _date(json['createdAt']),
    );
  }

  int get ticketCount => lines.fold(0, (sum, line) => sum + line.quantity);
}

class SavedCard {
  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;

  const SavedCard({required this.id, required this.brand, required this.last4, required this.expMonth, required this.expYear});

  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
        id: json['id'] as String,
        brand: json['brand'] as String? ?? 'card',
        last4: json['last4'] as String? ?? '****',
        expMonth: _int(json['expMonth']),
        expYear: _int(json['expYear']),
      );
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Event> recommendedEvents;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.recommendedEvents = const [],
  });
}

/// Image chosen by the user, uploaded to the backend (which stores it on Cloudinary).
class ImageUpload {
  final List<int> bytes;
  final String filename;

  const ImageUpload({required this.bytes, required this.filename});
}

/// Fields the host fills in when creating or editing an event.
class EventDraft {
  final String title;
  final String category;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String time;
  final String location;
  final String venue;
  final String description;
  final List<String> lineup;
  final List<TicketCategory> ticketCategories;
  final bool removeImage;

  const EventDraft({
    required this.title,
    required this.category,
    required this.startsAt,
    required this.endsAt,
    required this.time,
    required this.location,
    required this.venue,
    required this.description,
    required this.lineup,
    required this.ticketCategories,
    this.removeImage = false,
  });

  Map<String, Object?> toJson() => {
        'title': title,
        'category': category,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt?.toUtc().toIso8601String(),
        'time': time,
        'location': location,
        'venue': venue,
        'description': description,
        'lineup': lineup,
        'ticketCategories': ticketCategories.map((ticket) => ticket.toJson()).toList(),
        'removeImage': removeImage,
      };
}

/// Result of starting checkout: either a confirmed free booking or a Stripe Checkout page to open.
class CheckoutStart {
  final Booking? booking;
  final String? sessionId;
  final String? url;

  const CheckoutStart({this.booking, this.sessionId, this.url});
}

class CheckoutStatus {
  final String status; // pending | paid | expired | refunded | failed | invalid
  final String? message;
  final Booking? booking;

  const CheckoutStatus({required this.status, this.message, this.booking});

  bool get isFinal => status != 'pending';
}

const eventCategories = ['Music', 'Festival', 'Networking', 'Food', 'Cultural', 'Sports', 'Comedy', 'Workshop'];
