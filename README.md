LOLastfm - LOL a scrobbler
==========================
LOLastfm is a modular and extensible last.fm scrobbler.

It supports a virtually infinite array of music players and has a cool server-client
interface that lets you manage music related features seamlessly.

For instance, you can ask it the current playing song without having to relay on client specific
shims, or by including the glyr extension you can ask it to give you the lyrics of the currently
playing song.

How to configure
----------------
Before being able to use LOLastfm you have to allow access to it on last.fm, just run `LOLastfm -a`
and follow what it says, then create a file at `~/.LOLastfm/config` and put the session id it gave you
back.

You have to then tell LOLastfm what music player you want to be used, you can do it dynamically with
`LOLastfm-do --use player:path'.

```ruby
session 'heregoesthesession'

use :moc
```

The example above is if you're using moc.

You can also hook to certain events to, for example, change the attributes of a song before it's sent.

This allows for some neat features, like easily scrobbling from a radio, the following example shows
how to scrobble songs from trance.fm.

```ruby
%w(listened love now_playing).each {|name|
  on name do |song|
    next if song.artist || !song.stream?

    if song.comment && song.comment.include?('trance.fm')
      next :stop if song.title.include?('trance.fm') || song.title.start_with?('Trance - FM-')

      song.artist, song.title = song.title.split(/ - /, 2)
      song.length             = 60 * 1337

      next
    end

    :stop
  end
}
```
