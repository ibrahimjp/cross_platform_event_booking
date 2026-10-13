typedef Json = Map<String, dynamic>;

double _num(Object? value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String _str(Object? value) => value?.toString() ?? '';
DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
List<String> _strings(Object? value) => value is List ? value.map((e) => e.toString()).toList() : <String>[];

class UserStats {
  UserStats({required this.bookings, required this.totalSpent, required this.eventsHosted});

  factory UserStats.fromJson(Json? json) => UserStats(
    bookings: _int(json?['bookings']),
    totalSpent: _num(json?['totalSpent']),
    eventsHosted: _int(json?['eventsHosted']),
  );

  final int bookings;
  final double totalSpent;
  final int eventsHosted;
}

class AdminUser {
  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.avatarUrl,
    required this.role,
    required this.isBlocked,
    required this.blockedReason,
    required this.preferredCategories,
    required this.notificationsEnabled,
    required this.wishlistCount,
    required this.hasStripeCustomer,
    required this.lastLoginAt,
    required this.createdAt,
    required this.stats,
  });

  factory AdminUser.fromJson(Json json) => AdminUser(
    id: _str(json['id']),
    name: _str(json['name']),
    email: _str(json['email']),
    phone: _str(json['phone']),
    city: _str(json['city']),
    avatarUrl: _str(json['avatarUrl']),
    role: _str(json['role']).isEmpty ? 'user' : _str(json['role']),
    isBlocked: json['isBlocked'] == true,
    blockedReason: _str(json['blockedReason']),
    preferredCategories: _strings(json['preferredCategories']),
    notificationsEnabled: json['notificationsEnabled'] != false,
    wishlistCount: _int(json['wishlistCount']),
    hasStripeCustomer: json['hasStripeCustomer'] == true,
    lastLoginAt: _date(json['lastLoginAt']),
    createdAt: _date(json['createdAt']),
    stats: json['stats'] is Map ? UserStats.fromJson(json['stats']) : null,
  );

  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String avatarUrl;
  final String role;
  final bool isBlocked;
  final String blockedReason;
  final List<String> preferredCategories;
  final bool notificationsEnabled;
  final int wishlistCount;
  final bool hasStripeCustomer;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final UserStats? stats;

  bool get isAdmin => role == 'admin';
}

class TicketCategory {
  TicketCategory({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.remaining,
  });

  factory TicketCategory.fromJson(Json json) => TicketCategory(
    id: _str(json['id']),
    name: _str(json['name']),
    price: _num(json['price']),
    description: _str(json['description']),
    remaining: _int(json['remaining']),
  );

  final String id;
  final String name;
  final double price;
  final String description;
  final int remaining;

  Json toJson() => {
    if (id.isNotEmpty) 'id': id,
    'name': name,
    'price': price,
    'description': description,
    'remaining': remaining,
  };
}

class EventStats {
  EventStats({required this.bookings, required this.ticketsSold, required this.revenue, this.wishlisted = 0});

  factory EventStats.fromJson(Json? json) => EventStats(
    bookings: _int(json?['bookings']),
    ticketsSold: _int(json?['ticketsSold']),
    revenue: _num(json?['revenue']),
    wishlisted: _int(json?['wishlisted']),
  );

  final int bookings;
  final int ticketsSold;
  final double revenue;
  final int wishlisted;
}

class AdminEvent {
  AdminEvent({
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
    required this.matchPercentage,
    required this.aiReason,
    required this.isGarbaSpecial,
    required this.isTrending,
    required this.isHidden,
    required this.attendeeCount,
    required this.hostId,
    required this.hostName,
    required this.stats,
  });

