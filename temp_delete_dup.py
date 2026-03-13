import sys
import os

filename = r'd:/edu_platform_app_last_version/lib/presentation/screens/shared/course_details/course_details_screen.dart'
try:
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Remove lines 1583 to 1715 (1-based indices).
    # 0-based: 1582 to 1714.
    # Keep 0..1581 (lines 1..1582)
    # Keep 1715..end (lines 1716..end) (line 1716 is index 1715)
    
    start_remove_idx = 1582
    end_remove_idx = 1715
    
    new_lines = lines[:start_remove_idx] + lines[end_remove_idx:]
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
        
    print(f"Original lines: {len(lines)}")
    print(f"New lines: {len(new_lines)}")
    print(f"Deleted {len(lines) - len(new_lines)} lines.")
except Exception as e:
    print(f"Error: {e}")
