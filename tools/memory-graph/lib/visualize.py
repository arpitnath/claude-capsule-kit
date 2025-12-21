#!/usr/bin/env python3
"""
Memory Graph Visualizer v2 - Hybrid Tree + Connection Graph
Combines structured tree view with ASCII connection visualization
"""

import os
import sys
import json
from datetime import datetime, timezone
from typing import Dict, List, Set, Tuple, Optional
from collections import defaultdict

# Add lib directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from graph import MemoryGraph

# ANSI Colors
RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
BLUE = "\033[38;5;75m"
GREEN = "\033[38;5;114m"
YELLOW = "\033[38;5;221m"
CYAN = "\033[38;5;123m"
MAGENTA = "\033[38;5;177m"
RED = "\033[38;5;203m"
GRAY = "\033[38;5;242m"
WHITE = "\033[38;5;255m"

TYPE_CONFIG = {
    "file-summary": {"color": BLUE, "symbol": "◆", "icon": "📁"},
    "task": {"color": GREEN, "symbol": "●", "icon": "✅"},
    "decision": {"color": YELLOW, "symbol": "◇", "icon": "🎯"},
    "discovery": {"color": CYAN, "symbol": "★", "icon": "💡"},
    "session": {"color": MAGENTA, "symbol": "◈", "icon": "📅"},
    "error": {"color": RED, "symbol": "✕", "icon": "❌"},
    "subagent": {"color": MAGENTA, "symbol": "◎", "icon": "🤖"},
}


def get_time_ago(timestamp_str: str) -> str:
    """Convert timestamp to relative time."""
    if not timestamp_str:
        return ""
    try:
        dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
        now = datetime.now(timezone.utc)
        delta = now - dt
        if delta.days > 0:
            return f"{delta.days}d"
        elif delta.seconds >= 3600:
            return f"{delta.seconds // 3600}h"
        elif delta.seconds >= 60:
            return f"{delta.seconds // 60}m"
        return "now"
    except:
        return ""


def truncate(text: str, max_len: int = 25) -> str:
    if len(text) <= max_len:
        return text
    return text[:max_len-1] + "…"


def get_display_name(node_id: str, node_type: str, nodes_data: dict = None) -> str:
    """Get clean display name for node."""
    # Try to get title from node data first
    if nodes_data and node_id in nodes_data:
        node = nodes_data[node_id]
        # Use file_path or title if available
        if node_type == "file-summary":
            path = node.get("file_path") or node.get("path", "")
            if path and isinstance(path, str):
                # Remove .md from memory node path, get actual filename
                name = os.path.basename(path)
                if name.endswith(".md"):
                    # This is a memory node path, extract from node_id instead
                    pass
                else:
                    return truncate(name, 20)

    # Fallback to parsing from node_id
    if node_type == "file-summary":
        # file-auth-ts → auth.ts
        name = node_id.replace("file-", "")
        # Handle double extension from memory path (file-auth-ts.md -> auth.ts)
        if name.endswith(".md"):
            name = name[:-3]  # Remove .md
        parts = name.rsplit("-", 1)  # Split from right to get extension
        if len(parts) == 2 and len(parts[1]) <= 4:  # Extension should be short
            return truncate(f"{parts[0]}.{parts[1]}", 20)
        return truncate(name, 20)
    elif node_type == "task":
        name = node_id.replace("task-", "").replace("-", " ")
        return truncate(name.title(), 20)
    elif node_type == "discovery":
        name = node_id.replace("discovery-", "").replace("-", " ")
        return truncate(name.title(), 20)
    return truncate(node_id, 20)


def draw_header(graph: MemoryGraph):
    """Draw the header section."""
    stats = graph.get_stats()
    nodes_data = graph.cache.get("nodes", {})

    # Count connections
    conn_count = sum(len(n.get("links_to", [])) for n in nodes_data.values())

    print()
    print(f"  {BOLD}Memory Graph{RESET}")
    print(f"  {GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{RESET}")
    print(f"  {DIM}Nodes:{RESET} {stats['node_count']}  {DIM}Types:{RESET} {stats['type_count']}  {DIM}Edges:{RESET} {conn_count}  {DIM}Tags:{RESET} {stats['tag_count']}")
    print()


