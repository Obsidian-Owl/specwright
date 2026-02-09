#!/usr/bin/env node

/**
 * Specwright Session Start Hook
 * Loads constitution principles and active epic context at session start.
 * Outputs context information for the LLM to use during the session.
 */

import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const cwd = process.env.CLAUDE_CWD || process.cwd();
const specDir = join(cwd, '.specwright');

// Check if Specwright is initialized in this project
if (!existsSync(specDir)) {
  // Silent exit — Specwright not initialized in this project
  process.exit(0);
}

const output = [];
output.push('=== Specwright Session ===');
output.push('');

// Load constitution principles
const constitutionPath = join(specDir, 'memory', 'constitution.md');
if (existsSync(constitutionPath)) {
  try {
    const constitution = readFileSync(constitutionPath, 'utf-8');
    const principles = constitution.match(/^## Principle .+$/gm);
    if (principles && principles.length > 0) {
      output.push('CONSTITUTION PRINCIPLES:');
      principles.forEach(p => output.push(`  ${p.replace('## ', '')}`));
      output.push('');
    }
  } catch {
    // Silent — don't fail session start for constitution read errors
  }
}

// Load active epic from workflow state
const workflowPath = join(specDir, 'state', 'workflow.json');
if (existsSync(workflowPath)) {
  try {
    const workflow = JSON.parse(readFileSync(workflowPath, 'utf-8'));
    if (workflow.currentEpic && workflow.currentEpic.status !== 'complete') {
      output.push(`ACTIVE EPIC: ${workflow.currentEpic.id} — ${workflow.currentEpic.name}`);
      output.push(`  Status: ${workflow.currentEpic.status}`);
      output.push(`  Branch: ${workflow.currentEpic.branch || 'unknown'}`);
      output.push(`  Spec: ${workflow.currentEpic.specDir}`);
      output.push('');

      // Show gate status if any gates have been run
      if (workflow.gates) {
        const gateEntries = Object.entries(workflow.gates);
        const hasRun = gateEntries.some(([, g]) => g.status !== 'pending');
        if (hasRun) {
          output.push('GATE STATUS:');
          gateEntries.forEach(([name, gate]) => {
            output.push(`  ${name}: ${gate.status}`);
          });
          output.push('');
        }
      }
    }
  } catch {
    // Silent — don't fail session start for workflow read errors
  }
}

// Load config for build/test commands
const configPath = join(specDir, 'config.json');
if (existsSync(configPath)) {
  try {
    const config = JSON.parse(readFileSync(configPath, 'utf-8'));
    if (config.commands) {
      output.push('COMMANDS:');
      if (config.commands.build) output.push(`  Build: ${config.commands.build}`);
      if (config.commands.test) output.push(`  Test: ${config.commands.test}`);
      output.push('');
    }
  } catch {
    // Silent
  }
}

// Check learning queue size
const queuePath = join(specDir, 'state', 'learning-queue.jsonl');
if (existsSync(queuePath)) {
  try {
    const content = readFileSync(queuePath, 'utf-8').trim();
    if (content) {
      const count = content.split('\n').length;
      if (count >= 3) {
        output.push(`LEARNING QUEUE: ${count} entries pending review. Run /specwright:learn-review`);
        output.push('');
      }
    }
  } catch {
    // Silent
  }
}

// Only output if we have meaningful content beyond the header
if (output.length > 2) {
  console.log(output.join('\n'));
}
