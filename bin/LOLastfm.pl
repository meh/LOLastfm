#! /usr/bin/perl
# meh. [http://meh.doesntexist.org]
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Getopt::Std;
use XML::Simple qw(:strict);
use Net::LastFM::Submission;

use Data::Dumper;

my $Version = '0.2.2';

my %options;
getopts('hf:s:u:p:C:P:S:T:E:', \%options);

if ($options{h}) {
    print Misc::usage();
    exit;
}

my $Config  = XMLin($options{f} || '/etc/LOLastfm.xml', KeyAttr => 1, ForceArray => [ 'service' ]);
my $Cache   = $options{C} || $Config->{cache};
my $Tick    = $options{T} || $Config->{tick} || 6;
my $Seconds = $options{S} || $Config->{seconds} || 20;

Player::init ($options{P} || $Config->{player});

if (defined $options{s} || defined $Config->{services}) {
    Services::init($options{s} || $Config->{services});
}

my $LastFM = new Net::LastFM::Submission(
    user     => $options{u} || $Config->{lastfm}->{user},
    password => $options{p} || $Config->{lastfm}->{password},

    enc => $options{E} || $Config->{encoding} || 'utf8',

    client_id  => 'lol',
    client_ver => $Version,
);

my $Handshake = $LastFM->handshake();

if (not defined $Handshake->{error}) {
    Cache::submit();
}

my $old = Song::reset();

while (1) {
    my $song = Player::currentSong();

    if (!$song) {
        if ($old->{seconds} >= $old->{length} - $Seconds) {
            Song::submit($old);
            $old = Song::reset();
        }
    }
    else {
        if ($old->{title} eq $song->{title} && $old->{album} eq $song->{album} && $old->{artist} eq $song->{artist} && $old->{seconds} < $song->{seconds}) {
            if (not $Song::NowPlaying) {
                Song::nowPlaying($song);
            }
        }
        else {
            if ($old->{seconds} >= $old->{length} - $Seconds) {
                Song::submit($old);
            }

            Song::nowPlaying($song);
        }

        $old = $song;
    }

    sleep $Tick;
}

package Song;

our $NowPlaying = 0;

sub nowPlaying {
    if (defined $Handshake->{error}) {
        $Handshake = $LastFM->handshake();
    }

    my $song  = shift;
    my $check = $LastFM->now_playing($song);

    if (defined $check->{error}) {
        Misc::checkDisconnection($check);
        $NowPlaying = 0;
    }
    else {
        $NowPlaying = 1;
    }

    return $check;
}

sub submit {
    my $song = shift;

    my $check = Cache::submit();

    if (defined $check->{error}) {
        Misc::checkDisconnection($check);
        Cache::push($song);
        return;
    }

    $check = $LastFM->submit($song);

    if (defined $check->{error}) {
        Misc::checkDisconnection($check);
        Cache::push($song)
    }

    return $check;
}

sub reset {
    return {
        title   => '',
        album   => '',
        artist  => '',
        seconds => 42,
        length  => 9001,
    };
}

package Cache;

sub push {
    my $song = shift;

    if (!$Cache) {
        return;
    }

    my $separator = " _";
    while ($song->{title} =~ /$separator / || $song->{album} =~ /$separator / || $song->{artist} =~ /$separator /) {
        $separator .= "_";
    }
    $separator .= " ";

    open my $cache, ">>", $Cache;
    print $cache "$separator: ", $song->{title}, $separator, $song->{album}, $separator, $song->{artist}, $separator, $song->{length}, $separator, $song->{time}, "\n";
    close $cache;
}

sub get {
    my $number  = shift;
    my $counter = 0;
    my @songs;

    if (!$Cache) {
        return @songs;
    }

    open my $cache, "<", $Cache;
    while (<$cache>) {
        my $line = chomp($_);

        if ($line =~ m{^(.+): (.+)$}) {
            my @data = split /$1/, $2;
            CORE::push @songs, { title => $data[0], album => $data[1], artist => $data[2], length => $data[3], time => $data[4] };
        }
        
        if (++$counter >= $number) {
            last;
        }
    }
    close $cache;

    return @songs;
}

