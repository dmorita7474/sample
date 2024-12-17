const content503 = `<!DOCTYPE html>
<html>
    <head>
        <title>Out of Service</title>
        <meta charset="UTF-8">
    </head>
    <body>
        <p>メンテナンス中です</p>
    </body>
</html>
`

const content404 = `<!DOCTYPE html>
<html>
    <head>
        <title>Not Found</title>
        <meta charset="UTF-8">
    </head>
    <body>
        <p>ページがみつかりません。</p>
    </body>
</html>
`
function handler(event) {
    let response = event.response;
    // 特定のエラーの時、bodyを固定ページで上書き
    if (response.statusCode === 503) {
        response.body = {
            "encoding" : "text",
            "data" : content503
        }
    } else if (response.statusCode === 404) {
        response.body = {
            "encoding" : "text",
            "data" : content404
        }
    }
    return response
}