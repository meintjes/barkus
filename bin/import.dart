import 'dart:io';
import 'dart:async';
import 'package:xml/xml.dart' as XML;

/*
 * To use the import tool, run it from inside the bin subdirectory, passing a
 * set's abbreviation as the only argument. ngaconstructed.xml should be in the
 * main directory. Then update sets.dart with the new additions.
 */

Future main(List<String> args) async {
  if (args.length != 1) {
    print("Expected exactly one argument, a set's abbreviation.");
    return;
  }
  
  final String cardsPath = "../ngaconstructed.xml";
  final String setsPath = "../lib/common/sets/${args[0]}";
  
  List<String> commons = new List<String>();
  List<String> uncommons = new List<String>();
  List<String> rares = new List<String>();
  List<String> mythics = new List<String>();
  List<String> basics = ["Plains", "Island", "Swamp", "Mountain", "Forest"];
  
  XML.XmlDocument cardXml;
  try {
    File file = new File(cardsPath);
    String cards = file.readAsStringSync();
    cardXml = XML.parse(cards);
  }
  catch (e) {
    print("Failed to read ${cardsPath} as XML.");
  }

  // Find the rarities of every card in the set.
  for (var card in cardXml.findAllElements("card")) {
    var set = card.findElements("set").firstWhere((set) => set.text == args[0], orElse: () => null);
    if (set != null) {
      String cardName = card.findElements("name").first.text;
      switch (set.getAttribute("rarity")) {
        case "C":
          commons.add(cardName);
          break;
        case "U":
          uncommons.add(cardName);
          break;
        case "R":
          rares.add(cardName);
          break;
        case "M":
          mythics.add(cardName);
          break;
      }
    }
  }
  
  print("Found ${commons.length} commons.\n"
        "Found ${uncommons.length} uncommons.\n"
        "Found ${rares.length} rares.\n"
        "Found ${mythics.length} mythics.\n");
  
  if (commons.isEmpty || uncommons.isEmpty || rares.isEmpty) {
    print("Exiting without transcribing.");
    exit(1);
  }
  
  // Write the set's contents to disk.
  await Future.wait([
    writeFile(new File("${setsPath}/common.txt"), commons),
    writeFile(new File("${setsPath}/uncommon.txt"), uncommons),
    writeFile(new File("${setsPath}/rare.txt"), rares),
    writeFile(new File("${setsPath}/mythic.txt"), mythics),
    writeFile(new File("${setsPath}/special.txt"), basics)
  ]);
  
  print("Finished transcribing set ${args[0]}. Remember to update sets.dart!");
}

Future writeFile(File file, List<String> cards) async {
  if (cards.length > 0) {
    await file.create(recursive: true);
    var openedFile = file.openWrite();
    for (String card in cards) {
      await openedFile.write("${card}\n");
    }
    openedFile.close();
  }
}