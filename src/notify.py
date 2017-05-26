#!/usr/bin/env python
# get_and_wrangle_tweets.py
# David Laing, May 2017
#
# This script reads in a CSV containing information about tweets that have been
# identified as worthy of sending a notification. If a tweet has not
# yet been sent, it retweets that tweet from the authenticated API.


# import libraries/packages
import pandas as pd
import tweepy


# Read in the consumer key, consumer secret, access token, and access token secret.
consumer_key = open("../../auth/twitter/consumer_key.txt").read()[:-1]
consumer_secret = open("../../auth/twitter/consumer_secret.txt").read()[:-1]
access_token = open("../../auth/twitter/access_token.txt").read()[:-1]
access_token_secret = open("../../auth/twitter/access_token_secret.txt").read()[:-1]


# `notify` is the main function.

def notify(consumer_key, consumer_secret, access_token, access_token_secret):
    """Send a notification, if there is a new tweet to send one for.

    Args:
		consumer_key (str): The API's consumer key.
    	consumer_secret (str): The API's consumer secret.
		access_token (str): The API's access token.
		access_token_secret (str): The API's access_token_secret

    Returns:
        None
    """

    # Read in the CSV containing the tweets that have been identified.
    previous_notif_tweets = pd.read_csv('../data/previous_notif_tweets.csv')

    # Make sure there aren't extra tweets to send.
    assert sum(previous_notif_tweets['to_send'] <= 1)

    # If there are no new tweets to send notifications for...
    if sum(previous_notif_tweets['to_send']) == 0:

        # Stop.
        return(None)

    # Otherwise...
    else:

        # Authenticate the API.
    	print("Authenticating...")
    	api = authenticate_api(consumer_key, consumer_secret, access_token, access_token_secret)

        # Retweet the tweet that has not yet been sent.
        print("Retweeting...")
        api.retweet(previous_notif_tweets['tweet_id'][previous_notif_tweets['to_send'] == 1])

        # Reset the value of `to_send` for the tweet that was just retweeted.
        previous_notif_tweets['to_send'][previous_notif_tweets['to_send'] == 1] = 0

        # Read all the past notifactions back to CSV.
        previous_notif_tweets.to_csv('../data/previous_notif_tweets.csv', index = False)

        print("Done.")

def authenticate_api(consumer_key, consumer_secret, access_token, access_token_secret):
	"""Authenticate the script's access to the API.

	Args:
		consumer_key (str): The API's consumer key.
    	consumer_secret (str): The API's consumer secret.
		access_token (str): The API's access token.
		access_token_secret (str): The API's access_token_secret

	Returns:
		api: The authenticated tweepy API.
	"""

	# Read in the consumer key and secret.
	auth = tweepy.OAuthHandler(consumer_key=consumer_key, consumer_secret=consumer_secret)

	# Set the access token.
	auth.set_access_token(access_token, access_token_secret)

	# Define the authenticated API.
	api = tweepy.API(auth)

	return(api)


# Call the main function.
notify(consumer_key = consumer_key,
    consumer_secret = consumer_secret,
    access_token = access_token,
    access_token_secret = access_token_secret)
