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
use threads;
use threads::shared;
use Getopt::Std;
use XML::Simple qw(:strict);
use Net::LastFM::Submission;

my $Version = '0.4.4';

my %options;
getopts('hf:s:u:p:C:P:S:T:E:', \%options);

if ($options{h}) {
    print Misc::usage();
    exit;
}

our $Config : shared = shared_clone(XMLin($options{f} || '/etc/LOLastfm.xml', KeyAttr => 1, ForceArray => [ 'service' ]));

if (defined $options{s} || defined $Config->{services}) {
    Services::init($options{s} || $Config->{services});
}

our $Cache       : shared;
our $Tick        : shared;
our $Scrobblable : shared;
our $Encoding    : shared;

if (ref ($Cache = $options{C} || $Config->{cache}) eq 'HASH') {
    $Cache = '';
}
elsif ($Cache && not -e $Cache) {
    open my $test, ">", $Cache;

    if (not defined $test) {
        die "the cache can't be accessed.";
    }
}

$Encoding = $options{E} || $Config->{encoding};

$Tick        = $options{T} || $Config->{tick} || 5;
$Scrobblable = $options{S} || $Config->{seconds} || "seconds >= length - 20";

$Player::name = $options{P} || $Config->{player};
Player::init($Player::name);

our $User     = $options{u} || $Config->{lastfm}->{user};
our $Password = $options{p} || $Config->{lastfm}->{password};

our $LastFM;
our $Handshake;

if (defined $User && defined $Password) {
    $LastFM = new Net::LastFM::Submission(
        user     => $User,
        password => $Password,

        enc => $Encoding || 'utf8',

        client_id  => 'lol',
        client_ver => $Version,
    );

    $Handshake = $LastFM->handshake();

    if (not defined $Handshake->{error}) {
        Cache::submit();
    }
}

our $Old;
our $New;

while (1) {
    $New = Player::currentSong();

    if (!$New) {
        if ($Old) {
            if (Song::isScrobblable($Old)) {
                Song::submit($Old);
                $Old = 0;
            }
        }
    }
    else {
        if ($New->{state} eq 'pause' || (Song::equal($Old, $New) && $Old->{seconds} < $New->{seconds})) {
            if (!$Song::Paused && $New->{state} eq 'pause') {
                $Song::Paused = 1;
            }

            if ($Song::Paused && $New->{state} eq 'play' || !$Song::NowPlaying) {
                if ($Song::Paused) {
                    $Song::Paused = 0;
                }

                Song::nowPlaying($New);
            }
        }
        else {
            if (Song::isScrobblable($Old)) {
                Song::submit($Old);
            }

            Song::nowPlaying($New);
        }

        $Old = $New;
    }

    sleep $Tick;
}

package Song;

our $NowPlaying : shared;
our $Paused     : shared;

