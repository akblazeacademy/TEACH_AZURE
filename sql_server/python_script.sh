#!/bin/bash
set -e

echo "=============================="
echo " Azure Python + SQL Setup"
echo " Ubuntu 24.04"
echo "=============================="

APP_DIR="/home/azure/pythonapp"
VENV_DIR="$APP_DIR/venv"
APP_FILE="$APP_DIR/app.py"
KEYVAULT_NAME="kv-app-demo24"

echo "[1/7] Updating OS..."
sudo apt update -y

echo "[2/7] Installing base packages..."
sudo apt install -y \
  curl gnupg python3-pip python3-venv \
  unixodbc unixodbc-dev

echo "[3/7] Installing Microsoft ODBC Driver 18..."

curl https://packages.microsoft.com/keys/microsoft.asc \
| sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] \
https://packages.microsoft.com/ubuntu/24.04/prod noble main" \
| sudo tee /etc/apt/sources.list.d/microsoft-prod.list

sudo apt update -y
sudo ACCEPT_EULA=Y apt install -y msodbcsql18

echo "[4/7] Creating application directory..."
mkdir -p $APP_DIR
cd $APP_DIR

echo "[5/7] Creating Python virtual environment..."
python3 -m venv venv

source venv/bin/activate

echo "[6/7] Installing Python dependencies inside venv..."
pip install --upgrade pip
pip install flask pyodbc azure-identity azure-keyvault-secrets

echo "[7/7] Creating Flask application..."

cat <<EOF > $APP_FILE
from flask import Flask, request
import pyodbc
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

app = Flask(__name__)

KEY_VAULT_NAME = "${KEYVAULT_NAME}"
KV_URI = f"https://{KEY_VAULT_NAME}.vault.azure.net"

credential = DefaultAzureCredential()
client = SecretClient(vault_url=KV_URI, credential=credential)

conn_str = client.get_secret("sql-conn-string").value

def get_conn():
    return pyodbc.connect(conn_str)

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        name = request.form.get("name")
        email = request.form.get("email")

        conn = get_conn()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO user_data (name, email) VALUES (?, ?)",
            (name, email)
        )
        conn.commit()
        conn.close()

        return "<h3>✅ Data stored in Azure SQL Database</h3>"

    return """
    <h2>User Entry Form</h2>
    <form method="post">
        Name:<br><input type="text" name="name"><br><br>
        Email:<br><input type="text" name="email"><br><br>
        <input type="submit">
    </form>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=30080)
EOF

chmod +x $APP_FILE

echo "=============================="
echo " SETUP COMPLETED SUCCESSFULLY"
echo "=============================="
echo ""
echo "Next steps:"
echo "1) source $VENV_DIR/bin/activate"
echo "2) python app.py"
echo "3) Open browser: http://<VM_PUBLIC_IP>:30080"
