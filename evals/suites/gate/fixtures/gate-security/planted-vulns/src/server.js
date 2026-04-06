const express = require("express");
const path = require("path");
const sqlite3 = require("sqlite3");

const app = express();

// VULNERABILITY 1: Hardcoded API key in source code
// gitleaks:allow (intentionally planted for eval fixture)
const API_KEY = "sk-live-abc123def456ghi789jkl012mno345pqr678";

function authenticate(req, res, next) {
  if (req.headers.authorization === API_KEY) {
    next();
  } else {
    res.status(401).json({ error: "Unauthorized" });
  }
}

app.use(authenticate);

const db = new sqlite3.Database(":memory:");

// VULNERABILITY 2: SQL injection via string concatenation
app.get("/users", (req, res) => {
  const name = req.query.name;
  const query = "SELECT * FROM users WHERE name = '" + name + "'";
  db.all(query, (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
    } else {
      res.json(rows);
    }
  });
});

// VULNERABILITY 3: Path traversal — no validation on filename
app.get("/files/:filename", (req, res) => {
  const filePath = path.join(__dirname, "data", req.params.filename);
  res.sendFile(filePath);
});

module.exports = app;
