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
	def self.is_scrobblable? (position, duration)
		return false unless position && duration

		return false if duration < 30

		return true if position > 240

		return true if position >= duration / 2

		false
	end

	attr_accessor :track, :title, :album, :artist, :comment, :length, :listened_at, :path, :id

	def initialize (no_fill = false, data)
		data = Hash[data.map { |key, value| [key.to_sym, value] }]

		@track       = data[:track] && data[:track].to_i
		@title       = data[:title] && data[:title].strip
		@album       = data[:album] && data[:album].strip
		@artist      = data[:artist] && data[:artist].strip
		@length      = data[:length] && data[:length].to_i
		@comment     = data[:comment]
		@listened_at = data[:listened_at]
		@path        = data[:path]
		@id          = data[:id]

		fill! unless no_fill

		if data[:stream] || (@length && @length < 0)
			stream!

			@length = nil
		end

		if @listened_at
			@listened_at = @listened_at.is_a?(String) ? DateTime.parse(@listened_at) : @listened_at.to_datetime
		else
			if @length
				@listened_at = (Time.now - @length).to_datetime
			else
				@listened_at = DateTime.now
			end
		end

		@title = nil if @title && @title.strip.empty?
		@album = nil if @album && @album.empty?
		@arist = nil if @artist && @artist.empty?
	end

	def fill!
		return if !@path || (@track && @title && @album && @artist && @comment && @length && @id)

		TagLib::FileRef.open(@path) {|f|
			if f.tag
				@track   = f.tag.track && f.tag.track.to_i unless @track
				@title   = f.tag.title unless @title
				@album   = f.tag.album unless @album
				@artist  = f.tag.artist unless @artist
				@comment = f.tag.comment unless @comment
			end

			if f.audio_properties
				@length = f.audio_properties.length.to_i unless @length
			end
		}

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
	end

	def stream?; !!@stream;      end
	def stream!; @stream = true; end

	def nil?
		title.nil? || artist.nil?
	end

	def hash
		[title, artist].hash
	end

	def == (other)
		return true if super

		title == other.title && artist == other.artist
	end

	alias eql? ==

	def to_hash
		{
			track: track, title: title, album: album, artist: artist, comment: comment,
			length: length, listened_at: listened_at, path: path, id: id,
			stream: stream?
		}
	end

	def to_json
		to_hash.to_json
	end

	def to_yaml
		to_hash.to_yaml
	end

	def inspect
		header = ''
		header << "#{id} "                      if id
		header << "listened at #{listened_at} " if listened_at
		header << "#{length} seconds "          if length
		header << "found at #{path} "           if path

		parts = ''
		parts << "track=#{track} "   if track
		parts << "title=#{title} "   if title
		parts << "artist=#{artist} " if artist
		parts << "album=#{album} "   if album

		"#<LOLastfm::Song#{"(#{header[0 .. -2]})" unless header.empty?}:#{" #{parts[0 .. -2]}" if parts}>"
	end
end

end
