#!/bin/zsh

set -e

SOURCE_ROOT="src"
DESTINATION="build/linux"

EXCLUDED_EXTENSION=".ps1"
EXCLUDED_KEYWORD="windows"

echo "🚀 Start build for linux in '$DESTINATION'"

# Remove destination folder if it exists
if [ -d "$DESTINATION" ]; then
  rm -rf "$DESTINATION"
fi

mkdir -p "$DESTINATION"

# Find all files in the source directory, excluding specific extensions and keywords
all_files=("${(@f)$(find "$SOURCE_ROOT" -type f ! -name "*$EXCLUDED_EXTENSION" ! -path "*$EXCLUDED_KEYWORD*")}")

total_files=${#all_files[@]}
counter=0

for file in "${all_files[@]}"; do
  # Get relative path after 'src/'
  relative_path="${file#"$SOURCE_ROOT"/}"
  target="$DESTINATION/$relative_path"
  target_dir=$(dirname "$target")

  mkdir -p "$target_dir"
  
  echo " => Copying file: $relative_path"
  cp "$file" "$target"

  ((++counter))
  
  # Show progress
  percent=$((counter * 100 / total_files))
  echo -ne "Progress: $counter/$total_files ($percent%)\r"
done

echo ""
echo "✅ Build for macOS completed in '$DESTINATION'"
