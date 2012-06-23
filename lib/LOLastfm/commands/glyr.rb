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

module Glyr
	class Source
		def to_hash
			{ name: name, quality: quality, speed: speed, language_aware: language_aware? }
		end
	end

	class Result
		def to_hash
			{ source: source, url: url, data: data }
		end
	end
end

LOLastfm.define_command :lyrics? do
	song = now_playing?

	EM.defer -> {
		Glyr.query.title(song.title).artist(song.artist).album(song.album).lyrics
	}, -> results {
		send_line results.map(&:to_hash).to_json
	}
end
