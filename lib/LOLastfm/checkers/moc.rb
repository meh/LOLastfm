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

class Moc::Controller::Status
	memoize
	def to_song
		return unless song

		if song.file.start_with?('http://') || song.file.start_with?('ftp://')
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

LOLastfm.define_checker :moc do
	settings.default[:socket] = '~/.moc/socket2'
	settings.default[:every]  = 5

	@moc  = Moc::Controller.new(settings[:socket])
	@last = @moc.status

	if @last == :play
		now_playing @last.to_song
	end

	set_interval settings[:every] do
		status = @moc.status

		if status == :stop
			if @last != :stop && LOLastfm::Song.is_scrobblable?(@last.song.position, @last.song.duration)
				listened @last.to_song
			else
				stopped_playing!
			end
		elsif status == :pause
			stopped_playing!
		else
			if @last != :stop && (@last.to_song != status.to_song || @last.song.position > status.song.position) && LOLastfm::Song.is_scrobblable?(@last.song.position, @last.song.duration)
				listened @last.to_song
			end

			if @last != :play || @last.to_song != status.to_song
				now_playing status.to_song
			end
		end

		@last = status
	end
end
