PunchClock Server
=======

Provides a set of endpoints for the [PunchClock](https://github.com/martingordon/PunchClock) iOS app as well as a [Status Board](https://panic.com/statusboard/)-compatible In/Out panel.

This fork features several changes from [Panic's](https://github.com/martingordon/PunchClock) version:

- Uses Parse instead of ZeroPush for push notifications.
- Tracks status changes in a new `status_changes` table.
- Provides RSS feeds for in/out status changes for each user.

Setup
-----

Let's assume you've gone through the basic [heroku setup steps](https://devcenter.heroku.com/articles/quickstart) and are ready to deploy an application.

The server is designed to run with a [Postgres](https://devcenter.heroku.com/articles/heroku-postgresql) database and the [Parse](http://parse.com)'s push notification service. To get it running for testing you'll need to install some Ruby gems and customize your local enviroment.

- `$ cp dotenv.sample .env`
- `$ gem install bundler; bundle install`

To run the server locally run `foreman start`

#### Images
Put your people images in the public folder and name them the same as the names used in the app.


#### RSS Feeds
Each user is given a pair of RSS feeds. The feeds are accessible at `/rss/ins/#{lowercase_user_name}.xml?token=#{token}` and `/rss/outs/#{lowercase_user_name}.xml?token=#{token}`.

The token parameter must be provided and should match the `AUTH_TOKEN` environment variable. Additionally, the In feed accepts an optional "before" parameter to only show entries before a certain hour. The Out feed accepts an optional "after" parameter to only show entries after a certain hour. Both parameters must be in 24-hour time.

Contributing
------------

Feel free to fork and send us pull requests.

Bug Reporting
-------------

**PunchClockServer is an unsupported, unofficial Panic product.** If you can't contribute directly, please file bugs here.

