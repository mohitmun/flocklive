# Hashman
Project for Online Flockathon

![](http://hashman.herokuapp.com/flock_hashman.gif)

Hashman brings hashtag support to flock. It lets others see what you are talking about. Just start your message with /hashman or click on message action to make any message public across your team/ all flock users

##Features:
  - Twitter like Trends (see trends across team and all flock users)
  - Manage visibility of message (flock/your team/ private)
  - React to Hashtag or Tweet (like, sad, anger etc)
  - Quick message action to make any message public/private

## Steps to run
Update config/database.yml with database name and user credentials

```
$rake db:create
$rake db:migrate
$bundle install
$rails s
```

