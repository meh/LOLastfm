#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'taglib'
require 'json'
require 'yaml'
require 'date'

class LOLastfm

class Song
	attr_reader :track, :title, :album, :artist, :length, :listened_at, :path, :id

	def initialize (data)
		data = Hash[data.map { |key, value| [key.to_sym, value] }]

		@track       = data[:track] && data[:track].to_i
		@title       = data[:title]
		@album       = data[:album]
		@artist      = data[:artist]
		@length      = data[:length] && data[:length].to_i
		@listened_at = data[:listened_at]
		@path        = data[:path]
		@id          = data[:id]

		if @path
			TagLib::FileRef.open(@path) {|f|
				@track  = f.tag.track unless @track
				@title  = f.tag.title unless @title
				@album  = f.tag.album unless @album
				@artist = f.tag.artist unless @artist
				@length = f.properties.length.to_i unless @length

				unless @id
					TagLib::MPEG::File.new(@path).tap {|file|
						next unless tag = file.id3v2_tag

						if ufid = tag.frame_list('UFID').find { |u| u.owner == 'http://musicbrainz.org' }
							@id = ufid.identifier
						end
					}
				end

				unless @id
					TagLib::FLAC::File.new(@path).tap {|file|
						next unless tag = file.xiph_comment

						@id = tag.field_list_map['MUSICBRAINZ_TRACKID']
					}
				end

				unless @id
					TagLib::Ogg::Vorbis::File.new(@path).tap {|file|
						next unless tag = file.tag

						@id = tag.field_list_map['MUSICBRAINZ_TRACKID']
					}
				end
			}
		end

		if @length && @length < 0
			stream!
			@length = nil
		end

		if @listened_at
			@listened_at = @listened_at.is_a?(String) ? DateTime.parse(@listened_at) : @listened_at.to_datetime
		elsif @length
			@listened_at = DateTime.now - @length
		end
	end

	def stream?; @stream;        end
	def stream!; @stream = true; end

	def to_hash
		{
			track: track, title: title, album: album, artist: artist,
			length: length, listened_at: listened_at, path: path, id: id
		}
	end

	def to_json
		to_hash.to_json
	end

	def to_yaml
		to_hash.to_yaml
	end
end

end
