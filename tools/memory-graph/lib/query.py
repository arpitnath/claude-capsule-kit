#!/usr/bin/env python3
"""
Query Engine - Format and filter memory graph queries for context injection
"""

import os
import sys
import json
import argparse
from typing import List, Optional
from datetime import datetime, timedelta, timezone

# Add lib directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from graph import MemoryGraph
from parser import parse_node


def get_node_summary(node_id: str, graph: MemoryGraph) -> str:
    """Get a one-line summary of a node."""
    node_data = graph.get_node(node_id)
    if not node_data:
        return ""

    file_path = node_data.get("path")
    if not file_path or not os.path.exists(file_path):
        return ""

    node = parse_node(file_path)
    if not node:
        return ""

    # Extract first heading or first non-empty line as summary
    content_lines = node.content.strip().split('\n')
    title = ""
    summary = ""

    for line in content_lines:
        line = line.strip()
        if line.startswith('#'):
            title = line.lstrip('#').strip()
            break
        elif line and not summary:
            summary = line[:80]

    display = title or summary or node_id
    return display


def format_summary(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format nodes as brief summaries for context injection."""
    lines = []

    for node_id in node_ids:
        node_data = graph.get_node(node_id)
        if not node_data:
            continue

        node_type = node_data.get("type", "unknown")
        display = get_node_summary(node_id, graph)

        if display:
            lines.append(f"[{node_type}] {display}")

    return '\n'.join(lines)


def format_json(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format nodes as JSON."""
    nodes = []

    for node_id in node_ids:
        node_data = graph.get_node(node_id)
        if node_data:
            nodes.append({
                "id": node_id,
                **node_data
            })

    return json.dumps({"nodes": nodes, "count": len(nodes)}, indent=2)


def format_full(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format nodes with full content."""
    parts = []

    for node_id in node_ids:
        node_data = graph.get_node(node_id)
        if not node_data:
            continue

        file_path = node_data.get("path")
        if not file_path or not os.path.exists(file_path):
            continue

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            parts.append(f"--- {node_id} ---\n{content}")
        except IOError:
            continue

    return '\n\n'.join(parts)


def format_ids(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format as simple list of IDs."""
    return '\n'.join(node_ids)

def parse_date_arg(value: str) -> Optional[datetime]:
    """Parse the 'since' argument to obtain a minimum timestamp."""
    # cache time
    now = datetime.now(timezone.utc)
    # Defence check for no filtering
    if value == "all" or value.strip() == "":
        return None
    # Parse time range
    unit = value[-1]
    accepted_units = ["h", "d", "m", "y"]
    if unit not in accepted_units:
        raise ValueError(f"Time range unit must be one of: {accepted_units}.")
    unit_value = value[:-1]
    if not unit_value.isdigit():
        raise ValueError(f"Time range value must be an integer. Got {unit_value}.")
    if int(unit_value) <= 0:
        raise ValueError(f"Time range value must be greater than 0. Got {unit_value}.")
    unit_value = int(unit_value)
    # Obtain minimum time for search
    unit_funcs = {
        "h": lambda n: timedelta(hours=n),
        "d": lambda n: timedelta(days=n),
        "m": lambda n: timedelta(days=n*30),
        "y": lambda n: timedelta(days=n*365)
    }
    min_timestamp = now - unit_funcs[unit](unit_value)
    return min_timestamp

def main():
    parser = argparse.ArgumentParser(description="Query memory graph")
    parser.add_argument("--memory-dir", default=".claude/memory",
                        help="Path to memory directory")
    parser.add_argument("--command", required=True,
                        choices=["recent", "type", "tag", "related", "search", "id"],
                        help="Query command")
    parser.add_argument("--query", default="",
                        help="Query argument (type name, tag, node id, or search term)")
    parser.add_argument("--format", default="summary",
                        choices=["summary", "json", "full", "ids"],
                        help="Output format")
    parser.add_argument("--limit", type=int, default=5,
                        help="Maximum number of results")
    parser.add_argument("--status", default="active",
                        choices=["active", "archived", "all"],
                        help="Filter by status")
    parser.add_argument("--since", default="all",
                        help=(
                            "Filter results to a specific time range. "
                            "Use the format <value><unit> with no spaces. "
                            "Units: h = hours, d = days, m = months (30 days), y = years. "
                        ))
    args = parser.parse_args()

    # Override memory dir from environment if set
    memory_dir = os.environ.get("CLAUDE_MEMORY_DIR", args.memory_dir)
    graph = MemoryGraph(memory_dir)

    # Get node IDs based on command
    node_ids: List[str] = []

    if args.command == "recent":
        node_ids = graph.get_recent(args.limit)

    elif args.command == "type":
        node_ids = graph.get_by_type(args.query)[:args.limit]

    elif args.command == "tag":
        node_ids = graph.get_by_tag(args.query)[:args.limit]

    elif args.command == "related":
        node_ids = graph.get_related(args.query, args.limit)

    elif args.command == "search":
        node_ids = graph.search(args.query, args.limit)

    elif args.command == "id":
        if graph.get_node(args.query):
            node_ids = [args.query]

    # Filter by status
    if args.status != "all":
        filtered = []
        for nid in node_ids:
            node_data = graph.get_node(nid)
            if node_data and node_data.get("status") == args.status:
                filtered.append(nid)
        node_ids = filtered
    
    # Filter by date
    if args.since != "all":
        min_timestamp = parse_date_arg(value=args.since)
        filtered = []
        for nid in node_ids:
            node_data = graph.get_node(nid)
            updated_str = node_data.get("updated") if node_data else None
            if not updated_str:
                continue
            # convert str to timestamp
            try:
                if updated_str.endswith('Z'):
                    parsed_dt = datetime.strptime(
                        updated_str, "%Y-%m-%dT%H:%M:%SZ"
                    ).replace(tzinfo=timezone.utc)
                else:
                    parsed_dt = datetime.fromisoformat(updated_str)
            except Exception:
                continue # skip if timestamp cant be determined
            # safely add timezone (if not already included)
            if parsed_dt.tzinfo is None:
                parsed_dt = parsed_dt.replace(tzinfo=timezone.utc)
            if parsed_dt >= min_timestamp:
                filtered.append(nid)
        node_ids = filtered

    # Format output
    if args.format == "summary":
        output = format_summary(node_ids, graph)
    elif args.format == "json":
        output = format_json(node_ids, graph)
    elif args.format == "full":
        output = format_full(node_ids, graph)
    elif args.format == "ids":
        output = format_ids(node_ids, graph)
    else:
        output = ""

    if output:
        print(output)


if __name__ == "__main__":
    main()
