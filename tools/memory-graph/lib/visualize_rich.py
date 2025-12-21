#!/usr/bin/env python3
"""
Memory Graph Visualizer - Terminal visualization using Rich
"""

import os
import sys
import json
from datetime import datetime, timezone
from pathlib import Path

try:
    from rich.console import Console
    from rich.tree import Tree
    from rich.panel import Panel
    from rich.text import Text
    from rich import box
except ImportError:
    print("Rich library required. Install with: pip install rich")
    sys.exit(1)

# Add lib directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from graph import MemoryGraph


def get_time_ago(timestamp_str: str) -> str:
    """Convert timestamp to relative time."""
    if not timestamp_str:
        return ""
    try:
        dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
        now = datetime.now(timezone.utc)
        delta = now - dt

        if delta.days > 0:
            return f"{delta.days}d ago"
        elif delta.seconds >= 3600:
            return f"{delta.seconds // 3600}h ago"
        elif delta.seconds >= 60:
            return f"{delta.seconds // 60}m ago"
        else:
            return "just now"
    except:
        return ""


def truncate(text: str, max_len: int = 50) -> str:
    """Truncate text with ellipsis."""
    if len(text) <= max_len:
        return text
    return text[:max_len-3] + "..."


def visualize_graph(memory_dir: str = ".claude/memory"):
    """Render the memory graph in terminal."""
    console = Console()

    # Load graph
    graph = MemoryGraph(memory_dir)
    stats = graph.get_stats()

    if stats["node_count"] == 0:
        console.print(Panel(
            "[dim]No nodes in memory graph yet.[/dim]\n\n"
            "Nodes are created when you:\n"
            "• Read/Edit/Write files\n"
            "• Use TodoWrite\n"
            "• Log discoveries",
            title="📊 Memory Graph",
            border_style="dim"
        ))
        return

    # Header
    header = Text()
    header.append("Memory Graph", style="bold bright_magenta")
    header.append(f" · {stats['node_count']} nodes", style="bright_cyan")
    header.append(f" · {stats['type_count']} types", style="bright_cyan")
    header.append(f" · {stats['tag_count']} tags", style="bright_cyan")

    # Create main tree
    tree = Tree(header)

    # Group nodes by type
    types_data = graph.cache.get("types", {})
    nodes_data = graph.cache.get("nodes", {})

    # Type icons
    type_icons = {
        "file-summary": "📁",
        "task": "✅",
        "decision": "🎯",
        "discovery": "💡",
        "session": "📅",
        "subagent": "🤖",
        "error": "❌"
    }

    type_colors = {
        "file-summary": "bold bright_blue",
        "task": "bold bright_green",
        "decision": "bold bright_yellow",
        "discovery": "bold bright_cyan",
        "session": "bold bright_magenta",
        "subagent": "bold bright_blue",
        "error": "bold bright_red"
    }

    # Status icons with styles (will be converted to Text objects)
    status_styles = {
        "completed": ("●", "bold bright_green"),
        "in_progress": ("○", "bold bright_yellow"),
        "pending": ("◌", "bright_white"),
        "active": ("●", "bold bright_green"),
        "archived": ("◌", "dim")
    }

    # Render each type
    for node_type, node_ids in sorted(types_data.items()):
        icon = type_icons.get(node_type, "📄")
        color = type_colors.get(node_type, "white")

        type_label = node_type.replace("-", " ").title()
        branch = tree.add(f"{icon} [{color}]{type_label}[/{color}] [dim]· {len(node_ids)}[/dim]")

        # Add nodes
        for node_id in node_ids[:10]:  # Limit to 10 per type
            node = nodes_data.get(node_id, {})

            # Build node display
            status = node.get("status", "active")

            # Get display name
            if node_type == "file-summary":
                # Extract filename from path
                file_path = node.get("path", node_id)
                name = os.path.basename(file_path).replace(".md", "")
                # Try to get original file path from node content
                name = node_id.replace("file-", "").replace("-", "/")[-40:]
            elif node_type == "task":
                name = node_id.replace("task-", "").replace("-", " ")
            else:
                name = node_id

            name = truncate(name, 45)

            # Tags
            tags = node.get("tags", [])
            tags_str = ", ".join(tags[:3]) if tags else ""

            # Time ago
            time_ago = get_time_ago(node.get("updated", ""))

            # Build line
            line = Text()
            # Add status icon with color
            if status in status_styles:
                icon_char, icon_style = status_styles[status]
                line.append(icon_char + " ", style=icon_style)
            line.append(truncate(name, 40), style="bright_white")
            if tags_str:
                line.append(f" [{tags_str}]", style="bright_cyan")
            if time_ago:
                line.append(f" {time_ago}", style="dim")

            branch.add(line)

        # Show if truncated
        if len(node_ids) > 10:
            branch.add(f"[dim]... and {len(node_ids) - 10} more[/dim]")

    # Connections section
    connections = []
    for node_id, node in nodes_data.items():
        links = node.get("links_to", [])
        for target in links:
            if target in nodes_data:
                connections.append((node_id, target))

    if connections:
        conn_branch = tree.add(f"🔗 [bold bright_magenta]Connections[/bold bright_magenta] [dim]· {len(connections)}[/dim]")
        for src, dst in connections[:5]:
            src_short = truncate(src, 25)
            dst_short = truncate(dst, 25)
            conn_branch.add(f"[bright_white]{src_short}[/bright_white] [bright_yellow]→[/bright_yellow] [bright_white]{dst_short}[/bright_white]")
        if len(connections) > 5:
            conn_branch.add(f"[dim]... and {len(connections) - 5} more[/dim]")

    # Recent section
    recent = graph.get_recent(5)
    if recent:
        recent_branch = tree.add(f"🕐 [bold bright_white]Recent[/bold bright_white] [dim]· last {len(recent)}[/dim]")
        for node_id in recent:
            node = nodes_data.get(node_id, {})
            time_ago = get_time_ago(node.get("updated", ""))
            name = truncate(node_id, 40)
            recent_branch.add(f"[bright_white]{name}[/bright_white] [bright_black]{time_ago}[/bright_black]")

    # Tags summary
    tags_data = graph.cache.get("tags", {})
    if tags_data:
        tag_counts = [(tag, len(ids)) for tag, ids in tags_data.items()]
        tag_counts.sort(key=lambda x: -x[1])
        top_tags = tag_counts[:8]
        tags_str = " ".join([f"[bold bright_cyan]{t}[/bold bright_cyan][bright_yellow]({c})[/bright_yellow]" for t, c in top_tags])
        tree.add(f"🏷️  [bold]Tags:[/bold] {tags_str}")

    # Print
    console.print()
    console.print(tree)
    console.print()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Visualize memory graph")
    parser.add_argument("--memory-dir", default=None,
                        help="Path to memory directory")
    parser.add_argument("--no-color", action="store_true",
                        help="Disable colors")

    args = parser.parse_args()

    memory_dir = args.memory_dir or os.environ.get("CLAUDE_MEMORY_DIR", ".claude/memory")

    if args.no_color:
        os.environ["NO_COLOR"] = "1"

    visualize_graph(memory_dir)
