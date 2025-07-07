from flask import Flask, jsonify, make_response

app = Flask(__name__)

@app.route('/')
def home():
    body = {
        "status": "success",
        "message": "Welcome to the Flask server!"
    }
    response = make_response(jsonify(body), 200)
    response.headers['Content-Type'] = 'application/json'
    response.headers['X-Custom-Header'] = 'MyApp'
    return response


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=30000, debug=True)
