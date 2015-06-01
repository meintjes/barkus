class CardSet {
  final String longname;
  final String shortname;
  
  CardSet(this.longname, this.shortname);
}

final List<CardSet> supportedSets = [
  new CardSet("Velicta", "VEL"),
  new CardSet("Bloodied Streets", "BST"),
  //new CardSet("Velicta's Reckoning", "VLR"),
  new CardSet("Fleets of Ossia", "FOS"),
];