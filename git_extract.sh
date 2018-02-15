#!/bin/bash

echo "This script must be run from root directory of your repository"
echo "Please specify the subdirectory which should be extracted. Path to this subdirectory should be relative to git root directory."
read KEEP_DIR_PATH

TMP_DIR="/tmp"
FILES_TO_KEEP="$TMP_DIR/files_to_keep"
FILES_TO_REMOVE="$TMP_DIR/files_to_remove"
HELPER_SCRIPT="$TMP_DIR/helper.sh"

mkdir "$TMP_DIR"
touch "$HELPER_SCRIPT"
echo "echo \"\$1\"" > "$HELPER_SCRIPT"
echo "git log --name-only --format=format: --follow -- \"\$1\" >> \"$FILES_TO_KEEP\"" >> "$HELPER_SCRIPT"
chmod +x "$HELPER_SCRIPT"

touch "$FILES_TO_KEEP"
find "$KEEP_DIR_PATH" -exec "$HELPER_SCRIPT" '{}' \;
sort -u "$FILES_TO_KEEP" -o "$FILES_TO_KEEP"

# move files to newsubdir - modified command from git filter-branch help examples
export FILES_TO_KEEP
git filter-branch --index-filter \
    'git ls-files -s | grep -wFf "$FILES_TO_KEEP" | sed "s-\t\"*-&newsubdir/-" |
		GIT_INDEX_FILE=$GIT_INDEX_FILE.new \
			git update-index --index-info &&
	 mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE" || true' HEAD

# extract the new folder to the root of the repo
git filter-branch --prune-empty -f --subdirectory-filter newsubdir

# remove other files left accidentally
touch "$FILES_TO_REMOVE"
find -type f -not -path "./$KEEP_DIR_PATH/*" -not -path "./.git/*" > "$FILES_TO_REMOVE"
export FILES_TO_REMOVE
git filter-branch --prune-empty -f --tree-filter \
    'while read file; do
	if [ -f "$file" ]; then
	    rm "$file"
	fi
    done < "$FILES_TO_REMOVE"'
git gc --aggressive
