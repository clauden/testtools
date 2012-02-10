#! /usr/bin/env ruby

require 'open4'
require 'fileutils'
require 'slop'
require './simpletest'

S3CMD = 's3cmd'
MAKE_FILES_CMD = './tools/make_files.rb'
TEST_DIR = './temp'

# s3cmd credentials, endpoints
BASHO_TEST_CONFIG = './test.cfg'
SL_PROD_CONFIG = './production.cfg'
S3_CONFIG = './amazon.cfg'

# test parameters
SMALL_FILE_MAX_LENGTH = 1024 * 8
LARGE_FILE_MAX_LENGTH = SMALL_FILE_MAX_LENGTH * 10
RANDOM_LENGTH = true
MANY_FILES = 5
FEW_FILES = 1

# special stuff for generating random filenames
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

	#
	# This is wrong, ls s3://bucket/prefix should work.  
	# but it doesn't.
	# Needs to be fixed in backend.
	#
	def object_exists(bucket, name)
		cmd = "#{s3cmd} ls s3://#{bucket}"
		objects = run(cmd)	
		objects.each do |l|
			trace "LS RETURNS: #{l}"
			f = l.split[3].rpartition('/')[-1]
			trace "checking: #{f} against #{name}"
			return true if f.match(name)
		end
		false
	end
	
	def file_exists(name)
		File.exist? name
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
			assert(object_exists(bucket, f.rpartition('/')[-1]), "put_files: object doesnt exist")
		end
	end

	#
	# delete file
	# assert that it exists on entry
	#
	def unlink(names)
		names = [names] if not names.respond_to?('each')
		names.each do |f|
			assert(file_exists(f), "unlink: file not found")
			cmd = "rm #{f}"
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

		assert(object_exists(bucket, name), "get_file: object '#{name}' doesnt exist")

		cmd = "#{s3cmd} get s3://#{bucket}/#{name} #{path}"
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
		
		create_files(SMALL_FILE_MAX_LENGTH, RANDOM_LENGTH, MANY_FILES).each do |l|
			name, sum = l.split
			@files[name] = sum	
		end
		
		# puts one at a time?
		put_files(@files.keys)
	
		# clean up to avoid wasting runtime space
		unlink(@files.keys)

		@files.each_key do |f|
			sum = get_file(f.rpartition('/')[-1])
			assert(sum == @files[f], "bad checksum")
		end
		
	end

	def teardown
		trace "teardown"
		FileUtils.rm_rf(@test_dir)
		delete_bucket(@test_bucket)
	end

	#
	# unimplemented tests 
	#
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
		on :n, :noteardown, 'do not tear down on failure'
		on :d, :debug, 'enable debug'
		banner "Usage: #{$0} [options] test | prod | s3" 		\
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

	s3cmd_opts = ""
	p "before #{s3cmd_opts.inspect}"

	case ARGV[0]
	when 'test'
		s3cmd_opts += " -c #{BASHO_TEST_CONFIG}"
	when 'prod'
		s3cmd_opts += " -c #{SL_PROD_CONFIG}"
	when 's3'
		s3cmd_opts += " -c #{S3_CONFIG}"
	when nil
		puts "I prefer not to use your default s3cmd configuration."
		puts opts.help	
		exit 2
	end	

	p "after #{s3cmd_opts.inspect}"
	p @@s3cmd_opts
	@@s3cmd_opts += s3cmd_opts

	x = Tests.new
	x.debug = true # opts[:debug] if opts[:debug] 
	x.no_teardown_on_fail = opts[:noteardown] if opts[:noteardown] 
	x.main
end
