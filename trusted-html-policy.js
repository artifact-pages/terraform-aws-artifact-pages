function handler(event) {
  var request = event.request;
  var response = event.response;
  var headers = response.headers;
  var segments = request.uri.split("/");
  var hostHeader = request.headers.host;
  var host = hostHeader && hostHeader.value;
  var resourcePrefix = "";

  if (!host) {
    return response;
  }

  if (segments[1] === "_artifacts" && segments[2] && segments.length >= 4) {
    resourcePrefix = "https://" + host + "/_artifacts/" + segments[2] + "/";
  } else if (
    segments[1] === "_previews" &&
    segments[2] &&
    segments[3] &&
    segments[4] === "files" &&
    segments.length >= 6
  ) {
    resourcePrefix =
      "https://" + host + "/_previews/" + segments[2] + "/" + segments[3] + "/files/";
  }

  if (!resourcePrefix) {
    return response;
  }

  headers["content-security-policy"] = {
    value:
      "default-src " +
      resourcePrefix +
      " https: data: blob:; script-src " +
      resourcePrefix +
      " https: 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' data: blob:; style-src " +
      resourcePrefix +
      " https: 'unsafe-inline' data: blob:",
  };
  headers["x-content-type-options"] = { value: "nosniff" };

  return response;
}
