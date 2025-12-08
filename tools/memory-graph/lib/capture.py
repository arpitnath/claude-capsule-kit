#!/usr/bin/env python3
"""
Auto-Capture Module - Automatically create memory nodes from tool usage
"""

import os
import sys
import json
import hashlib
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Dict, List

# Add lib directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parser import create_node


def get_session_id() -> str:
    """Get current session ID from environment or generate one."""
    return os.environ.get("CLAUDE_SESSION_ID", "unknown")


def sanitize_id(text: str) -> str:
    """Convert text to a valid node ID."""
    # Replace path separators and special chars with dashes
    sanitized = re.sub(r'[^a-zA-Z0-9-]', '-', text)
    # Remove consecutive dashes
    sanitized = re.sub(r'-+', '-', sanitized)
    # Remove leading/trailing dashes
    sanitized = sanitized.strip('-').lower()
    # Truncate if too long
    if len(sanitized) > 60:
        sanitized = sanitized[:60]
    return sanitized


def file_path_to_node_id(file_path: str) -> str:
    """Convert a file path to a unique node ID."""
    # Remove common prefixes and create a readable ID
    path = file_path

    # Remove home directory prefix
    home = os.path.expanduser("~")
    if path.startswith(home):
        path = path[len(home):]

    # Remove leading slashes
    path = path.lstrip("/")

    # Create ID from path
    node_id = f"file-{sanitize_id(path)}"

    return node_id


def get_node_path(memory_dir: str, node_type: str, node_id: str) -> str:
    """Get the file path for a node."""
    type_dir_map = {
        "file-summary": "files",
        "decision": "decisions",
        "discovery": "discoveries",
        "session": "sessions",
        "task": "tasks",
        "error": "errors"
    }

    subdir = type_dir_map.get(node_type, node_type + "s")
    return os.path.join(memory_dir, "nodes", subdir, f"{node_id}.md")


def node_exists(memory_dir: str, node_type: str, node_id: str) -> bool:
    """Check if a node already exists."""
    path = get_node_path(memory_dir, node_type, node_id)
    return os.path.exists(path)


def update_node_timestamp(memory_dir: str, node_type: str, node_id: str) -> bool:
    """Update the 'updated' timestamp in an existing node."""
    path = get_node_path(memory_dir, node_type, node_id)

    if not os.path.exists(path):
        return False

    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Update the 'updated' field in frontmatter
        now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        content = re.sub(
            r'^(updated:\s*)[\d\-T:Z]+',
            f'\\g<1>{now}',
            content,
            flags=re.MULTILINE
        )

        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)

        return True
    except Exception:
        return False


def capture_file_access(
    memory_dir: str,
    file_path: str,
    action: str = "read"
) -> Dict:
    """
    Capture a file access event and create/update a file-summary node.

    Args:
        memory_dir: Path to memory directory
        file_path: Path to the file being accessed
        action: Type of access (read, edit, write)

    Returns:
        Dict with status and node_id
    """
    node_id = file_path_to_node_id(file_path)
    node_type = "file-summary"

    # Check if node exists
    if node_exists(memory_dir, node_type, node_id):
        # Just update timestamp
        update_node_timestamp(memory_dir, node_type, node_id)
        return {"status": "updated", "node_id": node_id}

    # Create new node
    # Extract file name and extension for tags
    basename = os.path.basename(file_path)
    ext = os.path.splitext(basename)[1].lstrip('.')

    tags = []
    if ext:
        tags.append(ext)

    # Add action as tag
    tags.append(action)

    # Determine parent directory for context
    parent_dir = os.path.basename(os.path.dirname(file_path))
    if parent_dir and parent_dir not in ['.', '..']:
        tags.append(sanitize_id(parent_dir))

    # Create minimal content - Claude will fill in details later
    title = file_path
    content = f"""File accessed via {action} operation.

## Purpose
(To be filled by Claude after reading the file)

## Key Elements
(To be filled by Claude)
"""

    extra_frontmatter = {
        "file_path": file_path,
        "session_id": get_session_id(),
        "last_action": action
    }

    node_content = create_node(
        node_id=node_id,
        node_type=node_type,
        title=title,
        content=content,
        tags=tags,
        related=[],
        extra_frontmatter=extra_frontmatter
    )

    # Write node file
    node_path = get_node_path(memory_dir, node_type, node_id)
    os.makedirs(os.path.dirname(node_path), exist_ok=True)

    with open(node_path, 'w', encoding='utf-8') as f:
        f.write(node_content)

    return {"status": "created", "node_id": node_id}


