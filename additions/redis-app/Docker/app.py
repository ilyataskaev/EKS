from flask import Flask, request, render_template_string
import redis, os, socket

app = Flask(__name__)

try:
    redis_host = os.environ['REDIS_HOST']
except KeyError:
    print("Variable REDIS_HOST not found")
    exit(1)

# Connect to Redis server
redis_client = redis.StrictRedis(host=redis_host, port=6379, db=0)

@app.route('/redis-client', methods=['GET', 'POST'])
def index():
    set_message = ''
    get_result = ''

    if request.method == 'POST':
        if 'set_data' in request.form:
            # Handling Set Data
            key = request.form['set_key']
            value = request.form['set_value']
            if key and value:
                redis_client.set(key, value)
                set_message = 'Data set successfully'
            else:
                set_message = 'Both key and value are required for setting data'

        elif 'get_data' in request.form:
            # Handling Get Data
            key = request.form['get_key']
            if key:
                value = redis_client.get(key)
                if value:
                    get_result = value.decode('utf-8')
                else:
                    get_result = 'Data not found for key: ' + key
            else:
                get_result = 'Key is required for getting data'

    return render_template_string("""
        <html>
            <head>
                <style>
                    body {
                        font-family: Arial, sans-serif;
                        background-color: #f4f4f4;
                        padding: 20px;
                    }
                    h2, h3 {
                        color: #333;
                    }
                    form {
                        margin-bottom: 20px;
                        background: #fff;
                        padding: 15px;
                        border-radius: 8px;
                        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                    }
                    input[type=text] {
                        width: 100%;
                        padding: 8px;
                        margin: 8px 0;
                        display: inline-block;
                        border: 1px solid #ccc;
                        border-radius: 4px;
                        box-sizing: border-box;
                    }
                    input[type=submit] {
                        width: 100%;
                        background-color: #4CAF50;
                        color: white;
                        padding: 14px 20px;
                        margin: 8px 0;
                        border: none;
                        border-radius: 4px;
                        cursor: pointer;
                    }
                    input[type=submit]:hover {
                        background-color: #45a049;
                    }
                    .message {
                        color: #31708f;
                        background-color: #d9edf7;
                        border-color: #bce8f1;
                        padding: 10px;
                        border-radius: 4px;
                        margin-bottom: 20px;
                    }
                </style>
            <title>Redis Data Manager</title>
            </head>
            <body>
                <h2>Redis Data Manager</h2>
                <h3>Set Data</h3>
                <form method="POST">
                    Key: <input type="text" name="set_key"><br>
                    Value: <input type="text" name="set_value"><br>
                    <input type="submit" name="set_data" value="Set Data">
                </form>
                <p>{{ set_message }}</p>

                <h3>Get Data</h3>
                <form method="POST">
                    Key: <input type="text" name="get_key"><br>
                    <input type="submit" name="get_data" value="Get Data">
                </form>
                <p>Value: {{ get_result }}</p>
                <div>
                    <h3>Container Information</h3>
                    <p>Hostname: {{ hostname }}</p>
                    <p>IP Address: {{ ip_address }}</p>
                </div>
            </body>
        </html>
    """, set_message=set_message, get_result=get_result, hostname=socket.gethostname(), ip_address=socket.gethostbyname(socket.gethostname()))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
