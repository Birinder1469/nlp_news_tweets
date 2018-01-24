# nlp_news_tweets

I completed [News360](https://news360.com/)'s NLP [test task](https://docs.google.com/document/d/1ziUlEDtOBChJzHvArc4GzQKJKG1s-Ut9IkzGAyzAdJI/edit#heading=h.o1egger9j1r), which was to write a data science pipeline that analyses tweets every ten minutes and sends a push notification when a big story breaks – but no more than twice per day.

My Twitter bot is now retired, but its life's work is viewable here: [https://twitter.com/news_nlp_bot](https://twitter.com/news_nlp_bot).

To understand my methodology, feel free to [read](https://github.com/laingdk/nlp_news_tweets/blob/master/src/get_and_wrangle_tweets.py) [my](https://github.com/laingdk/nlp_news_tweets/blob/master/src/find_hot_tweets.R) [scripts](https://github.com/laingdk/nlp_news_tweets/blob/master/src/notify.py), or read my [explanation](https://github.com/laingdk/nlp_news_tweets/blob/master/doc/methodology.md) of the main challenges I faced and decisions I made.

To test my script for yourself, clone this repo, set up authentication to Twitter's API, and type this in Terminal:

`watch -n 600 bash run_all.sh`

This will run the main script every ten minutes, as long as you keep the process running.

