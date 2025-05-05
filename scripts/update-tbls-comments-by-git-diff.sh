#!/bin/bash
set -eu

# Get the diff for the schema file
SCHEMA_FILE="src/db/schema.ts"
DIFF_FILE=$(mktemp)

# Get the diff for the schema file from git
git diff --cached "$SCHEMA_FILE" > "$DIFF_FILE"

# Check if there are changes
if [ -s "$DIFF_FILE" ]; then
    echo "Changes detected in $SCHEMA_FILE, updating TBLS comments..."

    # Run the Perl script to update tbls.yml with regex-based extraction
    # The Perl script now uses regex pattern matching and converts camelCase to snake_case
    perl scripts/update-tbls-comments.pl --diff="$DIFF_FILE" --verbose

    # Add the updated tbls.yml to the current commit if it was modified
    if git diff --quiet tbls.yml; then
        echo "No changes to tbls.yml detected"
    else
        echo "Adding updated tbls.yml to commit"
        git add tbls.yml
    fi
else
    echo "No changes in $SCHEMA_FILE, skipping TBLS comment update."
fi

# Clean up
rm -f "$DIFF_FILE"

exit 0
