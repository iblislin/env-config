from flask import Flask, request
app = Flask(__name__)

@app.route("/", methods=['POST'])
def hello():
    print(request.form)
    return 'ok'