def draw_type_section(ntype: str, node_ids: List[str], nodes_data: dict, all_connections: List[Tuple[str, str]]):
    """Draw a section for one node type with inline connections."""
    config = TYPE_CONFIG.get(ntype, {"color": GRAY, "symbol": "○", "icon": "📄"})
    color = config["color"]
    symbol = config["symbol"]
    icon = config["icon"]

    type_label = ntype.replace("-", " ").title()
    print(f"  {icon} {BOLD}{type_label}{RESET} {GRAY}({len(node_ids)}){RESET}")

    # Build connection map for this type's nodes
    outgoing = defaultdict(list)
    incoming = defaultdict(list)
    for src, dst in all_connections:
        if src in node_ids:
            outgoing[src].append(dst)
        if dst in node_ids:
            incoming[dst].append(src)

    for i, nid in enumerate(node_ids[:8]):
        node = nodes_data.get(nid, {})
        name = get_display_name(nid, ntype, nodes_data)
        time_ago = get_time_ago(node.get("updated", ""))

        # Status indicator
        status = node.get("status", "")
        status_char = ""
        if status == "completed":
            status_char = f"{GREEN}✓{RESET} "
        elif status == "in_progress":
            status_char = f"{YELLOW}◐{RESET} "
        elif status == "pending":
            status_char = f"{DIM}○{RESET} "

        # Connection indicators
        out_targets = outgoing.get(nid, [])
        in_sources = incoming.get(nid, [])

        conn_str = ""
        if out_targets:
            targets_preview = [get_display_name(t, nodes_data.get(t, {}).get("type", ""), nodes_data)[:12] for t in out_targets[:2]]
            conn_str += f" {GRAY}→{RESET} {', '.join(targets_preview)}"
            if len(out_targets) > 2:
                conn_str += f" {DIM}+{len(out_targets)-2}{RESET}"

        # Tree branch character
        is_last = (i == len(node_ids[:8]) - 1)
        branch = "└" if is_last else "├"

        # Build line
        line = f"     {branch}─ {status_char}{color}{symbol}{RESET} {name}"
        if time_ago:
            line += f" {DIM}{time_ago}{RESET}"
        if conn_str:
            line += conn_str

        print(line)

    if len(node_ids) > 8:
        print(f"     {DIM}   ... +{len(node_ids) - 8} more{RESET}")
    print()


def draw_connection_graph(nodes_data: dict, connections: List[Tuple[str, str]]):
    """Draw a small ASCII visualization of key connections."""
    if not connections:
        return

    # Get the most connected nodes
    conn_count = defaultdict(int)
    for src, dst in connections:
        conn_count[src] += 1
        conn_count[dst] += 1

    # Get top nodes by connectivity
    top_nodes = sorted(conn_count.keys(), key=lambda x: -conn_count[x])[:6]

    if len(top_nodes) < 2:
        return

    print(f"  {BOLD}Connection Map{RESET} {GRAY}(most connected){RESET}")
    print(f"  {GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{RESET}")

    # Draw simple radial layout from most connected node
    center = top_nodes[0]
    center_type = nodes_data.get(center, {}).get("type", "")
    center_config = TYPE_CONFIG.get(center_type, {"color": GRAY, "symbol": "○"})
    center_name = get_display_name(center, center_type, nodes_data)

    # Find direct connections from center
    center_out = [dst for src, dst in connections if src == center and dst in top_nodes]
    center_in = [src for src, dst in connections if dst == center and src in top_nodes]
    center_connected = list(set(center_out + center_in))[:4]

    if not center_connected:
        center_connected = top_nodes[1:5]

    # Draw radial ASCII graph
    print()

    # Top connections
    if len(center_connected) >= 2:
        n1 = center_connected[0]
        n2 = center_connected[1] if len(center_connected) > 1 else None

        n1_type = nodes_data.get(n1, {}).get("type", "")
        n1_config = TYPE_CONFIG.get(n1_type, {"color": GRAY, "symbol": "○"})
        n1_name = get_display_name(n1, n1_type, nodes_data)[:15]

        if n2:
            n2_type = nodes_data.get(n2, {}).get("type", "")
            n2_config = TYPE_CONFIG.get(n2_type, {"color": GRAY, "symbol": "○"})
            n2_name = get_display_name(n2, n2_type, nodes_data)[:15]

            # Draw top row with two nodes
            spacing = 30
            print(f"       {n1_config['color']}{n1_config['symbol']}{RESET} {n1_name:<15}           {n2_config['color']}{n2_config['symbol']}{RESET} {n2_name}")
            print(f"         {GRAY}╲{RESET}                         {GRAY}╱{RESET}")
            print(f"          {GRAY}╲{RESET}                       {GRAY}╱{RESET}")
        else:
            print(f"                  {n1_config['color']}{n1_config['symbol']}{RESET} {n1_name}")
            print(f"                       {GRAY}│{RESET}")

    # Center node
    print(f"             {center_config['color']}{center_config['symbol']}{RESET}━━━ {BOLD}{center_name}{RESET} ━━━{center_config['color']}{center_config['symbol']}{RESET}")

    # Bottom connections
    if len(center_connected) >= 3:
        n3 = center_connected[2]
        n4 = center_connected[3] if len(center_connected) > 3 else None

        n3_type = nodes_data.get(n3, {}).get("type", "")
        n3_config = TYPE_CONFIG.get(n3_type, {"color": GRAY, "symbol": "○"})
        n3_name = get_display_name(n3, n3_type, nodes_data)[:15]

        if n4:
            n4_type = nodes_data.get(n4, {}).get("type", "")
            n4_config = TYPE_CONFIG.get(n4_type, {"color": GRAY, "symbol": "○"})
            n4_name = get_display_name(n4, n4_type, nodes_data)[:15]

            print(f"          {GRAY}╱{RESET}                       {GRAY}╲{RESET}")
            print(f"         {GRAY}╱{RESET}                         {GRAY}╲{RESET}")
            print(f"       {n3_config['color']}{n3_config['symbol']}{RESET} {n3_name:<15}           {n4_config['color']}{n4_config['symbol']}{RESET} {n4_name}")
        else:
            print(f"                       {GRAY}│{RESET}")
            print(f"                  {n3_config['color']}{n3_config['symbol']}{RESET} {n3_name}")

    print()


