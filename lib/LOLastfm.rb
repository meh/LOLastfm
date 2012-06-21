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
    @events  = Hash.new { |h, k| h[k] = [] }

		cache_at '~/.LOLastfm.cache'
	end

	def load (path)
		instance_eval File.read(File.expand_path(path)), path
	end

	def start
		@server = EM.start_unix_domain_server(@socket || File.expand_path('~/.LOLastfm.socket'), LOLastfm::Connection) {|conn|
			conn.fm = self
		}

		@timer = EM.add_periodic_timer 360 do
			save
		end
	end

	def stop
		EM.stop_server @server
		EM.cancel_timer @timer

		@checker.stop if @checker
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

	def socket (path)
		@socket = path
	end

	def session (key)
		@session.session = key
	end

	def is_authenticated?
		@session.session
	end

	def now_playing (song)
		song = Song.new(song) unless song.is_a?(Song)

		return false unless fire(:now_playing, song)

		@now_playing = song

		@session.track.update_now_playing(song.artist, song.title)

		true
	end

	def listened (song)
		song = Song.new(song) unless song.is_a?(Song)

		return false unless fire :listened, song

		@cache.flush!
		@now_playing = nil

		unless listened! song
			@cache.listened(song)
		end
		
		true
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

		return false unless fire :love, song

		unless love! song
			@cache.love(song)
		end

		true
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

	def use (*args, &block)
		unless args.first.respond_to? :to_hash
			name  = args.shift.to_sym
			block = @@checkers[name]
		end

		if @checker
			@checker.stop
		end

		@checker = Checker.new(self, name, args.shift, &block)
		@checker.start
	end

	def hint (*args)
		return unless @checker

		@checker.hint(*args)
	end

	def on (event, &block)
		@events[event.to_sym] << block
	end

	def fire (event, *args)
		delete  = []
		stopped = false

		@events[event.to_sym].each {|block|
			result = block.call(*args)

			case result
			when :delete
				delete << event

			when :stop
				stopped = true
				break
			end
		}

		@events[event.to_sym] -= delete

		return !stopped
	end
end
