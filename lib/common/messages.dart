library draft.messages;

const int SERVER_PORT = 80;
const int MIN_DRAFTERS = 1;
const int MAX_DRAFTERS = 12;

/**
 * Classes used for HTTP messages in draft creation.
 */
class CreateRequest {
  List<int> sets;
  int drafters;

  CreateRequest() : sets = new List<int>();
}

class CreateResponse {
  String draftId;
  
  CreateResponse();
}