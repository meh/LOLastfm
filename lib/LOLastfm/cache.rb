#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'yaml'

class LOLastfm

class Cache
	attr_reader :fm

	def initialize (fm)
		@fm = fm

		@listened = []
		@loved    = []
		@unloved  = []
	end

	def listened (song)
		return if song.nil? || @listened.member?(song)

		@listened << song
	end

	def love (song)
		return if song.nil? || @loved.member?(song)

		@loved << song
	end

	def unlove (song)
		return if song.nil? || @unloved.member?(song)

		@unloved << song
	end

	def empty?
		@listened.empty? && @loved.empty? && @unloved.empty?
	end

	def flush!
		until @listened.empty?
			break unless fm.listened! Song.new(@listened.first)

			@listened.shift
		end

		until @loved.empty?
			break unless fm.love! Song.new(@loved.first)

			@loved.shift
		end

		until @unloved.empty?
			break unless fm.unlove! Song.new(@unloved.first)

			@unloved.shift
		end
	end

	def load (path)
		data = YAML.parse_file(path).transform

		data[:listened].each {|song|
			listened(Song.new(song))
		} if data[:listened]

		data[:loved].each {|song|
			love(Song.new(song))
		} if data[:loved]

		data[:unloved].each {|song|
			unlove(Song.new(song))
		} if data[:unloved]
	end

	def to_yaml
		{
			listened: @listened.map(&:to_hash),
			loved:    @loved.map(&:to_hash),
			unloved:  @unloved.map(&:to_hash)
		}.to_yaml
	end
end

end
