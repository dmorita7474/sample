'use strict';

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

exports.handler = (event, context, callback) => {
    const response = event.Records[0].cf.response;
    if (response.status === "404"){
        response.headers['content-type'] = [{
            key: 'Content-Type',
            value: 'text/html; charset=UTF-8'
        }];
        response.body = content404;
    } else if (response.status === "503"){
     response.headers['content-type'] = [{
            key: 'Content-Type',
            value: 'text/html; charset=UTF-8'
        }];
        response.body = content503;
    }
    callback(null, response);
};