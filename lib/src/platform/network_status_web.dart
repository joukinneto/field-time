import 'dart:js_interop';

@JS('navigator.onLine')
external bool get _navigatorOnline;

bool get isDeviceOnline => _navigatorOnline;
