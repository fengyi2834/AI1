import subprocess
import os

repo_path = r"C:\Users\Administrator\Desktop\AI1"
os.chdir(repo_path)

# Get git log with pretty format
result = subprocess.run(
    ["git", "log", "--oneline", "--decorate", "-20"],
    capture_output=True, text=True, shell=True
)
print("=== Git Log (oneline) ===")
print(result.stdout)
if result.stderr:
    print("STDERR:", result.stderr)

# Get detailed log
result2 = subprocess.run(
    ["git", "log", "--pretty=format:%h %ad %s", "--date=short", "-10"],
    capture_output=True, text=True, shell=True
)
print("\n=== Git Log (detailed) ===")
print(result2.stdout)
if result2.stderr:
    print("STDERR:", result2.stderr)

# Check branch
result3 = subprocess.run(
    ["git", "branch", "-a"],
    capture_output=True, text=True, shell=True
)
print("\n=== Git Branches ===")
print(result3.stdout)
if result3.stderr:
    print("STDERR:", result3.stderr)

# Check diff with master
result4 = subprocess.run(
    ["git", "log", "master..HEAD", "--oneline"],
    capture_output=True, text=True, shell=True
)
print("\n=== Commits on branch not in master ===")
print(result4.stdout)
