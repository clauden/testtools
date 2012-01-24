#! /usr/bin/env ruby

require 'open4'
require 'fileutils'
require 'slop'


class SimpleTest 

	@@debug = nil
	@@assertions = 0
	@@failed_assertions = 0
	@@tests = 0
	@@failed_tests = 0
	@@no_teardown_on_fail = nil				# leave fixtures up if a test fails

	def SimpleTest.trace(s)
		puts s if @@debug
	end

	#
	# return status, stdout
	#
	def SimpleTest.run(cmd)
		SimpleTest.trace "RUN: #{cmd}"
		pid, stdin, stdout, stderr = Open4::popen4(cmd)
		ignored, status = Process::waitpid2 pid	
		raise "EXEC FAILED (#{status}): #{cmd}\n#{stderr.readlines.join('')}" if status.exitstatus != 0
		return stdout.readlines
	end

	def SimpleTest.assert(condition, note ="assertion failed")
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

	def SimpleTest.random_name
		name = "#{rand(RANDEXP).to_s(RANDBASE)}"
	end
	

	# instance methods
	def _setup
		SimpleTest.trace "setup"
		setup if respond_to? 'setup'

	end

	def _teardown
		if @@current_test_failed and not @@no_teardown_on_fail
			SimpleTest.trace "teardown"
			teardown if respond_to? 'teardown'
		end
	end


	def debug
		class_variable_get(:@@debug)
	end

	def debug=(d)
		SimpleTest.class_variable_set(:@@debug, d)
	end

	def trace(s)
		SimpleTest.trace(s)
	end

	def run(s)
		SimpleTest.run(s)
	end

	def no_teardown_on_fail
		class_variable_get(:@@no_teardown_on_fail)
	end

	def no_teardown_on_fail=(d)
		SimpleTest.class_variable_set(:@@no_teardown_on_fail, d)
	end

	def assert(condition, note)
		SimpleTest.assert(condition, note)
	end

	def main
		current_test = nil

		t = self
		t.methods.grep(/^test_/).each do |m|
			begin
				self._setup		# t.method(:setup).call
			rescue
				puts "setup failed"
				raise
			end

			begin
				@@current_test_failed = nil
				puts "Running #{m.to_s}"
				@@tests += 1
				current_test = m.to_s
				t.method(m).call
			rescue Object => x
				if @@debug
					puts "caught: #{x.inspect}"
					puts x.backtrace.join("\n")
				end
				@@current_test_failed = true
				@@failed_tests += 1
				puts "FAILED: #{current_test}"
			end
			begin
				_teardown		# t.method(:teardown).call 	
			rescue
				puts "teardown failed"
				raise
			end
			puts "#{@@assertions} assertions, #{@@failed_assertions} failed"
			puts "#{@@tests} tests, #{@@failed_tests} failed" end
		end
end
