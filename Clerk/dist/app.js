const express = require("express");
const { Pool } = require("pg");
const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

const pool = new Pool({
  host: "postgres",
  database: "hospital",
  user: "hospital",
  password: "hospital123",
  port: 5432,
});

// INFO: Create Health Check endpoint
app.get("/healthz", async (req, res) => {
  let dbStatus = "connected";
  try {
    await pool.query("SELECT 1");
  } catch (err) {
    dbStatus = `error: ${err.message}`;
  }
  res.status(200).json({
    service: "clerk-app",
    status: "healthy",
    database: dbStatus,
    timestamp: new Date().toISOString(),
  });
});

app.listen(port, () => {
  console.log(`Clerk App listening on port ${port}`);
});
