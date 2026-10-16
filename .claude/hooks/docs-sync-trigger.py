"""PostToolUse hook: ask the session to run the docs-sync agent after a source-of-truth file was edited.

Prints an additionalContext reminder for home/.chezmoidata/packages.yaml and home/dot_profile/*.ps1,
and nothing for any other path or malformed input. Never fails the tool call (always exits 0).
"""
import json
import re
import sys

SYNC_SOURCES = (
    re.compile(r"(^|/)home/\.chezmoidata/packages\.yaml$"),
    re.compile(r"(^|/)home/dot_profile/[^/]+\.ps1$"),
)


def is_sync_source(path: str) -> bool:
    normalized = path.replace("\\", "/")
    return any(pattern.search(normalized) for pattern in SYNC_SOURCES)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
        path = payload["tool_input"]["file_path"]
        if not isinstance(path, str) or not is_sync_source(path):
            return 0
        json.dump(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": (
                        f"{path} is a source of truth for generated documentation "
                        "(ReadMe.md package table, docs/terminal-bindings.md). "
                        "When your current edits are done, run the docs-sync agent once to refresh them."
                    ),
                }
            },
            sys.stdout,
        )
        sys.stdout.write("\n")
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
