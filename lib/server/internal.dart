library draft.internal;

import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:draft/common/sets/sets.dart';

// TODO: Is this good randomness?
import 'dart:math';

Uuid uuid = new Uuid();
Random random = new Random();
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
  Draft(this.sets) : hasStarted = false {
    // Validate the arguments.
    if (sets.length != 3) {
      throw new Exception("Exactly 3 sets must be specified.");
    }
    for (int set in sets) {
      if (set < 0 || set >= supportedSets.length) {
        throw new Exception("Invalid set specified: ${set}");
      }
    }
  }

  // Adds the given user to the draft queue. Note that this does nothing if the
  // draft has already started. sendState is a callback, used by the Draft to
  // send messages to clients. The format is explained in draftserver.dart.
  void join(String user, void sendState(Map state)) {
    sendState({"message":"Joined draft. Waiting for others..."});
  }
  
  // Removes the given user from the draft queue. Note that this does nothing
  // if the draft has already started.
  void leave(String user) {
    
  }
  
  // Starts the draft. The list of users will be locked in and shuffled, and
  // users will start receiving packs to pick from.
  void start() {
    
  }

  // Picks the card of the given index for the given user.
  void pick(String user, int pick) {
    
  }
  
  // Returns the state of the draft for the current user, to be sent to them
  // over the WebSocket. See draftserver.dart for details on the format.
  Map getCurrentState(String user) {

    return new Map();
  }
  
  List<int> sets;
  bool hasStarted;
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