# Radio Playlist

If you love your local radio station and want to have a Spotify playlist with all your favorite songs currently playing on that station, you've found *the* right tool.

The app is currently still under development, but if you know how to use it, it already works and can extract playlist information from [OnlineRadioBox](https://onlineradiobox.com), then look it up on Spotify and finally create or update a playlist there.

## Goal

The goal of this tool is to have continuously refreshed playlist with the songs of your favourite radio station always available in your Spotify account.

## Development

The app is developed using Swift. So, using a Mac with Xcode is probably the easiest possibility to start developing.

### Steps to start local development

- Clone the repository
- Create an app in the [dashboard](https://developer.spotify.com/dashboard) of you Spotify account
- Double click the `Package.swift` to open the package in Xcode
- In directory `Sources` create a file called `secrets.swift` and add two variables:
  ```swift
  let spotifyClientId = "ENTER_YOUR_APPS_CLIENT_ID_HERE"
  let spotifyClientSecret = "ENTER_YOUR_APPS_CLIENT_SECRET_HERE"
  ```

And then it should be good to run. The log-in procedure is currently a bit cumbersome, but only needs to be done once.

### Things to do

List of things that need to be done in this app (unordered):

- Improve playlist update to not always replace everything, but just reorder/ add/ remove single songs :white_check_mark:
- Add test
- Add a lot of error handling
- Add automation scripts to build stuff in Github actions
- Split package into several packages for better reuse :white_check_mark:
- Add more input possibilities (for RSS feeds, other tracking sites, etc...)
- Add more output possibilities (Apple Music, ...)
- Improve the log-in procedure
- Switch from simple JSON cache to some DB
- Create a UI for local running
- Create some kind of Web-UI and publish as service - this would include some more steps like
  - Create some kind of storage DB 
  - Package as Lambda
  - Create Web UI
  - Link everything together
  - Publish in AWS (or somewhere else)
- Offer functionality for automation
- Build Docker images for easy local running on any machine (probably with Web UI)
