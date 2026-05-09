import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

final class PairingCredentials {
  const PairingCredentials({
    required this.embyServerUrl,
    required this.jellyseerrUrl,
    required this.jellyseerrApiKey,
    required this.username,
    required this.password,
  });

  final String embyServerUrl;
  final String jellyseerrUrl;
  final String jellyseerrApiKey;
  final String username;
  final String password;
}

final class PairingServer {
  HttpServer? _server;
  final Completer<PairingCredentials> _completer = Completer<PairingCredentials>();
  late final String _token;
  int? _port;

  int? get port => _port;
  String get token => _token;

  Future<PairingCredentials> get credentials => _completer.future;

  Future<void> start() async {
    _token = _generateToken();

    final router = Router()
      ..get('/pair/<token>', _handleGetForm)
      ..post('/pair/<token>', _handlePostCredentials);

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _port = _server!.port;
    if (kDebugMode) {
      debugPrint('[PairingServer] started on port $_port');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    if (kDebugMode) {
      debugPrint('[PairingServer] stopped');
    }
  }

  shelf.Response _handleGetForm(shelf.Request request, String token) {
    if (token != _token) {
      return shelf.Response.forbidden('Invalid pairing token');
    }
    return shelf.Response.ok(
      _buildFormHtml(token),
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  Future<shelf.Response> _handlePostCredentials(
    shelf.Request request,
    String token,
  ) async {
    if (token != _token) {
      return shelf.Response.forbidden('Invalid pairing token');
    }

    try {
      final body = await request.readAsString();
      final Map<String, dynamic> json = jsonDecode(body);
      final embyUrl = (json['embyServerUrl'] as String?)?.trim() ?? '';
      final seerrUrl = (json['jellyseerrUrl'] as String?)?.trim() ?? '';
      final seerrKey = (json['jellyseerrApiKey'] as String?)?.trim() ?? '';
      final username = (json['username'] as String?)?.trim() ?? '';
      final password = (json['password'] as String?)?.trim() ?? '';

      if (embyUrl.isEmpty || username.isEmpty) {
        return shelf.Response(
          400,
          body: jsonEncode({'error': 'Emby URL and username are required.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final creds = PairingCredentials(
        embyServerUrl: embyUrl,
        jellyseerrUrl: seerrUrl,
        jellyseerrApiKey: seerrKey,
        username: username,
        password: password,
      );

      if (!_completer.isCompleted) {
        _completer.complete(creds);
      }

      return shelf.Response.ok(
        jsonEncode({'status': 'ok'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  String _generateToken() {
    final rng = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _buildFormHtml(String token) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Zerk Play - TV Setup</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0d0d1a;color:#e8e8f0;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
.card{background:#1a1a2e;border-radius:16px;padding:32px;max-width:400px;width:100%;box-shadow:0 8px 32px rgba(0,0,0,.4)}
h1{font-size:1.5rem;margin-bottom:8px;font-weight:800}
p.desc{color:#888;margin-bottom:24px;font-size:.9rem}
label{display:block;font-size:.85rem;font-weight:600;margin-bottom:6px;color:#aaa}
input{width:100%;padding:12px;border-radius:10px;border:1px solid #333;background:#111;color:#fff;font-size:1rem;margin-bottom:16px;outline:none;transition:border .2s}
input:focus{border-color:#6c5ce7}
button{width:100%;padding:14px;border-radius:12px;border:none;background:#6c5ce7;color:#fff;font-size:1rem;font-weight:700;cursor:pointer;transition:background .2s}
button:hover{background:#5b4bd5}
.status{margin-top:16px;text-align:center;font-size:.9rem}
.ok{color:#2ecc71}
.err{color:#e74c3c}
</style>
</head>
<body>
<div class="card">
<h1>Zerk Play Setup</h1>
<p class="desc">Enter your server details to pair with your TV.</p>
<form id="f">
<label>Emby Server URL *</label>
<input name="embyServerUrl" placeholder="https://emby.example.com" required>
<label>*seerr URL</label>
<input name="jellyseerrUrl" placeholder="https://jellyseerr.example.com">
<label>*seerr API Key</label>
<input name="jellyseerrApiKey" placeholder="API key">
<label>Username *</label>
<input name="username" required>
<label>Password</label>
<input name="password" type="password">
<button type="submit">Pair with TV</button>
</form>
<div class="status" id="s"></div>
</div>
<script>
document.getElementById('f').addEventListener('submit',async e=>{
e.preventDefault();
const s=document.getElementById('s');
s.className='status';s.textContent='Sending...';
const d=Object.fromEntries(new FormData(e.target));
try{
const r=await fetch('/pair/$token',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(d)});
const j=await r.json();
if(r.ok){s.className='status ok';s.textContent='Paired successfully! You can close this page.';}
else{s.className='status err';s.textContent=j.error||'Error';}
}catch(e){s.className='status err';s.textContent='Network error: '+e.message;}
});
</script>
</body>
</html>''';
  }
}
