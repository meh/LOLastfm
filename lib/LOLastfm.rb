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
require 'stringio'

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
		logs_at  '~/.LOLastfm/logs'
	end

	def load (path)
		instance_eval File.read(File.expand_path(path)), path
	end

	def started?; !!@started; end

	def start
		return if started?

		@started = true

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
		@cache.flush!
	end

	def stop
		return unless started?

		EM.stop_server @server
		EM.cancel_timer @timer

		@checker.stop if @checker

		@started = false
	ensure
		save
	end

	def cache_at (path)
		@cache_at = File.expand_path(path)

		if File.exists? @cache_at
			@cache.load(@cache_at)
		end
	end

	def logs_at (path)
		@logs_at = File.expand_path(path)
	end

	def server_at (host, port = nil)
		if port
			@host = host
			@port = port
		else
			@path = host
		end
	end

	def save
		if @cache_at
			File.open(@cache_at, 'w') {|f|
				f.write(@cache.to_yaml)
			}
		end
	end

	def log (what, group = nil)
		io = StringIO.new
		io.print "[#{Time.now}#{", #{group}" if group}] "

		if what.is_a? Exception
			io.puts "#{what.class.name}: #{what.message}"
			io.puts what.backtrace
		else
			io.puts what
		end

		io.string.tap {|text|
			$stderr.puts text

			File.open(@logs_at, 'a') { |f| f.print text }
		}
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

		return false if song.nil?

		@now_playing = nil
		@last_played = song

		unless listened! song
			@cache.listened(song)
		end
		
		true
	end

	def listened! (song)
		@session.track.scrobble(song.artist, song.title, song.listened_at.to_time.to_i, song.album, song.track, song.id, song.length)
	rescue SystemCallError, SocketError, EOFError
		false
	rescue Exception => e
		log e, :listened

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
	rescue SystemCallError, SocketError, EOFError
		false
	rescue Exception => e
		log e, :love

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
	rescue SystemCallError, SocketError, EOFError
		false
	rescue Exception => e
		log e, :unlove

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
		if args.empty? && !block
			raise ArgumentError, 'no name or block given'
		end

		unless args.first.respond_to?(:to_hash) || block
			name = args.shift.to_sym

			if args.first.is_a? String
				require args.shift
			elsif !self.class.checkers[name]
				begin
					require "LOLastfm/checkers/#{name}"
				rescue LoadError; end
			end

			unless block = self.class.checkers[name]
				raise ArgumentError, "#{name} checker could not be found"
			end
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
