#! /usr/bin/env ruby
require 'socket'
require 'json'

socket = TCPSocket.open('127.0.0.1', 9001)
socket.print "current\n"

song = JSON.parse(socket.gets)
socket.close()

if (!song['id'].empty?)
    print "%s - " % song['id']
end

if (!song['title'].empty?)
    print "%s " % song['title']
end

if (!song['album'].empty?)
    print "(%s) " % song['album']
end

if (!song['artist'].empty?)
    print "{%s}" % song['artist']
end

puts ""
