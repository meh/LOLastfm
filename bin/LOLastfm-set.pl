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
my $json = new JSON()->allow_nonref(1);

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
