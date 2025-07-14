#!/bin/bash

# Create a logs folder if it doesn't exist
mkdir -p test_logs

# Find all test files in the test/ directory
find test -name "*_test.exs" | while read -r file; do
  # Extract just the filename (e.g., model_test.exs)
  filename=$(basename "$file")

  # Replace .exs with .txt for output
  outfile="test_logs/${filename%.exs}.txt"

  echo "Running $file..."
  mix test "$file" --trace > "$outfile" 2>&1

  echo "Output written to $outfile"
done

echo "✅ All tests run. See test_logs/*.txt for output."

