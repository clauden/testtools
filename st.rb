#)! /usr/bin/env ruby

require 'open4'
require 'fileutils'
require 'slop'
require './simpletest'

S3CMD = 's3cmd'
MAKE_FILES_CMD = './tools/make_files.rb'
TEST_DIR = './temp'

# s3cmd credentials, endpoints
BASHO_TEST_CONFIG = './basho-test.cfg'
SL_PROD_CONFIG = './production.cfg'
S3_CONFIG = './amazon.cfg'

# test parameters
SMALL_FILE_MAX_LENGTH = 1024 * 8
RANDOM_LENGTH = true
LARGE_NUM_FILES = 1

# special stuff 
RANDBASE = 36
RANDEXP = RANDBASE ** 8

@@s3cmd_opts = ""
@@make_files_cmd_opts = "-d #{TEST_DIR}"

class Tests < SimpleTest

	# 
	# tricky way to generate a pseudorandom filename
	#
	def random_name
		name = "#{rand(RANDEXP).to_s(RANDBASE)}"
	end
	
	#
	# invoke the cli with options
	#
	def s3cmd
		"#{S3CMD} #{@@s3cmd_opts}"
	end

	#
	# invoke the cli with options
	#
	def make_files_cmd
		"#{MAKE_FILES_CMD} #{@@make_files_cmd_opts}"
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
		# sleep 4
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
	
	def file_exists(name)
		File.exist? name
	end

	def test_foo
		create_bucket("xyzzy")
		delete_bucket("xyzzy")
	end

	# put this file into a bucket
	def _test_bucket_basics
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
	# returns name, checksum list
	#
	def create_files(maxsize, mode, num)
		cmd = "#{make_files_cmd} -n #{num} -z #{maxsize} #{mode ? '-r' : '-c'}"
		run(cmd)
	end

	#
	# put specifed files into bucket
	# assert that the objects exist on completion
	#
	def put_files(names, bucket = @test_bucket)
		names = [names] if not names.respond_to?('each')
		names.each do |f|
			cmd = "#{s3cmd} put #{f} s3://#{bucket}"
			run(cmd)
		end
		names.each do |f|
			assert(object_exists(bucket, f), "put_files: object doesnt exist")
		end
	end

	#
	# delete file
	# assert that it exists on entry
	#
	def unlink(names)
		names = [names] if not names.respond_to?('each')
		names.each do |f|
			cmd = "#{s3cmd} rm s3://#{bucket}/#{f}"
			run(cmd)
		end
	end

	#
	# get the named object
	# assert that object exists on entry and file exists on completion
	# returns file checksum
	#
	def get_file(name, bucket = @test_bucket)
		path = "#{TEST_DIR}/#{name}"

		assert(object_exists(bucket, name), "get_file: object doesnt exist")

		cmd = "#{s3cmd} get #{bucket}/#{name} #{path}"
		run(cmd)
		assert(file_exists("#{path}"), "get_file: file doesnt exist")

		cmd = "sum #{path}"
		sum_raw = run(cmd)
		sum = sum_raw[0].split[0]
		
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

	def test_many_small_objects	
		
		create_files(SMALL_FILE_MAX_LENGTH, RANDOM_LENGTH, LARGE_NUM_FILES).each do |l|
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

	x = Tests.new
	x.debug = opts[:debug] if opts[:debug] 
	x.main
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

	def _test_one_small_object_with_path_name
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

