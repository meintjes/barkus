import 'dart:html';
import 'package:draft/common/messages.dart';

void main() {
  String draftId = Uri.base.queryParameters['pod'];
  
  if (draftId == "") {
    // No query string was given.
    return;
  }
  
  Pack currentPack = getPack();
  displayPack(currentPack);
}

String getID() {
  if (!window.localStorage.containsKey('id')) {
    // TODO get ID from server if not available
    window.localStorage['id'] = "session";
  }
  return window.localStorage['id'];
}

// Returns a 'link' to the specified card (it goes nowhere).
Element getCardLink(Card card) {
  Element cardElement = new Element.a();
  cardElement.text = card.name;

  // TODO: Indicate rarity with CSS.
  // TODO: Autocard.
  // TODO: Apparently this is bad practice. Use CSS instead.
  cardElement.setAttribute('href', '#');
  return cardElement;
}

// Updates the DOM to show the contents of a pack.
void displayPack(Pack pack) {
  int pickNum = pack.pickNum;
  querySelector("#pickNum").text = "Pick $pickNum:";
  Element packElement = querySelector("#currentPack");
  
  packElement.children.clear();
  for (int i = 0; i < pack.cards.length; ++i) {
    Element cardElement = getCardLink(pack.cards[i]);
    cardElement.setAttribute("index", "$i");
    cardElement.onClick.listen(pickCard);
    packElement.children.add(cardElement);
    packElement.children.add(new Element.br());
  }
}

Pack getPack() {
  // TODO get pack from server
  Pack pack = new Pack(1, ["Ponder", "Select", "Susurrus of Voor"]);

  return pack;
}

void pickCard(Event e) {
  Element card = e.target;
  
  Element lastPickElement = querySelector("#lastPick");
  int index = int.parse(card.getAttribute("index"));
  
  // TODO notify server instead of printing this
  lastPickElement.text = "Just picked card $index";
}
