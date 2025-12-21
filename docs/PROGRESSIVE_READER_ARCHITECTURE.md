# Progressive Reader Architecture

## Executive Summary

Progressive Reader is a system primitive for Claude Capsule Kit that enables efficient reading of large files and outputs through semantic chunking. Unlike traditional line-based or byte-offset reading, Progressive Reader uses tree-sitter to parse code into Abstract Syntax Trees (AST) and chunks content at logical boundaries (functions, classes, methods), preserving semantic coherence while managing context window limits.

**Implementation**: Go-based tool with tree-sitter bindings
**Status**: Implemented in Claude Capsule Kit v2.0
**Binary Location**: `~/.claude/bin/progressive-reader`

---

## 1. Problem Statement

### Core Challenges

**Context Window Limitations**
- Claude Sonnet 4.5 has ~200K token context window
- Large files (>50KB) can consume significant context
- Reading entire files reduces available context for responses
- Multiple large file reads compound the problem

**TPM (Tokens Per Minute) Rate Limits**
- Loading large outputs consumes TPM budget quickly
- Sub-agent outputs can be 10-50K tokens
- Inefficient reading leads to rate limit exhaustion

**Attention Mechanism Degradation**
- Large context reduces model attention quality
- Relevant information buried in noise
- Performance degradation with context size

**Agent-to-Agent Communication**
- Sub-agents (Explore, Plan) generate large outputs
- Executive agent needs selective reading capability
- Full output loading is wasteful

**Codebase Indexing Requirements**
- Need to process entire codebases for understanding
- Traditional read-all approach doesn't scale
- Cursor's approach: intelligent chunking + indexing

### Why Existing Tools Fall Short

**Standard Read Tool**
- All-or-nothing approach (read entire file)
- No continuation mechanism
- No semantic awareness

**Line-based Reading (offset/limit)**
- Arbitrary splits break function/class boundaries
- Context loss at chunk boundaries
- No understanding of code structure

**Bash-based Solutions**
- No tree-sitter access without external tools
- Performance overhead (~800ms per chunk)
- Complex parsing logic difficult to maintain
- No AST-based semantic understanding

---

## 2. Use Cases

### 2.1 Agent-to-Agent Communication
**Scenario**: Explore agent generates 30K token analysis of database architecture

**Without Progressive Reader**:
```
Executive Agent → Read entire 30K output → Context bloated
```

**With Progressive Reader**:
```
Executive Agent → Read chunk 1 (database models) → Process
              → Read chunk 2 (migration patterns) → Process
              → Skip remaining chunks (not relevant)
```

**Benefit**: Read only 8K tokens instead of 30K, 73% context savings

### 2.2 TPM Rate Limit Management
**Scenario**: Multiple sub-agents running in parallel, each producing large outputs

**Without Progressive Reader**:
```
Agent 1 output: 15K tokens
Agent 2 output: 20K tokens
Agent 3 output: 12K tokens
Total: 47K tokens → TPM exhausted quickly
```

**With Progressive Reader**:
```
Agent 1: Read first 3 chunks (6K tokens) → Sufficient
Agent 2: Read first 2 chunks (5K tokens) → Sufficient
Agent 3: Read first 4 chunks (7K tokens) → Sufficient
Total: 18K tokens → 62% reduction
```

### 2.3 Attention Mechanism Optimization
**Scenario**: Reading 100KB TypeScript file with 40 classes

**Without Progressive Reader**:
- Load entire 100KB → ~50K tokens in context
- Model attention dispersed across all 40 classes
- Quality degradation for specific class understanding

**With Progressive Reader**:
- Load Class 1 definition + methods (800 tokens)
- Focused attention on single class
- Better code understanding and suggestions

### 2.4 Codebase Indexing (Cursor's Approach)
**Scenario**: Understanding project architecture across 500 files

**Progressive Indexing Flow**:
```
1. Scan codebase → Generate file list
2. For each file:
   - Chunk semantically (classes, functions)
   - Extract signatures + docstrings
   - Build lightweight index
3. Query index → Load only relevant chunks
```

**Result**: Understand 500 files using 20K tokens instead of 2M tokens

### 2.5 Large File Exploration
**Scenario**: User asks "What does AuthService.ts do?"

