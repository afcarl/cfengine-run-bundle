# cfengine-run-bundle

A little script to run a single CFEngine bundle with arguments for rapid
prototyping, inspired by [`cf-cmd`](http://blog.cf-learn.info/cf-cmd-a-command-line-tool-for-running-cfengi/).

(If your bundle doesn't take any arguments, you can just use
`cf-agent --bundlesequence <bundle>`.)

## Usage

* Customise the `CFENGINE_MASTERFILES_DIR` and `LIBRARY_FILES` variables
  to match your setup.
* Run with:
  ```
  $ sudo ./run_bundle.sh [options] <bundle to run> [arg 1] [arg 2] ...
  ```
  
  Options:
  * `-v`: run `cf-agent` with `--verbose`
  * `-s`: pass arguments as an slist rather than individually
  * `-f bundle.cf`: use `bundle.cf` for source of bundle
  
    If `-f` not specified, look for the bundle in `CFENGINE_MASTERFILES_DIR`
* `run_bundle.sh` will create a wrapper policy to run the bundle, and run it
  with `cf-agent`.
