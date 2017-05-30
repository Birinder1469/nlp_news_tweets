NLP News Tweets: Methodology
================

The goal of this project was to scan all tweets authored by some 25 news publications, and send a notification (i.e. a single tweet) when a big story breaks. This came with a number of challenges.

1. What data to use?
--------------------

Twitter's API provides many attributes for each [tweet](https://dev.twitter.com/overview/api/tweets) and each [user](https://dev.twitter.com/overview/api/users). I decided to keep things simple: I took each tweet's id, its creation time, its text, its favorite count, its retweet count, and its retweet status (i.e. whether or not it was itself a retweet). I also took each tweet's author's username and screen name.

Most of these tweets link to full news stories on their respective publication's webpages. I considered scraping the text of the full stories using Python [Goose](https://github.com/grangier/python-goose), but decided to see how far I could get with the text of the tweets alone, since I anticipated there being some difficulties getting around paywalls. Not to mention that text data fram HTML can be quite messy.

As for how *much* data to store, I decided to keep only the tweets from the past 24 hours. This usually amounts to about 3000 tweets.

2. How to identify important news stories?
------------------------------------------

This was the main challenge. At first I tried a few off-the-shelf clustering algorithms from sklearn, which required me to first vectorize the tweet texts. I created a document-term matrix, like the example below:

<table style="width:68%;">
<colgroup>
<col width="20%" />
<col width="18%" />
<col width="12%" />
<col width="16%" />
</colgroup>
<thead>
<tr class="header">
<th></th>
<th align="right">test</th>
<th align="right">Japan</th>
<th align="right">ballistic</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>North Korea fires missile into waters off Japan <a href="https://t.co/iBM24KTIyU" class="uri">https://t.co/iBM24KTIyU</a></td>
<td align="right">0</td>
<td align="right">1</td>
<td align="right">0</td>
</tr>
<tr class="even">
<td>Japan to take 'concrete action' with US against North Korea after its latest ballistic missile test… <a href="https://t.co/ycZmzebnVa" class="uri">https://t.co/ycZmzebnVa</a></td>
<td align="right">1</td>
<td align="right">1</td>
<td align="right">1</td>
</tr>
<tr class="odd">
<td>MORE: If confirmed as a ballistic missile test, it would be the ninth such test conducted by North Korea this year. <a href="https://t.co/jP7hmAXhww" class="uri">https://t.co/jP7hmAXhww</a></td>
<td align="right">2</td>
<td align="right">0</td>
<td align="right">1</td>
</tr>
</tbody>
</table>

