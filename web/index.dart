import 'dart:html';
import 'dart:async';
import 'package:draft/common/messages.dart';
import 'package:draft/common/sets/sets.dart';
import 'package:draft/client/draftapi.dart';
import 'package:http/browser_client.dart';

final String serverUrl = 'localhost:8088/';
final BrowserClient client = new BrowserClient();
DraftApi api;

void main() {
  var protocol = window.location.protocol;
  api = new DraftApi(client, rootUrl: "$protocol//$serverUrl");
  
  for (var elem in querySelectorAll("#pack")) {
    for (CardSet set in supportedSets) {
      Element option = new Element.option();
      option.text = set.longname;
      elem.children.add(option);
    }
  }

  querySelector("#create").onClick.listen(createPod);
}

Future createPod(Event e) async {
  CreateRequest request = new CreateRequest();

  // Prepare the creation request, trying to add the packs the user indicated.
  List<Element> packs = querySelectorAll("#pack");
  for (var elem in packs) {
    int selectedPack = (elem as SelectElement).selectedIndex - 1;
    if (selectedPack < 0) {
      querySelector("#create").onClick.listen(createPod);
      return null;
    }
    else {
      request.sets.add(selectedPack);
    }
  }
  
  // The dropdown selections are valid. Prepare to actually submit the request.
  querySelector("#create").setAttribute("disabled", "true");
  for (var elem in packs) {
    elem.setAttribute("disabled", "true");
  }
  
  Element result = querySelector("#result");
  result.text = "Getting link...";
  
  CreateResponse response;
  try {
    response = await api.createDraft(request);
    String draftId = response.draftId;
    Element link = new Element.a();
    link.setAttribute("href", "/draft.html?pod=" + draftId);
    link.text = "Continue to lobby";
    result.text = "";
    result.children.add(link);
  }
  catch (error) {
    result.text = "Failed to get link.";
  }
}