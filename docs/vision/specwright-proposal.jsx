import { useState } from "react";

const sections = [
  {
    id: "overview",
    title: "Overview",
    icon: "⚡",
  },
  {
    id: "competitive",
    title: "Landscape",
    icon: "🗺️",
  },
  {
    id: "architecture",
    title: "Architecture",
    icon: "🏗️",
  },
  {
    id: "skills",
    title: "Skills",
    icon: "🔧",
  },
  {
    id: "compatibility",
    title: "Compatibility",
    icon: "🔌",
  },
  {
    id: "customisation",
    title: "Customisation",
    icon: "🎛️",
  },
  {
    id: "branding",
    title: "Branding",
    icon: "✨",
  },
  {
    id: "roadmap",
    title: "Roadmap",
    icon: "🗓️",
  },
];

const Badge = ({ children, variant = "default" }) => {
  const colors = {
    default: "bg-zinc-800 text-zinc-300 border-zinc-700",
    green: "bg-emerald-950 text-emerald-300 border-emerald-800",
    amber: "bg-amber-950 text-amber-300 border-amber-800",
    red: "bg-red-950 text-red-300 border-red-800",
    blue: "bg-sky-950 text-sky-300 border-sky-800",
    purple: "bg-violet-950 text-violet-300 border-violet-800",
  };
  return (
    <span
      className={`inline-block px-2 py-0.5 text-xs font-medium rounded border ${colors[variant]}`}
    >
      {children}
    </span>
  );
};

const Card = ({ children, className = "" }) => (
  <div
    className={`bg-zinc-900 border border-zinc-800 rounded-lg p-5 ${className}`}
  >
    {children}
  </div>
);

const CompetitorRow = ({ name, stars, gates, learning, wiring, compaction, customise, omc }) => (
  <tr className="border-b border-zinc-800 last:border-0">
    <td className="py-2 pr-4 font-medium text-zinc-200">{name}</td>
    <td className="py-2 px-2 text-center text-zinc-400">{stars}</td>
    <td className="py-2 px-2 text-center">{gates ? "✅" : "⬜"}</td>
    <td className="py-2 px-2 text-center">{learning ? "✅" : "⬜"}</td>
    <td className="py-2 px-2 text-center">{wiring ? "✅" : "⬜"}</td>
    <td className="py-2 px-2 text-center">{compaction ? "✅" : "⬜"}</td>
    <td className="py-2 px-2 text-center">{customise ? "✅" : "⬜"}</td>
    <td className="py-2 px-2 text-center">{omc ? "✅" : "⬜"}</td>
  </tr>
);

const SkillCard = ({ name, cmd, desc, phase, isNew }) => (
  <div className="bg-zinc-800/50 border border-zinc-700/50 rounded-md p-3 hover:border-amber-700/50 transition-colors">
    <div className="flex items-center gap-2 mb-1">
      <code className="text-amber-400 text-sm font-mono">/{cmd}</code>
      {isNew && <Badge variant="green">NEW</Badge>}
      <Badge variant={phase === "plan" ? "blue" : phase === "build" ? "purple" : phase === "ship" ? "green" : "default"}>
        {phase}
      </Badge>
    </div>
    <div className="text-zinc-200 font-medium text-sm">{name}</div>
    <div className="text-zinc-500 text-xs mt-1">{desc}</div>
  </div>
);

