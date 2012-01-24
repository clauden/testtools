require './simpletest'

class X < SimpleTest

	def s3cmd 
		"s3cmd -c test.cfg "
	end

	def delete_bucket(name)
		name = "s3://#{name}" if not name.match(/s3:\/\//)
		cmd = "#{s3cmd} ls #{name}"
		objects = run(cmd)	
		objects.each do |l|
			f = l.split[3]
			cmd = "#{s3cmd} del #{f}"
			run(cmd)
		end
		sleep 1
		cmd = "#{s3cmd} rb #{name}"
		run(cmd)	
	end
end

x = X.new
x.debug = true
x.delete_bucket(ARGV[0])
