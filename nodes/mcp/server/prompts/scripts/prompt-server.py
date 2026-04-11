#!/usr/bin/env python3
"""MCP server demonstrating prompt template patterns.

Exposes prompts for code review, debugging, SQL assistance,
and text analysis. Use as a reference for building prompt-rich servers.

Usage:
    python prompt-server.py
    npx @modelcontextprotocol/inspector python prompt-server.py

Requires: pip install "mcp[cli]"
"""

import sys

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Error: Install mcp package: pip install 'mcp[cli]'", file=sys.stderr)
    sys.exit(1)

mcp = FastMCP("prompt-examples")


@mcp.prompt()
def code_review(code: str, language: str = "python") -> str:
    """Review code for bugs, security vulnerabilities, and improvements.

    Args:
        code: The source code to review
        language: Programming language of the code
    """
    return (
        f"You are a senior {language} developer performing a code review.\n\n"
        f"Review the following code for:\n"
        f"1. Bugs and logic errors\n"
        f"2. Security vulnerabilities (injection, XSS, etc.)\n"
        f"3. Performance issues\n"
        f"4. Code style and readability\n"
        f"5. Missing error handling\n\n"
        f"Provide specific line-by-line feedback.\n\n"
        f"```{language}\n{code}\n```"
    )


@mcp.prompt()
def debug_error(error_message: str, context: str = "") -> str:
    """Help diagnose and fix an error.

    Args:
        error_message: The error message or exception
        context: Additional context about what was happening
    """
    prompt = (
        "You are an expert debugger. Analyze this error and provide:\n"
        "1. Root cause explanation\n"
        "2. Step-by-step fix\n"
        "3. How to prevent this in the future\n\n"
        f"**Error:**\n```\n{error_message}\n```"
    )
    if context:
        prompt += f"\n\n**Context:** {context}"
    return prompt


@mcp.prompt()
def sql_query(table_name: str, task: str = "query") -> str:
    """Generate SQL for a specific table and task.

    Args:
        table_name: Name of the database table
        task: What to do — query, insert, update, delete, analyze
    """
    return (
        f"You are a SQL expert. Help with the following task on the "
        f"'{table_name}' table: {task}\n\n"
        f"Requirements:\n"
        f"- Use parameterized queries to prevent SQL injection\n"
        f"- Include appropriate WHERE clauses\n"
        f"- Add comments explaining complex logic\n"
        f"- Consider performance (indexes, query plans)\n"
    )


@mcp.prompt()
def summarize(text: str, style: str = "concise") -> str:
    """Summarize text in a specific style.

    Args:
        text: The text to summarize
        style: Summary style — concise, detailed, bullet-points, eli5
    """
    style_instructions = {
        "concise": "Provide a 2-3 sentence summary capturing the key points.",
        "detailed": "Provide a comprehensive summary covering all major points and supporting details.",
        "bullet-points": "Summarize as a bulleted list of key points.",
        "eli5": "Explain like I'm 5 — use simple language and analogies.",
    }
    instruction = style_instructions.get(style, style_instructions["concise"])
    return f"{instruction}\n\nText to summarize:\n\n{text}"


if __name__ == "__main__":
    print("Starting prompt-examples MCP server...", file=sys.stderr)
    mcp.run()
