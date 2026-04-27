#!/bin/bash

# 1. Stop the script if any command fails
set -e

echo "Starting deployment process..."

# 2. Clean up local public directory and rebuild
echo "Building site with Hugo..."
rm -rf public
hugo

# 3. Check if build was successful
if [ ! -d "public" ]; then
    echo "Error: Hugo build failed. 'public' folder not found."
    exit 1
fi

# 4. Upload files to your VPS
# We use 'rsync' instead of 'scp' because it is much faster (only uploads changed files)
# and it deletes files on the server that are no longer in your local build.
echo "Uploading files to VPS..."
rsync -avz --delete public/ petru@46.101.195.62:/var/www/blog-petru/

echo "Deployment complete! Your site is live."