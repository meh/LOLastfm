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
require 'LOLastfm/checker'

class LOLastfm
	@@checkers = {}

	def self.load (path)
		new.tap { |o| o.load(path) }
	end

	def self.define_checker (name, &block)
		@@checkers[name] = block
	end

	attr_reader :cache

	def initialize
		@session = Lastfm.new('5f7b134ba19b20536a5e29bc86ae64c9', '3b50e74d989795c3f4b3667c5a1c8e67')
		@cache   = Cache.new(self)

		cache_at '~/.LOLastfm.cache'
	end

	def load (path)
		instance_eval File.read(File.expand_path(path)), path
	end

	def start
		@server = EM.start_server(@host || '0.0.0.0', @port || 40506, LOLastfm::Connection) {|conn|
			conn.fm = self
		}

		@timer = EM.add_periodic_timer 360 do
			save
		end
	end

	def stop
		EM.stop_server @server
		EM.cancel_timer @timer
	ensure
		save
	end

	def cache_at (path)
		@cache_at = File.expand_path(path)

		if File.exists? @cache_at
			@cache.load(@cache_at)
		end
	end

	def save
		if @cache_at
			File.open(@cache_at, 'w') {|f|
				f.write(@cache.to_yaml)
			}
		end
	end

	def listen (host = '0.0.0.0', port)
		@host = host
		@port = port
	end

	def session (key)
		@session.session = key
	end

	def is_authenticated?
		@session.session
	end

	def now_playing (song)
		song = Song.new(song) unless song.is_a?(Song)

		@song.call(song) if @song
		@now_playing = song

		@session.track.update_now_playing(song.artist, song.title)
	end

	def listened (song)
		song = Song.new(song) unless song.is_a?(Song)

		@song.call(song) if @song
		@cache.flush!
		@now_playing = nil

		unless listened! song
			@cache.listened(song)
		end
	end

	def listened! (song)
		@session.track.scrobble(song.artist, song.title, song.listened_at, song.album, song.track, song.id, song.length)
		@last_played = song

		true
	rescue
		false
	end

	def love (song = nil)
		song = @last_played or return unless song
		song = Song.new(song) unless song.is_a? Song

		@song.call(song) if @song

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

	def now_playing?
		@now_playing
	end

	def last_played?
		@last_played
	end

	def checker (*args, &block)
		if args.first.is_a? Symbol
			block = @@checkers[args.shift]
		end

		raise LocalJumpError, 'no block given' unless block

		@checker = Checker.new(fm, name, args.shift, &block)
		@checker.start
	end

	def hint (*args)
		return unless @checker

		@checker.hint(*args)
	end

	def song (&block)
		@song = block
	end
end

require 'LOLastfm/checkers/moc'
require 'LOLastfm/checkers/cmus'
