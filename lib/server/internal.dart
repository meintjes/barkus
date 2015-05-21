library draft.internal;

import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';

// TODO: Is this good randomness?
import 'dart:math';

Uuid uuid = new Uuid();
Random random = new Random();

// Creates a draft with a unique ID. Returns that ID.
String create() {
  // TODO: Actually create something.
  return uuid.v4();
}

// Returns a pack from the given set, if the set exists.
// If the set doesn't exist, throws a FileSystemException.
// TODO: Generate foils.
Future<List<Map<String, String>>> generatePack(String shortname) async {
  List<Map<String, String>> pack = new List<Map>();

  String rareSlot = random.nextInt(8) == 0 ? "rare" : "mythic";
  pack.addAll(await getCardsFrom(shortname, rareSlot, 1));
  pack.addAll(await getCardsFrom(shortname, "uncommon", 3));
  pack.addAll(await getCardsFrom(shortname, "common", 10));
  pack.addAll(await getCardsFrom(shortname, "special", 1));

  return pack;
}

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