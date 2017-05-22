#!/usr/bin/env python
# get_and_wrangle_tweets.py
# David Laing, May 2017
#
# This script queries from the Twitter API to get the most recent tweets from
# a list of news publication accounts, attaches those tweets to a file containing
# older tweets, deletes tweets that are older than 24 hours, and writes the
# resulting data to a CSV.

# import libraries/packages
from datetime import datetime, timedelta
import json
import pandas as pd
import time
import tweepy

# Read in the consumer key, consumer secret, access token, and access token secret.
consumer_key = open("../../auth/twitter/consumer_key.txt").read()[:-1]
consumer_secret = open("../../auth/twitter/consumer_secret.txt").read()[:-1]
access_token = open("../../auth/twitter/access_token.txt").read()[:-1]
access_token_secret = open("../../auth/twitter/access_token_secret.txt").read()[:-1]

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

# Define the main function.
def get_and_wrangle(consumer_key, consumer_secret, access_token, access_token_secret, users):

    # Authenticate the API.
    print("Authenticating...")
    api = authenticate_api(consumer_key, consumer_secret, access_token, access_token_secret)

    # Save the current time, and the cutoff time for keeping old tweets.
    current_time = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    cutoff_time = (datetime.utcnow() - timedelta(days=1)).strftime('%Y-%m-%d %H:%M:%S')

    # Query the Twitter API to get the most recent tweets from the users of interest.
    print("Getting tweets...")
    new_tweets = query_tweets(api = api, users = users)

    # Convert the tweets from JSON to a pandas dataframe.
    print("Wrangling tweets...")
    tidy_new_tweets = wrangle_new_tweets(new_tweets = new_tweets)

    # Read in the previously stored tweets.
    print("Combining with old tweets...")
    old_tweets = pd.read_csv('../data/candidate_tweets.csv')

    # Combine the new data with the old data, and remove duplicate tweets.
    all_tweets = (tidy_new_tweets.append(other = old_tweets)
                                 .drop_duplicates(subset = 'tweet_url')
                                 .reset_index(drop = True))

    # Remove any tweets that are older than 24 hours.
    recent_tweets = remove_old_tweets(all_tweets, cutoff = cutoff_time)

    # Save the updated, pruned dataset to csv.
    recent_tweets.to_csv('../data/candidate_tweets.csv', index = False)
    print("Done.")

# Authenticate the script's access to the API.
def authenticate_api(consumer_key, consumer_secret, access_token, access_token_secret):

    # Read in the consumer key and secret.
    auth = tweepy.OAuthHandler(consumer_key=consumer_key,
                               consumer_secret=consumer_secret)

    # Set the access token.
    auth.set_access_token(access_token,
                          access_token_secret)

    # Define the authenticated API.
    api = tweepy.API(auth)

    return api

# Use the authenticated API to query the most recent tweets from the selected users.
def query_tweets(api, users):

    # Initialize a list to hold the tweets as JSON files.
    tweets_data = []

    # Loop over the users. (Hard to vectorize since I want to keep all tweets
    # on the same hierarchical level. I.e. I don't want a list of lists.)
    for user in range(len(users)):

        # Find the desired user.
        this_user = api.get_user(users[user])

        # Get their timeline.
        this_user_recent_tweets = api.user_timeline(user_id = this_user.id)

        # For each of their recent tweets, convert to JSON and store in a list.
        recent_tweets_json = list(map(get_tweet_json, this_user_recent_tweets))
        #recent_tweets_json = list(map(get_tweet_json, list(range(len(this_user_recent_tweets)))))

        # Append that list to the overall list of tweets.
        tweets_data += recent_tweets_json

    return(tweets_data)

# For a given user, convert a single tweet to JSON.
def get_tweet_json(tweet):
    json_str = json.dumps(tweet._json)
    tweet = json.loads(json_str)
    return(tweet)

# Convert the new tweets from JSON to a tidy pandas dataframe.
def wrangle_new_tweets(new_tweets):

    # Initialize a dataframe to hold the tweets.
    tweets = pd.DataFrame()

    # Get when the tweet was created.
    tweets['created_at'] = list(map(lambda tweet: tweet['created_at'], new_tweets))

    # Get the UTC offset, so that times can be correctly compared.
    tweets['utc_offset'] = list(map(lambda tweet: tweet['user']['utc_offset'], new_tweets))

    # Get the text in the tweet.
    tweets['text'] = list(map(lambda tweet: tweet['text'], new_tweets))

    # Get the url of the tweet itself.
    tweets['tweet_url'] = list(map(get_url, new_tweets))

    # Get the user's screen name.
    tweets['screen_name'] = list(map(lambda tweet: tweet['user']['screen_name'], new_tweets))

    # Get the user's username.
    tweets['name'] = list(map(lambda tweet: tweet['user']['name'], new_tweets))

    # Get the number of times the tweet was retweeted.
    tweets['retweet_count'] = list(map(lambda tweet: tweet['retweet_count'], new_tweets))

    # Get the number of times the tweet was favorited.
    tweets['favorite_count'] = list(map(lambda tweet: tweet['favorite_count'], new_tweets))

    return(tweets)

# Get the URL of a tweet even if it's a retweet.
def get_url(tweet):
    return("https://twitter.com/" + tweet['user']['screen_name'] + "/status/" + tweet['id_str'])

def remove_old_tweets(all_tweets, cutoff):

    # Convert the created_at variable to UTC.
    #all_tweets['utc_created_at'] = list(map(tweet_time_to_utc, list(range(len(all_tweets)))))
    all_tweets['utc_created_at'] = all_tweets.apply(tweet_time_to_utc, 1)

    # Remove all tweets that are older than the cutoff. (Default 24 hours.)
    all_tweets = all_tweets[all_tweets['utc_created_at'] > cutoff]

    # Reorder the tweets by their creation time.
    all_tweets = all_tweets.sort_values(by = 'utc_created_at', ascending = False)

    # Reset the index.
    all_tweets = all_tweets.reset_index(drop = True)

    return(all_tweets)

# Convert the time of the tweets to a proper datetime.
def tweet_time_to_utc(tweet):
    newtime = datetime.strptime(
        tweet['created_at'],
        '%a %b %d %H:%M:%S +0000 %Y') + timedelta(seconds = int(tweet['utc_offset'])
    )
    return(newtime)

# Call the main function.
get_and_wrangle(consumer_key = consumer_key,
                consumer_secret = consumer_secret,
                access_token = access_token,
                access_token_secret = access_token_secret,
                users = users)
