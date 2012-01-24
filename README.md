Run some tests against an object store backend using s3cmd.  

Ended up inventing a simplistic Test::Unit thingy that fits just about right.  No good reason other than that I got tired of working around weird behaviors in the real frameworks.

Idea is to run the same set of tests against S3, a "test" deployment of the backend, and a "production" deployment.

```ruby
$ ruby st.rb s3
Running test_foo
0 assertions, 0 failed
1 tests, 0 failed
Running test_many_small_objects
ASSERTION FAILED: put_files: object doesnt exist
FAILED: test_many_small_objects
1 assertions, 1 failed
2 tests, 1 failed
```
Debug or verbose mode can help track down details of what failed when:

```
$ ruby st.rb --debug prod
setup
RUN: mkdir -p ./temp/xwp1gpae
RUN: s3cmd  -c ./basho-test.cfg mb s3://2qcv18l7
Running test_foo
RUN: s3cmd  -c ./basho-test.cfg mb s3://xyzzy
# and so on...
```

Note: you'll need to provide credentials and endpoints in the placeholder s3cmd configuration files, one for each of the S3/test/prod environments.  
