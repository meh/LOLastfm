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
	def to_song
		data = song.marshal_dump
		data[:track] = data[:tracknumber]

		LOLastfm::Song.new(data)
	end
end

LOLastfm.define_checker :cmus do
	settings.default[:socket]  = '~/.cmus/socket'
	settings.default[:every]   = 5
	settings.default[:timeout] = 0.005

	@cmus = Cmus::Controller.new(settings[:socket], settings[:timeout])
	@last = @cmus.status

	set_interval settings[:every] do
		status = @cmus.status

		if status == :stopped
			if @last == :playing && LOLastfm::Song.is_scrobblable?(@last.position, @last.duration)
				listened @last.to_song
			end
		elsif status == :paused
			# nothing
		else
			if (@last.to_song != status.to_song || @last.position > status.position) && LOLastfm::Song.is_scrobblable?(@last.position, @last.duration)
				listened @last.to_song
			end

			now_playing status.to_song
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
