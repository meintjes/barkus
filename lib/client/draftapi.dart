library draft.draftApi.client;

import 'dart:core' as core;
import 'dart:collection' as collection;
import 'dart:async' as async;
import 'dart:convert' as convert;

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:draft/common/messages.dart';
export 'package:_discoveryapis_commons/_discoveryapis_commons.dart' show
    ApiRequestError, DetailedApiRequestError;

const core.String USER_AGENT = 'dart-api-client draftApi/v1';

class DraftApi {

  final commons.ApiRequester _requester;

  DraftApi(http.Client client, {core.String rootUrl: "http://localhost:8080/", core.String servicePath: "draftApi/v1/"}) :
      _requester = new commons.ApiRequester(client, rootUrl, servicePath, USER_AGENT);

  /**
   * [request] - The metadata request object.
   *
   * Request parameters:
   *
   * Completes with a [CreateResponse].
   *
   * Completes with a [commons.ApiRequestError] if the API endpoint returned an
   * error.
   *
   * If the used [http.Client] completes with an error when making a REST call,
   * this method will complete with the same error.
   */
  async.Future<CreateResponse> createDraft(CreateRequest request) {
    var _url = null;
    var _queryParams = new core.Map();
    var _uploadMedia = null;
    var _uploadOptions = null;
    var _downloadOptions = commons.DownloadOptions.Metadata;
    var _body = null;

    if (request != null) {
      _body = convert.JSON.encode(CreateRequestFactory.toJson(request));
    }

    _url = 'create';

    var _response = _requester.request(_url,
                                       "POST",
                                       body: _body,
                                       queryParams: _queryParams,
                                       uploadOptions: _uploadOptions,
                                       uploadMedia: _uploadMedia,
                                       downloadOptions: _downloadOptions);
    return _response.then((data) => CreateResponseFactory.fromJson(data));
  }

}



class CreateRequestFactory {
  static CreateRequest fromJson(core.Map _json) {
    var message = new CreateRequest();
    if (_json.containsKey("sets")) {
      message.sets = _json["sets"];
    }
    return message;
  }

  static core.Map toJson(CreateRequest message) {
    var _json = new core.Map();
    if (message.sets != null) {
      _json["sets"] = message.sets;
    }
    return _json;
  }
}

class CreateResponseFactory {
  static CreateResponse fromJson(core.Map _json) {
    var message = new CreateResponse();
    if (_json.containsKey("draftId")) {
      message.draftId = _json["draftId"];
    }
    return message;
  }

  static core.Map toJson(CreateResponse message) {
    var _json = new core.Map();
    if (message.draftId != null) {
      _json["draftId"] = message.draftId;
    }
    return _json;
  }
}