  factory AdminEvent.fromJson(Json json) {
    final host = json['host'];
    return AdminEvent(
      id: _str(json['_id']),
      title: _str(json['title']),
      category: _str(json['category']),
      startsAt: _date(json['startsAt']) ?? DateTime.now(),
      endsAt: _date(json['endsAt']) ?? DateTime.now(),
      time: _str(json['time']),
      location: _str(json['location']),
      venue: _str(json['venue']),
      priceStarting: _num(json['priceStarting']),
      imageUrl: _str(json['imageUrl']),
      description: _str(json['description']),
      lineup: _strings(json['lineup']),
      ticketCategories: (json['ticketCategories'] as List? ?? const [])
          .map((ticket) => TicketCategory.fromJson(ticket as Json))
          .toList(),
      matchPercentage: _int(json['matchPercentage']),
      aiReason: _str(json['aiReason']),
      isGarbaSpecial: json['isGarbaSpecial'] == true,
      isTrending: json['isTrending'] == true,
      isHidden: json['isHidden'] == true,
      attendeeCount: _int(json['attendeeCount']),
      hostId: _str(json['hostId']),
      hostName: host is Map ? _str(host['name']) : '',
      stats: json['stats'] is Map ? EventStats.fromJson(json['stats']) : null,
    );
  }

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
  final bool isHidden;
  final int attendeeCount;
  final String hostId;
  final String hostName;
  final EventStats? stats;

  bool get isPast => endsAt.isBefore(DateTime.now());
  int get remainingTickets => ticketCategories.fold(0, (sum, ticket) => sum + ticket.remaining);
}

class BookingLine {
  BookingLine({required this.categoryId, required this.name, required this.price, required this.quantity});

  factory BookingLine.fromJson(Json json) => BookingLine(
    categoryId: _str(json['categoryId']),
    name: _str(json['name']),
    price: _num(json['price']),
    quantity: _int(json['quantity']),
  );

  final String categoryId;
  final String name;
  final double price;
  final int quantity;
}

class Booking {
  Booking({
    required this.id,
    required this.status,
    required this.lines,
    required this.ticketCount,
    required this.subtotal,
    required this.discount,
    required this.taxesAndFees,
    required this.totalPaid,
    required this.promoCode,
    required this.paymentIntentId,
    required this.refunded,
    required this.cancelledAt,
    required this.cancelledBy,
    required this.cancelReason,
    required this.issuedByAdmin,
    required this.adminNote,
    required this.createdAt,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userAvatar,
    required this.eventId,
    required this.eventTitle,
    required this.eventStartsAt,
    required this.eventImage,
  });

  factory Booking.fromJson(Json json) {
    final user = json['user'] as Json?;
    final event = json['event'] as Json?;
    return Booking(
      id: _str(json['_id']),
      status: _str(json['status']),
      lines: (json['tickets'] as List? ?? const []).map((line) => BookingLine.fromJson(line as Json)).toList(),
      ticketCount: _int(json['ticketCount']),
      subtotal: _num(json['subtotal']),
      discount: _num(json['discount']),
      taxesAndFees: _num(json['taxesAndFees']),
      totalPaid: _num(json['totalPaid']),
      promoCode: _str(json['promoCode']),
      paymentIntentId: _str(json['paymentIntentId']),
      refunded: json['refunded'] == true,
      cancelledAt: _date(json['cancelledAt']),
      cancelledBy: json['cancelledBy']?.toString(),
      cancelReason: _str(json['cancelReason']),
      issuedByAdmin: json['issuedByAdmin'] == true,
      adminNote: _str(json['adminNote']),
      createdAt: _date(json['createdAt']),
      userId: _str(json['userId']),
      userName: user == null ? 'Deleted user' : _str(user['name']),
      userEmail: user == null ? '' : _str(user['email']),
      userAvatar: user == null ? '' : _str(user['avatarUrl']),
      eventId: _str(json['eventId']),
      eventTitle: event == null ? 'Deleted event' : _str(event['title']),
      eventStartsAt: event == null ? null : _date(event['startsAt']),
      eventImage: event == null ? '' : _str(event['imageUrl']),
    );
  }

