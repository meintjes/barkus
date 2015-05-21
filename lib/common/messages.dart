library draft.messages;

/**
 * Classes used for HTTP messages in draft creation.
 */
class CreateRequest {
  List<int> sets;

  CreateRequest() : sets = new List<int>();
}

class CreateResponse {
  String draftId;
  
  CreateResponse();
}