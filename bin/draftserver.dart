library draft;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';
import 'package:http_server/http_server.dart';
import 'package:draft/common/messages.dart';
import 'package:draft/server/draftapi.dart';

final ApiServer _apiServer = new ApiServer(prettyPrint: true);

final String _buildPath =
    Platform.script.resolve('../build/web/').toFilePath();
final VirtualDirectory _clientDir = 
    new VirtualDirectory(_buildPath);

main() async {
  Logger.root..level = Level.INFO
             ..onRecord.listen(print);

  _apiServer.addApi(new DraftApi());
  HttpServer server =
      await HttpServer.bind(InternetAddress.ANY_IP_V4, SERVER_PORT);
  server.listen(requestHandler);
  print('Server listening on http://${server.address.host}:'
        '${server.port}');
}

Future requestHandler(HttpRequest request) async {
  // Given the empty path, serve the index.
  if (request.uri.path == '/') {
    request.response.redirect(Uri.parse('/index.html'));
  }
  
  // Upgrade and handle WebSocket requests.
  else if (request.uri.path == '/ws') {
    WebSocketTransformer.upgrade(request).then(listenToWebSocket);
  }
  
  // Handle API requests.
  else if (request.uri.path.startsWith('/draftApi')) {
    var apiResponse;
    try {
      var apiRequest = new HttpApiRequest.fromHttpRequest(request);
      apiResponse =
          await _apiServer.handleHttpApiRequest(apiRequest);
    } catch (error, stack) {
      var exception =
          error is Error ? new Exception(error.toString()) : error;
      apiResponse = new HttpApiResponse.error(
          HttpStatus.INTERNAL_SERVER_ERROR, exception.toString(),
          exception, stack);
    }
    return sendApiResponse(apiResponse, request.response);
  }

  // Serve the requested file (path) from the virtual directory,
  // minus the preceeding '/'. This will fail with a 404 Not Found
  // if the request is not for a valid file.
  else {
    var fileUri = new Uri.file(_buildPath)
        .resolve(request.uri.path.substring(1));
    _clientDir.serveFile(new File(fileUri.toFilePath()), request);
  }
}

/**
 * For the draft creation API, see lib/server/draftapi.dart.
 * 
 * Each message the server sends via WebSocket is a JSON-encoded Map with keys:
 *    error (a String containing an error to show the user; the other fields
 *           are only present if this one is the empty string)
 *    pickNum (an int expressing the number of the current pick) 
 *    cards (a List<Map> expressing the current pack's contents)
 *    pool (a List<Map> expressing your pool of already-picked cards)
 * The Maps in these lists represent individual cards and have keys:
 *    name (the name of the card)
 *    rarity ('common', 'uncommon', 'rare', 'mythic', 'special')
 * 
 * Each message the client sends should be a JSON-encoded Map with keys:
 *    user (a string uniquely identifying the user
 *    pod (the string which identifies the pod the user is making a pick for)
 *    pick (the card the user is picking)
 * To attempt to join a draft, send a request with pick == -1.
 */

Future listenToWebSocket(WebSocket ws) async {
  Map currentState = new Map();
  currentState['error'] = "This is a message from the server!";
  ws.add(JSON.encode(currentState));
}
