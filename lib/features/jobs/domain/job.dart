final class Job {
  const Job({
    required this.jobId,
    required this.jobNumber,
    required this.jobName,
    required this.fullAddress,
    required this.status,
    this.address,
    this.city,
    this.county,
    this.state,
    this.zipCode,
    this.country,
    this.latitude,
    this.longitude,
    this.allowedRadiusFt,
    this.travelBonusHours,
    this.client,
    this.supervisor,
    this.startDate,
    this.endDate,
    this.notes,
    this.accessInstructions,
  });

  final String jobId;
  final String jobNumber;
  final String jobName;
  final String fullAddress;
  final String? address;
  final String? city;
  final String? county;
  final String? state;
  final String? zipCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final double? allowedRadiusFt;
  final double? travelBonusHours;
  final String status;
  final String? client;
  final String? supervisor;
  final String? startDate;
  final String? endDate;
  final String? notes;
  final String? accessInstructions;

  bool get isActive => status.toLowerCase() == 'active';
  bool get hasAddress => fullAddress.trim().isNotEmpty;

  String get searchableText => [
        jobId,
        jobNumber,
        jobName,
        fullAddress,
        address,
        city,
        county,
        state,
        zipCode,
        client,
        supervisor,
      ].whereType<String>().join(' ').toLowerCase();

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        jobId: _string(json['Job_ID']),
        jobNumber: _string(json['Job_Number']),
        jobName: _string(json['Job_Name']),
        fullAddress: _string(json['Full_Address']),
        address: _nullableString(json['Address']),
        city: _nullableString(json['City']),
        county: _nullableString(json['County']),
        state: _nullableString(json['State']),
        zipCode: _nullableString(json['ZIP_Code']),
        country: _nullableString(json['Country']),
        latitude: _nullableDouble(json['Latitude']),
        longitude: _nullableDouble(json['Longitude']),
        allowedRadiusFt: _nullableDouble(json['Allowed_Radius_ft']),
        travelBonusHours: _nullableDouble(json['Travel_Bonus_Hours']),
        status: _string(json['Status'], fallback: 'active'),
        client: _nullableString(json['Client']),
        supervisor: _nullableString(json['Supervisor']),
        startDate: _nullableString(json['Start_Date']),
        endDate: _nullableString(json['End_Date']),
        notes: _nullableString(json['Notes']),
        accessInstructions: _nullableString(json['Access_Instructions']),
      );

  Map<String, dynamic> toJson() => {
        'Job_ID': jobId,
        'Job_Number': jobNumber,
        'Job_Name': jobName,
        'Full_Address': fullAddress,
        'Address': address,
        'City': city,
        'County': county,
        'State': state,
        'ZIP_Code': zipCode,
        'Country': country,
        'Latitude': latitude,
        'Longitude': longitude,
        'Allowed_Radius_ft': allowedRadiusFt,
        'Travel_Bonus_Hours': travelBonusHours,
        'Status': status,
        'Client': client,
        'Supervisor': supervisor,
        'Start_Date': startDate,
        'End_Date': endDate,
        'Notes': notes,
        'Access_Instructions': accessInstructions,
      };
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final normalized = value.toString().trim().replaceAll(',', '');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
