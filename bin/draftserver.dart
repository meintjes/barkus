library draft;

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';
import 'dart:async';
import 'package:http_server/http_server.dart';

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
      await HttpServer.bind(InternetAddress.ANY_IP_V4, 8088);
  server.listen(_apiServer.httpRequestHandler);
  print('Server listening on http://${server.address.host}:'
        '${server.port}');
}

Future requestHandler(HttpRequest request) async {
  if (request.uri.path.startsWith('/draftApi')) {
    // Handle the API request.
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
  else if (request.uri.path == '/') {
    request.response.redirect(Uri.parse('/index.html'));
  }
  else {
    // Serve the requested file (path) from the virtual directory,
    // minus the preceeding '/'. This will fail with a 404 Not Found
    // if the request is not for a valid file.
    var fileUri = new Uri.file(_buildPath)
        .resolve(request.uri.path.substring(1));
    _clientDir.serveFile(new File(fileUri.toFilePath()), request);
  }
}

/**
 * Each message the server sends via WebSocket is a JSON-encoded Map with keys:
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
 * 
 * TODO: Implement all of this on the server end.
 */