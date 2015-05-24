library draft.internal;

import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:draft/common/sets/sets.dart';

// TODO: Is this good randomness?
import 'dart:math';

typedef void SendStateFunc(Map state);
Uuid uuid = new Uuid();
Random random = new Random();

final int DRAFTERS_TO_START = 1;
final int PACKS = 3;

// A map of draft IDs onto the Draft objects themselves.
Map<String, Draft> drafts = new Map<String, Draft>();

// Creates a draft with a unique ID. Returns that ID.
String create(List<int> sets) {  
  String id;
  do {
    id = uuid.v4();
  } while (drafts.containsKey(id));

  drafts[id] = new Draft(sets);

  return id;
}

// A class handling the drafting logic.
class Draft {
  // Adds the given user to the draft queue if it hasn't started yet. endState
  // is a callback, used by the Draft to send messages to clients. The format
  // is explained in draftserver.dart.
  void join(String user, SendStateFunc sendState) {
    if (!_hasStarted) {
      _drafters.add(new Drafter(user, sendState));
      if (_drafters.length == DRAFTERS_TO_START) {
        _start();
      }
      else {
        _sendWaitingMessage();
      }
    }
    else {
      // If the user isn't in the draft, tell them it started.
      Drafter drafter = _getDrafter(user);
      if (drafter == null) {
        sendState({"message":"That draft has already started!"});
        throw new Exception("Tried to join an already-started draft.");
      }
      // If the user is already in the draft and is reconnecting, update their
      // sendState function to send to the new WebSocket. Then send them all
      // the information they might be missing.
      else {
        drafter.sendState = sendState;
        drafter.sendPack();
        drafter.sendPool();
      }
    }
  }
  
  // Removes the given user from the draft queue. If the draft has already
  // started, it keeps them in the draft, but stops trying to send data until
  // they rejoin.
  void leave(String user) {
    if (!_hasStarted) {
      _drafters.remove(_getDrafter(user));
      _sendWaitingMessage();
    }
    else {
      _getDrafter(user).sendState = null;
    }
  }

  // Picks the card of the given index for the given user.
  void pick(String user, int pick) {
    // Add the picked card to the user's pool and remove it from the pack.
    Drafter drafter = _getDrafter(user);
    Map pickedCard = drafter.packs.first.elementAt(pick);
    Map cardInPool = drafter.pool.firstWhere((Map card) => card['name'] == pickedCard['name'], orElse: () => null);
    if (cardInPool != null) {
      cardInPool['quantity'] += 1;
    }
    else {
      pickedCard['quantity'] = 1;
      drafter.pool.add(pickedCard);
    }
    drafter.packs.first.removeAt(pick);
    drafter.sendPool();
    
    // Pass the pack to the next person in line.
    // Note that _currentPack % 2 == 0 if this is pack 0 or 2 (1 or 3), so if
    // this expression is true, then we pass "left" (backwards in index).
    int nextInLine = (_currentPack % 2 == 0 ? drafter.index - 1
                                            : drafter.index + 1);
    nextInLine %= _drafters.length;
    Drafter nextDrafter = _drafters[nextInLine];
    if (drafter.packs.first.length > 0) {
      nextDrafter.packs.add(drafter.packs.first);
      // If this is the only pack the person being passed to has, send them it.
      if (nextDrafter.packs.length == 1) {
        nextDrafter.sendPack();
      }
    }
    drafter.packs.removeAt(0);
    // If there's another pack waiting, send it.
    if (drafter.packs.length == 1) {
      drafter.sendPack();
    }


    // If everyone is out of cards to pick, open the next pack. 
    if (_drafters.every((Drafter drafter) => drafter.packs.isEmpty)) {
      openPacks();
    }
  }



  Draft(this._sets) :
    _drafters = new List<Drafter>(),
    _hasStarted = false,
    _currentPack = 0
  {
    // Validate the arguments.
    if (_sets.length != PACKS) {
      throw new Exception("Expected ${PACKS} sets but got ${_sets.length}.");
    }
    for (int set in _sets) {
      if (set < 0 || set >= supportedSets.length) {
        throw new Exception("Invalid set specified: ${set}");
      }
    }
  }
  
