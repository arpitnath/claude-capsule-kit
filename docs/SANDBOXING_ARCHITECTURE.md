## 🎯 Goals

1. **Security**: Prevent tools from accessing unauthorized resources
2. **Transparency**: Users know what tools can access
3. **Flexibility**: Allow legitimate use cases while blocking malicious ones
4. **Cross-Platform**: Works on macOS, Linux, Windows (Git Bash)
5. **Lightweight**: No heavy dependencies (Docker, VMs, etc.)

---

## 🔒 Security Threats

### What We're Protecting Against

| Threat | Example | Risk Level |
|--------|---------|------------|
| **Unauthorized File Access** | Tool reads `~/.ssh/private_key` | 🔴 HIGH |
| **Data Exfiltration** | Tool sends files to external server | 🔴 HIGH |
| **Malicious Code Execution** | Tool runs `rm -rf /` | 🔴 CRITICAL |
| **Resource Exhaustion** | Tool runs infinite loop | 🟡 MEDIUM |
| **Environment Tampering** | Tool modifies `.bashrc`, `PATH` | 🟡 MEDIUM |
| **Credential Theft** | Tool accesses `.env` files | 🔴 HIGH |

### What We're NOT Protecting Against (Out of Scope)
- Kernel exploits (OS-level security)
- Compromised Claude Code binary itself

---

## 🏗️ Architecture Layers

### Layer 1: Permission Declaration (tool.json)

**Purpose:** Tools explicitly declare what they need

```json
{
  "name": "example-tool",
  "permissions": {
    "read": [
      "**/*.ts",           // Can read all TypeScript files
      "package.json",      // Can read package.json
      "~/.claude/*.json"   // Can read Claude config
    ],
    "write": [
      "~/.claude/dep-graph.toon",  // Can write dependency graph
      "/tmp/*"                      // Can write to temp
    ],
    "network": {
      "enabled": false,
      "allowed_domains": []  // If enabled, restrict to these domains
    },
    "execute": {
      "allowed_commands": ["jq", "node"],  // Can only run these
      "shell_access": false                 // No arbitrary shell
    },
    "environment": {
      "read": ["PATH", "HOME"],      // Can read these env vars
      "write": []                     // Cannot modify env
    }
  },
  "resource_limits": {
    "timeout": 30,        // Max 30 seconds
    "max_memory": "512M", // Max 512MB RAM
    "max_files": 1000     // Max 1000 files accessed
  }
}
```

### Layer 2: Pre-Execution Validation

**Purpose:** Check permissions before running tool

```bash
# In tool-runner.sh
validate_permissions() {
    local tool_name=$1
    local operation=$2  # "read", "write", "network", "execute"
    local target=$3      # file path, domain, or command

    # Load tool permissions
    local perms=$(get_tool_metadata "$tool_name" | jq -r ".permissions.$operation")

    # Check if target matches allowed patterns
    if ! matches_pattern "$target" "$perms"; then
        log_security_violation "$tool_name" "$operation" "$target"
        return 1
    fi

    return 0
}
```

### Layer 3: Execution Wrapper

**Purpose:** Wrap tool execution with sandboxing

```bash
# Platform-specific sandboxing
execute_sandboxed() {
    local tool_type=$1
    local tool_script=$2
    shift 2
    local args=("$@")

    case "$PLATFORM" in
        darwin)
            # macOS: Use sandbox-exec
            sandbox-exec -f "$SANDBOX_PROFILE" \
                "$tool_script" "${args[@]}"
            ;;
        linux)
            # Linux: Use firejail or bubblewrap if available
            if command -v firejail >/dev/null; then
                firejail --noprofile --private-tmp \
                    "$tool_script" "${args[@]}"
            else
                # Fallback: Basic restrictions
                execute_restricted "$tool_script" "${args[@]}"
            fi
            ;;
        *)
            # Windows/Other: Basic validation only
            execute_restricted "$tool_script" "${args[@]}"
            ;;
    esac
}
```

### Layer 4: Path Validation

**Purpose:** Ensure file access is within allowed paths

```bash
# Whitelist approach
ALLOWED_PATHS=(
    "$PROJECT_ROOT"          # Project directory
    "$HOME/.claude"          # Claude config
    "/tmp"                   # Temp files
    "$HOME/.config/claude"   # User config
)

FORBIDDEN_PATHS=(
    "$HOME/.ssh"             # SSH keys
    "$HOME/.aws"             # AWS credentials
    "$HOME/.env"             # Environment secrets
    "/etc/passwd"            # System files
    "/root"                  # Root directory
)

validate_file_access() {
    local file_path=$1
    local operation=$2  # read/write

    # Normalize path
    file_path=$(realpath "$file_path" 2>/dev/null || echo "$file_path")

    # Check forbidden paths first
    for forbidden in "${FORBIDDEN_PATHS[@]}"; do
        if [[ "$file_path" == "$forbidden"* ]]; then
            return 1  # Denied
        fi
    done

    # Check allowed paths
    for allowed in "${ALLOWED_PATHS[@]}"; do
        if [[ "$file_path" == "$allowed"* ]]; then
            return 0  # Allowed
        fi
    done

    return 1  # Deny by default
}
```

