/// Platform-aware Stockfish service
/// Uses native implementation on mobile/desktop, stub on web

export 'stockfish_types.dart' show StockfishConfig, StockfishState;

export 'stockfish/stockfish_service_stub.dart'
    if (dart.library.io) 'stockfish/stockfish_service_native.dart';
