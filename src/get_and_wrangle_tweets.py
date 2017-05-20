#!/usr/bin/env python
# get_and_wrangle_tweets.py
# David Laing, May 2017
#
# This script queries from the Twitter API to get the most recent tweets from
# a list of news publication accounts, attaches those tweets to a file containing
# older tweets, deletes tweets that are older than 24 hours, and writes the
# resulting data to a CSV.

# import libraries/packages
#import argparse
from datetime import datetime, timedelta
import json
import pandas as pd
import time
import tweepy

# parse/define command line arguments here
parser = argparse.ArgumentParser()
parser.add_argument('input_file')
parser.add_argument('variable')
args = parser.parse_args()

# Define the users of interest.
users = ['nytimes',
         'thesun',
         'thetimes',
         'ap',
         'cnn',
         'bbcnews',
         'cnet',
         'msnuk',
         'telegraph',
         'usatoday',
         'wsj',
         'washingtonpost',
         'bostonglobe',
         'newscomauhq',
         'skynews',
         'sfgate',
         'ajenglish',
         'independent',
         'guardian',
         'latimes',
         'reutersagency',
         'abc',
         'business',
         'bw',
         'time']


# define main function
def get_and_wrangle(users):

    # Authenticate the API.
    authenticate_api()

    # Save the current time, and the cutoff time for keeping old tweets.
    current_time = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    cutoff_time = (datetime.utcnow() - timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S")

    new_tweets = query_tweets()

    tidy_new_tweets = wrangle_new_tweets()

    old_tweets = pd.read_csv("../data/old_tweets.csv")

    all_tweets = (tidy_new_tweets.pipe(append(old_tweets))
                                 .pipe(drop_duplicates(subset = 'tweet_url'))
                                 .pipe(reset_index(drop = True)))

    recent_tweets = all_tweets.drop_duplicates(subset = 'tweet_url').reset_index(drop = True)




# call main function
read_and_return()