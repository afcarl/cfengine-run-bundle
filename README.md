# cfengine-run-bundle

A little script to run a single CFEngine bundle with arguments for rapid
prototyping.

(If your bundle doesn't take any arguments, you can just use
`cf-agent --bundlesequence <bundle`>.)

## Usage

* Customise the `CFENGINE_MASTERFILES_DIR` and `LIBRARY_FILES` variables
  to match your setup.
* Run with:
  ```
  ./sudo run_bundle.sh [-v] <bundle to run> [arg 1] [arg 2] ..."
  ```
  (-v runs `cf-agent` with `--verbose`.)
* `run_bundle.sh` will figure out which file the bundle is in, create a wrapper
  policy to run the bundle, and run it with `cf-agent`.
