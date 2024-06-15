from flask import Flask, render_template, send_file
import pandas as pd

app = Flask(__name__)

@app.route('/')
def front_page():
    return render_template('front_page.html')

@app.route('/dashboard')
def dashboard():
    df = pd.read_csv('query_result.csv')
    data = df.to_dict(orient='records')
    return render_template('index.html', data=data)

if __name__ == '__main__':
    app.run(debug=True)
