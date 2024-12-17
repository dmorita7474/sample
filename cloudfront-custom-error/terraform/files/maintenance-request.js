function handler(event) {
    let request = event.request;
    request.uri = '/error500.html';
    return request
}
