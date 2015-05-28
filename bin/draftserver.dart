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
 * Each message the server sends via WebSocket is a JSON-encoded Map. It may
 * contain any or all of the following keys (use containsKey to check):
 *    message (a String containing a message to show the user)
 *    pack (a List<Map> expressing the current pack's contents)
 *    pool (a List<Map> expressing your pool of already-picked cards)
 * The Maps in these lists represent individual cards and have keys:
 *    name (the name of the card)
 *    rarity (a string: 'common', 'uncommon', 'rare', 'mythic', or 'special')
 *    html (a string containing an html representation of the card's appearance)
 *    quantity (ONLY FOR POOL; the number of that card in the player's pool)
 * 
 * To join a draft, the client should send a JSON-encoded Map with keys:
 *    user (a string uniquely identifying the user)
 *    pod (the string which identifies the pod the user is making a pick for)
 * To make a pick, the client should send a JSON-encoded Map with keys:
 *    pick (an int which is the index of the card the user has picked)
 */
Future listenToWebSocket(WebSocket ws) async {
  String userId = "";
  internal.Draft draft = null;

  await for (String json in ws) {
    try {
      Map message = JSON.decode(json);
      if (message.containsKey('user') && message.containsKey('pod')) {
        userId = message['user'];
        draft = internal.drafts[message['pod']];
        draft.join(userId, (Map map) => ws.add(JSON.encode(map)));
      }
      else if (message.containsKey('pick')) {
        int pick = message['pick'];
        draft.pick(userId, pick);
      }
      else {
        throw new Exception("Message did not contain the correct fields.");
      }
    }
    catch (error) {
      // If we get a bad request, close the connection.
      print("Invalid WebSocket request: ${error.toString()}");
      if (draft != null) {
        draft.leave(userId);
      }
      ws.close();
      return null;
    }
  }

  // When the user closes the connection, try to leave the draft.
  if (draft != null) {
    draft.leave(userId);
  }

}
