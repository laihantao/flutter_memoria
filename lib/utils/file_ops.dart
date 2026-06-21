// Conditional export: native implementation on mobile/desktop, web stubs on web.
export 'file_ops_web.dart'
    if (dart.library.io) 'file_ops_native.dart';