The real document-term matrix had one row for every tweet in the dataset, and one column for each of the top 200 most common words in the whole corpus (after removing [stop words](https://en.wikipedia.org/wiki/Stop_words)). With a few variants of the document-term matrix (word counts and [tf-idf](https://en.wikipedia.org/wiki/Tf%E2%80%93idf), with varying thresholds for inclusion in the matrix), I tried two clustering algorithms: [k-means](https://en.wikipedia.org/wiki/K-means_clustering) and [agglomerative hierarchical clustering](https://en.wikipedia.org/wiki/Hierarchical_clustering).

There were two problems with these approaches. The first problem is that there isn't a good way to choose the number of clusters to look for. If the goal had been simply to model the variance in the tweets as well as possible, then I could have done a grid search over some predefined list of *k*-values, and chosen the model with the best [silhouette](https://en.wikipedia.org/wiki/Silhouette_(clustering)) score. But the goal isn't the model the variance; the goal is to quickly identify a breaking news story, when it occurs, and then select the tweet that is most representative of that story. Besides, we know that the nature of the data is not that each tweet belongs to a clear cluster. The data does *not* look like this:

![](../results/strong_clusters.png)

Rather, a select few tweets will all be lexically close to each other, and everything else will be scattered all across the feature space, more like this:

![](../results/realistic_clusters.png)

How many clusters are there, overall? Aside from the fact that there is a clear cluster centered at (1,1), I don't think there's any way to say.

The second problem with the vectorize/cluster approach is that a lot of information is lost during the vectorization. The tweets are mostly about different subjects, so most of the tweets don't even use whichever words happen to be the most common in the full corpus. The document-term matrix ends up being extremely sparse; almost every entry is zero, and most of the rows (the tweets) don't even have any entries. The vectorized data looks more like this:

![](../results/vectorized_cluster.png)

Now it's the *least* important tweets — the ones that *don't* use the most common words in the corpus — that form the most distinct cluster. As a result, the tweets that we actually care about have now been scattered across the feature space. Their use of the most common words in the corpus has caused their differences to be exaggerated and their similarities to be diminished. This is the exact opposite of what I wanted.

Now, I could have vectorized the tweets such that the term-document matrix contained a column for every distinct word that appeared in the dataset. This would have solved the problem we see in the graph above. But that would have created a vastly high-dimensional feature space, which would have made the distances between tweets almost meaningless. So I tried a different strategy. First I transformed the original data to get one row for each word in the corpus:

``` r
# Get one word per row.
tweet_words <- tweets %>%
        unnest_tokens(word, text)

# Clean out highly common and uninformative words.
cleaned_tweet_words <- tweet_words %>%
        
        # Remove stop words.
        anti_join(stop_words) %>%
        
        # Remove html and retweet tokens.
        filter(word != "https",
               word != "t.co",
               word != "rt")
```

Then I simply counted the number of distinct authors who had used each word in the corpus, and added those counts up word-wise for each tweet:

``` r
breaking_tweets <- cleaned_tweet_words %>%
        
        # Count the number of distinct authors using each word.
        group_by(word) %>%
        summarise(distinct_authors = n_distinct(screen_name)) %>%

        # Join with the dataframe containing one row per word.
        right_join(cleaned_tweet_words) %>% 
        
        # Count the number of authors tweeting words that are present in each tweet.
        group_by(tweet_url) %>%
        summarise(conform_score = sum(distinct_authors)) %>% 
        
        # Join with the original tweets.
        right_join(tweets)
```

Let's take a look at the tweets in my current dataset that have the highest conformity score:

``` r
breaking_tweets %>%
        arrange(desc(conform_score)) %>% 
        select(screen_name, created_at, conform_score, text) %>% 
        head() %>%
        kable()
```

| screen\_name     | created\_at                    |  conform\_score| text                                                                                                                                         |
|:-----------------|:-------------------------------|---------------:|:---------------------------------------------------------------------------------------------------------------------------------------------|
| BBCNews          | Mon May 29 15:43:04 +0000 2017 |             135| RT @BBCBreaking: Golf star Tiger Woods has been arrested on a drink-driving charge in Florida, police say <https://t.co/eKVQW3snjD>          |
| AP               | Tue May 30 05:29:52 +0000 2017 |             132| BREAKING: A source close to the family of former Panamanian dictator Manuel Noriega says he has died at age 83.                              |
| nytimes          | Tue May 30 05:32:09 +0000 2017 |             129| Breaking News: Manuel Noriega is dead at 83. The brash Panamanian dictator was ousted in a U.S. invasion in 1989. <https://t.co/aY5UAzBPao>   |                                                                                                                                              |
| CNN              | Mon May 29 15:43:10 +0000 2017 |             129| Golf legend Tiger Woods arrested early Monday on suspicion of DUI in Jupiter, Florida, police say… <https://t.co/ztKlh4i2cN>                 |
| CNN              | Tue May 30 05:44:27 +0000 2017 |             128| JUST IN: Former Panamanian dictator Manuel Noriega has died at a Panama City hospital at age 83… <https://t.co/Pqm6QvXsQi>                   |
| TheSun           | Mon May 29 09:52:01 +0000 2017 |             126| Survivor of 7/7 found dead hours after Manchester bombing 'didn’t want to live in a world where attacks continue’… <https://t.co/g5pK09Try3> |

These tend to be fairly big stories. That's because the words used in these tweets are used by many distinct authors in the dataset. You might think my bot would simply retweet the tweet with the highest conformity score, but it's not that simple.

3. How to decide when to send a notification?
---------------------------------------------

The idea for this project was that I was to send on the best tweet from a breaking news story onto a separate module, which would send a push notification. The thing is, you don't want to send push notifications very often — maximum twice a day. But the script needs to make a decision *every ten minutes* about whether or not to send a notification. And when a big story breaks, we want to send the notification as soon as possible. So whatever function you use to decide whether to send a notification, the function needs to include three pieces of information:

1.  How big is the story? We'll only send notifications for big stories that everyone is talking about.
2.  How long has it been since the last notification was sent? In the flurry of tweets that are authored in the hours after a big story breaks, we don't want to keep sending notifications about that story just because it's big.
3.  What stories have we already sent notifications for? Sometimes a good tweet for a big story will be authored many hours after the story first broke; we don't want to send that tweet as a notification.

In my script, a tweet has to meet several conditions for it to qualify as worthy of notification. The first is that it must be one of the most highly conforming tweets of the past 24 hours. Namely, it must have a conformity score that is at least in the 99th percentile. This will be the asymptote of the conformity threshold — call it *m* for 'minimum'.

`asymptote <-  0.99`

*m* = 0.99

The 99th percentile is the absolute minimum threshold that a tweet must meet, but this requirement is stricter the more recently a notification has been sent. To set the minimum amount of time that must pass after a notification has been sent, before another one will be sent, we just need to add 0.01 (or 1 − *m*) to that asymptote to push it up to the 100th percentile. But the value we add to the asymptote can decrease as more time passes. We can use a reciprocal function, like so:

$C = m + (1-m)\\left(\\frac{t\_{min}}{t\_{prev}}\\right)$,

where *C* is the conformity score percentile threshold function, *t*<sub>*m**i**n*</sub> is the minimum amount of time (in hours) that must pass before a new notification is sent, and *t*<sub>*p**r**e**v*</sub> is the amount of time that has passed since the previous notification was sent. Below you can see two versions of the threshold function. The blue curve has *t*<sub>*m**i**n*</sub> = 1, and the green curve has *t*<sub>*m**i**n*</sub> = 5. You can see that if the *t*<sub>*m**i**n*</sub> were set to 5, we would be forcing the system to wait a full five hours before any tweet could have a chance of being sent as a notification. After that, the minimum percentile decreases steadily as time passes.

![](../results/threshold_graph.png)

There are a couple more checks that the tweets have to satisfy in order to be considered for notification. First, the tweet must have been created in the past hour. I don't particularly care if a tweet from 13 hours ago is in the 99.9th percentile for its conformity score — that story is old news. I only care if there's a *new* story that everyone is talking about. Second, the tweet not share any (non-stop-)words with the tweet that was sent as the previous notification. This helps guard against notifying the user of the same story several hours later, when people are still talking about that story on Twitter. Finally, the tweet must not be alone; that is, I require a minimum of four tweets to cross the prior thresholds, just as a final check to ensure that there is a *new* story that everyone is talking about. Once there are a minimum of four tweets that pass these tests, they're sent on to one last function to determine which one is the best for the notification.

4. How to select the best tweet for the notification?
-----------------------------------------------------

This part is pretty simple. My script allows a user to set weights on three tweet variables: its conformity score, its favorite count, and its retweet count. The default is that the conformity score is worth 60% of the notification score, the favorite count is worth 20%, and the retweet count is worth 20%. Whichever tweet has the height weighted sum of these three attributes gets to be sent as a notification. I could have used the conformity score alone, but I figured the favorite count and the retweet count would allow for a bit of quality control; the best tweets are typically well-written, with links to valuable content, and the favorite/retweet counts are probably correlated with those desirable qualities.

There you have it! If you'd like to see what my bot has been up to recently, you can see its activity (and even follow it — though you'll make it blush) right here:

<https://twitter.com/news_nlp_bot>
