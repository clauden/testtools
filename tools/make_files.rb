#! /usr/bin/env ruby

require "open4"
require "slop"

# create some random files for testing

BLOCKSIZE = 1024
RANDBASE = 36
RANDEXP = RANDBASE ** 8

DEFAULT_DEST_DIR = '.'
DEFAULT_NUM_FILES = 10
DEFAULT_MAX_SIZE = 100


#
# return status, stdout
#
def run(cmd)
	pid, stdin, stdout, stderr = Open4::popen4(cmd)
	ignored, status = Process::waitpid2 pid	
	raise "FAILED (#{status}): #{cmd}\n#{stderr.readlines.join('')}" if status != 0
	return status, stdout.readlines
end

# 
# generate a specified size file
# return sum
#
def create_file(path, blocks)
	cmd = "dd if=/dev/urandom of=#{path} bs=#{BLOCKSIZE} count=#{blocks}"
	run(cmd)

	cmd = "sum #{path}"
	status, sum_raw = run(cmd)
	sum = sum_raw[0].split[0]

	sum
end

#
# main begins
#
if __FILE__ == $0

	dest_dir = DEFAULT_DEST_DIR
	num_files = DEFAULT_NUM_FILES
	max_size = DEFAULT_MAX_SIZE 	# blocks
	policy = :random

	opts = Slop.new(:strict => true) do
		on :d, :destdir=, 'destination directory'
		on :n, :numfiles=, 'number of files'
		on :z, :size=, "file size in #{BLOCKSIZE/1024}kB blocks"
		on :r, :random, 'random file sizes'
		on :c, :constant, 'constant file sizes'

		banner "Usage: #{$0} [options]"
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
		# puts "Try --help for more info"
		exit 1
	end

	dest_dir = opts[:destdir] if opts[:destdir]
	num_files = opts[:numfiles].to_i if opts[:numfiles]
	max_size = opts[:size].to_i if opts[:size] 
	policy = opts.random? ? :random : :constant

	# puts "policy: #{policy}"
	# p dest_dir 
	# p num_files
	# p max_size
	# p policy 

	# cmd = "mkdir -p #{dest_dir}"
	# run(cmd)    # assume it worked if it didn't raise
		
	(1..num_files).each do |i|
		size = policy == :constant ? max_size : rand(max_size)
		name = "#{rand(RANDEXP).to_s(RANDBASE)}.#{i}"	# clever random filename
		checksum = create_file("#{dest_dir}/#{name}", size)
		puts "#{name}\t#{checksum}"
	end


end
