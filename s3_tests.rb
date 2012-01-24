#! /usr/bin/env ruby

require 'open4'
require 'fileutils'
require 'slop'

S3CMD = 's3cmd'
TEST_DIR = './temp'

# s3cmd credentials, endpoints
BASHO_TEST_CONFIG = './basho-test.cfg'
SL_PROD_CONFIG = './silverlining.cfg'
S3_CONFIG = './amazon.cfg'

@@debug = true
@@assertions = 0
@@failed_assertions = 0
@@tests = 0
@@failed_tests = 0
@@s3cmd_opts = ''
@@debug = nil


def trace(s)
	puts s if @@debug
end

#
# return status, stdout
#
def run(cmd)
	trace "RUN: #{cmd}"
	pid, stdin, stdout, stderr = Open4::popen4(cmd)
	ignored, status = Process::waitpid2 pid	
	raise "EXEC FAILED (#{status}): #{cmd}\n#{stderr.readlines.join('')}" if status.exitstatus != 0
	return stdout.readlines
end

def assert(condition, note ="assertion failed")
	@@assertions += 1
	tf = nil
	exc = nil
	bt = nil

	begin
		tf = condition
	rescue Object => x
		exc = x.to_s
		bt = x.backtrace
	end
		
	if not tf
		@@failed_assertions += 1
		puts "ASSERTION FAILED: #{note}"
		puts exc if exc
		puts bt if bt
		raise note
	end
end

RANDBASE = 36
RANDEXP = RANDBASE ** 8

class Tests

	def random_name
		name = "#{rand(RANDEXP).to_s(RANDBASE)}"
	end
	
	def s3cmd
		"#{S3CMD} #{@@s3cmd_opts}"
	end

	#
	# create a bucket
	#
	def create_bucket(name)
		cmd = "#{s3cmd} mb s3://#{name}"
		run(cmd)	
	end

	#
	# delete a bucket
	#
	def delete_bucket(name)
		cmd = "#{s3cmd} ls s3://#{name}"
		objects = run(cmd)	
		objects.each do |l|
			f = l.split[3]
			cmd = "#{s3cmd} del #{f}"
			run(cmd)
		end
		sleep 4
		cmd = "#{s3cmd} rb s3://#{name}"
		run(cmd)	
	end

	def bucket_exists(name)
		cmd = "#{s3cmd} ls s3://#{name}"
		run(cmd)	
	end

	def object_exists(bucket, name)

		# this is wrong, ls s3://bucket/prefix should work.  
		# but it doesn't.
		cmd = "#{s3cmd} ls s3://#{bucket}"
		objects = run(cmd)	
		objects.each do |l|
			trace "LS RETURNS: #{l}"
			f = l.split[3]
			return true if f.match(name)
		end
		false
	end
	

	def _test_foo
		delete_bucket("sjy3jaik")
	end

	# put this file into a bucket
	def test_bucket_basics
		assert(bucket_exists(@test_bucket), "bucket doesnt exist")
		trace "bucket exists"
		cmd = "#{s3cmd} put #{__FILE__} s3://#{@test_bucket}"
		run(cmd)
		trace "cmd ran"
		assert(object_exists(@test_bucket, __FILE__), "object doesnt exist")
		trace "object exists"
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
		trace "setup"
		@files = {}

		@test_dir = "#{TEST_DIR}/#{random_name}"
		cmd = "mkdir -p #{@test_dir}"
		run(cmd)

		@test_bucket = random_name
		create_bucket(@test_bucket)
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
		trace "teardown"
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

	opts = Slop.new(:strict => true) do
		on :d, :debug, 'enable debug'
		banner "Usage: #{$0} [options] [test | prod | s3]" 		\
					 "\nWhere 'test' is basho test env, 'prod' is SL, 's3' is Amazon"
		on :h, :help, 'get help' do 
			puts help
			exit 2
		end
	end

	begin
		opts.parse!
	rescue Slop::InvalidOptionError => x
		puts x.to_s
		puts opts.help	
		exit 1
	end

	@@debug = opts[:debug] if opts[:debug] 

	case ARGV[0]
	when 'test'
		@@s3cmd_opts += " -c #{BASHO_TEST_CONFIG}"
	when 'prod'
		@@s3cmd_opts += " -c #{SL_PROD_CONFIG}"
	when 's3'
		@@s3cmd_opts += " -c #{S3_CONFIG}"
	when nil
		# use env default
	end	

	current_test = nil

	t = Tests.new
	t.methods.grep(/^test_/).each do |m|
		begin
			t.method(:setup).call
		rescue
			puts "setup failed"
			raise
		end

		begin
			puts "Running #{m.to_s}"
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
		begin
			t.method(:teardown).call 	
		rescue
			puts "teardown failed"
			raise
		end
	end
	
	puts "#{@@assertions} assertions, #{@@failed_assertions} failed"
	puts "#{@@tests} tests, #{@@failed_tests} failed" end
