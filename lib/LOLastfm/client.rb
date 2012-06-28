#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'socket'
require 'json'

class LOLastfm

class Client
	def initialize (host, port = nil)
		@socket = port ? TCPSocket.new(host, port) : UNIXSocket.new(File.expand_path(host))
	end

	def respond_to_missing? (id, include_private = false)
		@socket.respond_to?(id, include_private)
	end

	def method_missing (id, *args, &block)
		if @socket.respond_to? id
			return @socket.__send__ id, *args, &block
		end

		super
	end

	def send_command (type, *arguments)
		@socket.puts [type, arguments].to_json
	end

	def read_response
		JSON.parse(?[ + @socket.readline.chomp + ?]).first
	end

	def close
		@socket.flush
		@socket.close
	end
end

end
