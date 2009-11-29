#! /usr/bin/env perl
use strict;
use warnings;
use IO::Socket;
use JSON;

while (1) {
    my $socket = new IO::Socket::INET(
        PeerAddr => '127.0.0.1',
        PeerPort => 9001
    );

    print $socket 'change', "\n";
    my $song = <$socket>;
    close $socket;

    my $json = new JSON()->allow_nonref(1);
    $song    = $json->decode($song, { utf8 => 1 });

    if ($song->{id}) {
        print "$song->{id} - ";
    }
    if ($song->{title}) {
        print "$song->{title} ";
    }
    
    if ($song->{album}) {
        print "($song->{album}) "
    }
    if ($song->{artist}) {
        print "{$song->{artist}}";
    }
    
    print "\n";
}