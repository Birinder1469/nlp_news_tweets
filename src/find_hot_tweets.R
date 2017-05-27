#! /usr/bin/env Rscript
# find_hot_tweets.R
# David Laing, May 2017
#
# This script reads in a CSV containing information about recent tweets from
# news publications, and it identifies tweets that are representative of the
# most important news stories.


# Load libraries.
suppressMessages(library(assertthat))
suppressMessages(library(lubridate))
suppressMessages(library(tidyverse))
suppressMessages(library(tidytext))


# Define the weights of the notification score function.
conform_weight <- 0.6    ## 60% for the conformity score.
favorite_weight <- 0.2   ## 20% for the number of favorites.
retweet_weight <- 0.2    ## 20% for the number of retweets.

# To make the notification score more interpretable, enforce a rule that all the weights must add up to 1.
assert_that(sum(conform_weight, favorite_weight, retweet_weight) == 1)


# Define the parameters of the notification threshold function.
asymptote <- 0.99  ## At all times, the conformity score of the selected tweet must be in the 99th percentile.
time_diff_prev_threshold <- 1  ## 1 hour must have passed since the previous notification.

# Check that the asymptote is strictly less than 1 (otherwise no tweet will ever be good enough for a notification.)
assert_that(asymptote < 1)


# `find_hot_tweets` is the main function; it calls the other functions defined below.

