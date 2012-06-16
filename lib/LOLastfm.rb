#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'eventmachine'
require 'lastfm'

require 'LOLastfm/version'
require 'LOLastfm/cache'
require 'LOLastfm/connection'
require 'LOLastfm/song'

class LOLastfm
	def self.load (path)
		new.tap { |o| o.load(path) }
	end

	attr_reader :cache

	def initialize
		@session = Lastfm.new('5f7b134ba19b20536a5e29bc86ae64c9', '3b50e74d989795c3f4b3667c5a1c8e67')

		@cache   = Cache.new(self)
		@events  = Hash.new { |h, k| h[k] = [] }
		@servers = []
	end

	def load (path)
		instance_eval File.read(File.expand_path(path)), path
	end

	def start
	end

	def stop
		@servers.each { |s| EM.stop_server s }
	ensure
		if @cache_at
			File.open(@cache_at, 'w') {|f|
				f.write(@cache.to_yaml)
			}
		end
	end

	def cache_at (path)
		@cache_at = File.expand_path(path)

		@cache.load(@cache_at)
	end

	def listen (host, port)
		@servers << EM.start_server(host, port, LOLastfm::Connection) {|conn|
			conn.fm = self
		}
	end

	def session (key)
		@session.session = key
	end

	def is_authenticated?
		@session.session
	end

	def now_playing (*args)
		song = args.first.is_a?(Song) ? args.first : Song.new(*args)

		fire :now_playing, song

		@session.track.update_now_playing(song.title, song.artist)
	end

	def listened (*args)
		song = args.first.is_a?(Song) ? args.first : Song.new(*args)

		fire :listened, song

		@cache.flush!

		unless listened! song
			@cache.listened(song)
		end
	end

	def listened! (song)
		@session.track.scrobble(song.artist, song.title, song.listened_at, song.album, song.track, song.id, song.length)
		@listened = song

		true
	rescue
		false
	end

	def love (*args)
		song = args.first.is_a?(Song) ? args.first : args.empty? ? @listened : Song.new(*args)

		fire :love, song

		unless love! song
			@cache.love(song)
		end
	end

	def love! (song)
		@session.track.love(song.artist, song.title)

		true
	rescue
		false
	end

	def on (event, &block)
		@events[event] << block
	end

	def fire (event, *args)
		delete = []

		@events[event].each {|event|
			result = event.call(*args)

			if result == :delete
				delete << event
			end
		}

		@events[event] -= delete
	end
end
