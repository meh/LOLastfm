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
	end

	def listened (song)
		return if @loved.contains? song

		@listened << song
	end

	def love (song)
		return if @loved.contains? song

		@loved << song
	end

	def empty?
		@listened.empty? && @loved.empty?
	end

	def flush!
		until @listened.empty?
			break unless fm.listened! @listened.first

			@listened.shift
		end

		until @loved.empty?
			break unless fm.love! @loved.first

			@loved.shift
		end
	end

	def load (path)
		data = YAML.parse_file(path).transform

		data['listened'].each {|song|
			listened(Song.new(song))
		}

		data['loved'].each {|song|
			love(Song.new(song))
		}
	end

	def to_yaml
		{ 'listened' => @listened.map(&:to_hash), 'loved' => @loved.map(&:to_hash) }.to_yaml
	end
end

end
