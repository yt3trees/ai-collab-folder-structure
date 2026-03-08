import sys
import tiktoken
import argparse

def count_tokens(text: str, model: str = "o200k_base") -> int:
    try:
        encoding = tiktoken.get_encoding(model)
        return len(encoding.encode(text))
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return -1

import json

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Count OpenAI tokens in a file or string.")
    parser.add_argument("--file", "-f", help="Path to a single file to count tokens for.")
    parser.add_argument("--files", nargs="+", help="List of file paths to count tokens for. Outputs JSON.")
    parser.add_argument("--text", "-t", help="Raw text string to count tokens for.")
    parser.add_argument("--model", "-m", default="o200k_base", help="Encoding model (e.g. o200k_base, cl100k_base)")
    
    args = parser.parse_args()

    if args.files:
        results = {}
        for path in args.files:
            try:
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                    results[path] = count_tokens(content, args.model)
            except Exception as e:
                pass # Skip unreadable or missing files
        print(json.dumps(results))
    else:
        content = ""
        if args.file:
            try:
                with open(args.file, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception as e:
                print(f"Error reading file: {e}", file=sys.stderr)
                sys.exit(1)
        elif args.text is not None:
            content = args.text
        else:
            # Read from stdin if no args provided
            if not sys.stdin.isatty():
                content = sys.stdin.read()
            else:
                print("Error: No input provided. Use --file, --text, --files, or pipe to stdin.", file=sys.stderr)
                sys.exit(1)

        tokens = count_tokens(content, args.model)
        print(tokens)
