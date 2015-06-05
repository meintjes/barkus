import 'dart:html';
import 'dart:async';
import 'package:draft/common/messages.dart';
import 'package:draft/common/sets/sets.dart';
import 'package:draft/client/draftapi.dart';
import 'package:http/browser_client.dart';

final BrowserClient client = new BrowserClient();
DraftApi api;

void main() {
  api = new DraftApi(client, rootUrl: "${window.location.protocol}//${window.location.hostname}:$SERVER_PORT/");
  
  for (var elem in querySelectorAll("#pack")) {
    for (CardSet set in supportedSets) {
      Element option = new Element.option();
      option.text = set.longname;
      elem.children.add(option);
    }
  }

  querySelector("#create").onSubmit.listen(createPod);
}

Future createPod(Event e) async {
  e.preventDefault();

  CreateRequest request = new CreateRequest();

  // Prepare the creation request, trying to add the packs the user indicated.
  List<Element> packs = querySelectorAll("#pack");
  for (var elem in packs) {
    int selectedPack = (elem as SelectElement).selectedIndex - 1;
    if (selectedPack < 0) {
      return;
    }
    else {
      request.sets.add(selectedPack);
    }

    InputElement drafters = querySelector("#drafters");
    try {
      request.drafters = int.parse(drafters.value);
    }
    catch (error) {
      drafters.value = "8";
      request.drafters = 8;
    }
  }
  
  // The dropdown selections are valid. Prepare to actually submit the request.
  querySelector("#button").setAttribute("disabled", "true");
  querySelector("#drafters").setAttribute("disabled", "true");
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