  // Sends a message to all users waiting.
  void _sendWaitingMessage() {
    _sendAll({"message":"Waiting for draft to start: ${_drafters.length}/${DRAFTERS_TO_START} users connected."});
  }
  
  // Starts the draft. The list of users will be locked in and shuffled, and
  // users will start receiving packs to pick from.
  void _start() {
    _hasStarted = true;
    
    // Assign the drafters random seats.
    _drafters.shuffle(random);
    for (int i = 0; i < _drafters.length; ++i) {
      _drafters[i].index = i;
    }
    
    openPacks();
  }
  
  // Causes each player to open the next pack.
  Future openPacks() async {
    if (_currentPack >= _sets.length) {
      _sendAll({"message":"All cards have been picked."});
      return;
    }
    
    // TODO: This used to use Future.wait(), but one of the futures was somehow
    // a null object. The current implementation contains a data race, I think,
    // in the event that someone gets a pack and passes it before the recipient
    // opens their own pack.
    for (Drafter drafter in _drafters) {
      drafter.packs.add(await generatePack(supportedSets[_sets[_currentPack]].shortname));
      drafter.sendPack();
    }
    // Then indicate that we've already opened this set of packs, and return.
    ++_currentPack;
  }

  // Returns the user with the given ID, or null if the ID doesn't exist.
  Drafter _getDrafter(String id) {
    return _drafters.firstWhere((Drafter drafter) => drafter.id == id, orElse: () => null);
  }

  // Sends the given data to all users.
  void _sendAll(Map state) {
    for (Drafter drafter in _drafters) {
      if (drafter.sendState != null) {
        drafter.sendState(state);
      }
    }    
  }

  List<Drafter> _drafters;
  List<int> _sets;
  bool _hasStarted;
  int _currentPack;
}

class Drafter {
  int index;
  String id;
  SendStateFunc sendState;
  List<List<Map<String, String>>> packs;
  List<Map<String, String>> pool;

  Drafter(this.id, this.sendState) :
    index = -55,
    packs = new List<List<Map<String, String>>>(),
    pool = new List<Map<String, String>>()
  {}
  
  void sendPack() {
    if (sendState != null && packs.isNotEmpty) {
      Map message = new Map();
      message['message'] = "Pick a card to add to your pool:";
      message['pack'] = packs.first;
      sendState(message);
    }
  }
  
  void sendPool() {
    if (sendState != null) {
      Map message = new Map();
      message['pool'] = pool;
      sendState(message);
    }
  }
}

// Returns a pack from the given set, if the set exists.
// TODO: Generate foils.
Future<List<Map<String, String>>> generatePack(String shortname) async {
  List<Map<String, String>> pack = new List<Map>();

  String rareSlot = random.nextInt(8) != 0 ? "rare" : "mythic";
  pack.addAll(await getCardsFrom(shortname, rareSlot, 1));
  pack.addAll(await getCardsFrom(shortname, "uncommon", 3));
  pack.addAll(await getCardsFrom(shortname, "common", 10));
  pack.addAll(await getCardsFrom(shortname, "special", 1));
  
  return pack;
}

// Returns 'numCards' cards of rarity 'rarity' from the set whose shortname is 'shortname'.
// If the set doesn't exist, throws a FileSystemException.
Future<List<Map<String, String>>> getCardsFrom(String shortname, String rarity, int numCards) async {
  List<Map<String, String>> cards = new List<Map>();
  
  File file = new File("lib/common/sets/${shortname}/${rarity}.txt");
  List<String> cardNames = await file.readAsLines();
  cardNames.shuffle(random);

  for (int i = 0; i < numCards; ++i) {
    cards.add({"name":cardNames[i],
               "rarity":rarity});
  }

  return cards;
}