sub flush {
    my $number  = shift;
    my $counter = 0;
    my @songs;

    if (!$Cache) {
        return;
    }

    open my $cache, "<", $Cache;
    while (<$cache>) {
        if (++$counter >= $number) {
            last;
        }
    }
    my @rest = <$cache>;
    close $cache;
    
    open $cache, ">", $Cache;
    for my $line (@rest) {
        print $cache $line;
    }
    close $cache;
}

sub submit {
    if (!$Cache) {
        return { status => 'OK' };
    }

    if (defined $Handshake->{error}) {
        $Handshake = $LastFM->handshake();
    }

    while (1) {
        my @songs = get(50);

        if (!@songs) {
            last;
        }

        my $check = $LastFM->submit(@songs);

        if (defined $check->{error}) {
            Misc::checkDisconnection($check);
        }
        else {
            flush(50);
        }

        return $check;
    }
}

package Player;

my $player;

sub init {
    $player = shift;

    if ($player eq 'moc') {
        if ($Config->{moc}->{as}) {
            $Player::MOC::command = "su -c 'mocp -i' $Config->{moc}->{as}";
        }
        else {
            $Player::MOC::command = "mocp -i";
        }
    }
    elsif ($player eq 'mpd') {
        use Audio::MPD;
        $Player::MPD::connection = Player::MPD::newConnection();
    }
    elsif ($player eq 'mp3blaster') {
        if (not defined $Config->{mp3blaster}->{statusFile}) {
            die "You have to set a mp3blaster status file to use LOLastfm.";
        }

        $Player::MP3Blaster::statusFile = $Config->{mp3blaster}->{statusFile};
    }
    else {
        die "No supported player has been selected.";
    }
}

sub currentSong {
    if ($player eq 'moc') {
        return Player::MOC::currentSong();
    }
    elsif ($player eq 'mpd') {
        return Player::MPD::currentSong();
    }
    elsif ($player eq 'mp3blaster') {
        return Player::MP3Blaster::currentSong();
    }
}

package Player::MOC;

our $command;

sub currentSong {
    my $song    = {};
    my $output  = `$command`;

    if ($output !~ m{State: (PLAY|PAUSE)}) {
        return 0;
    }

    if ($output =~ m{SongTitle: (.+)$}m) {
        $song->{title} = $1;
    }
    else {
        $song->{title} = '';
    }

    if ($output =~ m{Artist: (.+)$}m) {
        $song->{artist} = $1;
    }
    else {
        $song->{artist} = '';
    }

    if (!$song->{title} && !$song->{artist}) {
        return 0;
    }

    if ($output =~ m{Album: (.+)$}m) {
        $song->{album} = $1;
    }
    else {
        $song->{album} = '';
    }

    if ($output =~ m{CurrentSec: (.+)$}m) {
        $song->{seconds} = $1;
        $song->{time}    = time() - $1;
    }
    else {
        $song->{seconds} = '';
    }

    if ($output =~ m{TotalSec: (.+)$}m) {
        $song->{length} = $1;
    }
    else {
        return 0; # if there's not length we can't do anything.
    }

    $song->{source} = 'P';
    $song->{id}     = '';

    return $song;
}

package Player::MPD;

our $connection;

sub newConnection {
    my $options = {};

    if (defined $Config->{mpd}->{host}) {
        $options->{host} = $Config->{mpd}->{host};
    }
    if (defined $Config->{mpd}->{port}) {
        $options->{port} = $Config->{mpd}->{port};
    }
    if (defined $Config->{mpd}->{user}) {
        $options->{user} = $Config->{mpd}->{user};
    }
    if (defined $Config->{mpd}->{password}) {
        $options->{password} = $Config->{mpd}->{password};
    }

    $options->{conntype} = 'reuse';

    return new Audio::MPD($options);
}

