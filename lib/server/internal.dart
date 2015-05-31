library draft.internal;

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:draft/common/sets/sets.dart';

// TODO: Is this good randomness?
import 'dart:math';

typedef void SendStateFunc(Map state);
Uuid uuid = new Uuid();
Random random = new Random();

const int DRAFTERS_TO_START = 1;
const int PACKS = 3;
const int MAX_NAME_LENGTH = 20;
final Duration DELETION_TIME = new Duration(seconds: 90);

// A map of draft IDs onto the Draft objects themselves.
Map<String, Draft> drafts = new Map<String, Draft>();

// Creates a draft with a unique ID. Returns that ID.
String create(List<int> sets) {  
  String id;
  do {
    id = uuid.v4();
  } while (drafts.containsKey(id));

  drafts[id] = new Draft(sets, id);

  return id;
}

// A class handling the drafting logic.
class Draft {
  // Adds the given user to the draft queue if it hasn't started yet. endState
  // is a callback, used by the Draft to send messages to clients. The format
  // is explained in draftserver.dart.
  void join(String id, String name, SendStateFunc sendState) {
    Drafter drafter = _getDrafter(id);
    // Don't let the same user join the draft twice. 
    if (drafter != null && drafter.sendState != null) {
      sendState({"message":"You are already connected to this draft."});
      return;
    }

    if (!_hasStarted) {
      _drafters.add(new Drafter(id, sendState)..setName(name));
      if (_drafters.length == DRAFTERS_TO_START) {
        _start();
      }
      else {
        _sendWaitingMessage();
      }
    }
    else {
      // If the user isn't in the draft, tell them it started.
      if (drafter == null) {
        sendState({"message":"That draft has already started!"});
        return;
      }
      // If the user is already in the draft and is reconnecting, update their
      // sendState function to send to the new WebSocket. Then send them all
      // the information they might be missing.
      else {
        drafter.sendState = sendState;
        drafter.setName(name);
        drafter.sendPack();
        drafter.sendPool();
        _sendTableInfo();
      }
    }
    // If a user successfully joined or reconnected, stop the draft from being
    // deleted. This code will not be reached if a non-drafter tries to join an
    // already-started draft.
    _cancelDeletion();
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
      _sendTableInfo();
    }
    
    _scheduleDeletion();
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
      _openPacks();
    }
    
    _sendTableInfo();
  }
  
  void rename(String id, String newName) {
    Drafter drafter = _getDrafter(id);
    drafter.setName(newName);
    _sendTableInfo();
  }



  Draft(this._sets, this._id) :
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
    
    _scheduleDeletion();
  }
  
  // Schedules a draft to be deleted if it has no connected players. Call this
  // when creating the draft and when a player leaves the draft.
  void _scheduleDeletion() {
    if (_usersConnected == 0) {
      _deletionTimer = new Timer(DELETION_TIME,
        () {
          drafts.remove(_id);
        }
      );
    }
  }
  
  // If the draft is scheduled to be deleted, unschedule it. Call this when
  // players join the draft.
  void _cancelDeletion() {
    if (_deletionTimer != null) {
      _deletionTimer.cancel();
      _deletionTimer = null;
    }
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
    
    _openPacks();
  }
  
  // Causes each player to open the next pack.
  Future _openPacks() async {
    if (_currentPack >= _sets.length) {
      _sendAll({"message":"All cards have been picked."});
      return;
    }
    
    _sendAll({"message":"Opening pack ${_currentPack + 1}..."});

    // Generate packs asynchronously because it takes a long time.
    await Future.wait(_drafters.map(
      (Drafter drafter) async {
        drafter.packs.add(await generatePack(supportedSets[_sets[_currentPack]].shortname));
      }
    ));
    
    // Send everyone their packs, and update pack location information.
    for (Drafter drafter in _drafters) {
      drafter.sendPack();
    }
    _sendTableInfo();
    
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
  
  
  // Sends a message to all users waiting.
  void _sendWaitingMessage() {
    _sendAll({"message":"Waiting for draft to start: ${_drafters.length}/${DRAFTERS_TO_START} users connected."});
  }
  
  // Sends information to all players about where packs are.
  void _sendTableInfo() {
    List<Map> message = new List<Map>();
    for (Drafter drafter in _drafters) {
      String status = drafter.sendState != null ?
                      "connected" :
                      "disconnected";
      message.add({"name":drafter.name,
                   "packs":drafter.packs.length,
                   "status":status});
    }
    
    // TODO remove this testing code
    for (int i = 0; i < 6; ++i) {
      message.add({"name":"evil pack hoarder",
                   "packs":8,
                   "status":"disconnected"});
    }
    
    _sendAll({"table":message});
  }
  
  // Gets the number of drafters that are still connected to the draft.
  int get _usersConnected {
    return _drafters.where((Drafter drafter) => drafter.sendState != null).length;
  }

  List<Drafter> _drafters;
  List<int> _sets;
  bool _hasStarted;
  int _currentPack;
  String _id;
  Timer _deletionTimer;
}

class Drafter {
  int index;
  String id;
  String name;
  SendStateFunc sendState;
  List<List<Map<String, String>>> packs;
  List<Map<String, String>> pool;

  Drafter(this.id, this.sendState) :
    index = -55,
    packs = new List<List<Map<String, String>>>(),
    pool = new List<Map<String, String>>()
  {}
  
  void setName(String newName) {
    name = newName;
    if (name.length > MAX_NAME_LENGTH) {
      name = name.substring(0, MAX_NAME_LENGTH);
    }
  }
  
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
  
  // Add html representations to the cards in the pack.
  await Future.wait(pack.map(
    (Map<String, String> card) async {
      card['html'] = await getCardHtml(card['name']);
    }
  ));
  
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
               "rarity":rarity
    });
  }

  return cards;
}

// Gets the HTML representation of the named card.
// TODO: Caching.
Future<String> getCardHtml(String cardName) async {
  // Replace characters from card names that aren't safe for URLs.
  String safeCardName = cardName.replaceAllMapped(new RegExp(r'[ ~[\]]'), 
    (Match m) {
      return "%" + m.group(0).runes.first.toRadixString(16);
    }
  );
  return (await http.get("http://forum.nogoblinsallowed.com/view_card.php?view=render&name=${safeCardName}")).body;
}