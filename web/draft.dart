import 'dart:html';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:draft/common/messages.dart';

WebSocket ws;

void main() {
  ws = new WebSocket('ws://${Uri.base.host}:${SERVER_PORT}/ws')
    ..onError.first.then(displayError)
    ..onClose.first.then(displayError)
    ..onOpen.first.then(onConnected);
}

void onConnected(Event e) {
  // Send user ID and pod ID to server so they add us to the draft.
  Map request = new Map();
  request['user'] = getUserId();
  request['pod'] = getPodId();
  ws.send(JSON.encode(request));
  
  ws.onMessage.listen(handleMessage);
}

void handleMessage(MessageEvent e) {
  // See draftserver.dart for details on the message format.
  Map message = JSON.decode(e.data);
  
  if (message.containsKey('message')) {
    querySelector("#output").text = message['message'];
    return;
  }

  int pickNum = message['pickNum'];
  querySelector("#pickNum").text = "Pick $pickNum:";

  Element packElement = querySelector("#currentPack");  
  packElement.children.clear();
  List<Map> cards = message['cards'];
  for (int i = 0; i < cards.length; ++i) {
    packElement.children.add(getCardLink(cards[i])
                               ..setAttribute("index", "$i")
                               ..onClick.listen(pickCard)
                            );
    packElement.children.add(new Element.br());
  }
  
  // TODO: Show pool.
}

// Returns a 'link' to the specified card (it goes nowhere).
Element getCardLink(Map card) {
  Element cardElement = new Element.a();
  cardElement.text = card['name'];

  // TODO: Indicate rarity with CSS.
  // TODO: Autocard.
  // TODO: Use CSS for links, rather than targeting '#'.
  cardElement.setAttribute('href', '#');
  return cardElement;
}

void displayError(Event e) {
  querySelector("#output").text = "You are not connected to the server. Please refresh the page.";
}

void pickCard(Event e) {
  Map request = new Map();
  request['index'] = int.parse((e.target as Element).getAttribute("index"));

  ws.send(JSON.encode(request));
}

String getUserId() {
  if (!window.localStorage.containsKey('id')) {
    window.localStorage['id'] = new Uuid().v4();
  }
  return window.localStorage['id'];
}

String getPodId() {
  return Uri.base.queryParameters['pod'];
}
