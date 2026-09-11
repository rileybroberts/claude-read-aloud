A **shell pipeline** connects the output of one command to the input of another using the pipe operator (`|`), while a **subshell** creates a new child shell process that executes commands in isolation from the parent.

Pipelines chain commands together in a left-to-right flow where stdout becomes stdin. Each command in a pipeline runs in its own subprocess, but they execute concurrently and share the same environment—changes to variables in one stage don't affect others because each runs in a separate process, though they all descend from the same parent shell.

A subshell, created with parentheses `()` or explicit `bash -c`, spawns an entirely new shell instance. It inherits the parent's environment but operates independently. Variable assignments, directory changes, and other state modifications inside a subshell vanish when it exits because they never touched the parent's memory space.

```bash
# Pipeline: grep passes matches to wc
cat file.txt | grep "error" | wc -l

# Subshell: runs in isolated environment
(cd /tmp && rm *.log); pwd  # still in original directory
```

| **Pipeline** | **Subshell** |
|-------------|------------|
| Connects stdout→stdin between commands | Executes commands in isolated child shell |
| Uses `\|` operator | Uses `()` or `bash -c` |
| All stages run concurrently | Runs independently, then exits |
| Exit status is last command (or `pipefail`) | Returns its own exit status to parent |
| Variables unchanged (separate processes) | Variables scoped to subshell only |

**Three gotchas:**

- **Pipeline variables disappear**: Writing `cat data \| while read line; do count=$((count+1)); done` leaves `count` empty afterward because the `while` loop runs in a subprocess that can't modify the parent's variables. Use process substitution `while read line; do ...; done < <(cat data)` or a here-string instead.

- **Subshell exits are invisible**: A subshell can call `exit 1` without terminating your script—it only exits itself. Your parent shell continues merrily along unless you explicitly check `$?` afterward.

- **`set -e` behaves differently**: In pipelines with `set -e`, only the rightmost command's failure kills the script (unless `pipefail` is enabled). In subshells, `set -e` applies independently—the subshell dies but the parent might not unless you propagate the exit code with `|| exit $?`.
