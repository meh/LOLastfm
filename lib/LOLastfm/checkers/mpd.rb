#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'mpd'

class MPD::Controller::Status
	def to_song
		return unless song

		if song.file =~ %r{\w+://}
			comment = song.file
		else
			path = song.file
		end

		LOLastfm::Song.new(true,
			track:   song.track,
			title:   song.title,
			artist:  song.artist,
			album:   song.album,
			length:  song.duration,
			comment: comment,
			path:    path,
			stream:  !!comment
		)
	end
end

LOLastfm.define_checker :mpd do
	settings.default[:host]  = 'localhost'
	settings.default[:port]  = 6600
	settings.default[:every] = 5

	create = proc {
		unless @mpd = MPD::Controller.new(settings[:socket] || settings[:host], settings[:port])
			set_timeout settings[:every], &create unless stopped?

			next
		end

		if settings[:password]
			@mpd.authenticate(settings[:password])
		end

		@last = @mpd.status

		if @last == :play
			now_playing @last.to_song
		end

		Thread.new {
			timeout = set_interval settings[:every] do
				@mpd.stop_waiting
			end

			begin
				@mpd.loop {|e|
					if e == :player
						status = @mpd.status

						if status == :stop
							next unless @last

							song = @last.to_song

							if song.stream?
								listened song
							elsif LOLastfm::Song.is_scrobblable?(@position, song.length)
								listened song
							else
								stopped_playing!
							end
						elsif status == :pause
							stopped_playing!
						else
							if @last == :play
								song = @last.to_song

								if song.stream?
									listened song
								elsif LOLastfm::Song.is_scrobblable?(@position, song.length)
									listened song
								end
							end

							@position = 0

							now_playing status.to_song
						end

						@last = @mpd.status
					elsif e == :break
						@position = @mpd.status.song.position
					end
				}
			rescue Exception => e
				log e, 'checker: mpd'

				retry if mpd.active?
			end

			if song
				if song.stream?
					listened song
				else
					if LOLastfm::Song.is_scrobblable?(position, song.length)
						listened song
					else
						stopped_playing!
					end
				end
			end

			clear_timeout timeout

			set_timeout settings[:every], &create unless stopped?
		}
	}

	create.call
end
