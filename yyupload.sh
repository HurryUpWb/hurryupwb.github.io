#!/bin/sh
hexo clean
git add .
LENGTH=8
RANDOM_STRING=$(date +%s%N | md5sum | head -c $LENGTH)
git commit -m "$RANDOM_STRING"
git pull
git push