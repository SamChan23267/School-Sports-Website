// lib/cors_proxy.dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_proxy/shelf_proxy.dart';

// This is the server that will forward our requests.
void main() async {
  // 1. Define the middleware that adds CORS headers.
  final corsMiddleware = const Pipeline().addMiddleware((innerHandler) {
    return (req) async {
      // Handle preflight (OPTIONS) requests, which are sent by browsers
      // to check permissions before a "complex" request (like a POST with JSON).
      if (req.method == 'OPTIONS') {
        return Response.ok(null, headers: {
          'Access-Control-Allow-Origin': '*', // Allow any origin
          'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type',
        });
      }

      // For actual requests, pass them through the proxy and add the
      // 'Access-Control-Allow-Origin' header to the response.
      final response = await innerHandler(req);
      return response.change(headers: {'Access-Control-Allow-Origin': '*'});
    };
  });

  // 2. Create the main handler for the proxy.
  final handler = corsMiddleware.addHandler(
    proxyHandler(Uri.parse("https://www.collegesport.co.nz")),
  );

  // 3. Serve the handler on localhost.
  final server = await io.serve(
    handler,
    'localhost',
    9999, // We'll run our proxy on port 9999
  );

  print('CORS-Proxy server running on http://localhost:9999');
}
