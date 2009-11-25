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

use Data::Dumper;

my %options;
getopts('u:p:P:f:c:h', \%options);

if ($options{h}) {
    print Misc::usage();
    exit;
}

my $Config = XMLin($options{f} || '/etc/LOLastfm.xml', KeyAttr => 1, ForceArray => 0);
my $Player = $options{P} || $Config->{player} || die "What player should I use?";
my $Cache  = $options{c} || $Config->{cache} || '/var/lib/LOLastfm/cache.xml';

my $LastFM = new Net::LastFM::Submission(
    user     => $options{u} || $Config->{user},
    password => $options{p} || $Config->{password},

    enc => 'utf8',

#    client_id  => 'LOLastfm',
#    client_ver => $Version,
);

$LastFM->handshake();

my $old = {
    title   => '',
    album   => '',
    artist  => '',
    seconds => 42,
    length  => 9001,
};

while (1) {
    my $song = Song::get();

    if (!$song) {
        sleep(5);
        next;
    }

    if ($old->{title} eq $song->{title} && $old->{album} eq $song->{album} && $old->{artist} eq $song->{artist} && $old->{seconds} < $song->{seconds}) {
        $old = $song;
        sleep(5);
        next;
    }

    if ($old->{seconds} >= $old->{length}-20) {
        $LastFM->submit($old);
    }

    $LastFM->now_playing($song);
    print "Now playing $song->{title}", "\n";

    $old = $song;

    sleep(5);
}

package Song;

sub get {
    my $output;
    my $song = {};

    if ($Player eq 'moc') {
        $output = `mocp -i`;

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
            $song->{length} = '';
        }

        $song->{source} = 'P';

        return $song;
    }
}

package Misc;

sub usage {
    return << "USAGE";
Usage: LOLlastfm [options]

-h          : show this help.
-f file     : use the given file as config file
-c cache    : use the given cache as caching file
-P player   : use the given player as scrobbling one
-u user     : use the given username instead of the config one
-p password : use the given password instead of the config one
USAGE
}
