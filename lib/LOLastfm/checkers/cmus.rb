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
		data = tags.marshal_dump
		data[:track] = data[:tracknumber]

		Song.new(data)
	end
end

LOLastfm.define_checker :cmus do
	settings.default[:socket] = '~/.cmus/socket'
	settings.default[:every]  = 5

	@cmus = Cmus::Controller.new(settings[:socket])
	@last = @cmus.status

	set_interval settings[:every] do
		status = @cmus.status

		if status == :stopped
			if @last == :playing

			end
		else
		end

		@last = status
	end

	hint do |title|
		if @last_hint && title != @last_hint
			listened title: title, stream: true
		end

		now_playing title: title, stream: true

		@last_hint = title
	end
end
