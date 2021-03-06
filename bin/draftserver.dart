library draft;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';
import 'package:http_server/http_server.dart';
import 'package:draft/common/messages.dart';
import 'package:draft/server/draftapi.dart';
import 'package:draft/server/internal.dart' as internal;

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
  else if (request.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(request)) {
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
 * Each message the server sends via WebSocket is a JSON-encoded Map. It may
 * contain any or all of the following keys (use containsKey to check):
 *    message (a String containing a message to show the user)
 *    table (a List<Map> showing how many packs each player is holding)
 *    pack (a List<Map> expressing the current pack's contents)
 *    pool (a List<Map> expressing your pool of already-picked cards)
 * The Maps in 'table' have keys:
 *    name (a string, the player's name)
 *    packs (an int, the number of packs that player is holding)
 *    status ("connected" or "disconnected" or "you")
 * The Maps in 'pack' and 'pool' represent individual cards and have keys:
 *    name (a string: the name of the card)
 *    rarity (a string: 'common', 'uncommon', 'rare', 'mythic', or 'special')
 *    html (a string containing an html representation of the card's appearance)
 *    quantity (ONLY FOR POOL; the number of that card in the player's pool)
 * 
 * To join a draft, the client should send a JSON-encoded Map with keys:
 *    id (a string uniquely identifying the user)
 *    name (a string identifying the user in a human-readable way)
 *    pod (the string which identifies the pod the user is making a pick for)
 * To make a pick, the client should send a JSON-encoded Map with keys:
 *    pick (an int which is the index of the card the user has picked)
 * Clients can also rename themselves on the server end by sending a message
 * with only the key "name" as above.
 */
Future listenToWebSocket(WebSocket ws) async {
  String userId = "";
  internal.Draft draft = null;

  await for (String json in ws) {
    try {
      Map message = JSON.decode(json);
      if (message.containsKey('id') && message.containsKey('name') && message.containsKey('pod')) {
        userId = message['id'];
        draft = internal.drafts[message['pod']];
        draft.join(userId, message['name'], (Map map) => ws.add(JSON.encode(map)));
      }
      else if (message.containsKey('pick')) {
        int pick = message['pick'];
        draft.pick(userId, pick);
      }
      else if (message.containsKey('name')) {
        draft.rename(userId, message['name']);
      }
      else {
        throw new Exception("Message did not contain the correct fields.");
      }
    }
    catch (error) {
      // If we get a bad request, close the connection.
      print("Invalid WebSocket request: ${error.toString()}");
      ws.close();
      break;
    }
  }

  // When we (or the user) close the connection, remove them from the draft.
  if (draft != null) {
    try {
        draft.leave(userId);
    }
    catch (error) {
      print("Failed to leave draft: ${error.toString()}");
    }
  }

}