def capture_task(
    memory_dir: str,
    task_content: str,
    task_status: str
) -> Dict:
    """
    Capture a task from TodoWrite.

    Args:
        memory_dir: Path to memory directory
        task_content: The task description
        task_status: Status (pending, in_progress, completed)

    Returns:
        Dict with status and node_id
    """
    # Create ID from task content
    node_id = f"task-{sanitize_id(task_content)}"
    node_type = "task"

    # Check if node exists
    if node_exists(memory_dir, node_type, node_id):
        # Update timestamp and potentially status
        node_path = get_node_path(memory_dir, node_type, node_id)
        try:
            with open(node_path, 'r', encoding='utf-8') as f:
                content = f.read()

            now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
            content = re.sub(
                r'^(updated:\s*)[\d\-T:Z]+',
                f'\\g<1>{now}',
                content,
                flags=re.MULTILINE
            )
            content = re.sub(
                r'^(task_status:\s*)\w+',
                f'\\g<1>{task_status}',
                content,
                flags=re.MULTILINE
            )

            with open(node_path, 'w', encoding='utf-8') as f:
                f.write(content)

            return {"status": "updated", "node_id": node_id}
        except Exception:
            pass

    # Create new task node
    tags = ["task", task_status]

    title = task_content[:80] if len(task_content) > 80 else task_content
    content = f"""## Task
{task_content}

## Status
{task_status}

## Notes
(Add notes as task progresses)
"""

    extra_frontmatter = {
        "session_id": get_session_id(),
        "task_status": task_status
    }

    node_content = create_node(
        node_id=node_id,
        node_type=node_type,
        title=title,
        content=content,
        tags=tags,
        related=[],
        extra_frontmatter=extra_frontmatter
    )

    node_path = get_node_path(memory_dir, node_type, node_id)
    os.makedirs(os.path.dirname(node_path), exist_ok=True)

    with open(node_path, 'w', encoding='utf-8') as f:
        f.write(node_content)

    return {"status": "created", "node_id": node_id}


def capture_discovery(
    memory_dir: str,
    category: str,
    insight: str,
    related_files: List[str] = None
) -> Dict:
    """
    Capture a discovery/insight.

    Args:
        memory_dir: Path to memory directory
        category: Category (pattern, insight, decision, architecture, bug, optimization)
        insight: The discovery content
        related_files: Optional list of related file paths

    Returns:
        Dict with status and node_id
    """
    # Create unique ID from content hash
    content_hash = hashlib.md5(insight.encode()).hexdigest()[:8]
    node_id = f"discovery-{category}-{content_hash}"
    node_type = "discovery"

    # Check if exists (unlikely with hash, but check anyway)
    if node_exists(memory_dir, node_type, node_id):
        return {"status": "exists", "node_id": node_id}

    tags = ["discovery", category]

    # Create related links from file paths
    related = []
    if related_files:
        for fp in related_files:
            related.append(file_path_to_node_id(fp))

    title = f"{category.title()}: {insight[:60]}"
    content = f"""## Discovery
{insight}

## Category
{category}

## Context
(Session: {get_session_id()})
"""

    extra_frontmatter = {
        "session_id": get_session_id(),
        "category": category
    }

    node_content = create_node(
        node_id=node_id,
        node_type=node_type,
        title=title,
        content=content,
        tags=tags,
        related=related,
        extra_frontmatter=extra_frontmatter
    )

    node_path = get_node_path(memory_dir, node_type, node_id)
    os.makedirs(os.path.dirname(node_path), exist_ok=True)

    with open(node_path, 'w', encoding='utf-8') as f:
        f.write(node_content)

    return {"status": "created", "node_id": node_id}


