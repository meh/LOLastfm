#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'moc'

class Moc::Controller::Status::Live
	def to_song
		return unless song

		file = song.file
		tags = song.tags

		if file.start_with?('http://') || file.start_with?('ftp://')
			comment = file
		else
			path = file
		end

		LOLastfm::Song.new(true,
			track:   tags.track,
			title:   tags.title,
			artist:  tags.artist,
			album:   tags.album,
			length:  tags.time,
			comment: comment,
			path:    path,
			stream:  !!comment
		)
	end
end

LOLastfm.define_checker :moc do
	settings.default[:socket] = '~/.moc/socket2'
	settings.default[:every]  = 5

	create = proc {
		unless moc = Moc::Controller.new(settings[:socket]) rescue false
			set_timeout settings[:every], &create unless stopped?

			next
		end

		Thread.new {
			song, position = nil

			begin
				moc.loop {|e|
					if e == :audio_stop
						next unless song

						if song.stream?
							listened song
						else
							if LOLastfm::Song.is_scrobblable?(position, song.length)
								listened song
							else
								stopped_playing!
							end
						end

						song = nil
					elsif e == :audio_start
						now_playing song = moc.status(true).to_song
					elsif e == :state && moc.status(true) == :paused
						stopped_playing!
					elsif e == :ctime
						unless song
							now_playing song = moc.status(true).to_song
						end

						if song.stream?
							if moc.status(true).song.title != song.title
								listened song
								now_playing song = moc.status(true).to_song
							end
						else
							position = moc.status(true).song.position
						end
					end
				}
			rescue Exception => e
				log e, 'checker: moc'

				retry if moc.active?
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