function OverviewSection() {
  return (
    <div className="space-y-6">
      <div className="border-l-2 border-amber-500 pl-4 py-1">
        <p className="text-zinc-300 text-lg leading-relaxed">
          <strong className="text-zinc-100">Specwright</strong> is a Claude Code & OpenCode plugin that brings{" "}
          <em>engineering discipline</em> to AI-assisted development. It implements a full
          spec-driven workflow with quality gates, evidence capture, learning loops, and
          compaction recovery — all language and framework agnostic.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <div className="text-2xl mb-2">📋</div>
          <h3 className="text-zinc-100 font-semibold mb-1">Spec-First</h3>
          <p className="text-zinc-400 text-sm">
            Every feature starts with a specification: user stories, architecture decisions,
            and scored task breakdown. No more "just build it" chaos.
          </p>
        </Card>
        <Card>
          <div className="text-2xl mb-2">🚦</div>
          <h3 className="text-zinc-100 font-semibold mb-1">Quality Gates</h3>
          <p className="text-zinc-400 text-sm">
            Five sequential gates — build, test, wiring, security, spec compliance — with
            evidence capture. PRs ship with proof, not promises.
          </p>
        </Card>
        <Card>
          <div className="text-2xl mb-2">🧠</div>
          <h3 className="text-zinc-100 font-semibold mb-1">Learns & Adapts</h3>
          <p className="text-zinc-400 text-sm">
            Captures failures, promotes patterns, builds project memory. The system gets
            smarter with every session. Survives context compaction.
          </p>
        </Card>
      </div>

      <Card className="border-amber-900/50">
        <h3 className="text-zinc-100 font-semibold mb-3">The Problem We're Solving</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <div className="text-red-400 font-medium mb-2">❌ Without Specwright</div>
            <ul className="text-zinc-400 space-y-1">
              <li>• AI optimises for "task done" not "feature works"</li>
              <li>• Fast delivery of broken, unwired code</li>
              <li>• Context loss during long sessions causes drift</li>
              <li>• Tests pass but features aren't connected</li>
              <li>• No evidence trail for what was verified</li>
              <li>• Every project re-invents the wheel</li>
            </ul>
          </div>
          <div>
            <div className="text-emerald-400 font-medium mb-2">✅ With Specwright</div>
            <ul className="text-zinc-400 space-y-1">
              <li>• Specs before implementation, always</li>
              <li>• Mandatory wiring verification catches orphaned code</li>
              <li>• Compaction recovery reloads full context</li>
              <li>• Evidence-based PRs with gate proof</li>
              <li>• Learning system that captures and promotes patterns</li>
              <li>• One install, customise once, works everywhere</li>
            </ul>
          </div>
        </div>
      </Card>

      <div className="text-zinc-500 text-sm italic">
        Born from real production experience building FinancialFusion — 40+ skills refined over months of
        daily use. Not a theoretical framework; a battle-tested workflow.
      </div>
    </div>
  );
}

function CompetitiveSection() {
  return (
    <div className="space-y-6">
      <p className="text-zinc-400">
        The spec-driven development space is heating up. Here's how Specwright compares to existing
        solutions — and where the gaps are that we uniquely fill.
      </p>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-zinc-700 text-zinc-400">
              <th className="text-left py-2 pr-4">Plugin</th>
              <th className="py-2 px-2 text-center">⭐</th>
              <th className="py-2 px-2 text-center text-xs">Quality Gates</th>
              <th className="py-2 px-2 text-center text-xs">Learning</th>
              <th className="py-2 px-2 text-center text-xs">Wiring</th>
              <th className="py-2 px-2 text-center text-xs">Compaction</th>
              <th className="py-2 px-2 text-center text-xs">Customise</th>
              <th className="py-2 px-2 text-center text-xs">OMC</th>
            </tr>
          </thead>
          <tbody>
            <CompetitorRow name="Spec-Flow" stars="~150" gates={false} learning={false} wiring={false} compaction={false} customise={false} omc={false} />
            <CompetitorRow name="cc-sdd" stars="~2.5k" gates={false} learning={false} wiring={false} compaction={false} customise={true} omc={false} />
            <CompetitorRow name="claude-pilot" stars="~300" gates={false} learning={false} wiring={false} compaction={false} customise={false} omc={false} />
            <CompetitorRow name="context-eng-kit" stars="~800" gates={true} learning={true} wiring={false} compaction={false} customise={false} omc={false} />
            <CompetitorRow name="spec-workflow" stars="~200" gates={false} learning={false} wiring={false} compaction={false} customise={false} omc={false} />
            <tr className="border-b border-amber-800/50 bg-amber-950/20">
              <td className="py-2 pr-4 font-bold text-amber-400">Specwright</td>
              <td className="py-2 px-2 text-center text-zinc-400">NEW</td>
              <td className="py-2 px-2 text-center">✅</td>
              <td className="py-2 px-2 text-center">✅</td>
              <td className="py-2 px-2 text-center">✅</td>
              <td className="py-2 px-2 text-center">✅</td>
              <td className="py-2 px-2 text-center">✅</td>
              <td className="py-2 px-2 text-center">✅</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Card>
          <h4 className="text-zinc-100 font-semibold mb-2">Key Differentiators</h4>
          <ul className="text-zinc-400 text-sm space-y-2">
            <li><strong className="text-amber-400">Evidence Pipeline:</strong> 5 sequential gates that capture proof into structured reports. PRs ship with evidence, not "trust me."</li>
            <li><strong className="text-amber-400">Wiring Verification:</strong> Static analysis + runtime checks. No other plugin catches orphaned code, broken import chains, or missing subscribers.</li>
            <li><strong className="text-amber-400">Learning System:</strong> Hook-captured failures → queue → review → promote to patterns.md. The project gets smarter.</li>
            <li><strong className="text-amber-400">Compaction Recovery:</strong> State file + auto-reload protocol. The only plugin that handles context loss gracefully.</li>
          </ul>
        </Card>
        <Card>
          <h4 className="text-zinc-100 font-semibold mb-2">Market Positioning</h4>
          <p className="text-zinc-400 text-sm mb-3">
            cc-sdd (2.5k stars) is the leader but focuses on the <em>spec phase</em> only.
            They do multi-agent, multi-language support well. Specwright goes deeper on the
            <em>execution and verification</em> side — the part where AI agents actually fail.
          </p>
          <p className="text-zinc-400 text-sm">
            Target audience: senior engineers and tech leads who've been burned by AI-generated
            code that compiles but doesn't integrate. Teams that need audit trails.
            Enterprise developers who need quality evidence.
          </p>
        </Card>
      </div>
    </div>
  );
}

