#!/usr/bin/env python3
"""
Script to replace print statements with Logger calls in Swift files.
This helps clean up debug code for production builds.
"""

import os
import re
import sys
from pathlib import Path

def find_swift_files(directory):
    """Find all Swift files in the given directory."""
    swift_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.swift'):
                swift_files.append(os.path.join(root, file))
    return swift_files

def replace_print_statements(file_path):
    """Replace print statements with Logger calls in a Swift file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern to match print statements with different formats
    patterns = [
        # print("[Category] message")
        (r'print\("\[([^\]]+)\]\s*([^"]+)"\)', r'Logger.shared.log("\2", category: .\1, level: .info)'),
        # print("message")
        (r'print\("([^"]+)"\)', r'Logger.shared.log("\1", category: .general, level: .info)'),
        # print("message", variable)
        (r'print\("([^"]+)",\s*([^)]+)\)', r'Logger.shared.log("\1: \2", category: .general, level: .info)'),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    # Only write if content changed
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    
    return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python replace_prints.py <directory>")
        sys.exit(1)
    
    directory = sys.argv[1]
    if not os.path.exists(directory):
        print(f"Directory {directory} does not exist")
        sys.exit(1)
    
    swift_files = find_swift_files(directory)
    print(f"Found {len(swift_files)} Swift files")
    
    modified_files = []
    for file_path in swift_files:
        if replace_print_statements(file_path):
            modified_files.append(file_path)
            print(f"Modified: {file_path}")
    
    print(f"\nModified {len(modified_files)} files")
    print("Note: You may need to manually review and adjust Logger categories")

if __name__ == "__main__":
    main() 