#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

#--
# TODO: Find a nice way to check if the song is actually scrobblable based on position.
#       Right now there's no way to do it based on the MPD's event loop, the only way would
#       be to timeout after some seconds and save the current position, possibly a smart move
#       could be to add a timeout parameter to #loop.
#
#       Still gotta think about it tho.
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
			stream:  !!song.file
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
			begin
				@mpd.loop {|e|
					if e == :player
						status = @mpd.status

						if status == :stop
							next unless @last

							listened @last.to_song
						elsif status == :pause
							stopped_playing!
						else
							if @last == :play
								listened @last.to_song
							end

							now_playing status.to_song
						end

						@last = @mpd.status
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

			set_timeout settings[:every], &create unless stopped?
		}
	}

	create.call
end
