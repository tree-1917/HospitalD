from flask import Flask, jsonify, request
import os
import datetime
import psycopg2
import requests

app = Flask(__name__)

OPA_URL = os.getenv("OPA_URL", "http://opa:8181/v1/data/hospital/auth/allow")

def get_db():
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "postgres"),
        database=os.getenv("POSTGRES_DB", "hospital"),
        user=os.getenv("POSTGRES_USER", "hospital"),
        password=os.getenv("POSTGRES_PASSWORD", "hospital123")
    )

def check_opa(user_role, method, path):
    """Send authz request to OPA with exact route"""
    payload = {
        "input": {
            "user": {"role": user_role},
            "method": method,
            "path": path
        }
    }
    try:
        r = requests.post(OPA_URL, json=payload, timeout=2)
        return r.json().get("result", False)
    except Exception as e:
        print(f"[OPA ERROR] {e}")
        return False

# =================================================== #
# Health Check
# =================================================== #
@app.route("/healthz")
def health():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"

    return jsonify({
        "service": "doctor-app",
        "status": "healthy",
        "database": db_status,
        "timestamp": datetime.datetime.utcnow().isoformat()
    })

# =================================================== #
# Doctor Routes: /hospital/doctor/*
# =================================================== #

@app.route("/hospital/doctor/patients", methods=["GET"])
def doctor_patients():
    """Doctor lists their patients"""
    user_role = request.headers.get("X-User-Role", "anonymous")
    
    if not check_opa(user_role, "GET", "/hospital/doctor/patients"):
        return jsonify({"error": "Forbidden by OPA"}), 403

    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, username, email, summary 
        FROM patients 
        WHERE doctor_id = 1
        ORDER BY created_at DESC
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return jsonify({
        "patients": [
            {"id": r[0], "username": r[1], "email": r[2], "summary": r[3]} 
            for r in rows
        ]
    })

@app.route("/hospital/doctor/patients/<int:patient_id>", methods=["GET"])
def doctor_patient_detail(patient_id):
    """Doctor views single patient details"""
    user_role = request.headers.get("X-User-Role", "anonymous")
    
    if not check_opa(user_role, "GET", f"/hospital/doctor/patients/{patient_id}"):
        return jsonify({"error": "Forbidden by OPA"}), 403

    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        SELECT p.id, p.username, p.email, p.summary, p.created_at, d.username as doctor
        FROM patients p
        LEFT JOIN doctors d ON p.doctor_id = d.id
        WHERE p.id = %s
    """, (patient_id,))
    row = cur.fetchone()
    cur.close()
    conn.close()

    if not row:
        return jsonify({"error": "Patient not found"}), 404

    return jsonify({
        "id": row[0],
        "username": row[1],
        "email": row[2],
        "summary": row[3],
        "created_at": row[4],
        "doctor": row[5]
    })

# =================================================== #
# Shared Recipes: /hospital/recipes
# Doctor: GET (list), POST (create)
# =================================================== #

@app.route("/hospital/recipes", methods=["GET"])
def list_recipes():
    """List all recipes — accessible by doctor"""
    user_role = request.headers.get("X-User-Role", "anonymous")
    
    if not check_opa(user_role, "GET", "/hospital/recipes"):
        return jsonify({"error": "Forbidden by OPA"}), 403

    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        SELECT r.id, r.title, r.price, r.status, r.created_at,
               d.username as doctor, p.username as patient
        FROM recipes r
        JOIN doctors d ON r.doctor_id = d.id
        JOIN patients p ON r.patient_id = p.id
        ORDER BY r.created_at DESC
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return jsonify({
        "recipes": [
            {
                "id": r[0], "title": r[1], "price": str(r[2]),
                "status": r[3], "created_at": r[4],
                "doctor": r[5], "patient": r[6]
            } for r in rows
        ],
        "count": len(rows)
    })

@app.route("/hospital/recipes", methods=["POST"])
def create_recipe():
    """Doctor creates a new recipe"""
    user_role = request.headers.get("X-User-Role", "anonymous")
    
    if not check_opa(user_role, "POST", "/hospital/recipes"):
        return jsonify({"error": "Forbidden by OPA"}), 403

    data = request.get_json() or {}
    
    # Validate required fields
    required = ["doctor_id", "patient_id", "title", "price"]
    for field in required:
        if field not in data:
            return jsonify({"error": f"Missing field: {field}"}), 400

    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO recipes (doctor_id, patient_id, title, price, status) 
        VALUES (%s, %s, %s, %s, %s) 
        RETURNING id, doctor_id, patient_id, title, price, status, created_at
    """, (
        data.get("doctor_id"), 
        data.get("patient_id"), 
        data.get("title"), 
        data.get("price"), 
        "pending"
    ))
    row = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()

    return jsonify({
        "id": row[0],
        "doctor_id": row[1],
        "patient_id": row[2],
        "title": row[3],
        "price": str(row[4]),
        "status": row[5],
        "created_at": row[6]
    }), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
