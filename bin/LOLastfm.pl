#! /usr/bin/perl
#
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
use utf8;
use Getopt::Std;
use XML::Simple qw(:strict);
use Net::LastFM::Submission;

my $Version = '0.1';

my %options;
getopts('u:p:P:f:c:a:h', \%options);

if ($options{h}) {
    print Misc::usage();
    exit;
}

my $Config = XMLin($options{f} || '/etc/LOLastfm.xml', KeyAttr => 1, ForceArray => 0);
my $Player = $options{P} || $Config->{player} || die "What player should I use?";
my $Cache  = $options{c} || $Config->{cache} || '/var/lib/LOLastfm/cache.xml';
my $As     = $options{a} || $Config->{as} || `whoami`;

my $LastFM = new Net::LastFM::Submission(
    user     => $options{u} || $Config->{user},
    password => $options{p} || $Config->{password},

    enc => 'utf8',

#    client_id  => 'LOLastfm',
#    client_ver => $Version,
);

my $Handshake = $LastFM->handshake();

my $old = Song::reset();

while (1) {
    my $song = Song::get();

    if (!$song) {
        if ($old->{seconds} >= $old->{length}-20) {
            Song::submit($old);
            $old = Song::reset();
        }

        sleep(5);
        next;
    }

    if ($old->{title} eq $song->{title} && $old->{album} eq $song->{album} && $old->{artist} eq $song->{artist} && $old->{seconds} < $song->{seconds}) {
        if (not $Song::NowPlaying) {
            Song::nowPlaying($song);
        }

        $old = $song;
        sleep(5);
        next;
    }

    if ($old->{seconds} >= $old->{length}-20) {
        Song::submit($old);
    }

    Song::nowPlaying($song);

    $old = $song;

    sleep(5);
}

package Song;

our $NowPlaying = 0;

sub get {
    my $output;
    my $song = {};

    if ($Player eq 'moc') {
        $output = `su -c "mocp -i" $As`;

        if ($output !~ /State: PLAY/) {
            return 0;
        }

        if ($output =~ m{SongTitle: (.+)$}m) {
            $song->{title} = $1;
        }
        else {
            $song->{title} = '';
        }

        if ($output =~ m{Album: (.+)$}m) {
            $song->{album} = $1;
        }
        else {
            $song->{album} = '';
        }

        if ($output =~ m{Artist: (.+)$}m) {
            $song->{artist} = $1;
        }
        else {
            $song->{artist} = '';
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

        return $song;
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

}

sub submit {
    my $song = shift;

    my $check = Cache::submit();

    if (defined $check->{error}) {
        Cache::push($song);
    }

    $check = $LastFM->submit($song);

    if (defined $check->{error}) {
        Cache::push($song)
    }
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

    open my $cache, ">>", $Cache;
    print $cache "$song->{title} ||| $song->{album} ||| $song->{artist} ||| $song->{length} ||| $song->{time}", "\n";
    close $cache;
}

sub get {
    my $number  = shift;
    my $counter = 0;
    my @songs;

    open my $cache, "<", $Cache;
    while (<$cache>) {
        my @data = split / \|\|\| /, $_;
        CORE::push @songs, { title => $data[0], album => $data[1], artist => $data[2], length => $data[3], time => $data[4] };

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
        print $cache, "$line\n";
    }
    close $cache;
}

sub submit {
    if (defined $Handshake->{error}) {
        $Handshake = $LastFM->handshake();
    }

    while (1) {
        my @songs = get(50);

        if ($#songs == 0) {
            last;
        }

        my $check = $LastFM->submit(@songs);

        if (defined $check->{error}) {
            return $check;
        }

        flush(50);
    }
}

package Misc;

sub usage {
    return << "USAGE";
Usage: LOLlastfm [options]

-h          : show this help.
-a user     : execute the command as that user (eg: for mocp you have to be the user using it)
-f file     : use the given file as config file
-c cache    : use the given cache as caching file
-P player   : use the given player as scrobbling one
-u user     : use the given username instead of the config one
-p password : use the given password instead of the config one
USAGE
}
