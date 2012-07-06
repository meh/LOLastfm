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
require 'tmpdir'
require 'fileutils'

module Glyr
	class Source
		def to_hash
			{ name: name, quality: quality, speed: speed, language_aware: language_aware? }
		end
	end

	class Result
		def to_hash
			if respond_to? :to_str
				{ source: source, url: url, content: to_str }
			else
				{ source: source, url: url }
			end
		end
	end

	File.expand_path(ENV['GLYR_CACHE'] || '~/.LOLastfm/glyr.cache').tap {|path|
		FileUtils.mkpath(path)
		cache_at path
	}
end

LOLastfm.define_command :lyrics? do
	song = now_playing?

	EM.defer -> {
		Glyr.query(title: song.title, artist: song.artist, album: song.album).lyrics
	}, -> results {
		send_response results.map(&:to_hash)
	}
end
