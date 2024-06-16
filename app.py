from flask import Flask, render_template, jsonify
import pandas as pd

app = Flask(__name__)

@app.route('/')
def front_page():
    return render_template('front_page.html')

@app.route('/dashboard')
def dashboard():
    return render_template('dashboard.html')

@app.route('/api/data')
def data():
    # Ensure the time column is in a format that Chart.js can understand
    df = pd.read_csv('query_result.csv')
    df['time'] = pd.to_datetime(df['time'])
    
    # Interpolate missing values and then fill NaNs
    df = df.set_index('time').resample('D').interpolate().fillna(0).reset_index()
    df['time'] = df['time'].dt.strftime('%Y-%m-%dT%H:%M:%S')

    data = {
        "time": df['time'].tolist(),
        "supply": df['supply'].tolist(),
        "liquidity": df['liquidity'].tolist(),
        "ratio": df['ratio'].tolist()
    }
    return jsonify(data)

if __name__ == '__main__':
    app.run(debug=True)
