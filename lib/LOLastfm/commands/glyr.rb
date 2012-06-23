#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'glyr'

class Glyr::Result::Data
	def to_json
		{ source: source, provider: provider, data: data }.to_json
	end
end

LOLastfm.define_command :lyrics? do
	song = now_playing?

	EM.defer -> {
		Glyr.query.title(song.title).artist(song.artist).album(song.album).lyrics
	}, -> result {
		send_line result.first.to_str.to_json
	}
end
