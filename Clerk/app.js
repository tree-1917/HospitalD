const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const { Pool } = require("pg");
const axios = require("axios");

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(express.json());

const pool = new Pool({
  host: process.env.POSTGRES_HOST || "postgres",
  database: process.env.POSTGRES_DB || "hospital",
  user: process.env.POSTGRES_USER || "hospital",
  password: process.env.POSTGRES_PASSWORD || "hospital123",
  port: 5432,
});

const OPA_URL =
  process.env.OPA_URL || "http://opa:8181/v1/data/hospital/auth/allow";

// =================================================== //
// Logger Middleware
// =================================================== //
function logRequest(req, res, next) {
  const start = Date.now();
  const timestamp = new Date().toISOString();

  res.on("finish", () => {
    const duration = Date.now() - start;
    console.log(
      `[${timestamp}] ${req.method} ${req.path} | ` +
      `role=${req.headers["x-user-role"] || "none"} | ` +
      `status=${res.statusCode} | ${duration}ms | ` +
      `ip=${req.ip || req.connection.remoteAddress}`,
    );
  });
  next();
}
app.use(logRequest);

// =================================================== //
// OPA Auth Helper
// =================================================== //
async function checkOpa(userRole, method, path) {
  console.log(`[OPA CHECK] role=${userRole} method=${method} path=${path}`);
  try {
    const { data } = await axios.post(
      OPA_URL,
      { input: { user: { role: userRole }, method, path } },
      { timeout: 2000 },
    );
    console.log(`[OPA RESULT] allowed=${data.result}`);
    return data.result === true;
  } catch (e) {
    console.error("[OPA ERROR]", e.message);
    return false;
  }
}

// =================================================== //
// Health Check
// =================================================== //
app.get("/healthz", async (req, res) => {
  console.log("[HEALTH] Checking database connection...");
  let dbStatus = "connected";
  try {
    await pool.query("SELECT 1");
    console.log("[HEALTH] Database OK");
  } catch (err) {
    dbStatus = `error: ${err.message}`;
    console.error("[HEALTH] Database failed:", err.message);
  }

  res.json({
    service: "clerk-app",
    status: "healthy",
    database: dbStatus,
    timestamp: new Date().toISOString(),
  });
});

// =================================================== //
// Clerk Routes: /hospital/clerk/*
// =================================================== //

// Clerk lists all recipes with money flow summary
app.get("/hospital/clerk/recipes", async (req, res) => {
  const userRole = req.headers["x-user-role"] || "anonymous";
  console.log(`[CLERK] List recipes request | role=${userRole}`);

  if (!(await checkOpa(userRole, "GET", "/hospital/clerk/recipes"))) {
    console.log(`[CLERK] DENIED by OPA for role=${userRole}`);
    return res.status(403).json({ error: "Forbidden by OPA" });
  }

  try {
    console.log(`[DB] Fetching all recipes with money flow...`);
    const { rows: recipes } = await pool.query(`
      SELECT 
        r.id, r.title, r.price, r.status, r.created_at,
        d.username as doctor, p.username as patient
      FROM recipes r
      JOIN doctors d ON r.doctor_id = d.id
      JOIN patients p ON r.patient_id = p.id
      ORDER BY r.created_at DESC
    `);

    // Money flow summary
    const { rows: summary } = await pool.query(`
      SELECT 
        COUNT(*) as total_recipes,
        COALESCE(SUM(CASE WHEN status = 'paid' THEN price ELSE 0 END), 0) as total_paid,
        COALESCE(SUM(CASE WHEN status = 'pending' THEN price ELSE 0 END), 0) as total_pending,
        COALESCE(SUM(CASE WHEN status = 'cancelled' THEN price ELSE 0 END), 0) as total_cancelled
      FROM recipes
    `);

    const flowData = {
      event: "recipes-listed",
      recipes: recipes,
      summary: summary[0],
      count: recipes.length,
      timestamp: new Date().toISOString(),
    };

    // Realtime emit to subscribed clerks
    io.to("clerks").emit("money-flow", flowData);
    console.log(`[SOCKET] Emitted recipes-listed to clerks room`);

    res.json(flowData);
  } catch (err) {
    console.error(`[ERROR] Failed to list recipes:`, err.message);
    res.status(500).json({ error: err.message });
  }
});

