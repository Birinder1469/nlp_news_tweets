#! /usr/bin/env Rscript 
# cluster_and_notify.R
# David Laing, May 2017
#
# This script reads in a CSV containing information about recent tweets from
# news publications, and it identifies tweets that are representative of the
# most important news stories.

# Load libraries.
library(assertthat)
library(lubridate)
library(tidyverse)
library(tidytext)

# Define the weights of the notification score function.
conform_weight <- 0.4
favorite_weight <- 0.1
retweet_weight <- 0.1
time_diff_now_weight <- 0.4

# To make the notification score more interpretable, enforce a rule that all the weights must add up to 1.
assert_that(sum(conform_weight, fav_weight, retweet_weight, time_diff_now_weight) == 1)

#' Cluster the candidate tweets and identify which ones are most worthy of notifying users.
#' 
#' @param 
#' @return 
#' @examples
#' cluster_and_notify()
cluster_and_notify <- function(conform_weight = 0.4, favorite_weight = 0.1, retweet_weight = 0.1, time_diff_now_weight = 0.4) {
        
        # Read in the candidate tweets.
        tweets <- read.csv("../data/candidate_tweets.csv")
        
        # Get one word per row, and clean out uninformative words.
        cleaned_tweet_words <- clean_tweets(tweets)
        
        # Find the tweets that share the greatest number of words
        # with the greatest number of unique authors.
        # (The assumption is that these tweets are the most representative
        # of events that everyone is talking about.)
        tweets_w_conform_score <- compute_conform_score(cleaned_tweet_words, tweets)
        
        # Assign a score to each tweet that corresponds with its worthiness for sending a notification.
        tweets_w_notif_score <- compute_notif_score(tweets_w_conform_score = tweets_w_conform_score,
                                                    conform_weight = conform_weight,
                                                    favorite_weight = fav_weight,
                                                    retweet_weight = retweet_weight,
                                                    time_diff_now_weight = time_diff_now_weight)
        
}

#' Get one word per row, excluding stop words and other uninformative words.
#' 
#' @param tweets The full input dataframe, with one row per tweet.
#' @return A dataframe with one row per word, excluding stop words and other uninformative words.
#' @examples
#' clean_tweets(tweets)
clean_tweets <- function(tweets) {
        
        # Coerce the tweet text from factor to character,
        # so that the text can be split into words.
        tweets$text <- as.character(tweets$text)
        
        # Get one word per row.
        tidy_tweet_words <- tweets %>%
                unnest_tokens(word, text)
        
        # Clean out highly common and uninformative words.
        cleaned_tweet_words <- tidy_tweet_words %>%
                
                # Remove stop words.
                anti_join(stop_words) %>%
                
                # Remove html and retweet tokens.
                filter(word != "https",
                       word != "t.co",
                       word != "rt")
        
        return(cleaned_tweet_words)
        
}

#' For each tweet, determine how much it conforms with tweets from other authors.
#' 
#' @param cleaned_tweet_words A dataframe with one row per word, excluding stop words and other uninformative words.
#' @param tweets The full input dataframe, with one row per tweet.
#' @return The full tweets dataframe, including a new column that shows a measure of conformity.
#' @examples
#' compute_conform_score(cleaned_tweet_words, tweets)
compute_conform_score(cleaned_tweet_words, tweets) {
        
        tweets_w_conform_score <- cleaned_tweet_words %>%
                
                # For each word, count the number of unique authors using that word.
                group_by(word) %>%
                summarise(distinct_authors = n_distinct(screen_name)) %>%
                arrange(desc(distinct_authors)) %>% 
                
                # Right join with the dataframe containing one row per word.
                right_join(cleaned_tweet_words) %>% 
                
                # For each tweet, compute the conformity score by counting the number of
                # unique authors who use each of the words in that tweet.
                group_by(tweet_url) %>%
                summarise(conform_score = sum(distinct_authors)) %>% 
                
                # Right join with the original tweets.
                right_join(tweets)

        return(tweets_w_conform_score)
        
}

#' For each tweet, determine how worthy it is of notifying the user.
#' 
#' @param tweets_w_conform_score The full tweets dataframe, including a column that shows a measure of conformity.
#' @return A dataframe with one row per word, excluding stop words and other uninformative words.
#' @examples
#' compute_notif_score(tweets_w_conform_score)
compute_notif_score(tweets_w_conform_score, conform_weight, favorite_weight, retweet_weight, time_diff_now_weight) {
        
        # Compute the maximum values of the conformity score, the favorite count, and the retweet count.
        # (This is done to normalize the variables in the notification score.)
        conform_max <- max(tweets_w_conform_score$conform_score)
        favorite_max <- max(tweets_w_conform_score$favorite_count)
        retweet_max <- max(tweets_w_conform_score$retweet_count)
        
        # Compute the notification score.
        tweets_w_notif_score <- tweets_w_conform_score %>% 
                mutate(
                        notif_score = notif_score(
                                conform_weight = conform_weight,
                                conform_score = conform_score,
                                conform_max = conform_max,
                                favorite_weight = favorite_weight,
                                favorite_count = favorite_count,
                                favorite_max = favorite_max,
                                retweet_weight = retweet_weight,
                                retweet_count = retweet_count,
                                retwee_max = retweet_max,
                                time_diff_now_weight = time_diff_now_weight
                        )
                )
        
        return(tweets_w_notif_score)
        
}

#' Given a tweet's conformity score, its favorite count, its retweet count, and its creation time, assign a score
#' for how worthy it is of notifying the user.
#' 
#' @param conform_weight
#' @param conform_score
#' @param conform_max
#' @param favorite_weight
#' @param favorite_count
#' @param favorite_max
#' @param retweet_weight
#' @param retweet_count
#' @param retwee_max
#' @param time_diff_now_weight
#' @param time_diff_now
#' @return A score between 0 and 1, where 0 is the least worthy of notification and 1 is the most worthy.
#' @examples
#' compute_notif_score(conform_score, conform_max, favorite_count, favorite_max, retweet_count, retweet_max, time_diff_now)
notif_score(conform_weight = 0.4,
            conform_score,
            conform_max,
            favorite_weight = 0.1,
            favorite_count,
            favorite_max,
            retweet_weight = 0.1,
            retweet_count,
            retweet_max,
            time_diff_now_weight = 0.4,
            time_diff_now) {
        
        conform_weight*(conform_score/conform_max) + 
                favorite_weight*(favorite_count/favorite_max) +
                retweet_weight*(retweet_count/retweet_max) -
                time_diff_now_weight*time_diff_now
}

time_diff_prev_notif_func()

# Call the main function.
cluster_and_notify()

