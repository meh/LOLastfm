#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'json'

class LOLastfm

class Connection < EventMachine::Protocols::LineAndTextProtocol
	attr_writer :fm

	def receive_line (line)
		command, arguments = JSON.parse(line)

		case command.upcase.to_sym
		when :USE
			use arguments

		when :LISTENED
			listened(arguments)

		when :NOW_PLAYING
			now_playing(arguments)

		when :LOVE
			love(arguments)

		when :HINT
			hint(*arguments)

		when :NOW_PLAYING?
			send_data now_playing?.to_json

		when :NEXT?
			on :now_playing do |song|
				send_data song.to_json

				:delete
			end
		end
	rescue => e
		$stderr.puts e.to_s
		$stderr.puts e.backtrace
	end

	def respond_to_missing? (id)
		@fm.respond_to?(id)
	end

	def method_missing (id, *args, &block)
		if @fm.respond_to? id
			return @fm.__send__ id, *args, &block
		end

		super
	end
end

end