#' Cluster the candidate tweets and identify which ones are most worthy of notifying users.
#'
#' @param conform_weight The weight to assign to the conformity score in the notification score function.
#' @param favorite_weight The weight to assign to the favorite count in the notification score function.
#' @param retweet_weight The weight to assign to the retweet count in the notification score function.
#' @param asymptote The minimum acceptable percentile rank of a tweet's conformity score.
#' @param time_diff_prev_threshold The time that must have passed since the previous notification was sent.
#' @return
#' @examples
#' cluster_and_notify()
find_hot_tweets <- function(conform_weight = 0.6,
                            favorite_weight = 0.2,
                            retweet_weight = 0.2,
                            asymptote = 0.99,
                            time_diff_prev_threshold = 1) {

        # Get the time right now.
        time_now <- now("UTC")

        previous_notif_tweets <- tryCatch({

                # Read in the tweets that were previously sent as notifications.
                #previous_notif_tweets <- #
                read.csv("../data/previous_notif_tweets.csv")
                
                #previous_notif_tweets

        }, warning = function(w) {

                # Read in a dummy file.
                #previous_notif_tweets <- 
                read.csv("../data/prev_notif_first_run.csv")

                #previous_notif_tweets
                
        })
        
        # Find how much time has passed since the previous notification was sent.
        time_diff_prev_notif <- previous_notif_tweets %>%
                mutate(time_diff_prev_notif = as.numeric(difftime(time_now, parse_date_time(notif_time, "Ymd HMS"), units = "hours"))) %>%
                select(time_diff_prev_notif) %>% 
                min()
        
        # If not enough time has passed, do nothing.
        if (time_diff_prev_notif < time_diff_prev_threshold) {

                print("Not enough time has passed since the last notification.")
                return(NULL)

        # Otherwise...
        } else {

                # Read in the candidate tweets for the next notification.
                tweets <- read.csv("../data/candidate_tweets.csv")

                # Get one word per row, and clean out uninformative words.
                cleaned_tweet_words <- clean_tweets(tweets)
                
                # Find how much time has passed since each tweet's creation time.
                tweets_w_time_diff_now <- tweets %>%
                        mutate(time_diff_now = as.numeric(difftime(time_now, parse_date_time(created_at_stamp, "Ymd HMS"), units = "hours")))

                # Assign a score to each tweet according to how much it conforms with words used in tweets
                # by other authors. (This finds tweets that are representative of events that everyone
                # is talking about.)
                tweets_w_conform_score <- compute_conform_score(cleaned_tweet_words, tweets = tweets_w_time_diff_now)

                # Determine which (if any) of the candidate tweets meet the threshold for sending a notification.
                tweets_w_threshold <- compute_threshold(tweets = tweets_w_conform_score,
                                                        time_diff_prev_notif = time_diff_prev_notif,
                                                        asymptote = asymptote,
                                                        time_diff_prev_threshold = time_diff_prev_threshold)

                # If none of the tweets meet the notification threshold, stop.
                if (sum(tweets_w_threshold$meet_threshold) == 0) {
                        
                        print("No tweets meet the threshold.")
                        return(NULL)

                # Otherwise...
                } else {

                        # Keep only tweets that meet the threshold.
                        candidate_tweets <- tweets_w_threshold %>% filter(meet_threshold == 1)

                        # Assign a score to each tweet according to its worthiness for sending a notification.
                        candidate_tweets_w_notif_score <- compute_notif_score(candidate_tweets = candidate_tweets,
                                                                              conform_weight = conform_weight,
                                                                              favorite_weight = favorite_weight,
                                                                              retweet_weight = retweet_weight)
                        
                        # Get the best tweet.
                        best_tweet <- candidate_tweets_w_notif_score %>% 
                                filter(notif_score == max(notif_score))
                        
                        # Specify that the notification has not yet been sent.
                        best_tweet <- best_tweet %>% mutate(to_send = 1,
                                                            notif_time = strftime(time_now, tz = "GMT", format = "%Y-%m-%d %H:%M:%S"))
                        
                        # Prepend the best tweet to the dataframe containing the tweets that were previously sent as notifications.
                        previous_notif_tweets <- best_tweet %>%
                                rbind(previous_notif_tweets)
                        
                        # Save it back to CSV, to be read by the notification script.
                        write.csv(previous_notif_tweets, "../data/previous_notif_tweets.csv", row.names = FALSE)
                        
                        print("New tweet saved to notifications.")
                }

        }

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
compute_conform_score <- function(cleaned_tweet_words, tweets) {

        tweets_w_conform_score <- cleaned_tweet_words %>%

                # For each word, count the number of unique authors using that word.
                group_by(word) %>%
                summarise(distinct_authors = n_distinct(screen_name)) %>%
                #arrange(desc(distinct_authors)) %>%

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


#' For each tweet, determine whether it meets the threshold for notifying the user.
#'
#' @param tweets The full tweets dataframe, including a column that shows a measure of conformity.
#' @param time_diff_prev_notif The time that has passed since the previous notification was sent.
#' @param asymptote The asymptote for the conformity score percentile threshold function.
#' @param time_diff_now_threshold The maximum number of hours that can have passed since the tweet's creation.
#' @return The full tweets dataframe, including a new column that shows which (if any) tweets meet the threshold for sending a notification.
#' @examples
#' compute_threshold(tweets, conform_weight, favorite_weight, retweet_weight)
compute_threshold <- function(tweets, time_diff_prev_notif, asymptote = 0.99, time_diff_prev_threshold = 1) {

        # The threshold can be chosen arbitrarily, but I think the method below is a smart way to choose it,
        # so that notifications are only sent when a big story occurs, but they're not sent in quick succession.

        # Say we haven't sent a notification in over 24 hours. Do we just take the best tweet from the past 24 hours
        # and send that? No, because it might still not be big enough, or it might not be recent enough. We'll
        # notify only when we get a tweet that (a) is at least in the 99th percentile for conformity score over
        # the past day, and (b) was created in the past hour.

        # After a big event occurs, we don't want to send a notification every ten minutes just because the
        # incoming tweets have high conformity scores. So the threshold has to change as a function of the time
        # that has passed since the previous notification.

        # That being said, if a really big *new* news story occurs within an hour or two of a notification,
        # we should probably send another notification regardless. So we need a measure of how big an
        # incoming story is. Let's say that a tweet for a big story is one that is above the 99th percentile
        # for conformity score over the past day. If we send a notification for event A, and then event B occurs
        # half an hour later, we'll require event B to have a conformity score that is even higher - perhaps
        # the 99.9th percentile.

        # Get the percentile rank of each tweet, according to its conformity score.
        tweets_w_perc <- tweets %>%
                mutate(percent_rank = percent_rank(conform_score))

        # Set the threshold. (The 0.01 sets the time threshold to 100%. That is, the threshold requires
        # the tweet to have a conformity score that is above the 100th percentile until the time threshold has been reached.
        # See the README for a visualization of the threshold function, and it will make more sense.)
        conform_threshold <- asymptote + 0.01*(time_diff_prev_threshold/time_diff_prev_notif)
        
        # Set the maximum number of hours that can have passed since a tweet's creation and now.
        time_diff_now_threshold <- 10
        
        # Determine which tweets meet the threshold.
        tweets_w_threshold <- tweets_w_perc
        tweets_w_threshold$meet_threshold <- 0
        tweets_w_threshold$meet_threshold[tweets_w_threshold$percent_rank > conform_threshold &
                                                  tweets_w_threshold$time_diff_now < time_diff_now_threshold] <- 1
        
        return(tweets_w_threshold)

}


#' For each tweet, determine how worthy it is of notifying the user.
#'
#' @param candidate_tweets A dataframe with one row per candidate tweet, including a column that shows a measure of conformity.
#' @param conform_weight The weight to assign to the conformity score.
#' @param favorite_weight The weight to assign to the number of favorites.
#' @param retweet_weight The weight to assign to the number of retweets.
#' @return The full tweets dataframe, including a new column that shows the notification score.
#' @examples
#' compute_notif_score(tweets, conform_weight, favorite_weight, retweet_weight)
compute_notif_score <- function(candidate_tweets, conform_weight, favorite_weight, retweet_weight) {

        # Compute the maximum values of the conformity score, the favorite count, the retweet count, and the time since creation.
        # (This is done to normalize the variables in the notification score.)
        conform_max <- max(candidate_tweets$conform_score)
        favorite_max <- max(candidate_tweets$favorite_count)
        retweet_max <- max(candidate_tweets$retweet_count)
        time_diff_now_max <- max(candidate_tweets$time_diff_now)

        # Compute the notification score.
        candidate_tweets_w_notif_score <- candidate_tweets %>%
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
                                retweet_max = retweet_max,
                                is_retweet = is_retweet
                        )
                )

        return(candidate_tweets_w_notif_score)

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
#' @param retweet_max
#' @param is_retweet
#' @return A score between 0 and 1, where 0 is the least worthy of notification and 1 is the most worthy.
#' @examples
#' notif_score(conform_score, conform_max, favorite_count, favorite_max, retweet_count, retweet_max, is_retweet)
notif_score <- function(conform_weight = 0.6,
                        conform_score,
                        conform_max,
                        favorite_weight = 0.2,
                        favorite_count,
                        favorite_max,
                        retweet_weight = 0.2,
                        retweet_count,
                        retweet_max,
                        is_retweet) {

        # If the tweet is a retweet, discount it. The rest of the score is a weighted sum of the other
        # variables of interest.
        result <- (1-is_retweet)*(conform_weight*(conform_score/conform_max) +
                favorite_weight*(favorite_count/favorite_max) +
                retweet_weight*(retweet_count/retweet_max))

        return(result)

}


# Call the main function.
find_hot_tweets(conform_weight = conform_weight,
                favorite_weight = favorite_weight,
                retweet_weight = retweet_weight,
                asymptote = asymptote,
                time_diff_prev_threshold = time_diff_prev_threshold)
