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

define_command :use do |*args|
	use *args
end

define_command :commands do |*args|
	commands *args
end

define_command :listened do |song|
	listened song
end

define_command :now_playing do |song|
	now_playing song
end

define_command :stopped_playing do
	stopped_playing!
end

define_command :love do |song|
	love song
end

define_command :unlove do |song|
	unlove song
end

define_command :hint do |*args|
	hint *args
end

define_command :now_playing? do
	send_line now_playing?.to_json
end

define_command :next? do
	on :now_playing do |song|
		send_line song.to_json

		:delete
	end
end

class Connection < EventMachine::Protocols::LineAndTextProtocol
	attr_writer :fm

	def receive_line (line)
		command, arguments = JSON.parse(line)

		if block = LOLastfm.commands[command.to_sym.downcase]
			instance_exec *arguments, &block
		end
	rescue Exception => e
		$stderr.puts e.to_s
		$stderr.puts e.backtrace
	end

	def send_line (line)
		raise ArgumentError, 'the line already has a newline character' if line.include? "\n"

		send_data line.dup.force_encoding('BINARY') << "\r\n"
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
