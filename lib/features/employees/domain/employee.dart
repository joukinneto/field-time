final class EmployeeAddress {
  const EmployeeAddress({
    this.street,
    this.city,
    this.state,
    this.zipCode,
    this.country,
  });

  final String? street;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? country;

  String get displayAddress => [
        street,
        city,
        state,
        zipCode,
      ].where((value) => value?.trim().isNotEmpty == true).join(', ');

  factory EmployeeAddress.fromJson(Map<String, dynamic>? json) =>
      EmployeeAddress(
        street: _nullableString(json?['street']),
        city: _nullableString(json?['city']),
        state: _nullableString(json?['state']),
        zipCode: _nullableString(json?['zip_code']),
        country: _nullableString(json?['country']),
      );

  Map<String, dynamic> toJson() => {
        'street': street,
        'city': city,
        'state': state,
        'zip_code': zipCode,
        'country': country,
      };
}

final class EmployeeEmergencyContact {
  const EmployeeEmergencyContact({this.name, this.phone});

  final String? name;
  final String? phone;

  factory EmployeeEmergencyContact.fromJson(Map<String, dynamic>? json) =>
      EmployeeEmergencyContact(
        name: _nullableString(json?['name']),
        phone: _nullableString(json?['phone']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
      };
}

final class Employee {
  const Employee({
    required this.employeeId,
    required this.fullName,
    required this.company,
    required this.status,
    required this.active,
    this.id = '',
    this.registrationNumber = '',
    this.preferredName,
    this.photo,
    this.phone,
    this.email,
    this.category,
    this.employmentType,
    this.role,
    this.specialty,
    this.admissionDate,
    this.preferredLanguage,
    this.supervisor,
    this.defaultStartTime,
    this.defaultEndTime,
    this.allowedJobs = const [],
    this.address = const EmployeeAddress(),
    this.emergencyContact = const EmployeeEmergencyContact(),
    this.notes,
  });

  final String id;
  final String registrationNumber;
  final String employeeId;
  final String fullName;
  final String? preferredName;
  final String? photo;
  final String? phone;
  final String? email;
  final String company;
  final String? category;
  final String? employmentType;
  final String? role;
  final String? specialty;
  final String? admissionDate;
  final String status;
  final String? preferredLanguage;
  final String? supervisor;
  final String? defaultStartTime;
  final String? defaultEndTime;
  final List<String> allowedJobs;
  final EmployeeAddress address;
  final EmployeeEmergencyContact emergencyContact;
  final String? notes;
  final bool active;

  String get displayName => preferredName?.trim().isNotEmpty == true
      ? preferredName!.trim()
      : fullName;
  String get searchableText => [
        id,
        registrationNumber,
        employeeId,
        fullName,
        preferredName,
        company,
        category,
        role,
        supervisor,
      ].whereType<String>().join(' ').toLowerCase();

  Employee copyWith({
    String? id,
    String? registrationNumber,
    String? employeeId,
    String? fullName,
    String? preferredName,
    String? photo,
    String? phone,
    String? email,
    String? company,
    String? category,
    String? employmentType,
    String? role,
    String? specialty,
    String? admissionDate,
    String? status,
    String? preferredLanguage,
    String? supervisor,
    String? defaultStartTime,
    String? defaultEndTime,
    List<String>? allowedJobs,
    EmployeeAddress? address,
    EmployeeEmergencyContact? emergencyContact,
    String? notes,
    bool? active,
  }) =>
      Employee(
        id: id ?? this.id,
        registrationNumber: registrationNumber ?? this.registrationNumber,
        employeeId: employeeId ?? this.employeeId,
        fullName: fullName ?? this.fullName,
        preferredName: preferredName ?? this.preferredName,
        photo: photo ?? this.photo,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        company: company ?? this.company,
        category: category ?? this.category,
        employmentType: employmentType ?? this.employmentType,
        role: role ?? this.role,
        specialty: specialty ?? this.specialty,
        admissionDate: admissionDate ?? this.admissionDate,
        status: status ?? this.status,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        supervisor: supervisor ?? this.supervisor,
        defaultStartTime: defaultStartTime ?? this.defaultStartTime,
        defaultEndTime: defaultEndTime ?? this.defaultEndTime,
        allowedJobs: allowedJobs ?? this.allowedJobs,
        address: address ?? this.address,
        emergencyContact: emergencyContact ?? this.emergencyContact,
        notes: notes ?? this.notes,
        active: active ?? this.active,
      );

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: _string(json['id']),
        registrationNumber: _string(json['registration_number'],
            fallback: _string(json['employee_id'])),
        employeeId: _string(json['employee_id']),
        fullName: _string(json['full_name']),
        preferredName: _nullableString(json['preferred_name']),
        photo: _nullableString(json['photo']),
        phone: _nullableString(json['phone']),
        email: _nullableString(json['email']),
        company: _string(json['company']),
        category: _nullableString(json['category']),
        employmentType: _nullableString(json['employment_type']),
        role: _nullableString(json['role']),
        specialty: _nullableString(json['specialty']),
        admissionDate: _nullableString(json['admission_date']),
        status: _string(json['status'], fallback: 'active'),
        preferredLanguage: _nullableString(json['preferred_language']),
        supervisor: _nullableString(json['supervisor']),
        defaultStartTime: _nullableString(json['default_start_time']),
        defaultEndTime: _nullableString(json['default_end_time']),
        allowedJobs: (json['allowed_jobs'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        address: EmployeeAddress.fromJson(
          json['address'] is Map<String, dynamic>
              ? json['address'] as Map<String, dynamic>
              : null,
        ),
        emergencyContact: EmployeeEmergencyContact.fromJson(
          json['emergency_contact'] is Map<String, dynamic>
              ? json['emergency_contact'] as Map<String, dynamic>
              : null,
        ),
        notes: _nullableString(json['notes']),
        active: json['active'] as bool? ??
            _string(json['status'], fallback: 'active').toLowerCase() ==
                'active',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'registration_number': registrationNumber,
        'employee_id': employeeId,
        'full_name': fullName,
        'preferred_name': preferredName,
        'photo': photo,
        'phone': phone,
        'email': email,
        'company': company,
        'category': category,
        'employment_type': employmentType,
        'role': role,
        'specialty': specialty,
        'admission_date': admissionDate,
        'status': status,
        'preferred_language': preferredLanguage,
        'supervisor': supervisor,
        'default_start_time': defaultStartTime,
        'default_end_time': defaultEndTime,
        'allowed_jobs': allowedJobs,
        'address': address.toJson(),
        'emergency_contact': emergencyContact.toJson(),
        'notes': notes,
        'active': active,
      };
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
