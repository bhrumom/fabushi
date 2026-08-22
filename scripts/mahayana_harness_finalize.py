from pathlib import Path
import subprocess

# Keep the already-validated current-API patch body pinned while the remaining
# compatibility fixes stay small and easy to iterate. These helpers are
# one-shot CI scaffolding and are deleted before merge.
base = subprocess.check_output(
    ["git", "show", "79679ddb406f52b33dc296d7e583ad6d9596b0ec:scripts/mahayana_harness_finalize.py"],
    text=True,
)
exec(compile(base, "mahayana_harness_finalize_base.py", "exec"), globals(), globals())

for name in ("mahayana_harness_finalize_tail.py", "mahayana_harness_finalize_tail2.py"):
    tail_path = Path(__file__).with_name(name)
    exec(compile(tail_path.read_text(), str(tail_path), "exec"), globals(), globals())
