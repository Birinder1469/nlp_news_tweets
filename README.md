# nlp_news_tweets

I'm working on [News360](https://news360.com/)'s NLP [test task](https://docs.google.com/document/d/1ziUlEDtOBChJzHvArc4GzQKJKG1s-Ut9IkzGAyzAdJI/edit#heading=h.o1egger9j1r), described below:

> **Hot news from twitter feeds**
>
> You are given a list of important news agencies and their twitter feeds. There are a lot of news there: some of them are urgent and important, some aren’t. Your task is to analyze those feeds, recognize moments when something extraordinary happens and send these news to another module, which will send the news to the users using push notifications.
>
> (We’ve already launched similar notification system, so don’t worry about copyright - we won’t use your code in production in any case)
>
> Your service should
> 
> 1. launch every 10 minutes and download all new tweets (or use Twitter streams, but it’s more complicated)
> 2. store tweet texts and attributes into storage
> 3. group tweets about the same event into one cluster
> 4. recognize events that are hot, urgent and worthy to send notification to users (not more than 2 per day)
> 5. select the “best” tweet from every such cluster
> 6. create file with results: (tweet URL, tweet text, tweet date and any additional information you found useful) for every such cluster
>
> You can select any features you want to group and rank the tweets. Try to achieve the best quality you can. On one hand, we shouldn’t disturb users with useless news, on the other hand, if something really important takes place, we should inform users as fast as we can. So both parameters are important for quality: 1) selection accuracy; 2) latency, i.e. time difference between first tweet about this event and creating notification.

## Progress

### Complete

- Write script to query the tweets from Twitter.
- Write script to identify tweets that are worthy of notification.

### To do

- Write script to notify users (by retweeting the selected tweet from the API's authenticated account).
- Write Makefile for the whole pipeline.
- Set up cron job through AWS.
- Validate / tweak parameters.
- Write a blog post explaining my methodology.
- Add testing and package management.
- Add license.