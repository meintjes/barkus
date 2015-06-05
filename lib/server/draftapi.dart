library draft.server;

import 'package:rpc/rpc.dart';
import 'package:draft/common/messages.dart';
import 'package:draft/server/internal.dart' as internal;

@ApiClass(name: 'draftApi', version: 'v1')
class DraftApi {
  DraftApi();

  // Creates a draft.
  @ApiMethod(method: "POST", path: "create")
  CreateResponse createDraft(CreateRequest request) {
    CreateResponse response = new CreateResponse();
    response.draftId = internal.create(request.sets, request.drafters);
    return response;
  }
}