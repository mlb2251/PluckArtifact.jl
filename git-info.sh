echo "$(date '+%Y-%m-%d %H:%M:%S')"
dirty=""
if [ -n "$(git status --porcelain)" ]; then
  dirty=" (dirty)"
fi
echo "$(git remote -v | grep 'origin.*fetch' | awk '{print $2}') $(git branch --show-current || echo "detached") $(git rev-parse --short HEAD)$dirty"
git submodule foreach --recursive '
branch=$(git branch --show-current)
if [ -z "$branch" ]; then
  branch="detached"
fi
dirty=""
if [ -n "$(git status --porcelain)" ]; then
  dirty=" (dirty)"
fi
echo "$(git remote -v | grep "origin.*fetch" | awk "{print \$2}") $branch $(git rev-parse --short HEAD)$dirty"
' | grep -v "Entering"
