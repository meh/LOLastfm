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

my $Version = '0.2';

my %options;
getopts('u:p:P:f:C:S:E:h', \%options);

if ($options{h}) {
    print Misc::usage();
    exit;
}

my $Config  = XMLin($options{f} || '/etc/LOLastfm.xml', KeyAttr => 1, ForceArray => 0);
my $Player  = $options{P} || $Config->{player} || die "What player should I use?";
my $Cache   = $options{c} || $Config->{cache};
my $As      = $options{a} || $Config->{as};
my $Seconds = $options{S} || $Config->{seconds} || 20;

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
    my $song = Song::get();

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

    sleep 5;
}

package Song;

our $NowPlaying = 0;

sub get {
    if ($Player eq 'moc') {
        return Player::MOC::get();
    }
    elsif ($Player eq 'mpd') {
        return Player::MPD::get();
    }
    else {
        die "No supported player has been selected.";
    }
}

sub nowPlaying {
    my $song  = shift;
    my $check = $LastFM->now_playing($song);

    if (defined $check->{error}) {
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
        print $cache, $line;
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

package Player::MOC;

sub get {
    my $song    = {};
    my $command = ($Config->{moc}->{as}) ? "su -c 'mocp -i' $Config->{moc}->{as}" : "mocp -i";
    my $output  = `$command`;

    if ($output !~ /State: PLAY/) {
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

my $connection = newConnection();

sub newConnection {
    use Audio::MPD;

    return new Audio::MPD({
        host => $Config->{mpd}->{host} || undef,
        port => $Config->{mpd}->{port} || undef,

        user     => $Config->{mpd}->{user} || undef,
        password => $Config->{mpd}->{password} || undef,
    
        conntype => 'reuse',
    });
}

sub get {
    use Audio::MPD;

    my $song = {};

    if (!$connection->ping()) {
        $connection = newConnection();
    }

    my $mpdState = $connection->status();

    if ($mpdState->{state} != 'play') {
        return 0;
    }

    my $mpdSong = $connection->current();

    $song->{title}   = $mpdSong->{title};
    $song->{artist}  = $mpdSong->{artist};

    if (!$song->{title} && !$song->{artist}) {
        return 0;
    }

    $song->{album}   = $mpdSong->{album};
    $song->{seconds} = $mpdState->{time}->{seconds_sofar};
    $song->{length}  = $mpdSong->{time};
    $song->{id}      = $mpdSong->{track};
    $song->{source}  = 'P';

    return $song;
}

package Misc;

sub usage {
    return << "USAGE";
Usage: LOLlastfm [options]

-h          : show this help.
-f file     : use the given file as config file

-u user     : use the given username instead of the config one
-p password : use the given password instead of the config one

-C cache    : use the given cache as caching file
-P player   : use the given player as scrobbling one
-S seconds  : sends the song as listened when you got past (songLength - seconds)
-E encoding : encoding to automatically encode from, last.fm needs utf8 strings
USAGE
}

sub checkDisconnection {
    my $check = shift;

    if (defined $check->{code} && $check->{code} == 500) {
        $Handshake = { error => 'lol' };
    }
}
