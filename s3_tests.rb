require 'open4'
require 'fileutils'

CLI = 's3cmd'
TEST_DIR = './temp'

@@debug = false
@@assertions = 0
@@failed_assertions = 0
@@tests = 0
@@failed_tests = 0

#
# return status, stdout
#
def run(cmd)
	puts "RUN: #{cmd}"
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

	#
	# create a bucket
	#
	def create_bucket(name)
		cmd = "s3cmd mb #{name}"
		run(cmd)	
	end

	#
	# delete a bucket
	#
	def delete_bucket(name)
		cmd = "s3cmd rb #{name}"
		puts "NOT RUNNING #{cmd}"
		# run(cmd)	
	end

	def bucket_exists(name)
		cmd = "s3cmd ls s3://#{name}"
		run(cmd)	
	end

	def object_exists(bucket, name)

		# this is wrong, ls s3://bucket/prefix should work.  
		# but it doesn't.
		cmd = "s3cmd ls s3://#{bucket}"
		objects = run(cmd)	
		objects.each do |l|
			f = l.split[3]
			return true if f.match(name)
		end
		false
	end

	def test_bucket_basics
		assert(bucket_exists(@test_bucket), "bucket doesnt exist")
		cmd = "s3cmd put #{__FILE__} s3://#{@test_bucket}"
		run(cmd)
		assert(bucket_exists(@test_bucket), __FILE__, "object doesnt exist")
	end
		
		
	#
	# create testdata files
	#
	def create_files(maxsize, mode, num)
	end

	#
	# put specifed files into bucket
	# assert that the objects exist on completion
	#
	def put_files(bucket, names)
		names = [names] if not names.respond_to('each')
	end

	#
	# delete file
	# assert that it exists on entry
	#
	def unlink(names)
		names = [names] if not names.respond_to('each')
	end

	#
	# get the named object
	# assert that object exists on entry and file exists on completion
	# returns file checksum
	#
	def get_file(bucket, name)
	end

	def setup
		@files = {}

		@test_dir = "#{TEST_DIR}/#{random_name}"
		cmd = "mkdir -p #{@test_dir}"
		run(cmd)

		@test_bucket = random_name
		create_bucket(random_name)
	end

	def _test_bucket_create_delete
		b = random_name

		create_bucket(b)
		assert(bucket_exists(b), "bucket not created")

		delete_bucket(b)
		assert(!bucket_exists(b), "bucket not destroyed")
	end

	def _test_one_small_object_with_simple_name
		# create a file
		name, sum = create_files(SMALL_FILE, RANDOM_LENGTH, 1)
		@files[name] = sum	
		
		# put file -> object
		put_files(name)
	
		# clean up file
		unlink(name)

		# get object -> file with checksum
		sum = get_file(name)

		# verify
		assert(sum == @files[name], "bad checksum")
		
	end

	def one_small_object_with_path_name
		# create a file 
		name, sum = create_files(SMALL_FILE, RANDOM_LENGTH, 1)
		# name = "#{name}/#{name}/"
		@files[name] = sum	

		# put file -> object
		put_files(name)
	
		# clean up file
		unlink(name)

		# get object -> file with checksum
		sum = get_file(name)

		# verify
		assert(sum == @files[name], "bad checksum")
		
	end

	def _test_many_small_objects	# _one_at_a_time
		
		create_files(SMALL_FILE, RANDOM_LENGTH, MANY_FILES).each do |l|
			name, sum = l.split
			@files[name] = sum	
		end
		
		# puts one at a time?
		put_files(@files.keys)
	
		# clean up to avoid wasting runtime space
		unlink(@files.keys)

		@files.each_key do |f|
			sum = get_file(f)
			assert(sum == @files[f], "bad checksum")
		end
		
	end

	def teardown
		FileUtils.rm_rf(@test_dir)
		delete_bucket(@test_bucket)
	end

	def one_medium_object
	end

	def one_large_object
	end

	def many_small_objects_at_once
	end

	def many_medium_objects
	end

	def many_large_objects
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