sub currentSong {
    my $song = {};

    if (!$connection->ping()) {
        $connection = newConnection();
    }

    my $mpdState = $connection->status();

    if ($mpdState->{state} !~ m{(play|pause)}) {
        return 0;
    }

    my $mpdSong = $connection->current();

    $song->{title}   = $mpdSong->title();
    $song->{artist}  = $mpdSong->artist();

    if (!$song->{title} && !$song->{artist}) {
        return 0;
    }

    $song->{album}   = $mpdSong->album();
    $song->{seconds} = $mpdState->time()->seconds_sofar();
    $song->{length}  = $mpdSong->time();
    $song->{id}      = $mpdSong->track();
    $song->{source}  = 'P';

    return $song;
}

package Player::MP3Blaster;

our $statusFile;

sub currentSong {
    my $song = {};

    if (not -e $statusFile) {
        return 0;
    }

    open my $file, "<", $statusFile;
    my @lines = <$file>;
    close $file;

    my $output = join '', @lines;

    if ($output !~ m{^status (playing|paused)}m) {
        return 0;
    }

    if ($output =~ m{^title (.*)$}m) {
        $song->{title} = $1;
    }
    else {
        $song->{title} = '';
    }

    if ($output =~ m{^artist (.*)$}m) {
        $song->{artist} = $1;
    }
    else {
        $song->{artist} = '';
    }

    if (!$song->{title} && !$song->{artist}) {
        return 0;
    }

    if ($output =~ m{^album (.*)$}m) {
        $song->{album} = $1;
    }
    else {
        $song->{album} = '';
    }

    if ($output =~ m{^length (.*)$}m) {
        $song->{length} = $1;

        if ($old->{title} eq $song->{title} && $old->{album} eq $song->{album} && $old->{artist} eq $song->{artist}) {
            $song->{seconds} = $old->{seconds} + $Tick;
        }
        else {
            $song->{seconds} = 0;
        }

        $song->{time} = time() - $song->{length};
    }
    else {
        return 0;
    }

    return $song;
}

package Services;

my $services = {};

sub init {
    use threads;

    my $enable = shift;

    if (ref $enable eq 'HASH') {
        if (defined $enable->{service}) {
            for my $service (@{$enable->{service}}) {
                $services->{$service->{name}} = 1;
            }
        }
    }
    else {
        my @services = split /\s*,\s*/, $enable;

        for my $service (@services) {
            $services->{$service} = 1;
        }
    }

    if (defined $services->{current}) {
        Services::Current::init();
    }
}

package Services::Current;

sub init {
    use IO::Socket;
    use JSON;

    my $dispatch = new threads(\&dispatcher);
    $dispatch->detach();
}

sub dispatcher {
    my $conf = (grep { name => 'current' }, @{$Config->{services}->{service}})[0];

    my $socket = new IO::Socket::INET(
        LocalHost => '127.0.0.1',
        LocalPort => $conf->{port} || 9001,
        Listen    => SOMAXCONN,
        Reuse     => 1
    );

    my $connection;

    while (($connection = $socket->accept())) {
        my $thread = new threads(\&answer, $connection);
        $thread->detach();
    }
}

sub answer {
    my $socket = shift;

    my $song = Player::currentSong();

    if (!$song) {
        print $socket 'null', "\n";
    }
    else {
        print $socket to_json(Player::currentSong()), "\n";
    }

    close $socket;
}

package Misc;

sub usage {
    return << "USAGE";
LOLastfm $Version

Usage: LOLlastfm [options]

-h          : show this help.
-f file     : use the given file as config file
-s services : enable the passed services (needs a threads enabled Perl version)

-u user     : use the given username instead of the config one
-p password : use the given password instead of the config one

-C cache    : use the given cache as caching file
-P player   : use the given player as scrobbling one
-S seconds  : sends the song as listened when you got past (songLength - seconds)
-T tick     : check informations again every tick seconds
-E encoding : encoding to automatically encode from, last.fm needs utf8 strings
USAGE
}

sub checkDisconnection {
    my $check = shift;

    if ((defined $check->{code} && $check->{code} == 500) || (defined $check->{reason} && $check->{reason} =~ /handshake/)) {
        $Handshake = {
            reason => "Can't connect to post.audioscrobbler.com:80 (connect: timeout)",
            error  => "500",
            code   => 500,
        };
    }
}
