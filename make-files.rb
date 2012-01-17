#!/usr/bin/env ruby

require "open4"
require "slop"

# create some random files for testing

BLOCKSIZE = 1024
RANDBASE = 36
RANDEXP = RANDBASE ** 8

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

	dest_dir = "."
	num_files = 10
	max_size = 100    # blocks
	policy = :random
	
	opts = Slop.parse do
		on :d, :destdir=, 'destination directory'
		on :n, :numfiles, 'number of files', num_files
		on :s, :size, 'file size in #{BLOCKSIZE/1024)kB blocks', max_size
		on :r, :random, 'random file sizes', optional: true # policy == :random
		on :c, :constant, 'constant file sizes', optional: true # policy == :constant
	end

	dest_dir = opts[:destdir]
	num_files = opts[:numfiles].to_i
	max_size = opts[:size].to_i
	policy = opts.random? || opts.constant?
	# policy = opts.random? ? :random : :constant

	p dest_dir 
	p num_files
	p max_size
	p policy 

	cmd = "mkdir -p #{dest_dir}"
	# run(cmd)    # assume it worked if it didn't raise
		
	(1..num_files).each do |i|
		size = policy == :constant ? max_size : rand(max_size)
		name = "#{rand(RANDEXP).to_s(RANDBASE)}.#{i}"
		puts name,size
	end


	# create_file("a", 1000)
end