  final String id;
  final String status;
  final List<BookingLine> lines;
  final int ticketCount;
  final double subtotal;
  final double discount;
  final double taxesAndFees;
  final double totalPaid;
  final String promoCode;
  final String paymentIntentId;
  final bool refunded;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String cancelReason;
  final bool issuedByAdmin;
  final String adminNote;
  final DateTime? createdAt;
  final String userId;
  final String userName;
  final String userEmail;
  final String userAvatar;
  final String eventId;
  final String eventTitle;
  final DateTime? eventStartsAt;
  final String eventImage;

  bool get isCancelled => status == 'Cancelled';
  String get shortId => id.length > 8 ? id.substring(id.length - 8).toUpperCase() : id.toUpperCase();
}

class Promo {
  Promo({
    required this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.value,
    required this.maxDiscount,
    required this.minSubtotal,
    required this.maxUses,
    required this.uses,
    required this.active,
    required this.expiresAt,
    required this.totalDiscount,
    required this.revenue,
  });

  factory Promo.fromJson(Json json) => Promo(
    id: _str(json['id']),
    code: _str(json['code']),
    description: _str(json['description']),
    type: _str(json['type']),
    value: _num(json['value']),
    maxDiscount: _num(json['maxDiscount']),
    minSubtotal: _num(json['minSubtotal']),
    maxUses: _int(json['maxUses']),
    uses: _int(json['uses']),
    active: json['active'] == true,
    expiresAt: _date(json['expiresAt']),
    totalDiscount: _num(json['totalDiscount']),
    revenue: _num(json['revenue']),
  );

  final String id;
  final String code;
  final String description;
  final String type;
  final double value;
  final double maxDiscount;
  final double minSubtotal;
  final int maxUses;
  final int uses;
  final bool active;
  final DateTime? expiresAt;
  final double totalDiscount;
  final double revenue;

  bool get isPercent => type == 'percent';
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isExhausted => maxUses > 0 && uses >= maxUses;
  bool get isLive => active && !isExpired && !isExhausted;

  Json toJson() => {
    'code': code,
    'description': description,
    'type': type,
    'value': value,
    'maxDiscount': maxDiscount,
    'minSubtotal': minSubtotal,
    'maxUses': maxUses,
    'active': active,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };
}

class PlatformSettings {
  PlatformSettings({required this.categories, required this.salesPaused, required this.registrationsOpen});

  factory PlatformSettings.fromJson(Json? json) => PlatformSettings(
    categories: _strings(json?['categories']),
    salesPaused: json?['salesPaused'] == true,
    registrationsOpen: json?['registrationsOpen'] != false,
  );

  final List<String> categories;
  final bool salesPaused;
  final bool registrationsOpen;
}

class AdminLogEntry {
  AdminLogEntry({
    required this.id,
    required this.adminName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.summary,
    required this.createdAt,
  });

  factory AdminLogEntry.fromJson(Json json) => AdminLogEntry(
    id: _str(json['id']),
    adminName: _str(json['adminName']),
    action: _str(json['action']),
    targetType: _str(json['targetType']),
    targetId: _str(json['targetId']),
    summary: _str(json['summary']),
    createdAt: _date(json['createdAt']),
  );

  final String id;
  final String adminName;
  final String action;
  final String targetType;
  final String targetId;
  final String summary;
  final DateTime? createdAt;
}

/// A page of results from a paginated admin endpoint.
class Paged<T> {
  Paged({required this.items, required this.total, required this.page, required this.pages});

  factory Paged.fromJson(Json json, String key, T Function(Json) parse) => Paged(
    items: (json[key] as List? ?? const []).map((item) => parse(item as Json)).toList(),
    total: _int(json['total']),
    page: _int(json['page']),
    pages: _int(json['pages']),
  );

  final List<T> items;
  final int total;
  final int page;
  final int pages;
}

double asDouble(Object? value) => _num(value);
int asInt(Object? value) => _int(value);
DateTime? asDate(Object? value) => _date(value);
