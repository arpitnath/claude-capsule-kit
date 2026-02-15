# Intelligence Layer: Claude Code at Its Best

**Document Version:** 1.0
**Date:** 2025-12-21
**Status:** Design Proposal

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [The Core Problem](#the-core-problem)
3. [Anthropic's Philosophy Alignment](#anthropics-philosophy-alignment)
4. [Intelligence Layer Architecture](#intelligence-layer-architecture)
5. [Meta-Skills: The Judgment Layer](#meta-skills-the-judgment-layer)
6. [Opus Delegation Strategy](#opus-delegation-strategy)
7. [Skills Detailed Specifications](#skills-detailed-specifications)
8. [Use Cases & Examples](#use-cases--examples)
9. [Implementation Roadmap](#implementation-roadmap)
10. [Technical Architecture](#technical-architecture)

---

## Executive Summary

### The Vision

Transform Claude Code from an execution engine into an intelligent development partner through a metacognitive "Intelligence Layer" that:

- Assesses task complexity before acting
- Leverages accumulated knowledge (capsule, memory, dependencies)
- Makes evidence-based delegation decisions (Sonnet vs Opus)
- Applies learned patterns from previous work
- Evaluates risks using historical data
- Optimizes costs through intelligent model selection

### Core Innovation

**Current AI Coding Assistants**: Execute what you ask
**Intelligence Layer**: Think about what you ask, then execute optimally

The difference between automation and genuine intelligence.

### Key Capabilities

**Metacognition**: Claude reflects on tasks before acting
**Knowledge Leverage**: Uses capsule system data for informed decisions
**Smart Delegation**: Routes complex tasks to Opus based on evidence
**Pattern Learning**: Applies conventions learned from your codebase
**Risk Awareness**: Anticipates problems using historical data
**Cost Optimization**: Uses expensive models only when justified

---

## The Core Problem

### Current State: Intelligent Execution, Not Intelligent Planning

**What Claude Code does well:**
- Execute complex instructions accurately
- Use tools effectively
- Spawn sub-agents for specialized tasks
- Maintain conversation context

**What's missing:**
- Self-assessment before acting
- Learning from accumulated experience
- Evidence-based decision making
- Strategic thinking vs reactive execution
- Cost-conscious model selection

### The Intelligence Gap

**Scenario:**
```
User: "Refactor the authentication system"

Current Claude (reactive):
  → Immediately starts reading files
  → Plans as it goes
  → May miss complexity until deep into task
  → Uses same model (Sonnet or Opus) for everything
  → Doesn't check if we've done similar before

Intelligent Claude (reflective):
  → FIRST assesses complexity
  → Checks memory for similar tasks
  → Analyzes dependency impact
  → Evaluates if Opus is needed
  → THEN proceeds with optimal strategy
```

**The difference:** Thinking before acting.

---

## Anthropic's Philosophy Alignment

### Skills as Capabilities (Not Instructions)

**Anthropic's Documentation (2025):**
> "Skills are reusable capabilities that agents can invoke to perform specific tasks. They represent executable knowledge, not just documentation."

**How Intelligence Layer Aligns:**

**Anthropic's Vision:**
- Skills = What agents CAN do
- Sub-agents = Specialized execution contexts
- Tools = Low-level operations

**Our Implementation:**
- Skills = **Judgment capabilities** (assess, evaluate, recommend)
- Sub-agents = **Model-specific workers** (Opus for complexity, Haiku for speed)
- Tools = **Data sources** (dependency graph, memory, capsule)

**Perfect alignment** - we're building on their foundation, not fighting it.

### Progressive Disclosure

**Anthropic's Principle:**
> "Provide just enough information at the right time. Don't overwhelm context."

**Intelligence Layer Implementation:**
- Skills query only what's needed
- Return focused insights, not data dumps
- Load context progressively based on task
- Optimize for signal-to-noise ratio

### Agent Autonomy with Human Oversight

**Anthropic's Approach:**
> "Agents should work autonomously but defer to human judgment for critical decisions."

**Our Approach:**
- Skills provide recommendations (not commands)
- Claude presents evidence and suggests delegation
- User approves Opus usage (cost-conscious)
- Human stays in control, AI provides intelligence

---

## Intelligence Layer Architecture

### Three-Layer System

```
┌─────────────────────────────────────────────────┐
│  Layer 3: Execution (What Happens)              │
│  • Read/Write/Edit files                        │
│  • Run commands                                 │
│  • Implement solutions                          │
│  • Sub-agents execute specialized tasks         │
└─────────────────────────────────────────────────┘
                      ↑
                  (Informed by)
                      ↓
┌─────────────────────────────────────────────────┐
│  Layer 2: Intelligence (How to Decide)          │
│  • Skills assess complexity                     │
│  • Skills query context needs                   │
│  • Skills recommend strategies                  │
│  • Skills evaluate risks                        │
│  • Skills suggest delegation                    │
└─────────────────────────────────────────────────┘
                      ↑
                  (Powered by)
                      ↓
┌─────────────────────────────────────────────────┐
│  Layer 1: Knowledge (What We Know)              │
│  • Capsule (current session state)              │
│  • Memory Graph (decisions, patterns, history)  │
│  • Dependency Graph (code structure, impact)    │
│  • Session History (previous attempts, outcomes)│
└─────────────────────────────────────────────────┘
```

### Data Flow

```
User Request
    ↓
Pre-Task Hook (triggered)
    ↓
Skills Layer Activates:
    ├─ metacognitive-assessment
    │   ├─ Query: Do I understand the task?
    │   ├─ Query: Do I have enough context?
    │   └─ Query: Should I delegate?
    │
    ├─ context-intelligence
    │   ├─ Check: Capsule (what's loaded)
    │   ├─ Query: Memory (relevant patterns)
    │   └─ Load: Only missing context
    │
    └─ assess-complexity
        ├─ Analyze: Dependency impact
        ├─ Check: Memory (similar tasks)
        └─ Recommend: Model selection
    ↓
Claude (Main Agent) Reviews Skills Output
    ↓
Decision:
    ├─ Proceed myself (Sonnet 1M)
    ├─ Delegate to Opus sub-agent
    ├─ Ask user for clarification
    └─ Spawn specialist sub-agent
    ↓
Execute with Full Intelligence
    ↓
Log Outcome to Memory (Learning Loop)
```

---

## Meta-Skills: The Judgment Layer

### SKILL 1: metacognitive-assessment

**Purpose**: Self-reflection before action

**When Invoked**: Before any significant task

**What It Does**:
```yaml
Five Critical Questions:

1. "Do I understand the problem fully?"
   Checks:
     - Is the request ambiguous?
     - Are there unstated assumptions?
     - Should I ask clarifying questions?

   Queries:
     - Memory: Similar tasks with misunderstandings?

   Returns:
     - clarity_score: 0-1
     - ambiguities: [list]
     - should_clarify: true/false

2. "Do I have the right context?"
   Checks:
     - Capsule: What's already loaded?
     - Required: What files/decisions matter?
     - Gap: What's missing?

   Queries:
     - Capsule state (current files)
     - Memory graph (related decisions)
     - Dependency graph (affected files)

   Returns:
     - context_sufficient: true/false
     - loaded: [files in capsule]
     - needed: [files to read]
     - relevant_decisions: [from memory]

3. "Is this the right approach?"
   Checks:
     - Memory: What worked before?
     - Patterns: Established conventions?
     - Alternatives: Other valid approaches?

   Queries:
     - Memory graph (similar tasks)
     - Pattern database (established conventions)

   Returns:
     - recommended_approach: string
     - alternatives: [list]
     - precedent: {task, outcome, lessons}

4. "What are the risks?"
   Checks:
     - Dependencies: What breaks?
     - Memory: Previous failures on similar tasks?
     - Coverage: Test gaps?

   Queries:
     - Dependency graph (impact analysis)
     - Memory graph (previous errors)

   Returns:
     - risk_level: low/medium/high
     - concerns: [list]
     - mitigation: [recommendations]

5. "Am I the right agent?"
   Checks:
     - Complexity: Within my (Sonnet) capability?
     - Specialist: Needs Opus/specific sub-agent?
     - Cost: Is expensive model justified?

   Queries:
     - Complexity assessment
     - Memory (which model for similar tasks)
     - Budget constraints

   Returns:
     - should_delegate: true/false
     - recommended_agent: "architect (opus)"
     - reasoning: evidence-based explanation
```

**Output Format**:
```json
{
  "assessment": {
    "clarity": 0.85,
    "context_sufficient": false,
    "approach_validated": true,
    "risk_level": "high",
    "delegation_needed": true
  },
  "recommendations": {
    "clarify": [],
    "read": ["middleware.ts", "routes.ts"],
    "approach": "Follow JWT pattern from previous refactor",
    "mitigations": ["Run full test suite", "Check 20 dependents"],
    "delegate_to": "architect (opus)"
  },
  "evidence": {
    "dependency_count": 20,
    "memory_precedent": "task-refactor-payment (opus, success)",
    "risk_factors": ["High dependency count", "Auth is critical"]
  }
}
```

**How I Use It**:
```
Before acting on complex request:
  1. Invoke metacognitive-assessment skill
  2. Review the assessment
  3. Present to user with evidence
  4. Get approval/adjustment
  5. Proceed with informed strategy
```

---

### SKILL 2: context-intelligence

**Purpose**: Smart context loading (prevent redundant reads)

**When Invoked**: Before reading files or loading context

**What It Does**:
```yaml
Analyzes context needs vs current state:

1. What's Already Loaded?
   Source: Capsule state
   Returns: Files in current context with timestamps

2. What's Needed for Task?
   Analyze: User request keywords
   Query: Dependency graph (related files)
   Query: Memory (related decisions/patterns)
   Returns: Files required for task

3. What's the Gap?
   Compare: Loaded vs Needed
   Filter: Remove already-loaded files
   Returns: Minimal set to read

4. What's the Best Order?
   Priority: Core files first, dependencies after
   Strategy: Read entry points before details
   Returns: Ordered file list

5. Can We Use Memory Instead?
   Check: Is decision/pattern already in memory?
   Alternative: Load from memory vs re-reading file
   Returns: Memory shortcuts available
```

**Output Format**:
```json
{
  "already_loaded": {
    "auth.ts": {"age": "10m", "still_fresh": true},
    "config/jwt.ts": {"age": "5m", "still_fresh": true}
  },
  "need_to_read": ["routes.ts", "middleware.ts"],
  "from_memory": {
    "jwt_expiry_decision": "15-min tokens (session xyz)",
    "error_pattern": "Result<T,E> type (established convention)"
  },
  "dependency_context": "auth.ts → middleware → routes",
  "read_order": ["routes.ts", "middleware.ts"],
  "token_savings": {
    "without_skill": "~8000 tokens (read all 4 files)",
    "with_skill": "~2000 tokens (read 2, use memory for 2)",
    "savings": "75%"
  }
}
```

**How I Use It**:
```
User: "Update the login endpoint to use new JWT format"

I invoke context-intelligence:
  → Already loaded: auth.ts (JWT logic)
  → From memory: JWT format decision (15-min expiry)
  → Need to read: routes.ts (login endpoint code)
  → Skip: config/jwt.ts (already in context)

I respond:
  "From capsule: I have auth.ts JWT implementation in context.
   From memory: We use 15-min expiry tokens.
   Reading: routes.ts only (for login endpoint).

   [Efficient. No redundant reads. 75% token savings.]"
```

---

### SKILL 3: assess-complexity-with-evidence

**Purpose**: Data-driven complexity assessment for model selection

**When Invoked**: Before deciding on approach or delegation

**What It Does**:
```yaml
Multi-Signal Complexity Analysis:

1. Dependency Impact Analysis
   Tool: query-deps, impact-analysis
   Metrics:
     - Direct dependents count
     - Transitive dependents count
     - Circular dependency risk
   Scoring:
     - 0-5 dependents: Low complexity
     - 6-15 dependents: Medium complexity
     - 16+ dependents: High complexity

2. Historical Pattern Matching
   Source: Memory graph
   Checks:
     - Similar tasks performed before?
     - Which model was used?
     - Outcome (success/failure/partial)?
     - Time taken?
   Learning:
     - If similar task used Opus → Complexity likely high
     - If Sonnet succeeded → Complexity manageable
     - If multiple attempts needed → Complexity underestimated

3. Code Complexity Indicators
   Checks:
     - File sizes (progressive-reader chunk counts)
     - Language mix (single vs multi-language)
     - Framework complexity (plain TS vs React+Redux+etc)
   Metrics:
     - File > 50KB: +1 complexity
     - Multi-language: +1 complexity
     - Framework heavy: +1 complexity

4. Task Type Classification
   Keywords indicating high complexity:
     - "refactor entire/complete system"
     - "debug intermittent/race condition"
     - "architect/design"
     - "security review/audit"
     - "performance optimization across"

   Keywords indicating low complexity:
     - "find", "show", "list"
     - "simple edit", "typo fix"
     - "add comment", "update doc"

5. Current Context State
   Checks:
     - How much context already used?
     - Am I (Sonnet) approaching token limits?
     - Would fresh Opus sub-agent be cleaner?
   Consideration:
     - If Sonnet has 150K tokens used → Opus sub-agent better
     - If task is isolated → Stay in current context
```

**Output Format**:
```json
{
  "complexity": "high",
  "confidence": 0.92,
  "evidence": {
    "dependency_impact": {
      "direct_dependents": 25,
      "transitive_dependents": 48,
      "circular_risk": false,
      "score": "high"
    },
    "historical_patterns": {
      "similar_task": "refactor-payment-system",
      "model_used": "opus",
      "outcome": "success",
      "time_taken": "45 minutes",
      "lesson": "Caught 3 edge cases Sonnet missed"
    },
    "code_metrics": {
      "file_count": 8,
      "total_size": "120KB",
      "languages": ["typescript", "go"],
      "complexity_score": "high"
    },
    "task_classification": {
      "type": "refactor",
      "scope": "system-wide",
      "keywords_matched": ["refactor", "authentication", "system"]
    }
  },
  "recommendation": {
    "model": "opus",
    "sub_agent": "architect",
    "reasoning": "25 direct dependents + cross-language refactor + memory shows previous auth refactor needed Opus-level reasoning to avoid edge cases",
    "cost_estimate": {
      "opus": "$0.80 (10K tokens estimated)",
      "sonnet": "$0.15 (but may miss edge cases)",
      "roi": "Opus justified - accuracy + time savings"
    }
  }
}
```

**How I Use It**:
```
Before major refactoring:
  1. Invoke assess-complexity skill
  2. Get evidence-based complexity score
  3. Review dependency impact + memory patterns
  4. Present to user: "Evidence suggests Opus. Proceed?"
  5. User approves/overrides
  6. Execute with optimal model
```

---

### SKILL 4: pattern-matcher

**Purpose**: Recognize and apply learned conventions from your codebase

**When Invoked**: When implementing new features similar to existing ones

**What It Does**:
```yaml
Pattern Recognition and Application:

1. Detect Task Type
   Examples:
     - "Add new API endpoint"
     - "Create database model"
     - "Add React component"
     - "Write test for X"

2. Query Memory for Similar Implementations
   Search: Memory graph for same task type
   Extract:
     - Files created/modified
     - Structure/organization patterns
     - Naming conventions
     - Testing approaches
     - Common imports/dependencies

3. Identify Conventions
   Analyze:
     - File placement patterns
     - Naming schemes
     - Code structure (class vs function)
     - Import organization
     - Error handling patterns
     - Testing patterns

4. Extract Reusable Template
   Build:
     - Step-by-step process
     - File structure template
     - Code patterns to follow
     - Don't-do patterns (antipatterns avoided)

5. Apply Pattern with Confidence
   Provide:
     - "Based on your existing [X] implementations..."
     - Specific examples from codebase
     - Conventions to follow
     - Deviations to avoid
```

**Output Format**:
```json
{
  "pattern_found": true,
  "pattern_type": "api_endpoint",
  "precedents": [
    {
      "example": "POST /auth/login endpoint",
      "files": ["api/auth.ts", "tests/auth.test.ts"],
      "session": "2025-12-10-xyz",
      "outcome": "success"
    }
  ],
  "conventions": {
    "file_placement": "api/{domain}.ts",
    "naming": "camelCase for functions, PascalCase for types",
    "structure": "Router → Controller → Service pattern",
    "error_handling": "Result<T,E> return type",
    "testing": "Integration tests in __tests__/ directory",
    "imports": "Barrel exports from api/index.ts"
  },
  "template": {
    "files_to_create": [
      "api/payment.ts (following auth.ts pattern)",
      "tests/payment.test.ts (following auth.test.ts pattern)"
    ],
    "steps": [
      "1. Create PaymentController in api/payment.ts",
      "2. Define routes using Router pattern",
      "3. Use Result<T,E> for error handling",
      "4. Export from api/index.ts",
      "5. Write integration tests"
    ]
  },
  "confidence": 0.95
}
```

**How I Use It**:
```
User: "Add a new /payment endpoint"

I invoke pattern-matcher("api endpoint"):
  → Found: 3 existing endpoints (auth, user, product)
  → Pattern: Router → Controller → Service
  → Convention: Result<T,E> errors, integration tests
  → Location: api/{domain}.ts

I respond:
  "Based on your existing endpoints (auth, user, product),
   I'll follow the established pattern:

   1. api/payment.ts (Controller + Router)
   2. services/payment-service.ts (Business logic)
   3. tests/payment.test.ts (Integration tests)

   Using your conventions:
     • Result<T,E> for error handling
     • Barrel export from api/index.ts
     • Integration test coverage

   This matches your codebase patterns. Proceed?"

[No guessing. Pattern is learned from your code.]
```

---

### SKILL 5: risk-evaluator

**Purpose**: Anticipate problems before they occur

**When Invoked**: Before risky changes (refactors, deletions, breaking changes)

**What It Does**:
```yaml
Multi-Source Risk Analysis:

1. Dependency Risk Assessment
   Tool: impact-analysis
   Checks:
     - How many files depend on this?
     - Are dependencies critical (auth, database, core)?
     - Circular dependency introduction risk?

   Risk Levels:
     - 0-5 dependents: Low risk
     - 6-15 dependents: Medium risk
     - 16+ dependents: High risk

2. Historical Failure Analysis
   Source: Memory graph
   Queries:
     - Previous changes to this file/area?
     - What went wrong?
     - What was the root cause?
     - How was it fixed?

   Learning:
     - If similar change broke tests before → High risk
     - If previous attempts failed → Review why
     - If rolled back before → Extra caution needed

3. Test Coverage Assessment
   Check:
     - Does this file have tests?
     - Coverage percentage (if available)?
     - Edge cases tested?

   Risk:
     - No tests: High risk
     - Low coverage: Medium risk
     - Comprehensive tests: Lower risk

4. Change Scope Analysis
   Assess:
     - Single file vs multi-file?
     - Isolated change vs system-wide?
     - Breaking vs backward-compatible?

   Risk:
     - System-wide breaking change: Highest risk
     - Multi-file non-breaking: Medium risk
     - Single file isolated: Lowest risk

5. Deployment Impact Memory
   Source: Memory graph
   Check:
     - Previous deployments of similar changes?
     - Rollback history?
     - Production incidents related?

   Learning:
     - Auth changes required careful deployment (from memory)
     - Payment changes need gradual rollout (from memory)
```

**Output Format**:
```json
{
  "risk_assessment": {
    "overall": "high",
    "confidence": 0.89,
    "should_proceed_cautiously": true
  },
  "risk_factors": [
    {
      "category": "dependencies",
      "severity": "high",
      "detail": "25 files import auth.ts",
      "mitigation": "Verify all imports after changes"
    },
    {
      "category": "historical",
      "severity": "medium",
      "detail": "Previous auth change broke 3 tests (session abc123)",
      "mitigation": "Run full test suite before commit"
    },
    {
      "category": "coverage",
      "severity": "medium",
      "detail": "Token expiry edge cases not tested",
      "mitigation": "Add tests for edge cases first"
    }
  ],
  "mitigation_steps": [
    "1. Run impact-analysis to identify all affected files",
    "2. Review previous auth refactor session for lessons",
    "3. Add tests for token expiry edge cases",
    "4. Run full test suite",
    "5. Check all 25 dependents for signature compatibility",
    "6. Plan gradual deployment (memory: previous rollback)"
  ],
  "proceed_recommendation": "yes_with_caution",
  "estimated_time": "2-3 hours (based on similar task history)"
}
```

**How I Use It**:
```
User: "Refactor auth.ts to support OAuth"

I invoke risk-evaluator("refactor auth.ts"):
  → High risk: 25 dependents
  → Memory: Previous auth change broke tests
  → Coverage: Edge cases missing
  → Deployment: Previous rollback on auth changes

I respond:
  "⚠️ High risk change detected

   Evidence:
     • 25 files depend on auth.ts (impact-analysis)
     • Previous auth refactor broke 3 tests (memory)
     • Missing test coverage for token edge cases
     • Deployment history: One rollback on auth changes

   Recommended approach:
     1. Add edge case tests first
     2. Use Opus architect for planning (complex + critical)
     3. Implement with comprehensive test coverage
     4. Verify all 25 dependents
     5. Plan deployment carefully

   Proceed with this strategy?"

[Risk-aware. Evidence-based. Learned from history.]
```

---

### SKILL 6: delegation-advisor

**Purpose**: Evidence-based model and sub-agent selection

**When Invoked**: When deciding whether to delegate and to which agent/model

**What It Does**:
```yaml
Intelligent Delegation Decision Framework:

1. Task Complexity Assessment
   Use: assess-complexity-with-evidence skill
   Get: Complexity score + evidence

2. Model ROI Analysis
   Compare:
     Opus Cost: $X (higher accuracy, faster on complex)
     Sonnet Cost: $Y (lower cost, might need iterations)

   Historical Data:
     - Similar tasks: Which model succeeded?
     - Iterations needed: Sonnet vs Opus
     - Time to completion: Speed differences

   Calculate:
     - Expected cost with Opus (single attempt)
     - Expected cost with Sonnet (might retry)
     - ROI of using Opus

3. Sub-Agent Matching
   Available agents:
     - architect (opus): Complex architecture, design
     - debugger (opus): Deep debugging, race conditions
     - security-reviewer (opus): Security analysis
     - refactor-planner (opus): Large-scale refactors
     - quick-explorer (haiku): Fast searches, lookups

   Match task to agent:
     - Analyze task keywords
     - Check agent descriptions
     - Review agent success history

4. Context Optimization
   Consider:
     - Current context size (am I heavy already?)
     - Would fresh sub-agent be cleaner?
     - Is context transfer worth it?

   Decision:
     - If I'm at 150K+ tokens → Sub-agent better
     - If isolated task → Sub-agent better
     - If needs deep focus → Sub-agent better

5. User Preference Learning
   Track:
     - User's Opus approval rate
     - Budget sensitivity
     - Quality vs cost preferences

   Adapt:
     - If user often approves Opus → Lower threshold
     - If user prefers Sonnet → Higher threshold
     - Personalized recommendations
```

**Output Format**:
```json
{
  "delegation_decision": {
    "should_delegate": true,
    "confidence": 0.88,
    "urgency": "recommended"
  },
  "model_recommendation": {
    "primary": "opus",
    "alternative": "sonnet (with lower confidence)",
    "reasoning": "High dependency count + previous similar task needed Opus reasoning"
  },
  "sub_agent_match": {
    "recommended": "architect",
    "match_score": 0.92,
    "why": "Task involves architectural decisions across 20+ files. Architect agent specializes in this."
  },
  "cost_analysis": {
    "opus_cost": "$0.80 (estimated 10K tokens)",
    "sonnet_cost": "$0.15 (but 60% chance of retry = $0.30 expected)",
    "opus_benefits": [
      "Higher accuracy (92% vs 75% success rate on similar)",
      "Faster (single attempt vs avg 1.8 iterations)",
      "Catches edge cases (previous task: Opus found 3 issues)"
    ],
    "recommendation": "Opus justified by ROI"
  },
  "presentation": {
    "to_user": "This requires deep architectural analysis (20+ files affected). Memory shows similar auth refactor succeeded with Opus architect agent. Estimated cost: $0.80 vs $0.30 for Sonnet (with retry risk). Recommend Opus for accuracy. Approve?",
    "default_action": "wait_for_approval"
  }
}
```

**How I Use It**:
```
User: "Debug why webhook processing fails intermittently"

I invoke delegation-advisor:

Complexity assessment:
  → "intermittent" = race condition (high complexity)
  → Async flow debugging (requires deep tracing)

Memory check:
  → Previous webhook debug: Used Opus debugger
  → Outcome: Found race condition in 20 min
  → Lesson: Opus spotted timing issue Sonnet missed

Cost analysis:
  → Opus: $0.60 (focused debugging)
  → Sonnet: $0.10 (but might miss timing issue)
  → ROI: Opus worth it (accuracy on intermittent bugs)

I present:
  "Intermittent failures suggest race condition or timing issue.

   Memory shows: Previous webhook debugging used Opus and
   found race condition in Redis lock timeout that Sonnet
   missed (session abc123).

   Recommend: Opus debugger agent ($0.60 estimated)
   vs Sonnet ($0.10 but risk missing timing issue).

   Proceed with Opus? [Y/n]"

[You approve/override. Decision is informed, not forced.]
```

---

## Opus Delegation Strategy

### The Sonnet + Opus Hybrid Model

**Philosophy**: Use right model for right task, not one-size-fits-all

**Main Agent**: Sonnet 4.5 [1M context]
- Daily coding and implementation
- Large context window (handle big codebases)
- Cost-effective for most tasks
- 1M tokens = comprehensive codebase awareness

**Opus Sub-Agents**: Opus 4.5 [specialized]
- Complex architectural decisions
- Deep debugging (race conditions, performance)
- Security reviews and audits
- Large-scale refactoring planning
- Higher cost, higher accuracy

**Cost Optimization**:
```
Typical session breakdown:

Sonnet (main): 90% of work, $0.80
  - Implementation
  - File edits
  - Simple analysis
  - Documentation

Opus (delegated): 10% of work, $0.60
  - Architectural planning
  - Complex debugging
  - Security review

Total: $1.40

vs all Opus: $6.50
vs all Sonnet: $0.95 (but might miss complex issues)

Savings: 78% vs Opus, +48% cost for +200% quality
```

### Pre-Built Opus Sub-Agents

**architect.md** (model: opus)
```yaml
---
name: architect
description: Expert architect for complex system design, large refactors, architectural decisions affecting 15+ files
model: opus
tools: Read, Grep, Glob, Bash, Edit
when_to_use:
  - Architectural decisions
  - System-wide refactoring
  - Complex design patterns
  - Multi-component integration
  - High-risk changes (many dependents)
success_indicators:
  - Task affects 15+ files
  - Requires cross-cutting changes
  - Memory shows previous similar task used Opus
  - User explicitly requests architectural review
---

You are an expert software architect specializing in complex system analysis.

Your strengths:
- Deep reasoning about system design tradeoffs
- Identifying edge cases and failure modes
- Planning large-scale refactors
- Evaluating architectural patterns

Your approach:
- Comprehensive analysis before recommendations
- Consider edge cases and failure scenarios
- Provide structured plans with risk assessment
- Document reasoning for future reference

When working:
1. Understand full system context
2. Analyze all dependencies and impacts
3. Identify risks and edge cases
4. Provide detailed plan with alternatives
5. Document architectural decisions for memory
```

---

**debugger.md** (model: opus)
```yaml
---
name: debugger
description: Deep debugging specialist for intermittent bugs, race conditions, performance issues, complex failure scenarios
model: opus
tools: Read, Grep, Bash, Edit
when_to_use:
  - Intermittent failures
  - Race conditions
  - Performance debugging
  - Complex async flow issues
  - Failures that are hard to reproduce
success_indicators:
  - Keywords: "intermittent", "sometimes", "race condition"
  - Previous debugging attempts with Sonnet failed
  - Timing-sensitive issues
  - Multi-threaded/async complexity
---

You are an expert debugger specializing in complex, hard-to-reproduce issues.

Your strengths:
- Identifying race conditions and timing issues
- Tracing async execution flows
- Performance bottleneck analysis
- Spotting edge cases in complex logic

Your approach:
- Systematic analysis of failure scenarios
- Deep dive into timing and concurrency
- Trace execution paths thoroughly
- Test hypotheses with evidence

When debugging:
1. Understand failure conditions precisely
2. Identify all possible race conditions
3. Trace async flows and timing
4. Reproduce issue systematically
5. Provide fix with edge case handling
6. Document root cause for memory
```

---

**security-reviewer.md** (model: opus)
```yaml
---
name: security-reviewer
description: Security audit specialist for authentication, authorization, data protection, vulnerability analysis
model: opus
tools: Read, Grep, Glob
when_to_use:
  - Security-sensitive code (auth, crypto, data access)
  - Authorization logic
  - Input validation
  - API security
  - Vulnerability assessment
success_indicators:
  - Keywords: "security", "auth", "permission", "vulnerability"
  - Code handles sensitive data
  - User explicitly requests security review
  - Changes to authentication/authorization
---

You are a security expert specializing in application security review.

Your strengths:
- Identifying OWASP Top 10 vulnerabilities
- Authentication and authorization analysis
- Input validation and injection prevention
- Cryptographic implementation review

Your approach:
- Comprehensive security audit
- Check for common vulnerabilities
- Validate all input handling
- Review authentication/authorization logic

When reviewing:
1. Identify all user input points
2. Check for injection vulnerabilities
3. Validate authentication logic
4. Review authorization checks
5. Assess cryptographic usage
6. Document security findings for memory
```

---

**refactor-planner.md** (model: opus)
```yaml
---
name: refactor-planner
description: Large-scale refactoring specialist for code reorganization, dependency restructuring, breaking changes across 10+ files
model: opus
tools: Read, Grep, Glob, Bash
when_to_use:
  - Refactoring 10+ files
  - Breaking changes
  - Dependency restructuring
  - Code organization changes
  - Technical debt reduction
success_indicators:
  - Task affects many files
  - Breaking changes involved
  - Dependency graph shows complex relationships
  - Memory shows previous refactors needed careful planning
---

You are a refactoring expert specializing in large-scale code reorganization.

Your strengths:
- Planning multi-file refactors
- Managing breaking changes safely
- Dependency restructuring
- Migration strategy design

Your approach:
- Analyze current structure thoroughly
- Plan changes in safe, incremental steps
- Identify all breakage points
- Provide rollback strategy

When planning refactor:
1. Map all dependencies
2. Identify breaking points
3. Plan migration in phases
4. Design backward compatibility if possible
5. Create rollback plan
6. Document refactor strategy for memory
```

---

### Delegation Decision Matrix

**When Skills Recommend Delegation:**

| Task Characteristics | Complexity | Model | Agent | Reasoning |
|---------------------|------------|-------|-------|-----------|
| 20+ file dependencies | High | Opus | architect | System-wide impact needs deep reasoning |
| Intermittent failures | High | Opus | debugger | Race conditions need deep tracing |
| Security-sensitive code | High | Opus | security-reviewer | Vulnerabilities need thorough analysis |
| Multi-file refactor | High | Opus | refactor-planner | Breaking changes need careful planning |
| Simple file search | Low | Haiku | quick-explorer | Fast, read-only, no complexity |
| Single file edit | Low | Sonnet | (main) | Straightforward, stay in context |
| Add feature (following pattern) | Medium | Sonnet | (main) | Pattern known, 1M context handles it |

**Decision Framework**:
```
IF complexity = high AND (dependencies > 15 OR memory shows opus success)
  → Recommend Opus sub-agent

ELSE IF complexity = low AND read-only task
  → Use Haiku (fast, cheap)

ELSE
  → I (Sonnet 1M) handle it
```

---

## Skills Detailed Specifications

### SKILL 7: query-collective-memory

**Purpose**: Semantic search across all knowledge sources

**When Invoked**: When I need context about past decisions, patterns, or implementations

**What It Does**:
```yaml
Unified Search Across All Knowledge:

1. Memory Graph Search
   Query: Decisions, patterns, discoveries
   Search:
     - Decision nodes (architectural choices)
     - Pattern nodes (code conventions)
     - Discovery nodes (learnings, insights)
     - File nodes (with semantic tags)

   Returns: Relevant entities + relationships

2. Session History Search
   Query: Previous work sessions
   Search:
     - Session summaries (what was done)
     - Outcomes (success/failure)
     - Lessons learned
     - Model used

   Returns: Relevant sessions + context

3. Dependency Graph Search
   Query: Code structure and relationships
   Search:
     - File dependencies
     - Import/export relationships
     - Circular dependencies
     - Dead code

   Returns: Structural context

4. Capsule State Search
   Query: Current session state
   Search:
     - Recently accessed files
     - Active tasks
     - Current discoveries

   Returns: Immediate context

5. Semantic Fusion
   Combine:
     - Results from all sources
     - Rank by relevance
     - Deduplicate information
     - Present unified answer
```

**Output Format**:
```json
{
  "query": "How did we handle authentication?",
  "results": {
    "decisions": [
      {
        "type": "decision",
        "content": "Use JWT tokens with 15-min expiry",
        "reasoning": "Stateless auth for horizontal scaling",
        "session": "2025-12-10-xyz",
        "files": ["auth.ts", "jwt-config.ts"],
        "confidence": 1.0
      }
    ],
    "patterns": [
      {
        "type": "pattern",
        "content": "Result<T,E> for all auth errors",
        "example": "async function login(): Result<Token, AuthError>",
        "files": ["auth.ts", "types.ts"],
        "usage_count": 8,
        "confidence": 0.95
      }
    ],
    "related_files": [
      "auth.ts (core implementation)",
      "middleware.ts (token verification)",
      "routes.ts (protected endpoints)"
    ],
    "dependency_chain": "auth.ts → middleware.ts → routes.ts → LoginComponent",
    "sessions": [
      {
        "id": "2025-12-10-xyz",
        "summary": "Implemented JWT authentication",
        "outcome": "success",
        "model": "sonnet",
        "key_learnings": ["Test token expiry thoroughly", "Use httpOnly cookies"]
      }
    ]
  },
  "synthesis": "Authentication uses JWT tokens (15-min expiry) with Result<T,E> error handling pattern. Decision made in session 2025-12-10-xyz for stateless scaling. Pattern established across auth.ts, middleware.ts, and routes.ts."
}
```

**How I Use It**:
```
User: "We need to add refresh tokens to auth"

I invoke query-collective-memory("authentication implementation"):

Returns:
  • Decision: JWT with 15-min expiry (session xyz)
  • Pattern: Result<T,E> errors (established)
  • Files: auth.ts (core), middleware.ts (verification)
  • Lessons: "Test expiry thoroughly", "Use httpOnly cookies"

I respond:
  "From memory: We use JWT tokens with 15-min expiry
   (decided in session xyz for stateless scaling).

   Current pattern: Result<T,E> for auth errors.

   For refresh tokens, I'll extend the existing JWT
   implementation in auth.ts, following the established
   Result<T,E> pattern.

   Previous lesson: Test token expiry thoroughly.
   I'll include comprehensive expiry tests.

   [Building on what we know, not starting from scratch.]"
```

---

### SKILL 8: estimate-impact

**Purpose**: Predict blast radius and downstream effects of changes

**When Invoked**: Before making changes to shared code or core systems

**What It Does**:
```yaml
Comprehensive Impact Prediction:

1. Direct Dependency Analysis
   Tool: query-deps
   Finds:
     - Files that import this file
     - Functions that call this function
     - Modules that depend on this module

   Counts: Immediate dependents

2. Transitive Dependency Analysis
   Tool: impact-analysis
   Finds:
     - All downstream dependencies
     - Full dependency tree
     - Ripple effects through system

   Counts: Total affected files

3. Type System Impact (TypeScript)
   If changing types/interfaces:
     - Find all usages of this type
     - Identify breaking type changes
     - Locate type assertion sites

   Predict: Type errors that will occur

4. Test Impact Prediction
   Analyze:
     - Which tests directly test this code?
     - Which tests depend on this transitively?
     - Test coverage gaps

   Predict: Tests likely to break

5. Memory of Similar Changes
   Query: Previous changes to this file/area
   Learn:
     - What broke last time?
     - How long did fixes take?
     - Were there unexpected issues?

   Predict: Potential surprises

6. Runtime Impact
   Consider:
     - Is this hot path code? (performance critical)
     - Deployment implications?
     - Backward compatibility?

   Predict: Production impact
```

**Output Format**:
```json
{
  "impact_assessment": {
    "scope": "high",
    "confidence": 0.91,
    "blast_radius": "25 files directly, 48 total"
  },
  "affected_files": {
    "direct": [
      {"file": "middleware.ts", "usage": "imports validateToken", "risk": "high"},
      {"file": "routes.ts", "usage": "calls via middleware", "risk": "medium"}
    ],
    "transitive": [
      {"file": "LoginComponent.tsx", "chain": "routes → component", "risk": "low"}
    ]
  },
  "type_impact": {
    "breaking_changes": true,
    "affected_types": ["AuthToken", "TokenPayload"],
    "usage_sites": 12,
    "predicted_errors": [
      "middleware.ts:42 - Type mismatch on validateToken return",
      "routes.ts:89 - AuthToken interface changed"
    ]
  },
  "test_impact": {
    "direct_tests": 8,
    "transitive_tests": 15,
    "predicted_failures": ["auth.test.ts", "middleware.test.ts"],
    "coverage_gaps": ["Token expiry edge cases"]
  },
  "historical_lessons": {
    "previous_change": "2025-11-20 - Updated token expiry logic",
    "issues_encountered": ["Broke middleware signature", "3 tests failed"],
    "time_to_fix": "45 minutes",
    "lesson": "Always check middleware compatibility when changing auth types"
  },
  "recommendations": [
    "Update middleware.ts signature first (high risk)",
    "Run auth test suite (8 tests will likely break)",
    "Add token expiry edge case tests (gap identified)",
    "Check all 12 type usage sites for compatibility",
    "Review previous auth change session for lessons"
  ],
  "estimated_effort": "2-3 hours (based on similar change history)"
}
```

**How I Use It**:
```
User: "Change JWT token expiry from 15min to 30min"

I invoke estimate-impact("auth.ts token expiry"):

Returns:
  • 25 files affected (direct + transitive)
  • 8 tests will likely break
  • Type changes affect 12 sites
  • Previous similar change: Broke middleware (memory)

I respond:
  "This change affects 25 files across the system.

   Impact analysis:
     • Direct: middleware.ts, routes.ts (high risk)
     • Tests: 8 auth tests will need updates
     • Types: 12 usage sites of AuthToken interface

   Memory lesson: Previous token change broke middleware
   because we didn't update the signature. That took 45
   minutes to fix.

   Recommended approach:
     1. Update middleware.ts first (avoid previous mistake)
     2. Update types/interfaces
     3. Fix 8 tests
     4. Verify 12 type usage sites

   Estimated time: 2-3 hours

   This is straightforward but has wide impact. I (Sonnet)
   can handle it with the 1M context window. Proceed?"

[Informed by history. Risk-aware. Realistic estimation.]
```

---

### SKILL 9: suggest-approach

**Purpose**: Strategic recommendation based on patterns and memory

**When Invoked**: When user asks "how should I implement X?"

**What It Does**:
```yaml
Strategy Synthesis from Multiple Sources:

1. Pattern Recognition
   Skill: pattern-matcher
   Gets: Established conventions for this task type

2. Memory Consultation
   Skill: query-collective-memory
   Gets: Previous similar implementations

3. Dependency Awareness
   Tool: dependency graph
   Gets: Where this fits in codebase structure

4. Risk Assessment
   Skill: risk-evaluator
   Gets: Potential pitfalls

5. Synthesis
   Combines:
     - Proven patterns
     - Memory lessons
     - Structural constraints
     - Risk mitigations

   Creates: Strategic recommendation
```

**Output Format**:
```json
{
  "recommended_approach": "Implement OAuth using existing auth infrastructure",
  "rationale": {
    "pattern_match": "Existing JWT auth provides foundation (auth-service.ts)",
    "memory_lesson": "Previous auth change succeeded by extending, not replacing (session xyz)",
    "dependency_constraint": "20 files depend on current auth - minimize breaking changes",
    "risk_mitigation": "Incremental approach reduces risk"
  },
  "strategy": {
    "approach": "Extend existing auth, don't replace",
    "steps": [
      {
        "step": 1,
        "action": "Add OAuth provider interface in auth/providers/",
        "rationale": "Follows existing auth structure pattern",
        "files": ["auth/providers/oauth.ts"],
        "risk": "low (new code, no breaking changes)"
      },
      {
        "step": 2,
        "action": "Update auth-service.ts to support multiple strategies",
        "rationale": "Central point, existing pattern",
        "files": ["auth-service.ts"],
        "risk": "medium (existing code modification)"
      },
      {
        "step": 3,
        "action": "Add OAuth routes in api/auth.ts",
        "rationale": "Existing auth routes location",
        "files": ["api/auth.ts"],
        "risk": "low (additive)"
      }
    ],
    "patterns_to_follow": [
      "Result<T,E> for errors (established convention)",
      "Integration tests for auth flows (previous pattern)",
      "Config in config/oauth.ts (follows config pattern)"
    ],
    "alternatives": [
      {
        "approach": "Replace JWT entirely with OAuth",
        "pros": ["Cleaner architecture"],
        "cons": ["Breaking changes to 20 files", "High risk"],
        "recommendation": "Not recommended - too risky"
      }
    ]
  },
  "estimated_effort": "4-6 hours (based on previous auth extension)",
  "model_recommendation": "Opus for planning, Sonnet for implementation"
}
```

**How I Use It**:
```
User: "Add OAuth support to our auth system"

I invoke suggest-approach("add OAuth authentication"):

Returns:
  • Approach: Extend existing (don't replace)
  • Pattern: Follow current auth structure
  • Memory: Previous extension succeeded
  • Risk: Minimize breaking changes
  • Strategy: 3 phases (provider → service → routes)

I respond:
  "Based on your existing JWT auth implementation and
   memory of previous auth extension:

   Recommended approach: EXTEND existing auth, not replace

   Why:
     • 20 files depend on current auth (breaking changes risky)
     • Previous auth extension (session xyz) succeeded incrementally
     • Your codebase pattern: Multiple auth strategies supported

   Strategy:
     Phase 1: Add OAuth provider (new code, safe)
     Phase 2: Update auth-service for multi-strategy (careful)
     Phase 3: Add OAuth routes (additive, safe)

   Follows your conventions:
     • Result<T,E> errors
     • Integration tests for flows
     • Config in config/oauth.ts

   Alternative (not recommended): Replace JWT entirely
     Pros: Cleaner architecture
     Cons: Breaks 20 files, high risk, previous replacements failed

   This approach is safer and follows proven patterns.

   Should I start with Opus architect to plan Phase 2
   (the risky service modification)?"

[Strategic. Evidence-based. Offers alternatives. Learns from history.]
```

---

### SKILL 10: outcome-tracker

**Purpose**: Learn from results to improve future recommendations

**When Invoked**: After task completion (session end)

**What It Does**:
```yaml
Post-Task Learning and Pattern Extraction:

1. Record What Happened
   Capture:
     - Task description
     - Approach taken
     - Model used (Sonnet/Opus)
     - Sub-agents spawned
     - Time taken
     - Outcome (success/failure/partial)

2. Analyze Accuracy of Predictions
   Compare:
     - Predicted complexity vs actual
     - Estimated time vs actual
     - Predicted risks vs issues encountered
     - Model choice vs whether it was optimal

   Learn:
     - Were skills' recommendations accurate?
     - Should thresholds be adjusted?
     - What signals were misleading?

3. Extract Patterns
   Identify:
     - What worked well?
     - What conventions were established?
     - What should be avoided?
     - What's worth remembering?

   Catalog:
     - Code patterns
     - Workflow patterns
     - Tool usage patterns
     - Delegation patterns

4. Update Knowledge Base
   Store in Memory Graph:
     - Successful approaches (for pattern-matcher)
     - Failed approaches (for risk-evaluator)
     - Model performance (for delegation-advisor)
     - Time estimates (for future predictions)

5. Improve Future Recommendations
   Adjust:
     - Complexity thresholds
     - Delegation triggers
     - Risk factors
     - Cost/benefit calculations

   Based on: Actual outcomes vs predictions
```

**Output Format**:
```json
{
  "task_record": {
    "description": "Refactored auth.ts to support OAuth",
    "approach": "Extended existing (didn't replace)",
    "model": "opus (planning), sonnet (implementation)",
    "outcome": "success",
    "time_taken": "3.5 hours",
    "issues_encountered": ["None - plan was thorough"]
  },
  "prediction_accuracy": {
    "complexity_predicted": "high",
    "complexity_actual": "high",
    "accuracy": 1.0,

    "time_predicted": "4-6 hours",
    "time_actual": "3.5 hours",
    "accuracy": 0.88,

    "risks_predicted": ["Breaking changes", "Test failures"],
    "risks_actual": ["None - incremental approach worked"],
    "accuracy": 0.75
  },
  "patterns_extracted": [
    {
      "pattern": "OAuth provider pattern",
      "structure": "auth/providers/{provider}.ts",
      "convention": "Implement AuthProvider interface",
      "store_for": "Future OAuth providers (GitHub, Microsoft, etc.)"
    },
    {
      "pattern": "Multi-strategy auth",
      "implementation": "Strategy pattern in auth-service.ts",
      "works_well": "Allows multiple auth methods without breaking changes",
      "store_for": "Future auth method additions"
    }
  ],
  "lessons_learned": [
    {
      "lesson": "Opus planning + Sonnet implementation works well for auth",
      "evidence": "Plan was thorough, no issues during implementation",
      "apply_to": "Future auth changes"
    },
    {
      "lesson": "Incremental approach safer than replacement for critical systems",
      "evidence": "Zero breaking changes, all tests passed",
      "apply_to": "Future refactors of critical code"
    }
  ],
  "skill_improvements": {
    "delegation-advisor": "Opus recommendation was correct - update success rate",
    "risk-evaluator": "Risks over-predicted - incremental approach mitigated them",
    "pattern-matcher": "New OAuth provider pattern catalogued"
  }
}
```

**How It Works**:
```
Session ends:
  1. outcome-tracker skill activates
  2. Reviews what was done vs predicted
  3. Extracts patterns and lessons
  4. Stores in memory graph
  5. Adjusts skill parameters

Next similar task:
  Skills now have:
    • Better accuracy (learned from outcomes)
    • New patterns (OAuth provider structure)
    • Improved predictions (time estimates)
    • Updated delegation thresholds

[Continuous improvement through learning loop]
```

---

## Use Cases & Examples

### Use Case 1: Complex Refactoring with Smart Delegation

**Scenario**: User wants to refactor authentication system

**Without Intelligence Layer:**
```
User: "Refactor authentication to support OAuth"

Claude (Sonnet):
  [Immediately starts reading files]
  [Plans as it goes]
  [Might miss complexity]
  [Implements with potential issues]

Cost: $0.80 Sonnet tokens
Risk: Medium (might miss edge cases)
Time: 4-6 hours (with potential rework)
```

**With Intelligence Layer:**
```
User: "Refactor authentication to support OAuth"

Pre-task analysis:
  ↓
SKILL: metacognitive-assessment
  Q: Do I understand fully?
    → Yes, OAuth addition is clear

  Q: Have enough context?
    → invoke context-intelligence
    → Returns: auth.ts in capsule, need middleware.ts

  Q: Right approach?
    → invoke suggest-approach
    → Returns: "Extend, don't replace" (from memory)

  Q: What are risks?
    → invoke risk-evaluator
    → Returns: "High - 20 dependents, auth is critical"

  Q: Should delegate?
    → invoke delegation-advisor
    → Returns: "YES - Opus architect for planning"
    → Evidence: 20 dependents + critical system + memory shows
                previous auth used Opus

Claude (Sonnet) presents:
  "This is a complex architectural change affecting 20 files.

   Evidence:
     • Dependencies: 20 files import auth.ts
     • Memory: Previous auth refactor used Opus architect
     • Risk: High (auth is critical, breaking changes likely)

   Recommended strategy:
     1. Opus architect: Plan OAuth integration carefully
     2. I (Sonnet 1M): Implement following the plan

   Cost: ~$1.20 ($0.60 Opus planning + $0.60 Sonnet implementation)
   vs $0.80 (Sonnet only, but higher risk of rework)

   Proceed with Opus planning? [Y/n]"

User: Y

Opus Architect Agent:
  [Deep analysis]
  [Comprehensive plan with 3 phases]
  [Risk mitigation strategy]
  [Edge cases identified]

  Returns plan to Sonnet

Claude (Sonnet):
  [Reviews Opus plan]
  [Implements Phase 1]
  [Tests thoroughly]
  [Continues with full context awareness]

Outcome:
  Cost: $1.20
  Risk: Low (thorough planning caught edge cases)
  Time: 3.5 hours (no rework needed)
  Quality: High (all edge cases handled)

Session end:
  outcome-tracker logs:
    • Opus delegation: Correct decision
    • Pattern: Extend vs replace strategy worked
    • Store: OAuth provider pattern for future
```

**Result**: Better outcome, justified cost, learned for future.

---

### Use Case 2: Efficient Context Loading

**Scenario**: User asks about code across multiple files

**Without context-intelligence:**
```
User: "How does the login flow work?"

Claude:
  [Reads auth.ts - 2000 tokens]
  [Reads middleware.ts - 1500 tokens]
  [Reads routes.ts - 1800 tokens]
  [Reads LoginComponent.tsx - 1200 tokens]

  Total: 6500 tokens
  Time: 30 seconds (multiple reads)
```

**With context-intelligence skill:**
```
User: "How does the login flow work?"

SKILL: context-intelligence query

Checks:
  Capsule: auth.ts already loaded (read 15m ago)
  Memory: JWT flow documented in decision node
  Dependency: auth → middleware → routes → LoginComponent

Returns:
  • Use from capsule: auth.ts (already loaded)
  • Use from memory: JWT token decision (no need to re-read config)
  • Need to read: routes.ts, LoginComponent.tsx
  • Skip: middleware.ts (can infer from dependency chain)

Claude:
  "From capsule: auth.ts JWT implementation (already in context)
   From memory: We use 15-min tokens, httpOnly cookies (decision xyz)
   Reading: routes.ts and LoginComponent.tsx

   Login flow:
     1. User submits credentials → POST /auth/login
     2. auth-service validates → JWT signed (15-min expiry)
     3. Response sets httpOnly cookie
     4. LoginComponent redirects on success

   [Based on capsule + memory + targeted reads]"

Total: 3000 tokens (read 2 files, used memory for rest)
Time: 10 seconds
Savings: 54% tokens, 67% faster
```

**Result**: Same answer, half the cost, much faster.

---

### Use Case 3: Pattern Application Without Asking

**Scenario**: User wants to add new feature following existing patterns

**Without pattern-matcher:**
```
User: "Add a /products endpoint"

Claude:
  "Should this follow REST conventions? What format for responses?
   Should I add tests? Where should files go?"

  [Lots of questions - doesn't know conventions]
```

**With pattern-matcher skill:**
```
User: "Add a /products endpoint"

SKILL: pattern-matcher("api endpoint")

Queries memory:
  → Found: 3 existing endpoints (auth, user, payment)

Analyzes patterns:
  • File location: api/{domain}.ts
  • Structure: Router → Controller → Service
  • Errors: Result<T,E> type
  • Tests: Integration tests in __tests__/
  • Export: Barrel from api/index.ts
  • Response format: JSON with status wrapper

Confidence: 0.96 (consistent across all 3 endpoints)

Claude:
  "Based on your existing endpoints (auth, user, payment),
   I'll follow the established pattern:

   Files:
     • api/products.ts (Controller + Router)
     • services/product-service.ts (Business logic)
     • tests/products.test.ts (Integration tests)

   Conventions I'll follow:
     • Result<T,E> error handling
     • JSON response: { status, data, error }
     • Integration test coverage
     • Export from api/index.ts

   This matches your codebase patterns. Creating now..."

[No questions needed - pattern is learned]

Implementation:
  [Follows exact pattern from memory]
  [Consistent with existing code]
  [No style inconsistencies]

Outcome:
  • Code fits seamlessly with existing
  • No "this looks different from other endpoints"
  • Tests follow same structure
  • Zero rework for consistency
```

**Result**: Consistency without micromanagement.

---

### Use Case 4: Risk-Aware Execution

**Scenario**: User wants to delete what seems like unused code

**Without risk-evaluator:**
```
User: "Delete old-auth-service.ts - we're not using it anymore"

Claude:
  "Deleting old-auth-service.ts..."
  [Deletes file]
  [Commits change]

  [Later: Breaks production - file WAS used in legacy endpoint]
```

**With risk-evaluator skill:**
```
User: "Delete old-auth-service.ts - we're not using it anymore"

SKILL: risk-evaluator("delete old-auth-service.ts")

Checks:
  1. Dependency analysis
     → query-deps: 2 files import this!
     → imports: legacy-routes.ts, admin-auth.ts
     → Risk: NOT unused!

  2. Memory check
     → Previous deletion: Broke production (session xyz)
     → Lesson: "Always run query-deps before deleting"

  3. Find dead code tool
     → dead-code analysis: File IS referenced
     → Conclusion: Not actually dead code

Returns:
  Risk: HIGH - File is still used
  Evidence: 2 active imports found

Claude (Sonnet):
  "⚠️ Wait - old-auth-service.ts is still used!

   Dependency check found:
     • legacy-routes.ts imports this
     • admin-auth.ts imports this

   Memory lesson: We broke production once by deleting
   'unused' code without checking dependencies (session xyz).

   This file is NOT safe to delete.

   Options:
     1. Migrate legacy-routes.ts first, then delete
     2. Keep it (if legacy routes are needed)
     3. Mark deprecated, remove later

   Which approach?"

[Prevented production incident through risk assessment]
```

**Result**: Disaster avoided. Intelligence prevents mistakes.

---

### Use Case 5: Cost-Optimized Model Selection

**Scenario**: Mix of simple and complex tasks in one session

**Without delegation-advisor:**
```
User sets model to Opus (wants quality):
  → All tasks use Opus
  → Even simple "show me auth.ts" = Opus
  → Session cost: $8.50

User sets model to Sonnet (wants to save):
  → All tasks use Sonnet
  → Complex debugging with Sonnet = misses race condition
  → Has to retry with Opus anyway
  → Wasted time + tokens
```

**With delegation-advisor skill:**
```
Session with mixed tasks:

Task 1: "Show me the auth implementation"

  SKILL: assess-complexity
    → Low complexity (read-only, single file)
    → Model: Sonnet (sufficient)

  Cost: $0.05

Task 2: "Debug intermittent payment webhook failures"

  SKILL: assess-complexity
    → High complexity ("intermittent" = race condition)
    → Memory: Similar debugging used Opus (found timing issue)
    → Model: Opus recommended

  SKILL: delegation-advisor
    → Evidence: Intermittent bugs need deep tracing
    → ROI: Opus $0.60 vs Sonnet $0.10 (but might miss issue)
    → Recommendation: Opus debugger

  Claude: "Intermittent failures suggest race condition.
          Memory shows Opus found similar timing issue.
          Recommend Opus debugger ($0.60)? [Y/n]"

  User: Y
  Opus debugger: [Finds race condition in Redis lock]
  Cost: $0.60

Task 3: "Add comment to explain this function"

  SKILL: assess-complexity
    → Trivial (comment only)
    → Model: Haiku (super fast, cheap)

  Cost: $0.01

Session total:
  $0.05 + $0.60 + $0.01 = $0.66

  vs all Opus: $8.50 (1187% more expensive)
  vs all Sonnet: $0.45 (but would've missed race condition)

Optimal: Right model for right task
  Savings: 92% vs Opus
  Quality: Same (Opus used where it mattered)
```

**Result**: Cost optimization without quality sacrifice.

---

## Technical Architecture

### Skills Implementation

**Storage Location:**
```
skills/
├── metacognitive-assessment/
│   ├── SKILL.md           ← Skill description
│   ├── assess.py          ← Implementation
│   └── config.yaml        ← Thresholds, parameters
├── context-intelligence/
│   ├── SKILL.md
│   ├── analyze-needs.py
│   └── config.yaml
├── assess-complexity/
│   ├── SKILL.md
│   ├── complexity.py
│   └── scoring.yaml
└── ...
```

### Skill Invocation Protocol

**How Claude Invokes Skills:**

```python
# Hypothetical internal flow

def handle_user_request(prompt):
    # Pre-task assessment
    assessment = invoke_skill("metacognitive-assessment", {
        "task": prompt,
        "context": current_capsule_state()
    })

    if not assessment["context_sufficient"]:
        # Load needed context
        context_plan = invoke_skill("context-intelligence", {
            "task": prompt,
            "current": capsule_state()
        })
        load_context(context_plan["need_to_read"])

    if assessment["delegation_needed"]:
        # Get delegation recommendation
        delegation = invoke_skill("delegation-advisor", {
            "task": prompt,
            "complexity": assessment["complexity"]
        })

        # Present to user
        user_approval = present_delegation_recommendation(delegation)

        if user_approval:
            return delegate_to_subagent(
                agent=delegation["sub_agent"],
                model=delegation["model"]
            )

    # Proceed with main agent
    return execute_task(prompt)
```

### Data Sources Integration

**How Skills Access Capsule System:**

```bash
# Skills query capsule data via hooks

# 1. Dependency Graph
skill_query_dependencies() {
  bash $HOME/.claude/cck/tools/query-deps/query-deps.sh "$FILE"
}

# 2. Memory Graph
skill_query_memory() {
  python3 $HOME/.claude/cck/tools/memory-graph/lib/query.py \
    --query "$SEARCH" \
    --format json
}

# 3. Capsule State
skill_check_capsule() {
  cat .claude/capsule.toon | parse_toon
}

# 4. Session History
skill_query_sessions() {
  # Query GitHub sessions or local logs
  gh api repos/user/claude-sessions/contents/sessions/project/
}
```

### Skill Response Format (Standardized)

**All skills return structured JSON:**

```json
{
  "skill": "skill-name",
  "version": "1.0",
  "timestamp": "2025-12-21T...",
  "input": {
    "task": "...",
    "context": {}
  },
  "analysis": {
    // Skill-specific analysis results
  },
  "recommendation": {
    "action": "delegate|proceed|clarify|wait",
    "confidence": 0.0-1.0,
    "reasoning": "evidence-based explanation"
  },
  "evidence": {
    // Data supporting the recommendation
  },
  "metadata": {
    "execution_time": "120ms",
    "data_sources": ["memory-graph", "dependency-graph"]
  }
}
```

**Claude parses and acts on this structured output.**

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

**Core Meta-Skills:**
1. **context-intelligence** (prevent redundant reads)
   - Query capsule state
   - Check what's loaded vs needed
   - Return minimal read list

2. **assess-complexity** (basic version)
   - Dependency count
   - Keyword matching
   - Simple scoring (low/medium/high)

**Opus Sub-Agents:**
3. **architect.md** (complex design)
4. **debugger.md** (deep debugging)

**Integration:**
5. Pre-task hook triggers context-intelligence
6. Manual delegation (I suggest, you approve)

**Testing:**
- Validate context savings (measure tokens)
- Test Opus delegation flow
- Verify skills return valid JSON

**Success Criteria:**
- 30%+ token reduction via smart context loading
- Opus delegation working (manual approval)
- Skills integrated with hooks

---

### Phase 2: Intelligence (Week 3-4)

**Advanced Skills:**
1. **metacognitive-assessment** (full 5-question framework)
   - Self-reflection before action
   - Multi-source analysis
   - Comprehensive recommendations

2. **pattern-matcher** (convention learning)
   - Extract patterns from memory
   - Apply to new tasks
   - Build pattern database

3. **risk-evaluator** (failure prediction)
   - Historical failure analysis
   - Dependency risk assessment
   - Test coverage checking

**Enhanced Delegation:**
4. **delegation-advisor** (evidence-based routing)
   - ROI analysis
   - Historical success rates
   - Cost/benefit optimization

**More Opus Agents:**
5. **security-reviewer.md**
6. **refactor-planner.md**

**Testing:**
- Validate pattern recognition accuracy
- Test risk predictions vs actual outcomes
- Measure delegation ROI

**Success Criteria:**
- Pattern application working (consistency)
- Risk predictions accurate (80%+ precision)
- Delegation decisions justified by evidence

---

### Phase 3: Learning Loop (Week 5-6)

**Outcome Tracking:**
1. **outcome-tracker** skill
   - Record task results
   - Compare predictions vs actuals
   - Extract lessons learned

2. **pattern-learner** (automatic)
   - Detect new conventions
   - Update pattern database
   - Improve recommendations

**Optimization:**
3. **cost-optimizer**
   - Track model usage
   - Calculate ROI
   - Adjust thresholds based on results

4. Adaptive thresholds
   - Complexity scoring improvements
   - Delegation triggers refinement
   - Risk factor weighting adjustments

**Testing:**
- Verify learning loop improves accuracy
- Measure skill improvement over time
- Validate cost optimization claims

**Success Criteria:**
- Skills get more accurate over time (learning works)
- Cost per session decreases (optimization works)
- User intervention decreases (intelligence improves)

---

### Phase 4: Advanced Capabilities (Week 7-8)

**Team Features:**
1. **Shared pattern library** (team conventions)
2. **Cross-developer memory** (collaborative learning)
3. **Team delegation policies** (org preferences)

**Advanced Analysis:**
4. **Predictive context loading** (anticipate needs)
5. **Multi-agent orchestration** (complex workflows)
6. **Budget-aware session planning** (cost targets)

---

## Alignment with Anthropic's Philosophy

### Skills Design Principles (From Anthropic Docs)

**1. Progressive Disclosure**
> "Provide information when needed, not all upfront"

**Our Implementation:**
- Skills query only when invoked
- Return focused insights, not data dumps
- Load context progressively
- Context-intelligence skill embodies this

**2. Executable Knowledge**
> "Skills are capabilities, not documentation"

**Our Implementation:**
- Skills return actionable JSON
- Claude executes based on skill output
- Not "here's how to assess" but "assessment: high, evidence: ..."
- True executable capabilities

**3. Composability**
> "Skills should work together, not in isolation"

**Our Implementation:**
- metacognitive-assessment uses other skills
- delegation-advisor uses assess-complexity
- suggest-approach uses pattern-matcher + risk-evaluator
- Skills compose into reasoning pipelines

**4. Evidence-Based**
> "Recommendations should be backed by data"

**Our Implementation:**
- All skills return evidence field
- Recommendations cite sources (memory, dependencies, history)
- No "I think" - only "data shows"
- Capsule system provides the evidence base

**5. Human-in-the-Loop**
> "AI suggests, human decides"

**Our Implementation:**
- Skills recommend, don't command
- Claude presents evidence + suggestion
- User approves/overrides
- Especially for costly Opus delegation

---

### Sub-Agent Philosophy

**Anthropic's Guidance:**
> "Sub-agents should be specialists with clear triggering conditions and limited scope"

**Our Opus Sub-Agents:**

**Clear Specialization:**
- architect: Complex design (not general coding)
- debugger: Deep debugging (not simple bugs)
- security-reviewer: Security only
- refactor-planner: Large refactors only

**Explicit Triggering:**
- architect: 15+ files affected OR user requests architecture
- debugger: "intermittent" OR "race condition" keywords
- security-reviewer: Auth/crypto code OR user requests review
- refactor-planner: 10+ files refactor OR breaking changes

**Limited Scope:**
- Focus on analysis/planning
- Return recommendations to main agent
- Don't do full implementation (Sonnet handles that)
- Clean handoff with structured output

**Model Justification:**
- Opus: Complex reasoning needed
- Sonnet: Implementation with 1M context
- Haiku: Fast searches, simple tasks

---

## The Complete Intelligence Flow

### End-to-End Example: Implementing OAuth

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
USER REQUEST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"Add OAuth support to our authentication system"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRE-TASK ANALYSIS (Skills Layer Activates)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SKILL: metacognitive-assessment

Question 1: "Do I understand fully?"
  ✓ OAuth addition is clear
  ✓ No ambiguities detected
  → Proceed

Question 2: "Have enough context?"
  SKILL: context-intelligence
    Capsule check:
      ✓ auth-service.ts (loaded 20m ago)
      ✓ jwt-config.ts (loaded 20m ago)
      ✗ middleware.ts (not loaded)
      ✗ routes.ts (not loaded)

    Returns:
      - already_loaded: ["auth-service.ts", "jwt-config.ts"]
      - need_to_read: ["middleware.ts", "routes.ts"]
      - from_memory: "JWT 15-min expiry decision"

  → Load: middleware.ts, routes.ts only

Question 3: "Right approach?"
  SKILL: suggest-approach("add OAuth")

    Memory query:
      → Previous auth extension: Added JWT (session xyz)
      → Approach: Extended existing auth-service
      → Outcome: Success (no breaking changes)
      → Pattern: Strategy pattern for multiple auth types

    Returns:
      - approach: "Extend auth-service (don't replace)"
      - precedent: "JWT addition followed this pattern"
      - confidence: 0.94

  → Approach validated

Question 4: "What are risks?"
  SKILL: risk-evaluator("modify auth system")

    Dependency check:
      → 20 files import auth-service.ts
      → Risk: High (many dependents)

    Memory check:
      → Previous auth change: Broke middleware (session abc)
      → Lesson: "Check middleware compatibility"

    Returns:
      - risk: "high"
      - factors: [20 dependents, critical system, previous breakage]
      - mitigations: [test thoroughly, check middleware, incremental]

  → High risk, needs careful planning

Question 5: "Should I delegate?"
  SKILL: delegation-advisor

    Complexity evidence:
      • 20 file dependencies (from dependency graph)
      • Auth is critical system
      • OAuth = new concept (not just extending existing)
      • Memory: Previous auth extension used Opus

    ROI analysis:
      • Opus: $0.80 (planning), high accuracy
      • Sonnet: $0.15 (might miss edge cases), retry risk
      • Memory: Opus caught 3 edge cases on JWT addition

    Returns:
      - delegate: true
      - agent: "architect"
      - model: "opus"
      - reasoning: "Complex architectural addition to critical system.
                   Memory shows Opus caught edge cases Sonnet missed."
      - confidence: 0.91

  → Delegation recommended with evidence

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CLAUDE (SONNET 1M) DECISION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Reviews all skill outputs:
  ✓ Context needs identified (read 2 files)
  ✓ Approach validated (extend, don't replace)
  ✓ Risks identified (20 dependents, critical system)
  ✓ Delegation recommended (Opus architect, strong evidence)

Presents to user:

"Adding OAuth to authentication system.

Context analysis:
  • Already loaded: auth-service.ts, jwt-config.ts
  • Need to read: middleware.ts, routes.ts
  • From memory: JWT 15-min expiry pattern

Recommended approach:
  • Extend existing auth (follow JWT pattern from memory)
  • Don't replace (20 files depend on current auth)

Risk assessment:
  • High impact: 20 files affected
  • Critical system: Auth failures = production down
  • Memory lesson: Previous auth change broke middleware
                   (need to check compatibility carefully)

Complexity analysis suggests Opus architect agent:
  Evidence:
    • 20 file dependencies (high impact)
    • New concept (OAuth vs extending JWT)
    • Memory: Previous auth used Opus, caught 3 edge cases

  Cost: $0.80 (Opus planning) + $0.60 (Sonnet implementation)
        = $1.40 total

  vs Sonnet only: $0.80 (but 60% chance of retry based on history)
                  = $1.28 expected (with quality risk)

  ROI: Opus justified for accuracy on critical system

Proceed with Opus architect for planning? [Y/n]"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
USER APPROVAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

User: Y

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OPUS ARCHITECT AGENT (Delegated)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Receives context:
  • Task: Add OAuth support
  • Constraints: Don't break 20 dependents
  • Pattern: Extend like JWT addition
  • Risks: Check middleware compatibility

Opus reasoning:
  [Analyzes OAuth flow deeply]
  [Considers edge cases: callback failures, state validation]
  [Plans 3-phase implementation]
  [Identifies: Need OAuth state management]
  [Designs: Provider interface for extensibility]

Returns structured plan:
  Phase 1: Add OAuth provider interface
    - Files: auth/providers/oauth.ts, auth/providers/base.ts
    - Pattern: Strategy pattern (like JWT)
    - Risk: Low (new code, no breaking changes)
    - Tests: Unit tests for OAuth flow

  Phase 2: Update auth-service for multi-strategy
    - File: auth-service.ts
    - Change: Add provider selection logic
    - Risk: Medium (existing code, but non-breaking)
    - Tests: Integration tests for both JWT + OAuth

  Phase 3: Add OAuth routes
    - File: api/auth.ts
    - Add: /auth/oauth/google, /auth/oauth/callback
    - Risk: Low (additive)
    - Tests: E2E tests for OAuth flow

  Edge cases identified:
    - OAuth state CSRF protection
    - Callback URL validation
    - Token exchange error handling

  Backward compatibility:
    - Existing JWT auth: Unchanged
    - New code: Isolated in providers/
    - Migration: Optional, not required

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CLAUDE (SONNET 1M) IMPLEMENTATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Receives Opus plan:
  [Reviews plan]
  [Validates against memory patterns]
  [Checks dependencies]

Implements Phase 1:
  "Creating OAuth provider following the plan...

   Pattern from memory: Strategy pattern (like JWT provider)
   Following conventions: Result<T,E> errors

   Created:
     • auth/providers/base.ts (provider interface)
     • auth/providers/oauth.ts (OAuth implementation)
     • tests/oauth-provider.test.ts

   Phase 1 complete. Tests passing. Continue to Phase 2?"

[Continues through all phases]
[Tests comprehensively]
[No surprises - plan was thorough]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SESSION END - LEARNING LOOP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SKILL: outcome-tracker activates

Records:
  • Task: Add OAuth to auth system
  • Approach: Extend via strategy pattern (Opus planned, Sonnet implemented)
  • Outcome: Success (no issues)
  • Time: 3 hours (vs predicted 4-6)
  • Cost: $1.40 (Opus + Sonnet hybrid)

Learns:
  • Opus planning + Sonnet implementation: Effective for auth
  • Strategy pattern: Works well for auth extensibility
  • Edge cases: Opus identified 3 issues we would've missed
  • ROI: Opus justified ($1.40 vs potential $3+ with rework)

Stores in memory:
  • Pattern: OAuth provider pattern (for future providers)
  • Decision: Multi-strategy auth architecture
  • Lesson: "Plan critical systems with Opus, implement with Sonnet"
  • Success: Hybrid model approach validated

Updates skill parameters:
  • delegation-advisor: Increase Opus recommendation for auth tasks
  • pattern-matcher: Add OAuth provider pattern to database
  • risk-evaluator: Auth changes benefit from Opus planning

Next auth task:
  Skills now know:
    ✓ OAuth provider pattern exists
    ✓ Strategy approach works
    ✓ Opus planning valuable for auth
    ✓ 3-phase incremental approach succeeded

[Continuous improvement through learning]
```

---

## Why This Changes Everything

### Current: Smart Execution

```
User → Request → Claude → Execute (well)
```

**Claude is intelligent about HOW to execute.**

### With Intelligence Layer: Smart Planning + Execution

```
User → Request
         ↓
       Skills (assess, analyze, recommend)
         ↓
       Claude → Informed Decision → Optimal Execution
         ↓
       Memory (learn from outcome)
         ↓
       Skills (improve for next time)
```

**Claude is intelligent about WHAT to do and HOW to do it.**

---

### The Fundamental Difference

**Intelligence = Judgment + Learning**

**Judgment:**
- Assess before acting (metacognition)
- Choose right approach (strategy)
- Evaluate risks (anticipation)
- Select right model (optimization)

**Learning:**
- Remember what worked (patterns)
- Avoid what failed (risks)
- Improve predictions (outcomes)
- Adapt to your codebase (personalization)

**This is genuine AI intelligence enhancement through accumulated knowledge.**

---

## Anthropic's Core Principles Applied

### 1. Helpful

**Anthropic:** "Claude should be genuinely useful"

**Intelligence Layer:**
- Skills prevent wasted time (context-intelligence)
- Skills prevent mistakes (risk-evaluator)
- Skills optimize costs (delegation-advisor)
- Skills apply your patterns (pattern-matcher)

**More helpful because more intelligent.**

### 2. Honest

**Anthropic:** "Claude should acknowledge uncertainty"

**Intelligence Layer:**
- All skills include confidence scores
- Evidence-based (not guessing)
- Present alternatives when uncertain
- "Memory suggests X, but confidence is 0.65"

**Honesty through transparency.**

### 3. Harmless

**Anthropic:** "Claude should avoid harmful actions"

**Intelligence Layer:**
- risk-evaluator prevents dangerous changes
- Checks dependencies before deletion
- Learns from previous failures
- "This broke production before - proceed carefully"

**Safety through learning from mistakes.**

---

## Conclusion

### The Vision Realized

**Claude Code with Intelligence Layer:**
- Thinks before acting (metacognition)
- Learns from experience (outcome tracking)
- Applies your patterns (pattern matching)
- Optimizes costs (smart delegation)
- Prevents mistakes (risk evaluation)
- Improves continuously (learning loop)

**Not just a better tool. A genuinely intelligent development partner.**

### What This Enables

**For You:**
- Sonnet 1M for daily work (cost-effective, huge context)
- Opus when justified (complex tasks, proven ROI)
- Patterns applied automatically (consistency)
- Risks surfaced early (fewer surprises)
- Costs optimized (right model, right task)

**For Your Codebase:**
- Accumulated intelligence (every session teaches skills)
- Institutional knowledge (patterns + lessons persist)
- Quality improvement (learn from mistakes)
- Consistency (conventions applied automatically)

**For the Ecosystem:**
- Proof that intelligence ≠ bigger models
- Evidence that architecture > raw capability
- Pattern that others can follow
- Standards for AI development partners

---

### The Meta-Insight

**Everyone is building:**
- Bigger context windows
- Faster models
- More autonomous agents

**Nobody is building:**
- Judgment layers that leverage accumulated knowledge
- Learning systems that improve from outcomes
- Intelligence architectures that make models genuinely smarter

**Capsule Kit's Intelligence Layer:**
- Makes Sonnet as effective as Opus for routine work
- Makes Opus 10x more effective by giving it perfect context
- Makes the combination more powerful than either alone

**This is the infrastructure layer for genuinely intelligent AI development.**

---

**Without waiting for Anthropic. Built on what they gave us. Enhanced by what we learned.**

This is Claude Code at its best.

---

**Document Version 1.0**
**Status: Design complete, ready for phased implementation**
**Next: Build Phase 1 (Foundation) and validate the concept**