def capture_error(
    memory_dir: str,
    error_type: str,
    error_message: str,
    context: str = "",
    related_files: List[str] = None
) -> Dict:
    """
    Capture an error for future reference.

    Args:
        memory_dir: Path to memory directory
        error_type: Type of error
        error_message: The error message
        context: Additional context
        related_files: Optional list of related file paths

    Returns:
        Dict with status and node_id
    """
    # Create unique ID
    content_hash = hashlib.md5(error_message.encode()).hexdigest()[:8]
    node_id = f"error-{sanitize_id(error_type)}-{content_hash}"
    node_type = "error"

    if node_exists(memory_dir, node_type, node_id):
        return {"status": "exists", "node_id": node_id}

    tags = ["error", sanitize_id(error_type)]

    related = []
    if related_files:
        for fp in related_files:
            related.append(file_path_to_node_id(fp))

    title = f"Error: {error_type}"
    content = f"""## Error
**Type:** {error_type}

**Message:**
```
{error_message}
```

## Context
{context if context else "(No additional context)"}

## Resolution
(To be filled when resolved)
"""

    extra_frontmatter = {
        "session_id": get_session_id(),
        "error_type": error_type,
        "resolved": False
    }

    node_content = create_node(
        node_id=node_id,
        node_type=node_type,
        title=title,
        content=content,
        tags=tags,
        related=related,
        extra_frontmatter=extra_frontmatter
    )

    node_path = get_node_path(memory_dir, node_type, node_id)
    os.makedirs(os.path.dirname(node_path), exist_ok=True)

    with open(node_path, 'w', encoding='utf-8') as f:
        f.write(node_content)

    return {"status": "created", "node_id": node_id}


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Capture memory nodes")
    parser.add_argument("--memory-dir", default=".claude/memory",
                        help="Path to memory directory")

    subparsers = parser.add_subparsers(dest="command", help="Capture command")

    # File capture
    file_parser = subparsers.add_parser("file", help="Capture file access")
    file_parser.add_argument("file_path", help="Path to the file")
    file_parser.add_argument("--action", default="read",
                            choices=["read", "edit", "write"],
                            help="Type of access")

    # Task capture
    task_parser = subparsers.add_parser("task", help="Capture task")
    task_parser.add_argument("content", help="Task description")
    task_parser.add_argument("--status", default="pending",
                            choices=["pending", "in_progress", "completed"],
                            help="Task status")

    # Discovery capture
    discovery_parser = subparsers.add_parser("discovery", help="Capture discovery")
    discovery_parser.add_argument("category", help="Discovery category")
    discovery_parser.add_argument("insight", help="The insight/discovery")
    discovery_parser.add_argument("--related", nargs="*", default=[],
                                 help="Related file paths")

    # Error capture
    error_parser = subparsers.add_parser("error", help="Capture error")
    error_parser.add_argument("error_type", help="Type of error")
    error_parser.add_argument("message", help="Error message")
    error_parser.add_argument("--context", default="", help="Additional context")
    error_parser.add_argument("--related", nargs="*", default=[],
                             help="Related file paths")

    args = parser.parse_args()

    memory_dir = os.environ.get("CLAUDE_MEMORY_DIR", args.memory_dir)

    if args.command == "file":
        result = capture_file_access(memory_dir, args.file_path, args.action)
    elif args.command == "task":
        result = capture_task(memory_dir, args.content, args.status)
    elif args.command == "discovery":
        result = capture_discovery(memory_dir, args.category, args.insight, args.related)
    elif args.command == "error":
        result = capture_error(memory_dir, args.error_type, args.message,
                              args.context, args.related)
    else:
        parser.print_help()
        sys.exit(1)

    print(json.dumps(result))