**Flow**:
```
1. Read chunk 1 (imports + class definition) → Understand structure
2. Read chunk 2 (constructor + init methods) → Understand setup
3. User satisfied → Skip remaining 8 chunks
```

**Benefit**: Answered with 2 chunks instead of full file

### 2.6 Dependency Graph Enhancement
**Scenario**: Enrich dependency graph with function-level granularity

**Current**: File-level imports (A imports B)
**Future**: Function-level references (A.foo() calls B.bar())

**Progressive Reader enables**:
- Chunk each file by function
- Extract call graphs per chunk
- Build fine-grained dependency maps

### 2.7 Code Review Workflows
**Scenario**: Reviewing large PR with 50-file diff

**Progressive Approach**:
```
For each changed file:
  - Read only changed functions (not entire file)
  - Focus review on modifications
  - Skip unchanged code
```

---

## 3. Technical Design

### 3.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Claude Code CLI                      │
│                                                         │
│  ┌──────────────┐    calls    ┌──────────────────┐    │
│  │     User     │ ──────────> │ Progressive      │    │
│  │   Prompt     │             │ Reader CLI       │    │
│  └──────────────┘             └──────────────────┘    │
│                                       │                │
│                                       ↓                │
│                           ┌──────────────────────┐    │
│                           │   Go Binary          │    │
│                           │                      │    │
│                           │  ┌────────────────┐  │    │
│                           │  │ Tree-sitter    │  │    │
│                           │  │ Parser         │  │    │
│                           │  │ - TypeScript   │  │    │
│                           │  │ - JavaScript   │  │    │
│                           │  │ - Python       │  │    │
│                           │  │ - Go           │  │    │
│                           │  └────────────────┘  │    │
│                           │          │           │    │
│                           │          ↓           │    │
│                           │  ┌────────────────┐  │    │
│                           │  │ Semantic       │  │    │
│                           │  │ Chunker        │  │    │
│                           │  │ - AST walker   │  │    │
│                           │  │ - Boundary     │  │    │
│                           │  │   detection    │  │    │
│                           │  └────────────────┘  │    │
│                           │          │           │    │
│                           │          ↓           │    │
│                           │  ┌────────────────┐  │    │
│                           │  │ Chunk          │  │    │
│                           │  │ Formatter      │  │    │
│                           │  │ - Add context  │  │    │
│                           │  │ - Line nums    │  │    │
│                           │  └────────────────┘  │    │
│                           └──────────────────────┘    │
│                                       │                │
│                                       ↓                │
│                           ┌──────────────────────┐    │
│                           │  Continuation        │    │
│                           │  Token (TOON)        │    │
│                           │  CONTINUE:file=...   │    │
│                           │  CONTINUE:offset=2   │    │
│                           │  CONTINUE:lang=ts    │    │
│                           │                      │    │
│                           │                      │    │
│                           └──────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Core Components

#### 3.2.1 Tree-sitter Parser

**Purpose**: Parse source code into Abstract Syntax Trees (AST)

**Supported Languages**:
- TypeScript/TSX
- JavaScript/JSX
- Python
- Go

**Key Functions**:
```go
type Parser struct {
    tsParser  *sitter.Parser
    language  *sitter.Language
}

func NewParser(lang string) (*Parser, error)
func (p *Parser) Parse(sourceCode []byte) (*sitter.Tree, error)
func (p *Parser) GetLanguage() *sitter.Language
```

**AST Node Types** (TypeScript example):
- `function_declaration`: Top-level functions
- `method_definition`: Class methods
- `class_declaration`: Classes
- `interface_declaration`: Interfaces
- `type_alias_declaration`: Type definitions
- `export_statement`: Exports

#### 3.2.2 Semantic Chunker

**Purpose**: Split files at logical boundaries using AST structure

**Chunking Strategy**:

```go
type Chunk struct {
    Content       string
    StartLine     int
    EndLine       int
    Type          string  // "function", "class", "method", "interface"
    Name          string  // Identifier name
    Context       string  // Brief description
    HasMore       bool    // More chunks available?
    TotalChunks   int
    CurrentChunk  int
}

type Chunker interface {
    ChunkFile(filePath string, maxTokens int) ([]Chunk, error)
    GetChunk(filePath string, index int) (*Chunk, error)
}
```

**Boundary Detection Algorithm**:

