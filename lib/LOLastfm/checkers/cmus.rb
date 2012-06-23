#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'cmus'

class Cmus::Controller::Status
	memoize
	def to_song
		return unless song

		LOLastfm::Song.new(true,
			track:   song.track,
			title:   song.title,
			artist:  song.artist,
			album:   song.album,
			length:  song.duration,
			comment: song.tags.comment,
			path:    song.file,
			stream:  !song.file
		)
	end
end

LOLastfm.define_checker :cmus do
	settings.default[:socket]  = '~/.cmus/socket'
	settings.default[:every]   = 5
	settings.default[:timeout] = 0.005

	@cmus = Cmus::Controller.new(settings[:socket], settings[:timeout])
	@last = @cmus.status

	if @last == :play
		now_playing @last.to_song
	end

	set_interval settings[:every] do
		status = @cmus.status

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

	hint do |type, *args|
		if type == 'stream'
			title, comment = args

			if @hint && title != @hint
				next unless listened title: @hint, comment: comment || @cmus.status.song.comment, stream: true
			end

			next unless now_playing title: title, comment: comment || @cmus.status.song.comment, stream: true

			@hint = title
		end
	end
end
