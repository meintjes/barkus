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
  querySelector("#rename-form").onSubmit.listen(rename);
  ws = new WebSocket('ws://${Uri.base.host}:${SERVER_PORT}/ws')
    ..onError.first.then(displayError)
    ..onClose.first.then(displayError)
    ..onOpen.first.then(onConnected);
}

void onConnected(Event e) {
  // Send user ID and pod ID to server so they add us to the draft.
  Map request = new Map();
  request['id'] = getUserId();
  request['name'] = getUserName();
  request['pod'] = getPodId();
  ws.send(JSON.encode(request));

  // Start listening for updates.
  ws.onMessage.listen(handleMessage);
}

void handleMessage(MessageEvent e) {
  // See draftserver.dart for details on the message format.
  Map message = JSON.decode(e.data);
  
  if (message.containsKey('message')) {
    querySelector("#message").text = message['message'];
  }
  
  if (message.containsKey('table')) {
    displayTableInfo(message['table']);
  }

  if (message.containsKey('pack')) {
    pack = message['pack'];
    List<Element> packElements = querySelector("#current-pack").children;
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

void displayTableInfo(List table) {
  List<Element> left = querySelector("#table-left").children;
  List<Element> right = querySelector("#table-right").children;
  left.clear();
  right.clear();
  for (int i = 0; i < table.length; ++i) {
    Element name = new Element.td()..children.add(
                     new Element.span()
                     ..setAttribute("class", "player-name")
                     ..setAttribute("status", table[i]['status'])
                     ..text = table[i]['name']
                   );
    Element packs = new Element.td()..children.add(
                      new Element.span()
                      ..setAttribute("class", "player-packs")
                      ..text = "${table[i]['packs']}"
                    );

    Element entry = new Element.tr();
    if (i <= table.length ~/ 2) {
      entry.children.add(name);
      entry.children.add(packs);
      left.add(entry);
    }
    else {
      entry.children.add(packs);
      entry.children.add(name);
      right.insert(0, entry);
    }
  }
  querySelector(".player-name[status=you]").onClick.listen((Event e) => querySelector("#rename-form").hidden = false);
}

void rename(Event e) {
  InputElement input = querySelector("#new-name");
  if (input.value != "") {
    window.localStorage['name'] = input.value;
    ws.send(JSON.encode({"name":input.value}));
    input.value = "";
  }
  querySelector("#rename-form").hidden = true;
  e.preventDefault();
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
  querySelector("#message").text = "You are not connected. Perhaps there was a server error, or you're trying to join an expired or invalid draft.";
}

void pickCard(Event e) {
  Map request = new Map();
  request['pick'] = int.parse((e.target as Element).getAttribute("index"));
  
  querySelector("#current-pack").children.clear();
  querySelector("#message").text = "Waiting for another pack...";

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

String getUserName() {
  if (!window.localStorage.containsKey('name')) {
    window.localStorage['name'] = "";
  }
  return window.localStorage['name'];  
}

String getPodId() {
  return Uri.base.queryParameters['pod'];
}
