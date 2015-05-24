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

  // Start listening for updates.
  ws.onMessage.listen(handleMessage);
}

void handleMessage(MessageEvent e) {
  // See draftserver.dart for details on the message format.
  Map message = JSON.decode(e.data);
  
  if (message.containsKey('message')) {
    querySelector("#output").text = message['message'];
  }

  if (message.containsKey('pack')) {
    List cards = message['pack'];
    List<Element> pack = querySelector("#currentPack").children;
    pack.clear();
    for (int i = 0; i < cards.length; ++i) {
      pack.add(getCardLink(cards[i])
                 ..setAttribute("index", "$i")
                 ..onClick.listen(pickCard)
              );
      pack.add(new Element.br());
    }
  }

  if (message.containsKey('pool')) {
    List cards = message['pool'];
    List<Element> pool = querySelector("#pool").children;
    
    pool.clear();
    for (int i = 0; i < cards.length; ++i) {
      pool.add(new Element.span()..text = "${cards[i]['quantity']} ");
      pool.add(getCardLink(cards[i]));
      pool.add(new Element.br());
    }
  }
}

// Returns a link to the specified card.
Element getCardLink(Map card) {
  Element cardElement = new Element.span();
  cardElement.text = card['name'];
  cardElement.setAttribute('class', 'card');
  cardElement.setAttribute('rarity', card['rarity']);
  
  // TODO: Autocard.

  return cardElement;
}

void displayError(Event e) {
  querySelector("#output").text = "You are not connected to the server. Please refresh the page.";
}

void pickCard(Event e) {
  Map request = new Map();
  request['pick'] = int.parse((e.target as Element).getAttribute("index"));
  
  querySelector("#currentPack").children.clear();

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
