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

class LOLastfm
	def self.load (path)
		new.tap { |o| o.load(path) }
	end

	def self.checkers
		@checkers ||= {}
	end

	def self.define_checker (name, &block)
		checkers[name.to_sym.downcase] = block
	end

	def self.commands
		@commands ||= {}
	end

	def self.define_command (name, &block)
		commands[name.to_sym.downcase] = block
	end

	attr_reader :path, :host, :port, :cache

	def initialize
		@session = Lastfm.new('5f7b134ba19b20536a5e29bc86ae64c9', '3b50e74d989795c3f4b3667c5a1c8e67')
		@cache   = Cache.new(self)
    @events  = Hash.new { |h, k| h[k] = [] }

		cache_at '~/.LOLastfm/cache'
	end

	def load (path)
		instance_eval File.read(File.expand_path(path)), path
	end

	def started?; !!@started; end

	def start
		return if started?

		@server = if @host && @port
			EM.start_server(host, port, LOLastfm::Connection) {|conn|
				conn.fm = self
			}
		else
			EM.start_unix_domain_server(path || File.expand_path('~/.LOLastfm/socket'), LOLastfm::Connection) {|conn|
				conn.fm = self
			}
		end

		@timer = EM.add_periodic_timer 360 do
			save
		end

		@checker.start
	end

	def stop
		return unless started?

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

	def server_at (host, port = nil)
		if port
			@host = host
			@port = port
		else
			@path = host
		end
	end

	def session (key)
		@session.session = key
	end

	def is_authenticated?
		!!@session.session
	end

	def now_playing (song)
		song = Song.new(song) unless song.is_a?(Song)
		song = song.dup

		return false unless fire :now_playing, song

		@now_playing = nil

		return false if song.nil?

		@now_playing = song

		@session.track.update_now_playing(song.artist, song.title, song.album, song.track, song.id, song.length)
	rescue
		false
	end

	def listened (song)
		song = Song.new(song) unless song.is_a?(Song)
		song = song.dup

		return false unless fire :listened, song

		@cache.flush!
		@now_playing = nil

		return false if song.nil?

		unless listened! song
			@cache.listened(song)
		end
		
		true
	end

	def listened! (song)
		@session.track.scrobble(song.artist, song.title, song.listened_at.to_time.to_i, song.album, song.track, song.id, song.length).tap {
			@last_played = song
		}
	rescue
		false
	end

	def love (song = nil)
		song = @last_played or return unless song
		song = now_playing? or return if song == 'current' || song == :current
		song = Song.new(song) unless song.is_a? Song
		song = song.dup

		return false unless fire :love, song

		return false if song.nil?

		unless love! song
			@cache.love(song)
		end

		true
	end

	def love! (song)
		@session.track.love(song.artist, song.title)
	rescue
		false
	end

	def unlove (song = nil)
		song = @last_played or return unless song
		song = now_playing? or return if song == 'current' || song == :current
		song = Song.new(song) unless song.is_a? Song
		song = song.dup

		return false unless fire :unlove, song

		return false if song.nil?

		unless unlove! song
			@cache.unlove(song)
		end

		true
	end

	def unlove! (song)
		@session.track.unlove(song.artist, song.title)
	rescue
		false
	end

	def stopped_playing!
		@now_playing = nil
	end

	def now_playing?
		@now_playing
	end

	def last_played?
		@last_played
	end

	def commands (name)
		begin
			require "LOLastfm/commands/#{name}"
		rescue LoadError
			require name.to_s
		end
	end

	def use (*args, &block)
		return if args.empty? && !block

		unless args.first.respond_to?(:to_hash) || block
			name = args.shift.to_sym

			if args.first.is_a? String
				require args.pop
			elsif !self.class.checkers[name]
				begin
					require "LOLastfm/checkers/#{name}"
				rescue LoadError; end
			end

			block = self.class.checkers[name]
		end

		if @checker
			@checker.stop
		end

		@checker = Checker.new(self, name, args.shift, &block).tap {|c|
			c.start if started?
		}
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

require 'LOLastfm/version'
require 'LOLastfm/cache'
require 'LOLastfm/connection'
require 'LOLastfm/song'
require 'LOLastfm/checker'