```
1. Parse file → Generate AST
2. Walk AST root nodes (top-level declarations)
3. For each node:
   a. Extract start/end positions
   b. Classify type (function/class/etc)
   c. Estimate token count
   d. If tokens < maxTokens:
      - Add to current chunk
   e. Else:
      - Finalize current chunk
      - Start new chunk
4. Return chunk array
```

**Example** (TypeScript file with 3 classes):

```typescript
// chunk 0: imports + first class (lines 1-85)
import { User } from './user';
export class AuthService {
  // 60 lines of methods
}

// chunk 1: second class (lines 86-150)
export class TokenService {
  // 50 lines of methods
}

// chunk 2: third class (lines 151-220)
export class SessionService {
  // 55 lines of methods
}
```

**Token Estimation**:
```go
func estimateTokens(text string) int {
    // Rough heuristic: 1 token ≈ 4 characters
    return len(text) / 4
}
```

#### 3.2.3 Continuation Token System

**Purpose**: Enable stateful reading across multiple calls

**Token Structure** (TOON format):
```
CONTINUE:file=/absolute/path/to/file.ts
CONTINUE:offset=2
CONTINUE:language=typescript
CONTINUE:totalChunks=5
CONTINUE:checksum=sha256_hash_of_file
---
```

**Workflow**:
```
Call 1: progressive-reader --path file.ts
  → Returns chunk 0 + continuation token (TOON format)

Call 2: progressive-reader --continue-file '/tmp/token.toon'
  → Returns chunk 2 + continuation token

Call 3: progressive-reader --continue-file '/tmp/token.toon'
  → Returns chunk 3 + continuation token
```

**Checksum Validation**:
- Detect if file changed between reads
- Invalidate continuation token if mismatch
- Return error prompting fresh read

#### 3.2.4 Chunk Formatter

**Purpose**: Add context and metadata to chunks

**Output Format**:

```
┌─ Chunk 1/3 ─────────────────────────────────────────┐
│ File: src/services/auth.service.ts                  │
│ Lines: 1-85                                          │
│ Type: class                                          │
│ Name: AuthService                                    │
│ Context: Authentication service with login/logout   │
└─────────────────────────────────────────────────────┘

     1  import { User } from './user';
     2  import { Token } from './token';
     3
     4  export class AuthService {
     5    private tokenService: TokenService;
     6
     7    constructor() {
     8      this.tokenService = new TokenService();
     9    }
    10
    11    async login(username: string, password: string): Promise<User> {
    ...
    85  }

┌─────────────────────────────────────────────────────┐
│ More content available                              │
│ Continuation token saved to: /tmp/continue.toon     │
│ Use: progressive-reader --continue-file /tmp/...    │
└─────────────────────────────────────────────────────┘

Continuation Token (/tmp/continue.toon):
CONTINUE:file=/abs/path/src/services/auth.service.ts
CONTINUE:offset=1
CONTINUE:language=typescript
CONTINUE:totalChunks=3
CONTINUE:checksum=abc123def456
---
```

**Context Generation**:
- Extract first comment/docstring
- Fallback to class/function signature
- Limit to 60 characters

### 3.3 CLI Interface

**Command Structure**:

```bash
progressive-reader [options]
```

**Options**:

```
--path <path>           File to read (required unless --continue-file)
--chunk <n>             Read specific chunk number (0-indexed)
--continue-file <path>  Continue from previous read (TOON token file)
--max-tokens <n>        Maximum tokens per chunk (default: 2000)
--list                  List all chunks without content
--version               Show version
--help                  Show help
```

**Usage Examples**:

```bash
# Read first chunk of a file
progressive-reader --path src/auth.service.ts

# Read specific chunk
progressive-reader --path src/auth.service.ts --chunk 2

# Continue reading from token file
progressive-reader --continue-file /tmp/continue.toon

# List all chunks (lightweight)
progressive-reader --path src/auth.service.ts --list

# Adjust chunk size
progressive-reader --path src/auth.service.ts --max-tokens 4000
```

**Continuation Token Output** (/tmp/continue.toon):

```
CONTINUE:file=/abs/path/src/auth.service.ts
CONTINUE:offset=1
CONTINUE:language=typescript
CONTINUE:totalChunks=3
CONTINUE:checksum=abc123def456
CONTINUE:currentChunk=0
CONTINUE:hasMore=true
---
```
