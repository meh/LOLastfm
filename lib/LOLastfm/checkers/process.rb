#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

LOLastfm.define_checker :process do
	settings.default[:every] = 5

	ENV['PATH'].split(':').each {|path|
		if File.executable?("#{path}/lsof")
			break settings.default[:lsof] = "#{path}/lsof"
		end
	}

	unless settings[:name]
		raise 'I need the name of the process to check'
	end

	unless settings[:lsof]
		raise 'I need the path to lsof to work'
	end

	set_interval settings[:every] do

	end

	hint do |path|
		listened path: path
	end
end
