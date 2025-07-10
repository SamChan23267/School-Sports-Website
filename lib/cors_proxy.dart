// lib/cors_proxy.dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_proxy/shelf_proxy.dart';
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final app = Router();

  // Route for CollegeSport requests
  app.mount('/collegesport/', proxyHandler("https://www.collegesport.co.nz"));

  // Route for Auckland Rugby requests
  app.mount('/aucklandrugby/', proxyHandler("https://www.aucklandrugby.co.nz"));

  // Middleware to add CORS headers to every response
  final handler = const Pipeline()
      .addMiddleware(logRequests()) // Helpful for debugging
      .addMiddleware(_corsMiddleware)
      .addHandler(app);

  final server = await io.serve(handler, 'localhost', 9999);
  print('CORS Proxy server running on http://localhost:${server.port}');
  print('-> Forwarding /collegesport/ to https://www.collegesport.co.nz/');
  print('-> Forwarding /aucklandrugby/ to https://www.aucklandrugby.co.nz/');
}

// Middleware handler to add CORS headers
Middleware _corsMiddleware = (innerHandler) {
  return (request) async {
    // Handle pre-flight (OPTIONS) requests
    if (request.method == 'OPTIONS') {
      return Response.ok(null, headers: _corsHeaders);
    }
    // Handle actual requests
    final response = await innerHandler(request);
    return response.change(headers: {...response.headers, ..._corsHeaders});
  };
};

const Map<String, String> _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
};