def draw_edge_list(connections: List[Tuple[str, str]], nodes_data: dict):
    """Draw a compact edge list."""
    if not connections:
        return

    print(f"  {BOLD}Edges{RESET} {GRAY}({len(connections)} connections){RESET}")
    print(f"  {GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{RESET}")

    for i, (src, dst) in enumerate(connections[:8]):
        src_type = nodes_data.get(src, {}).get("type", "")
        dst_type = nodes_data.get(dst, {}).get("type", "")

        src_config = TYPE_CONFIG.get(src_type, {"color": GRAY, "symbol": "○"})
        dst_config = TYPE_CONFIG.get(dst_type, {"color": GRAY, "symbol": "○"})

        src_name = get_display_name(src, src_type, nodes_data)
        dst_name = get_display_name(dst, dst_type, nodes_data)

        print(f"     {src_config['color']}{src_config['symbol']}{RESET} {src_name} {GRAY}───▶{RESET} {dst_config['color']}{dst_config['symbol']}{RESET} {dst_name}")

    if len(connections) > 8:
        print(f"     {DIM}... +{len(connections) - 8} more edges{RESET}")
    print()


def draw_tags(graph: MemoryGraph):
    """Draw tags summary."""
    tags_data = graph.cache.get("tags", {})
    if not tags_data:
        return

    tag_counts = sorted([(t, len(ids)) for t, ids in tags_data.items()], key=lambda x: -x[1])

    print(f"  {BOLD}Tags{RESET}")
    tags_str = "  "
    for tag, count in tag_counts[:10]:
        tags_str += f"{CYAN}#{tag}{RESET}{GRAY}({count}){RESET}  "
    print(tags_str)
    print()


def draw_recent(graph: MemoryGraph, nodes_data: dict):
    """Draw recent activity."""
    recent = graph.get_recent(5)
    if not recent:
        return

    print(f"  {BOLD}Recent{RESET} {GRAY}(last 5){RESET}")
    for nid in recent:
        node = nodes_data.get(nid, {})
        ntype = node.get("type", "")
        config = TYPE_CONFIG.get(ntype, {"color": GRAY, "symbol": "○"})
        name = get_display_name(nid, ntype, nodes_data)
        time_ago = get_time_ago(node.get("updated", ""))
        print(f"     {config['color']}{config['symbol']}{RESET} {name} {DIM}{time_ago}{RESET}")
    print()


def visualize_graph(memory_dir: str = ".claude/memory"):
    """Main visualization function."""
    graph = MemoryGraph(memory_dir)
    nodes_data = graph.cache.get("nodes", {})
    types_data = graph.cache.get("types", {})

    if not nodes_data:
        print(f"\n  {DIM}No nodes in memory graph yet.{RESET}\n")
        return

    # Collect all connections
    connections = []
    for nid, node in nodes_data.items():
        for target in node.get("links_to", []):
            if target in nodes_data:
                connections.append((nid, target))

    # Draw sections
    draw_header(graph)

    # Draw each type section
    for ntype, node_ids in sorted(types_data.items()):
        draw_type_section(ntype, node_ids, nodes_data, connections)

    # Draw connection visualization if we have enough connections
    if len(connections) >= 3:
        draw_connection_graph(nodes_data, connections)
    elif connections:
        draw_edge_list(connections, nodes_data)

    draw_tags(graph)
    draw_recent(graph, nodes_data)


if __name__ == "__main__":
    memory_dir = os.environ.get("CLAUDE_MEMORY_DIR", ".claude/memory")
    if len(sys.argv) > 1:
        memory_dir = sys.argv[1]
    visualize_graph(memory_dir)