sub nowPlaying {
    if (not defined $LastFM) {
        return;
    }

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
    if (not defined $LastFM) {
        return;
    }

    my $song  = shift;
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

sub equal {
    my $first  = shift;
    my $second = shift;

    if (not defined $first) {
        if (not defined $second) {
            return 1;
        }

        return 0;
    }
    elsif (not defined $second) {
        return 0;
    }

    if ($first == 0) {
        if ($second == 0) {
            return 1;
        }

        return 0;
    }
    elsif ($second == 0) {
        return 0;
    }

    return ($first->{title} eq $second->{title} && $first->{album} eq $second->{album} && $first->{artist} eq $second->{artist});
}

sub isScrobblable {
    my $song        = shift;
    my $scrobblable = $Scrobblable;

    if (!$song) {
        return 0;
    }

    $scrobblable =~ s/length/$song->{length}/;
    $scrobblable =~ s/seconds/$song->{seconds}/;

    if (eval($scrobblable)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub fromFile {
    require Music::Tag;

    my $path = shift;
    my $pid  = shift;
    my $song = {};

    if ($Old && defined $Old->{path} && $Old->{path} eq $path) {
        if (defined $Old->{pid} && defined $pid && $Old->{pid} == $pid) {
            my %copy = %{$Old};
               $song = \%copy;

            $song->{seconds} += $Tick;
            $song->{time}     = time() - $song->{length};
            return $song;
        }
    }

    if (defined $pid) {
        $song->{pid} = $pid;
    }

    my $file = new Music::Tag($path);
    $file->get_tag();

    $song->{path} = $path;

    $song->{title}  = $file->title();
    $song->{artist} = $file->artist();

    if (!$song->{title} && !$song->{artist}) {
        return 0;
    }

    $song->{album} = $file->album();
    $song->{id}    = $file->track();

    $song->{length}  = $file->secs();
    $song->{time}    = time() - $song->{length};
    $song->{seconds} = 0;

    $song->{genre}   = $file->genre();
    $song->{country} = $file->country();
    $song->{year}    = $file->year();

    $song->{state} = 'play';

    return $song;
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
        my $line = $_;

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
    if (not defined $LastFM) {
        return;
    }

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

our $name : shared;

sub init {
    my $player = shift;

    if (inited($player)) {
        return;
    }

    if ($player eq 'moc') {
        Player::MOC::init();
    }
    elsif ($player eq 'mpd') {
        Player::MPD::init();
    }
    elsif ($player eq 'mp3blaster') {
        Player::MP3Blaster::init();
    }
    elsif ($player eq 'rhythmbox') {
        Player::Rhythmbox::init();
    }
    elsif ($player eq 'amarok') {
        Player::Amarok::init();
    }
    else {
        Player::Other::init($player);
    }
}

sub getFunction {
    my $player = shift;

    if ($player eq 'moc') {
        return \&Player::MOC::currentSong;
    }
    elsif ($player eq 'mpd') {
        return \&Player::MPD::currentSong;
    }
    elsif ($player eq 'mp3blaster') {
        return \&Player::MP3Blaster::currentSong;
    }
    elsif ($player eq 'rhythmbox') {
        return \&Player::Rhythmbox::currentSong;
    }
    elsif ($player eq 'amarok') {
        return \&Player::Amarok::currentSong;
    }
    else {
        return \&Player::Other::currentSong;
    }
}

sub inited {
    my $player = shift;

    if ($player eq 'moc') {
        return $Player::MOC::inited;
    }
    elsif ($player eq 'mpd') {
        return $Player::MPD::inited;
    }
    elsif ($player eq 'mp3blaster') {
        return $Player::MP3Blaster::inited;
    }
    elsif ($player eq 'rhythmbox') {
        return $Player::Rhythmbox::inited;
    }
    elsif ($player eq 'amarok') {
        return $Player::Amarok::inited;
    }
    else {
        return $Player::Other::inited;
    }
}

sub currentSong {
    my $function = getFunction($name);
    &$function();
}

package Player::MOC;

our $inited;
our $command;

sub init {
    $command = 'mocp -i';

    if ($Config->{moc}->{as}) {
        $command = "su -c '$command' $Config->{moc}->{as}";
    }

    $inited = 1;
}

sub currentSong {
    my $song   = {};
    my $output = `$command`;

    if ($output =~ m{State: (PLAY|PAUSE)}) {
        $song->{state} = lc $1;
    }
    else {
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

our $inited : shared;
our $connection;

sub init {
    require Audio::MPD;

    $connection = newConnection();
    $inited     = 1;
}

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

    if ($mpdState->{state} =~ m{(play|pause)}) {
        $song->{state} = $1;
    }
    else {
        return 0;
    }

    my $mpdSong = $connection->current();

    $song->{title}  = $mpdSong->title();
    $song->{artist} = $mpdSong->artist();

    if (!$song->{title} && !$song->{artist}) {
        return 0;
    }

    $song->{album}   = $mpdSong->album();
    $song->{seconds} = $mpdState->time()->seconds_sofar();
    $song->{length}  = $mpdSong->time();
    $song->{time}    = time() - $song->{seconds};
    $song->{id}      = $mpdSong->track();
    $song->{source}  = 'P';

    return $song;
}

package Player::MP3Blaster;

our $inited     : shared;
our $statusFile : shared;

sub init {
    if (not defined $Config->{mp3blaster}->{statusFile}) {
        die "You have to set a mp3blaster status file to use LOLastfm.";    
    }

    $statusFile = $Config->{mp3blaster}->{statusFile};
    $inited     = 1;
}

sub currentSong {
    my $song = {};

    if (not -e $statusFile) {
        return 0;
    }

    open my $file, "<", $statusFile;
    my @lines = <$file>;
    close $file;

    my $output = join '', @lines;

    if ($output =~ m{^status ((play)ing|(pause)d)}m) {
        $song->{state} = $2;
    }
    else {
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

        if (Song::equal($Old, $song)) {
            $song->{seconds} = $Old->{seconds} + $Tick;
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

package Player::Rhythmbox;

our $inited  : shared;
our $command : shared;

sub init {
    $command = "rhythmbox-client --print-playing-format \"%tn\n%tt\n%ta\n%at\n%te\n%td\"";

    if ($Config->{rhythmbox}->{as}) {
        $command = "su -c '$command' $Config->{rhythmbox}->{as}";
    }

    $inited = 1;
}

sub currentSong {
    my $song   = {};
    my $output = `$command`;
    my @data   = split /\n/, $output;

    $song->{id}     = $data[0];
    $song->{title}  = $data[1];
    $song->{artist} = $data[2];

    if (!$song->{title} && !$song->{artist}) {
        return 0;
    }

    $song->{album}   = $data[3];
    $song->{seconds} = $data[4];
    $song->{length}  = $data[5];

    if ($song->{seconds} =~ /^(\d+)\.(\d+)$/) {
        $song->{seconds} = ($1 * 60) + $2;
    }
    else {
        $song->{seconds} = 0;
    }

    if ($song->{length} =~ /^(\d+)\.(\d+)$/) {
        $song->{length} = ($1 * 60) + $2;
    }
    else {
        $song->{length} = 0;
    }

    if (!$song->{length}) {
        return 0;
    }

    if (Song::equal($Old, $song) && $Old->{seconds} == $song->{seconds}) {
        $song->{state} = 'pause';
    }
    else {
        $song->{state} = 'play';
    }

    $song->{time}   = time() - $song->{seconds};
    $song->{source} = 'P';

    return $song;
}

package Player::Amarok;

our $inited : shared;
our $player;

sub init {
    require DCOP::Amarok::Player;

    $player = new DCOP::Amarok::Player;
    $inited = 1;
}

sub currentSong {
    my $song = {};

    my $status = $player->status();
    if ($status <= 0) {
        return 0;
    }
    else {
        if ($status == 1) {
            $song->{state} = 'pause';
        }
        elsif ($status == 2) {
            $song->{state} = 'play';
        }
    }

    $song->{title}  = $player->title();
    $song->{artist} = $player->artist();

    if (!$song->{title} && !$song->{artist}) {
        return 0;
    }

    $song->{album}   = $player->album();
    $song->{seconds} = $player->trackCurrentTime();
    $song->{length}  = $player->trackTotalTime();
    $song->{time}    = time() - $song->{seconds};
    $song->{id}      = $player->track();
    $song->{source}  = 'P';

    return $song;
}

package Player::Other;

our $name    : shared;
our $inited  : shared;
our $command : shared;

sub init {
    $name    = shift;
    $command = "lsof -c $name | egrep -i '\\.(mp3|ogg|m4a|m4b|m4p|mp4|3gp|flac)\$'";
    $inited  = 1;
}

sub currentSong {
    my $output = `$command`;

    if (not defined $output) {
        return 0;
    }

    if ($output =~ m{\w+\s*(\d+).+?\d+\s+(\/.+)$}) {
        return Song::fromFile($2, $1);
    }
    else {
        return 0;
    }
}

package Services;

our $Services = {};

sub init {
    my $enable = shift;

    if (ref $enable eq 'HASH') {
        if (defined $enable->{service}) {
            for my $service (@{$enable->{service}}) {
                if ($service->{name} eq 'set') {
                    $Services->{$service->{name}} = \&Services::Set::exec;
                }
                elsif ($service->{name} eq 'current') {
                    $Services->{$service->{name}} = \&Services::Current::exec;
                }
                elsif ($service->{name} eq 'submit') {
                    $Services->{$service->{name}} = \&Services::Submit::exec;
                }
                elsif ($service->{name} eq 'change') {
                    $Services->{$service->{name}} = \&Services::Change::exec;
                }
            }
        }
    }

    my $thread = new threads(\&dispatcher);
    $thread->detach();
}

sub dispatcher {
    require IO::Socket;
    require JSON;

    my $socket;
    while (1) {
        $socket = new IO::Socket::INET(
            LocalHost => $Config->{services}->{host} || '127.0.0.1',
            LocalPort => $Config->{services}->{port} || 9001,
            Listen    => 1337,
            Reuse     => 1
        );

        if ($socket) {
            last;
        }

        sleep $Tick;
    }

    my $connection;
    while (($connection = $socket->accept())) {
        my $thread = new threads(\&dispatch, $connection);
        $thread->detach();
    }
}

sub dispatch {
    my $socket = shift;
    my $line   = <$socket>;

    if (not defined $line) {
        close $socket;
        return;
    }

    chomp $line;
    if ($line =~ /^(.+?)(\s+(.*)|)$/) {
        my $service = $1;
        my $data    = $3;

        if (defined $Services->{$service}) {
            $Services->{$service}($socket, $data);
        }
    }

    close $socket;
}

package Services::Set;

sub exec {
    my $socket = shift;
    my $data   = shift;

    if (not defined $data) {
        return;
    }

    my $json = new JSON()->allow_nonref(1);

    $data = $json->decode($data, { utf8 => 1 });

    if (set($data->{name}, $json->decode($data->{value}, { utf8 => 1 }))) {
        print $socket "true", "\n";
    }
    else {
        print $socket "false", "\n";
    }
}

sub set {
    my $name = shift;
    my $data = shift;

    if ($name eq 'player') {
        $Player::name = $data;
        Player::init($Player::name);
        $Song::NowPlaying = 0;
    }
    elsif ($name eq 'scrobblable') {
        $::Scrobblable = $data;
    }
    elsif ($name eq 'tick') {
        $::Tick = $data;
    }
    elsif ($name eq 'access') {
        if (defined $data->{user}) {
            $::User = $data->{user};
        }
        if (defined $data->{password}) {
            $::Password = $data->{password};
        }
    }
    elsif ($name eq 'cache') {
        if ( -e $data ) {
            $::Cache = $data;
        }
        else {
            return 0;
        }
    }

    return 1;
}

package Services::Current;

sub exec {
    my $socket = shift;
    my $data   = shift;

    if (defined $data) {
        $data = JSON::from_json($data, { utf8 => 1 });
    }

    my $function;
    if (defined $data->{player}) {
        Player::init($data->{player});
        $function = Player::getFunction($data->{player});
    }
    else {
        $function = \&Player::currentSong;
    }

    my $song = &$function();

    if (!$song) {
        print $socket 'null', "\n";
    }
    else {
        print $socket JSON::to_json(Player::currentSong()), "\n";
    }
}

package Services::Submit;

sub exec {
    my $socket = shift;
    my $data   = shift;

    my $song = JSON::from_json($data, { utf8 => 1 });

    if (defined $song->{user} && defined $song->{password}) {
        my $lastfm = new Net::LastFM::Submission(
            user     => $song->{user},
            password => $song->{password},

            enc => $options{E} || $Config->{encoding} || 'utf8',

            client_id  => 'lol',
            client_ver => $Version,
        );
        $lastfm->handshake();
        $lastfm->submit($song);
    }
    else {
        Song::submit($song);
    }
}

package Services::Change;

sub exec {
    my $socket = shift;
    my $data   = shift;

    if (defined $data) {
        $data = JSON::from_json($data, { utf8 => 1 });
    }

    my $function;
    if (defined $data->{player}) {
        Player::init($data->{player});
        $function = Player::getFunction($data->{player});
    }
    else {
        $function = \&Player::currentSong;
    }

    $Old = &$function();
    $New = $Old;

    while (Song::equal($Old, $New)) {
        sleep $Tick;

        if (($New = &$function()) == 0) {
            $Old = 0;
        }
    }

    print $socket JSON::to_json($New), "\n";
}

package Misc;

sub usage {
    return << "USAGE";
LOLastfm $Version

Usage: LOLastfm [options]

-h             : show this help.
-f file        : use the given file as config file

-u user        : use the given username instead of the config one
-p password    : use the given password instead of the config one

-C cache       : use the given cache as caching file
-P player      : use the given player as scrobbling one (moc, mpd, mp3blaster, rhythmbox, amarok, others)
-S scrobblable : sends the song as listened if the expression is true (seconds = current listened seconds; length = song's length)
-T tick        : check informations again every tick seconds
-E encoding    : encoding to automatically encode from, last.fm needs utf8 strings
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
