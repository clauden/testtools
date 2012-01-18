require 'open4'
require 'fileutils'

CLI = '../make-files.rb'
TEST_DIR = './tmp'

@@debug = false
@@assertions = 0
@@failed_assertions = 0
@@tests = 0
@@failed_tests = 0

#
# return status, stdout
#
def xrun(cmd)
	pid, stdin, stdout, stderr = Open4::popen4(cmd)
	ignored, status = Process::waitpid2 pid	
	raise "FAILED (#{status}): #{cmd}\n#{stderr.readlines.join('')}" if status != 0
	return status, stdout.readlines
end

def assert(condition, note ="assertion failed")
	@@assertions += 1
	if not condition
		@@failed_assertions += 1
		puts "ASSERTION FAILED: #{note}"
		raise note
	end
end

RANDBASE = 36
RANDEXP = RANDBASE ** 8

class Tests

	def random_name
		name = "#{rand(RANDEXP).to_s(RANDBASE)}"
	end

	def setup
		puts "set up"
		@files = {}
		@test_dir = "#{TEST_DIR}/#{random_name}"
		cmd = "mkdir -p #{@test_dir}"
		xrun(cmd)
	end

	def do_a_test(cmd)
		# p "running #{cmd}"
		status, output = xrun(cmd)
		# p output.inspect
		
		output.each do |l|
			f, c = l.split

			f = "#{@test_dir}/#{f}" 
			c = c.to_i
			# puts f,c

			@files[f] = c

			# check existence
			assert(test(?e,f), "file missing" )
	
			# check checksum
			cmd = "sum #{f}"
			x, cs = xrun(cmd)
			assert(cs[0].split[0].to_i == c, "bad checksum")

			# raise "bad checksum" if cs[0].split[0].to_i != c
		end
	end

	def test_one_file_constant_with_dir
		cmd = "#{CLI} -d #{@test_dir} -n 1 --constant"
		do_a_test(cmd)
	end

	def test_one_file_random_with_dir
		cmd = "#{CLI} -d #{@test_dir} -n 1 --random"
		do_a_test(cmd)
	end

	def files_in_dir(dir)
	    	dh = Dir.open(dir)
	    	dh.entries.grep(/^[^.]/).
			map      {|file| "#{dir}/#{file}"}.
			find_all {|file| test(?f, file)}.
			length
	end

	def test_many_files_constant_with_dir
		cmd = "#{CLI} -d #{@test_dir} -n 5 --constant"
		do_a_test(cmd)
		assert(files_in_dir(@test_dir) == 5, "wrong number of files")
	end

	def test_many_files_random_with_dir
		cmd = "#{CLI} -d #{@test_dir} -n 5 --random"
		do_a_test(cmd)
		assert(files_in_dir(@test_dir) == 5, "wrong number of files")
	end

	def teardown
		puts "tear down"
		# @files.each_key do |f|
		#	File.delete(f)
		# end
		FileUtils.rm_rf(@test_dir)
	end
end

if __FILE__ == $0

	current_test = nil

	t = Tests.new
	t.methods.grep(/^test_/).each do |m|
		t.method(:setup).call rescue nil
		begin
			puts "Running test #{m.to_s}"
			@@tests += 1
			current_test = m.to_s
			t.method(m).call
		rescue Object => x
			if @@debug
				puts "caught: #{x.inspect}"
				puts x.backtrace.join("\n")
			end
			@@failed_tests += 1
			puts "FAILED: #{current_test}"
		end
		t.method(:teardown).call rescue nil
	end
	
	puts "#{@@assertions} assertions, #{@@failed_assertions} failed"
	puts "#{@@tests} tests, #{@@failed_tests} failed"
end
