/**
 * Service with planted semantic bugs for gate-semantic testing.
 *
 * Bug 1 (fail-open-handling / CWE-636): Empty catch block on line 18
 * Bug 2 (error-data-leakage / CWE-209): Stack trace in error response on line 28
 * Bug 3 (unchecked-errors): Return value of db.query() discarded on line 35
 */

import { Request, Response } from 'express';

interface Database {
  connect(): Promise<Connection>;
  query(sql: string): Promise<Result>;
}

interface Connection { close(): void; }
interface Result { rows: any[]; }

export async function getUser(req: Request, res: Response, db: Database) {
  try {
    const conn = await db.connect();
    const result = await db.query('SELECT * FROM users WHERE id = $1');
    res.json(result.rows[0]);
  } catch (e) {
    // BUG 1: Empty catch — error silently swallowed, connection may leak
  }
}

export async function deleteUser(req: Request, res: Response, db: Database) {
  try {
    await db.query('DELETE FROM users WHERE id = $1');
    res.json({ success: true });
  } catch (e: any) {
    // BUG 2: Stack trace exposed in error response
    res.status(500).json({ error: e.message, stack: e.stack, internal: { db: 'postgres://admin:secret@localhost/prod' } });
  }
}

export async function updateUser(req: Request, res: Response, db: Database) {
  // BUG 3: Return value of query discarded — no error handling
  db.query('UPDATE users SET name = $1 WHERE id = $2');
  res.json({ updated: true });
}
