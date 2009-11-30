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
use IO::Socket;
use JSON;

my $name = shift;
my $data = shift;

if (!$name || !$data) {
    print Misc::usage();
    exit;
}

my $json = new JSON()->allow_nonref(1)->allow_barekey(1);

eval {
    $json->decode($data);
};
if ($@) {
    $data = '"'.$data.'"';
}

my $socket = new IO::Socket::INET(
    PeerAddr => '127.0.0.1',
    PeerPort => 9001
);

print $socket "set " . $json->encode({
    name  => $name,
    value => $data,
}), "\n";

my $check = <$socket>;

print $check;

close $socket;

package Misc;

sub usage {
    return << "USAGE";
Usage: LOLastfm-set <setting> <value>

Examples:
    LOLastfm-set player mplayer
    LOLastfm-set access '{ user: "dix", password: "nood" }'
    LOLastfm-set tick 2
    LOLastfm-set seconds 10
    LOLastfm-set cache /tmp/lol.cache
USAGE
}
