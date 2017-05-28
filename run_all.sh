#!/usr/bin/env bash
# run_all shell script
# Created by David Laing, May 2017
#
# This script runs all the scripts for my Twitter news bot.
#
# Output:
#
# -- data/recent_tweets.csv
# -- data/previous_notif_tweets.csv
#
# Usage:
#
# Navigate to the project's root directory and type `bash run_all.sh`.

# Download the new tweets and save them to .csv in 'data'.
python src/get_and_wrangle_tweets.py

# Find the hottest tweets.
Rscript src/find_hot_tweets.R

# If a tweet has been selected, notify the user.
python src/notify.py

# Rerun the script in a minute.
at now + 1 minute << END
"$0" "$@"
END
