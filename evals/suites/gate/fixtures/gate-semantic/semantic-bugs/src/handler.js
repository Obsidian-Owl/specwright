const db = require("./db");

async function createOrder(req, res) {
  const conn = await db.getConnection();

  try {
    const order = await conn.query(
      "INSERT INTO orders (user_id, total) VALUES (?, ?)",
      [req.body.userId, req.body.total]
    );
    res.json({ id: order.insertId });
  } catch (e) {
    // BUG 1 (CWE-636): Empty catch block — error is silently swallowed,
    // request hangs or returns undefined instead of an error response
  }

  // BUG 3 (resource-lifecycle): Connection is only released on the success
  // path. If the catch block above fires, conn.release() is never called.
  conn.release();
}

async function getOrder(req, res) {
  try {
    const order = await db.query("SELECT * FROM orders WHERE id = ?", [
      req.params.id,
    ]);
    res.json(order);
  } catch (e) {
    // BUG 2 (CWE-209): Stack trace exposed in error response
    res.status(500).json({
      error: e.message,
      stack: e.stack,
      query: "SELECT * FROM orders WHERE id = " + req.params.id,
    });
  }
}

module.exports = { createOrder, getOrder };
