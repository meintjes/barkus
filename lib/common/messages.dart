library draft.messages;

/**
 * Classes used for HTTP messages.
 */
class User {
  String id;
  
  User();
}

class CreateRequest {
  List<int> sets;

  CreateRequest() : sets = new List<int>();
}

class CreateResponse {
  String draftId;
  
  CreateResponse();
}



class Card {
  String name;
  String rarity;
  
  Card(this.name, this.rarity);
}

class Pack {
  final int pickNum;
  final List<Card> cards;

  Pack(this.pickNum, this.cards);
}