### Layer 5: Network Restrictions

**Purpose:** Control network access

```bash
# Check if tool can make network calls
validate_network_access() {
    local tool_name=$1
    local domain=$2

    # Get tool's network permissions
    local network_enabled=$(get_tool_metadata "$tool_name" | \
        jq -r '.permissions.network.enabled // false')

    if [[ "$network_enabled" != "true" ]]; then
        log_security_violation "$tool_name" "network" "$domain"
        return 1
    fi

    # Check domain whitelist
    local allowed_domains=$(get_tool_metadata "$tool_name" | \
        jq -r '.permissions.network.allowed_domains[]')

    if ! echo "$allowed_domains" | grep -q "$domain"; then
        log_security_violation "$tool_name" "network" "$domain"
        return 1
    fi

    return 0
}
```

### Layer 6: Audit Logging

**Purpose:** Log all tool executions for security review

```bash
# Security audit log
AUDIT_LOG="$HOME/.claude/security_audit.log"

log_tool_execution() {
    local tool_name=$1
    local operation=$2
    local target=$3
    local result=$4  # "allowed" or "denied"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "$timestamp|$tool_name|$operation|$target|$result" >> "$AUDIT_LOG"
}

log_security_violation() {
    local tool_name=$1
    local operation=$2
    local target=$3
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Log to audit log
    log_tool_execution "$tool_name" "$operation" "$target" "DENIED"

    # Alert user
    echo "[SECURITY] Blocked: $tool_name attempted $operation on $target" >&2

    # Optional: Send to security monitoring
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Security Alert" \
            "$tool_name attempted unauthorized $operation"
    fi
}
```

---

## 🔄 Execution Flow

```
┌─────────────────────┐
│ User runs tool      │
│ run_tool find-deps  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Load tool.json      │
│ Get permissions     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Validate permissions│
│ - Check read/write  │
│ - Check network     │
│ - Check commands    │
└──────────┬──────────┘
           │
      ┌────┴────┐
      │ Valid?  │
      └────┬────┘
           │
     ┌─────┴─────┐
     │           │
    YES          NO
     │           │
     ▼           ▼
┌─────────┐  ┌─────────┐
│ Execute │  │ Deny &  │
│ Tool    │  │ Log     │
└────┬────┘  └─────────┘
     │
     ▼
┌─────────────────────┐
│ Monitor execution   │
│ - Track file access │
│ - Track network     │
│ - Enforce timeouts  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Log to audit trail  │
└─────────────────────┘
```

## 📊 Default Permission Policies

### Built-in Tools (Trusted)
```json
{
  "policy": "trusted",
  "permissions": {
    "read": ["**/*"],
    "write": ["~/.claude/**"],
    "network": { "enabled": false }
  }
}
```

### Third-Party Tools (Restricted)
```json
{
  "policy": "restricted",
  "permissions": {
    "read": ["$PROJECT_ROOT/**"],
    "write": ["$PROJECT_ROOT/**", "/tmp/**"],
    "network": { "enabled": false }
  }
}
```

### User Tools (Untrusted - Require Approval)
```json
{
  "policy": "untrusted",
  "permissions": {
    "read": [],    // Explicit only
    "write": [],   // Explicit only
    "network": { "enabled": false }
  }
}
```

---

## 🚨 Edge Cases

### 1. Symbolic Links
**Risk:** Tool creates symlink to sensitive file
**Solution:** Resolve all paths with `realpath`, check target

### 2. Relative Paths
**Risk:** `../../etc/passwd`
**Solution:** Normalize to absolute paths before validation

### 3. Shell Injection
**Risk:** Tool runs `$(rm -rf /)`
**Solution:** Escape arguments, use exec instead of eval

### 4. Time-of-check Time-of-use (TOCTOU)
**Risk:** File permissions change between check and use
**Solution:** Atomic operations where possible

### 5. Path Traversal
**Risk:** `/allowed/path/../../../etc/passwd`
**Solution:** Canonicalize paths, reject `..`

---



### Tool Runner Location

The sandboxing logic is implemented in `.claude/lib/tool-runner.sh` which:
- Loads tool.json manifests
- Validates permissions before execution
- Wraps tool execution with platform-appropriate sandboxing
- Logs all operations to audit trail
