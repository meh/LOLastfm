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
	attr_accessor :fm

	def receive_line (line)
		command, arguments = JSON.parse(line)

		case command.upcase.to_sym
		when :LISTENED
			fm.listened(arguments)

		when :NOW_PLAYING
			fm.now_playing(arguments)

		when :LOVE
			fm.love(arguments)

		when :NEXT?
			fm.on :now_playing do |song|
				send_data song.to_json

				:delete
			end
		end
	rescue => e
		$stderr.puts e.to_s
		$stderr.puts e.backtrace
	end
end

end