// Clerk views money flow dashboard summary
app.get("/hospital/clerk/flow", async (req, res) => {
  const userRole = req.headers["x-user-role"] || "anonymous";
  console.log(`[CLERK] Flow dashboard request | role=${userRole}`);

  if (!(await checkOpa(userRole, "GET", "/hospital/clerk/flow"))) {
    return res.status(403).json({ error: "Forbidden by OPA" });
  }

  try {
    const { rows } = await pool.query(`
      SELECT 
        status,
        COUNT(*) as count,
        COALESCE(SUM(price), 0) as total
      FROM recipes
      GROUP BY status
      ORDER BY status
    `);

    const { rows: daily } = await pool.query(`
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as recipes_count,
        COALESCE(SUM(price), 0) as daily_total
      FROM recipes
      WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
      GROUP BY DATE(created_at)
      ORDER BY date DESC
    `);

    res.json({
      by_status: rows,
      daily_summary: daily,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error(`[ERROR] Flow dashboard failed:`, err.message);
    res.status(500).json({ error: err.message });
  }
});

// =================================================== //
// Shared Recipes: /hospital/recipes
// Clerk: PUT (update status only)
// =================================================== //

app.put("/hospital/recipes", async (req, res) => {
  const userRole = req.headers["x-user-role"] || "anonymous";
  console.log(`[RECIPES] Update request | role=${userRole}`);

  if (!(await checkOpa(userRole, "PUT", "/hospital/recipes"))) {
    console.log(`[RECIPES] DENIED by OPA for role=${userRole}`);
    return res.status(403).json({ error: "Forbidden by OPA" });
  }

  console.log(`[RECIPES] ALLOWED by OPA | body=`, req.body);

  try {
    const { recipe_id, status } = req.body;

    if (!recipe_id || !status) {
      return res.status(400).json({ error: "Missing recipe_id or status" });
    }

    console.log(`[DB] Updating recipe ${recipe_id} -> status=${status}`);

    const { rows } = await pool.query(
      "UPDATE recipes SET status = $1 WHERE id = $2 RETURNING *",
      [status, recipe_id],
    );

    if (rows.length === 0) {
      console.log(`[DB] Recipe ${recipe_id} not found`);
      return res.status(404).json({ error: "Recipe not found" });
    }

    const updated = rows[0];
    console.log(`[DB] Recipe updated:`, updated);

    // Get money flow summary
    console.log(`[DB] Fetching money flow summary...`);
    const { rows: summary } = await pool.query(`
      SELECT 
        COUNT(*) as total_recipes,
        COALESCE(SUM(CASE WHEN status = 'paid' THEN price ELSE 0 END), 0) as total_paid,
        COALESCE(SUM(CASE WHEN status = 'pending' THEN price ELSE 0 END), 0) as total_pending,
        COALESCE(SUM(CASE WHEN status = 'cancelled' THEN price ELSE 0 END), 0) as total_cancelled
      FROM recipes
    `);

    const flowData = {
      event: "money-flow-update",
      updated_recipe: updated,
      summary: summary[0],
      timestamp: new Date().toISOString(),
    };

    console.log(`[SOCKET] Emitting money-flow event to clerks`);
    io.to("clerks").emit("money-flow", flowData);

    console.log(`[RESPONSE] Sending flow data`);
    res.json(flowData);
  } catch (err) {
    console.error(`[ERROR] Recipe update failed:`, err.message);
    res.status(500).json({ error: err.message });
  }
});

// =================================================== //
// Socket.IO Realtime
// =================================================== //
io.on("connection", (socket) => {
  console.log(`[SOCKET] Client connected: ${socket.id}`);

  socket.on("subscribe-flow", () => {
    socket.join("clerks");
    console.log(`[SOCKET] ${socket.id} subscribed to money flow`);
    socket.emit("subscribed", { room: "clerks", status: "ok" });
  });

  socket.on("unsubscribe-flow", () => {
    socket.leave("clerks");
    console.log(`[SOCKET] ${socket.id} unsubscribed from money flow`);
  });

  socket.on("disconnect", () => {
    console.log(`[SOCKET] Client disconnected: ${socket.id}`);
  });
});

// =================================================== //
// Start Server
// =================================================== //
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`[START] Clerk App with Socket.IO on port ${PORT}`);
  console.log(`[START] OPA URL: ${OPA_URL}`);
  console.log(
    `[START] Postgres: ${process.env.POSTGRES_HOST || "postgres"}:${process.env.POSTGRES_DB || "hospital"}`,
  );
});
