#! /usr/bin/env perl
use strict;
use warnings;
use IO::Socket;
use JSON;

my $socket = new IO::Socket::INET(
    PeerAddr => '127.0.0.1',
    PeerPort => 9001
);

my $song = {
    'title'  => 'lololol',
    'artist' => 'nigger',
    'album'  => 'dix',
};

print $socket 'submit ' . JSON::to_json($song), "\n";

close $socket;
