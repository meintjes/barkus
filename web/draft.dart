import 'dart:html';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:draft/common/messages.dart';

List<Map<String, String>> pack;
List<Map<String, String>> pool;
WebSocket ws;

void main() {
  pack = new List();
  pool = new List();
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
    pack = message['pack'];
    List<Element> packElements = querySelector("#currentPack").children;
    packElements.clear();
    for (int i = 0; i < pack.length; ++i) {
      packElements.add(getCardLink(pack[i])
                       ..setAttribute("index", "$i")
                       ..setAttribute("pack", "true")
                       ..onClick.listen(pickCard)
                      );
      packElements.add(new Element.br());
    }
  }

  if (message.containsKey('pool')) {
    pool = message['pool'];
    List<Element> poolElements = querySelector("#pool").children;
    
    poolElements.clear();
    for (int i = 0; i < pool.length; ++i) {
      poolElements.add(new Element.span()..text = "${pool[i]['quantity']} ");
      poolElements.add(getCardLink(pool[i])
                       ..setAttribute("index", "$i")
                       ..setAttribute("pack", "false")
                      );
      poolElements.add(new Element.br());
    }
  }
}

// Returns a link to the specified card.
Element getCardLink(Map card) {
  Element cardElement = new Element.span();
  cardElement.text = card['name'];
  cardElement.setAttribute('class', 'card');
  cardElement.setAttribute('rarity', card['rarity']);
  cardElement.onMouseOver.listen(displayAutocard);

  return cardElement;
}

void displayError(Event e) {
  querySelector("#output").text = "You are not connected to the server. Please refresh the page.";
}

void pickCard(Event e) {
  Map request = new Map();
  request['pick'] = int.parse((e.target as Element).getAttribute("index"));
  
  querySelector("#currentPack").children.clear();
  querySelector("#output").text = "Waiting for another pack...";

  ws.send(JSON.encode(request));
}

void displayAutocard(Event e) {
  int index = int.parse((e.target as Element).getAttribute("index"));
  Element autocard = querySelector("#autocard");
  
  String cardHtml = (e.target as Element).getAttribute("pack") == "true" ?
                    pack[index]['html'] :
                    pool[index]['html'];

  var validator = new NodeValidatorBuilder()
    ..allowTextElements()
    ..allowElement("img", attributes: ["class", "src"])
    ..allowElement("div", attributes: ["class"])
    ..allowInlineStyles();
  
  autocard.children.clear();
  autocard.children.add(new Element.html(cardHtml, validator: validator));
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
