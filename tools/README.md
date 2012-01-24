Generate a bunch of randomly named files containing random data.  Useful for testing object stores and filesystems.

```ruby
$ ./make_files.rb --help
Usage: ./make_files.rb [options]
options:

    -d, --destdir       destination directory
    -n, --numfiles      number of files
    -z, --size          file size in 1kB blocks
    -r, --random        random file sizes
    -c, --constant      constant file sizes
    -h, --help          get help
```

A temp dir will be created under destdir.
If -c is specified, all files will be size blocks long.  Otherwise they will vary in length between 1 and size blocks, presumably in a uniform distribution.