function ArchitectureSection() {
  return (
    <div className="space-y-6">
      <p className="text-zinc-400">
        The plugin is structured as a single Claude Code marketplace plugin with a clear separation
        between the generic workflow engine and project-specific customisation.
      </p>

      <Card>
        <h4 className="text-zinc-100 font-semibold mb-3">Plugin Structure</h4>
        <pre className="text-xs text-zinc-300 font-mono leading-relaxed overflow-x-auto">{`specwright/
├── .claude-plugin/
│   ├── marketplace.json          # Marketplace registry
│   └── plugin.json               # Plugin metadata
├── skills/                       # Core workflow skills
│   ├── init/SKILL.md             # Project customisation wizard
│   ├── specify/SKILL.md          # Epic specification
│   ├── roadmap/SKILL.md          # Domain roadmap planning
│   ├── build/SKILL.md            # TDD implementation loop
│   ├── validate/SKILL.md         # Quality gates orchestrator
│   ├── ship/SKILL.md             # Evidence-based PR creation
│   ├── learn-review/SKILL.md     # Learning queue review
│   ├── learn-consolidate/SKILL.md # Pattern consolidation
│   ├── gate-build/SKILL.md       # Build & test gate
│   ├── gate-tests/SKILL.md       # Test quality gate
│   ├── gate-wiring/SKILL.md      # Integration verification gate
│   ├── gate-security/SKILL.md    # Security scan gate
│   └── gate-spec/SKILL.md        # Spec compliance gate
├── agents/                       # Specialised subagents
│   ├── architect.md              # Architecture decisions (opus)
│   ├── executor.md               # TDD implementation (sonnet)
│   ├── code-reviewer.md          # Final review (opus)
│   ├── build-fixer.md            # Auto-fix build failures (sonnet)
│   └── researcher.md             # Documentation lookup (sonnet)
├── hooks/
│   ├── hooks.json                # Hook definitions
│   ├── session-start.sh          # Context loading on session start
│   ├── capture-learning.sh       # PostToolUse failure capture
│   └── dangerous-command.sh      # PreToolUse safety guard
├── templates/                    # Customisable templates
│   ├── constitution-template.md  # Principles template
│   ├── spec-template.md          # User story template
│   ├── plan-template.md          # Architecture plan template
│   ├── tasks-template.md         # Task breakdown template
│   ├── context-template.md       # Service CONTEXT.md template
│   └── pr-template.md            # Pull request template
├── README.md                     # Documentation + branding
├── CLAUDE.md                     # Plugin CLAUDE.md guidance
└── LICENSE`}</pre>
      </Card>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Card>
          <h4 className="text-zinc-100 font-semibold mb-2">State Management</h4>
          <p className="text-zinc-400 text-sm mb-2">
            All state lives in <code className="text-amber-400">.specwright/</code> within the project:
          </p>
          <pre className="text-xs text-zinc-400 font-mono">{`.specwright/
├── state/
│   ├── workflow.json       # Active epic, gate status, lock
│   ├── learning-queue.jsonl # Captured failures
│   └── learning-dismissed.jsonl
├── memory/
│   ├── constitution.md     # Project principles
│   └── patterns.md         # Promoted learnings
├── epics/
│   └── {epic-id}/
│       ├── spec.md
│       ├── plan.md
│       ├── tasks.md
│       ├── status.md
│       └── evidence/       # Gate outputs
└── templates/              # Customised copies`}</pre>
        </Card>
        <Card>
          <h4 className="text-zinc-100 font-semibold mb-2">Workflow Pipeline</h4>
          <div className="text-sm space-y-2">
            {[
              { step: "1", name: "Init", desc: "Configure project (once)", color: "text-zinc-400" },
              { step: "2", name: "Roadmap", desc: "Domain planning + complexity scoring", color: "text-sky-400" },
              { step: "3", name: "Specify", desc: "spec.md → plan.md → tasks.md", color: "text-sky-400" },
              { step: "4", name: "Build", desc: "TDD loop per task + wiring checks", color: "text-violet-400" },
              { step: "5", name: "Validate", desc: "5 gates with evidence capture", color: "text-amber-400" },
              { step: "6", name: "Ship", desc: "Evidence-based PR + code review", color: "text-emerald-400" },
              { step: "∞", name: "Learn", desc: "Capture → review → promote patterns", color: "text-zinc-400" },
            ].map((s) => (
              <div key={s.step} className="flex items-center gap-3">
                <span className={`font-mono text-xs w-5 text-center ${s.color}`}>{s.step}</span>
                <span className="text-zinc-200 font-medium w-20">{s.name}</span>
                <span className="text-zinc-500 text-xs">{s.desc}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <Card className="border-amber-900/30">
        <h4 className="text-zinc-100 font-semibold mb-2">Key Design Decision: .specwright/ not .specify/</h4>
        <p className="text-zinc-400 text-sm">
          The plugin uses its own namespace (<code className="text-amber-400">.specwright/</code>) rather than
          overloading <code>.claude/</code> or <code>.specify/</code>. This avoids collisions with other plugins,
          makes the state directory self-contained and portable, and is clearly identifiable
          in <code>.gitignore</code> patterns. The templates directory inside <code>.specwright/</code> contains
          project-customised copies generated by <code>/specwright:init</code>.
        </p>
      </Card>
    </div>
  );
}

function SkillsSection() {
  const skills = [
    { name: "Project Init", cmd: "specwright:init", desc: "Interactive wizard to customise Specwright for your project — language, framework, build/test commands, architecture style", phase: "plan", isNew: true },
    { name: "Epic Specification", cmd: "specwright:specify", desc: "Produces spec.md (user stories), plan.md (architecture), and tasks.md (complexity-scored breakdown)", phase: "plan", isNew: false },
    { name: "Domain Roadmap", cmd: "specwright:roadmap", desc: "Analyses domain scope, scores epic complexity, flags oversized epics for splitting, produces ordered roadmap", phase: "plan", isNew: false },
    { name: "TDD Build Loop", cmd: "specwright:build", desc: "Red-Green-Refactor per task with wiring verification, progress tracking, commit per task", phase: "build", isNew: false },
    { name: "Quality Gates", cmd: "specwright:validate", desc: "Orchestrates 5 gates sequentially — build, tests, wiring, security, spec — with evidence", phase: "build", isNew: false },
    { name: "Ship PR", cmd: "specwright:ship", desc: "Pushes branch, creates PR with evidence mapping, runs final code review, archives epic", phase: "ship", isNew: false },
    { name: "Learn Review", cmd: "specwright:learn-review", desc: "Review captured failures, promote to patterns.md or CLAUDE.md memories, dismiss noise", phase: "learn", isNew: false },
    { name: "Learn Consolidate", cmd: "specwright:learn-consolidate", desc: "Auto-group similar learnings, score by frequency/recency, promote top candidates", phase: "learn", isNew: false },
    { name: "Status Dashboard", cmd: "specwright:status", desc: "Shows current epic progress, gate status, learning queue size, active locks", phase: "plan", isNew: true },
    { name: "Constitution Edit", cmd: "specwright:constitution", desc: "Add, amend, or review project principles. Guides the architect agent on what matters", phase: "plan", isNew: true },
  ];

  return (
    <div className="space-y-6">
      <p className="text-zinc-400">
        Skills are the user-facing commands. Each maps to a phase in the workflow.
        All skills from the existing <code>ff-*</code> workflow are extracted and
        made generic — no Encore, Go, or project-specific references.
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {skills.map((s) => (
          <SkillCard key={s.cmd} {...s} />
        ))}
      </div>

      <Card>
        <h4 className="text-zinc-100 font-semibold mb-2">Gate Skills (Internal — called by validate)</h4>
        <div className="grid grid-cols-1 md:grid-cols-5 gap-3 text-sm">
          {[
            { name: "Build", desc: "Compile check + full test suite", icon: "🔨" },
            { name: "Tests", desc: "Coverage, quality, negative cases", icon: "🧪" },
            { name: "Wiring", desc: "Imports, endpoints, events, deps", icon: "🔗" },
            { name: "Security", desc: "Secrets, deps, patterns", icon: "🔒" },
            { name: "Spec", desc: "Acceptance criteria mapping", icon: "📋" },
          ].map((g) => (
            <div key={g.name} className="bg-zinc-800/30 rounded p-2 text-center">
              <div className="text-lg">{g.icon}</div>
              <div className="text-zinc-200 font-medium text-xs">{g.name}</div>
              <div className="text-zinc-500 text-xs mt-1">{g.desc}</div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}

function CompatibilitySection() {
  return (
    <div className="space-y-6">
      <p className="text-zinc-400">
        The critical design question: does Specwright require oh-my-claudecode (OMC)
        or work standalone? The answer is <strong className="text-zinc-200">both</strong>.
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Card className="border-emerald-900/50">
          <h4 className="text-emerald-400 font-semibold mb-2">✅ Standalone Mode</h4>
          <p className="text-zinc-400 text-sm mb-3">
            Works without OMC. Skills use Claude Code's native <code>Task()</code> tool
            for subagent delegation. All functionality available.
          </p>
          <ul className="text-zinc-400 text-sm space-y-1">
            <li>• Uses built-in agents for architect, executor, reviewer</li>
            <li>• Quality gates run sequentially in same session</li>
            <li>• Learning hooks capture via standard PostToolUse</li>
            <li>• Pipeline locking via state file</li>
          </ul>
        </Card>
        <Card className="border-violet-900/50">
          <h4 className="text-violet-400 font-semibold mb-2">🚀 Enhanced with OMC</h4>
          <p className="text-zinc-400 text-sm mb-3">
            Detects OMC presence and unlocks advanced features. Works as an overlay.
          </p>
          <ul className="text-zinc-400 text-sm space-y-1">
            <li>• <code>ralph</code> mode for persistent epic completion</li>
            <li>• <code>ultrawork</code> for parallel independent tasks</li>
            <li>• OMC's <code>architect</code> agent with model selection</li>
            <li>• OMC notepad/memory integration</li>
            <li>• Rate limit recovery via <code>omc wait</code></li>
          </ul>
        </Card>
      </div>

      <Card>
        <h4 className="text-zinc-100 font-semibold mb-3">Detection Strategy</h4>
        <pre className="text-xs text-zinc-400 font-mono">{`# In skill.md, check for OMC presence:
if [ -d ".omc" ] && command -v omc &>/dev/null; then
  # OMC available — use enhanced delegation
  # e.g., delegate to oh-my-claudecode:architect agent
else
  # Standalone — use built-in agents via Task()
fi`}</pre>
        <p className="text-zinc-500 text-sm mt-3">
          Skills detect OMC at runtime and adapt. No hard dependency, no installation
          order requirement. The OMC integration is a capability upgrade, not a prerequisite.
        </p>
      </Card>

      <Card>
        <h4 className="text-zinc-100 font-semibold mb-3">OpenCode Compatibility</h4>
        <p className="text-zinc-400 text-sm mb-3">
          OpenCode uses the same skill file format (SKILL.md in skill directories). The plugin
          ships with a parallel <code>opencode/</code> export that mirrors the skill structure:
        </p>
        <pre className="text-xs text-zinc-400 font-mono">{`specwright/
├── skills/           # Claude Code skills (primary)
├── opencode-skills/  # OpenCode-compatible exports
│   ├── specwright-specify/SKILL.md
│   ├── specwright-build/SKILL.md
│   └── ...
└── install.sh        # Symlinks into .opencode/skills/`}</pre>
        <p className="text-zinc-500 text-sm mt-2">
          A simple install script creates symlinks. The SKILL.md content is identical — only the
          directory structure differs for each tool's conventions.
        </p>
      </Card>

      <Card>
        <h4 className="text-zinc-100 font-semibold mb-3">Custom Hooks</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <div className="text-zinc-200 font-medium mb-1">SessionStart</div>
            <p className="text-zinc-500 text-xs">
              Loads constitution principles, detects active epic, shows gate status.
              After compaction: reminds to reload spec artifacts.
            </p>
          </div>
          <div>
            <div className="text-zinc-200 font-medium mb-1">PostToolUse (Bash)</div>
            <p className="text-zinc-500 text-xs">
              Captures failed commands to learning queue (JSONL).
              Non-blocking, 3s timeout, only on non-zero exit.
            </p>
          </div>
          <div>
            <div className="text-zinc-200 font-medium mb-1">PreToolUse (Bash)</div>
            <p className="text-zinc-500 text-xs">
              Blocks dangerous operations: recursive deletes on root/home,
              force pushes, hard resets. Customisable blocklist.
            </p>
          </div>
          <div>
            <div className="text-zinc-200 font-medium mb-1">PreToolUse (Edit/Write)</div>
            <p className="text-zinc-500 text-xs">
              Blocks direct edits to sensitive files (.env, .pem, .key, secrets).
              Configurable via init.
            </p>
          </div>
        </div>
      </Card>
    </div>
  );
}

function CustomisationSection() {
  return (
    <div className="space-y-6">
      <p className="text-zinc-400">
        The <code className="text-amber-400">/specwright:init</code> skill is the linchpin.
        It transforms the generic framework into a project-specific workflow through an
        interactive wizard, then generates all customised artifacts.
      </p>

      <Card>
        <h4 className="text-zinc-100 font-semibold mb-3">Init Wizard Questions</h4>
        <div className="space-y-3 text-sm">
          {[
            { q: "Project structure", opts: "Monorepo / Multi-service / Single app / Monolith", section: "Structure" },
            { q: "Primary language(s)", opts: "Go, TypeScript, Python, Rust, Java, etc.", section: "Language" },
            { q: "Framework(s)", opts: "Auto-detected from project files + manual override", section: "Language" },
            { q: "Build command", opts: "Auto-detected (go build, npm run build, cargo build, etc.)", section: "Commands" },
            { q: "Test command", opts: "Auto-detected (go test, npm test, pytest, etc.)", section: "Commands" },
            { q: "Lint command", opts: "Auto-detected (golangci-lint, eslint, ruff, etc.)", section: "Commands" },
            { q: "Architecture style", opts: "Hexagonal / Clean / Layered / Modular / None", section: "Architecture" },
            { q: "Service communication", opts: "REST / gRPC / Events / GraphQL / None", section: "Architecture" },
            { q: "Git workflow", opts: "GitHub Flow / GitFlow / Trunk-based", section: "Git" },
            { q: "PR tool", opts: "GitHub (gh) / GitLab (glab) / Bitbucket / None", section: "Git" },
            { q: "OMC integration", opts: "Auto-detected, opt-in/out", section: "Plugins" },
          ].map((item, i) => (
            <div key={i} className="flex items-start gap-3">
              <Badge>{item.section}</Badge>
              <div>
                <span className="text-zinc-200">{item.q}</span>
                <span className="text-zinc-600 text-xs ml-2">→ {item.opts}</span>
              </div>
            </div>
          ))}
        </div>
      </Card>

      <Card>
        <h4 className="text-zinc-100 font-semibold mb-3">What Init Generates</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <div className="text-zinc-200 font-medium mb-2">Project Config</div>
            <ul className="text-zinc-400 space-y-1 text-xs">
              <li>• <code>.specwright/config.json</code> — all settings in one place</li>
              <li>• <code>.specwright/memory/constitution.md</code> — project principles (from template)</li>
              <li>• <code>.specwright/templates/</code> — customised copies of all templates</li>
              <li>• <code>.gitignore</code> additions for state files</li>
            </ul>
          </div>
          <div>
            <div className="text-zinc-200 font-medium mb-2">Gate Configuration</div>
            <ul className="text-zinc-400 space-y-1 text-xs">
              <li>• Build gate: configured with project's build/test commands</li>
              <li>• Wiring gate: configured for language-specific import analysis</li>
              <li>• Security gate: configured for language-specific secret patterns</li>
              <li>• Spec gate: default acceptance criteria format</li>
            </ul>
          </div>
        </div>
      </Card>

      <Card className="border-amber-900/30">
        <h4 className="text-zinc-100 font-semibold mb-2">Config File Example</h4>
        <pre className="text-xs text-zinc-300 font-mono overflow-x-auto">{`{
  "project": {
    "name": "financialfusion",
    "structure": "multi-service",
    "languages": ["go", "python"],
    "framework": { "go": "encore", "python": "fastapi" }
  },
  "commands": {
    "build": "encore check",
    "test": "encore test ./...",
    "lint": "golangci-lint run ./...",
    "format": "gofmt -w ."
  },
  "architecture": {
    "style": "hexagonal",
    "layers": ["service", "manager", "repository"],
    "communication": "events"
  },
  "gates": {
    "wiring": {
      "importAnalysis": "go-imports",
      "endpointCheck": "encore-mcp",
      "eventCheck": "encore-mcp"
    },
    "security": {
      "sensitiveFiles": [".env", ".pem", ".key", ".secrets.*"],
      "secretPatterns": ["API_KEY", "SECRET", "TOKEN", "PASSWORD"]
    }
  },
  "git": {
    "workflow": "github-flow",
    "prTool": "gh",
    "branchPrefix": "feat/",
    "commitFormat": "conventional"
  },
  "integration": {
    "omc": true,
    "omcAgents": { "architect": "opus", "executor": "sonnet" }
  }
}`}</pre>
      </Card>
    </div>
  );
}

function BrandingSection() {
  return (
    <div className="space-y-6">
      <div className="text-center py-8">
        <div className="text-6xl mb-4">⚒️</div>
        <h2 className="text-4xl font-black tracking-tight" style={{ fontFamily: "'Georgia', serif" }}>
          <span className="text-amber-400">Spec</span><span className="text-zinc-100">wright</span>
        </h2>
        <p className="text-zinc-500 mt-2 text-lg italic">Craft quality software with AI discipline</p>
      </div>

      <Card>
        <h4 className="text-zinc-100 font-semibold mb-3">Why "Specwright"</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <ul className="text-zinc-400 space-y-2">
              <li><strong className="text-zinc-200">Memorable:</strong> Portmanteau of "spec" + "wright" (craftsman). Like playwright, shipwright, wheelwright.</li>
              <li><strong className="text-zinc-200">Descriptive:</strong> "One who crafts specifications" — immediately communicates spec-driven development.</li>
              <li><strong className="text-zinc-200">Unique:</strong> No existing GitHub repos, npm packages, or plugins with this name.</li>
              <li><strong className="text-zinc-200">Namespace-friendly:</strong> <code>/specwright:build</code> reads naturally and is distinct from other plugins.</li>
            </ul>
          </div>
          <div>
            <ul className="text-zinc-400 space-y-2">
              <li><strong className="text-zinc-200">Emoji:</strong> ⚒️ (hammer and pick) — craftsmanship, building with precision</li>
              <li><strong className="text-zinc-200">Colour:</strong> Amber/gold — craft, quality, warmth. Not another purple gradient.</li>
              <li><strong className="text-zinc-200">Tone:</strong> Professional but opinionated. "We build things right."</li>
              <li><strong className="text-zinc-200">Tagline options:</strong>
                <br />• "Craft quality software with AI discipline"
                <br />• "The spec-driven workflow engine"
                <br />• "Working software &gt; task velocity"
              </li>
            </ul>
          </div>
        </div>
      </Card>

      <Card>
        <h4 className="text-zinc-100 font-semibold mb-3">README Hero Section (Draft)</h4>
        <div className="bg-zinc-950 rounded-md p-5 text-sm">
          <pre className="text-zinc-300 font-mono text-xs leading-relaxed whitespace-pre-wrap">{`# ⚒️ Specwright

**The spec-driven workflow engine for Claude Code & OpenCode.**

AI agents optimise for "done." Specwright optimises for "works."

> Spec → Build → Gate → Ship → Learn → Repeat

## What You Get

🔨 **5 quality gates** with evidence capture — build, test, wiring, security, spec compliance
📋 **Spec-first workflow** — user stories, architecture plans, scored task breakdowns
🧠 **Learning system** — captures failures, promotes patterns, builds project memory
🔗 **Wiring verification** — catches orphaned code, missing imports, broken event chains
♻️ **Compaction recovery** — survives context loss, reloads full state automatically
🎛️ **One command setup** — \`/specwright:init\` customises for your language and framework

## Install

\`\`\`bash
/plugin marketplace add dmccarthy/specwright
/plugin install specwright
/specwright:init
\`\`\`

Works standalone. Even better with [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode).`}</pre>
        </div>
      </Card>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <Card>
          <h4 className="text-zinc-100 font-semibold mb-1 text-sm">Star Strategy</h4>
          <ul className="text-zinc-500 text-xs space-y-1">
            <li>• Write blog post on paddo.dev/specwright</li>
            <li>• Share on r/ClaudeAI, X, LinkedIn</li>
            <li>• Reference from FinancialFusion case study</li>
            <li>• Target cc-sdd audience (SDD fans)</li>
          </ul>
        </Card>
        <Card>
          <h4 className="text-zinc-100 font-semibold mb-1 text-sm">SEO Keywords</h4>
          <ul className="text-zinc-500 text-xs space-y-1">
            <li>• spec-driven development</li>
            <li>• claude code quality gates</li>
            <li>• AI development workflow</li>
            <li>• TDD claude code plugin</li>
          </ul>
        </Card>
        <Card>
          <h4 className="text-zinc-100 font-semibold mb-1 text-sm">Community</h4>
          <ul className="text-zinc-500 text-xs space-y-1">
            <li>• Contributing guide for gate plugins</li>
            <li>• Language-specific wiring analysers</li>
            <li>• Template gallery (PR welcome)</li>
            <li>• Integration packs (OMC, Cursor, etc.)</li>
          </ul>
        </Card>
      </div>
    </div>
  );
}

function RoadmapSection() {
  const phases = [
    {
      name: "Phase 1: Core Engine",
      time: "Week 1-2",
      items: [
        { text: "Plugin scaffold with marketplace.json", done: false },
        { text: "Extract generic skills from ff-* (remove Encore refs)", done: false },
        { text: "Build specwright:init wizard", done: false },
        { text: "State management (.specwright/)", done: false },
        { text: "Constitution + template system", done: false },
        { text: "Hooks: session-start, capture-learning, safety guards", done: false },
      ],
    },
    {
      name: "Phase 2: Quality Gates",
      time: "Week 2-3",
      items: [
        { text: "Gate orchestrator (validate skill)", done: false },
        { text: "Generic build gate (configurable commands)", done: false },
        { text: "Generic wiring gate (Go + TS + Python analysers)", done: false },
        { text: "Security gate (secret scanning, dep audit)", done: false },
        { text: "Spec compliance gate (criteria → evidence mapping)", done: false },
        { text: "Evidence report format + PR template", done: false },
      ],
    },
    {
      name: "Phase 3: Learning & Polish",
      time: "Week 3-4",
      items: [
        { text: "Learning capture → review → consolidate pipeline", done: false },
        { text: "OpenCode skill exports + install script", done: false },
        { text: "OMC detection + enhanced mode", done: false },
        { text: "README, blog post, demo GIF", done: false },
        { text: "Publish to Claude Code marketplace", done: false },
        { text: "Community: contributing guide, issue templates", done: false },
      ],
    },
    {
      name: "Phase 4: Ecosystem",
      time: "Month 2+",
      items: [
        { text: "Language packs: Rust, Java, C# wiring analysers", done: false },
        { text: "Framework packs: Next.js, Django, Rails gate configs", done: false },
        { text: "Linear/Jira integration (tasks → tickets)", done: false },
        { text: "Dashboard web UI (like spec-workflow)", done: false },
        { text: "Cursor/Windsurf compatibility layer", done: false },
        { text: "Enterprise: custom gate plugins, SSO audit trail", done: false },
      ],
    },
  ];

  return (
    <div className="space-y-6">
      <p className="text-zinc-400">
        A phased approach: extract the battle-tested ff-* workflow, genericise, package,
        and ship. Each phase is independently valuable.
      </p>

      <div className="space-y-4">
        {phases.map((phase) => (
          <Card key={phase.name}>
            <div className="flex items-center justify-between mb-3">
              <h4 className="text-zinc-100 font-semibold">{phase.name}</h4>
              <Badge variant="blue">{phase.time}</Badge>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-1">
              {phase.items.map((item, i) => (
                <div key={i} className="flex items-center gap-2 text-sm">
                  <span className="text-zinc-600">○</span>
                  <span className="text-zinc-400">{item.text}</span>
                </div>
              ))}
            </div>
          </Card>
        ))}
      </div>

      <Card className="border-amber-900/30">
        <h4 className="text-zinc-100 font-semibold mb-2">Bootstrap Strategy</h4>
        <p className="text-zinc-400 text-sm">
          Use Specwright to build Specwright. Create the initial <code>.specwright/</code> structure
          in a new repo, write the constitution for the project itself, then use the
          specify → build → validate → ship workflow to implement each phase. This is both
          dogfooding and a compelling demo for the README.
        </p>
      </Card>
    </div>
  );
}

const sectionComponents = {
  overview: OverviewSection,
  competitive: CompetitiveSection,
  architecture: ArchitectureSection,
  skills: SkillsSection,
  compatibility: CompatibilitySection,
  customisation: CustomisationSection,
  branding: BrandingSection,
  roadmap: RoadmapSection,
};

export default function SpecwrightProposal() {
  const [activeSection, setActiveSection] = useState("overview");
  const ActiveComponent = sectionComponents[activeSection];

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      <div className="max-w-5xl mx-auto px-4 py-6">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6 pb-4 border-b border-zinc-800">
          <span className="text-3xl">⚒️</span>
          <div>
            <h1 className="text-2xl font-bold tracking-tight">
              <span className="text-amber-400">Spec</span>wright
            </h1>
            <p className="text-zinc-500 text-sm">Plugin Design Proposal</p>
          </div>
        </div>

        {/* Navigation */}
        <div className="flex flex-wrap gap-1 mb-6">
          {sections.map((section) => (
            <button
              key={section.id}
              onClick={() => setActiveSection(section.id)}
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                activeSection === section.id
                  ? "bg-amber-900/40 text-amber-300 border border-amber-700/50"
                  : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50 border border-transparent"
              }`}
            >
              <span className="mr-1.5">{section.icon}</span>
              {section.title}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="min-h-96">
          <ActiveComponent />
        </div>

        {/* Footer */}
        <div className="mt-8 pt-4 border-t border-zinc-800 text-zinc-600 text-xs text-center">
          Specwright — Born from building FinancialFusion with Claude Code
        </div>
      </div>
    </div>
  );
}
