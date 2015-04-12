#!/bin/bash

################################################################################
# Copyright (c) 2015 Genome Research Ltd.                                      
#                                                                               
# Author: Matthew Rahtz <matthew.rahtz@sanger.ac.uk>                                                
#                                                                               
# Permission is hereby granted, free of charge, to any person obtaining         
# a copy of this software and associated documentation files (the               
# "Software"), to deal in the Software without restriction, including           
# without limitation the rights to use, copy, modify, merge, publish,           
# distribute, sublicense, and/or sell copies of the Software, and to            
# permit persons to whom the Software is furnished to do so, subject to         
# the following conditions:                                                     
#                                                                               
# The above copyright notice and this permission notice shall be included       
# in all copies or substantial portions of the Software.                        
#                                                                               
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,               
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF            
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.        
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY          
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,          
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE             
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                        
################################################################################

readonly CFENGINE_MASTERFILES_DIR=/var/cfengine/inputs
# relative to CFENGINE_MASTERFILES_DIR
readonly LIBRARY_FILES=(def.cf lib/3.6/common.cf sanger/global_functions.cf)

function usage() {
    echo "Run a CFEngine bundle with arguments" >&2
    echo >&2
    echo "Usage: $0 [-v] [-f bundle.cf] <bundle to run> [arg 1] [arg 2] ..." >&2
    echo >&2
    echo "-v: run cf-agent with --verbose" >&2
    echo >&2
    echo "-f bundle.cf: use bundle.cf for source of bundle" >&2
    echo -n "If not specified, " >&2
    echo "look for the bundle in '$CFENGINE_MASTERFILES_DIR'" >&2
}

function clean_up() {
    # since we're running as root, we're going to be rather careful
    # about deleting things, rather than just "rm -rf $wrapper_pol_dir"
    if [[ $wrapper_pol_dir == "" ]]; then
        return
    fi
    if [[ -e "$wrapper_pol_dir/test.cf" ]]; then
        rm "$wrapper_pol_dir/test.cf"
    fi
    if [[ -e "$wrapper_pol_dir" ]]; then
        rmdir "$wrapper_pol_dir"
    fi
}
trap clean_up exit

function find_bundle_file() {
    local bundle=$1
    bundle_file=$(grep -E -R -l \
        "bundle agent $bundle\$|bundle agent $bundle\(" \
        "$CFENGINE_MASTERFILES_DIR"
    )
    echo "$bundle_file"
}

function prepare_wrapper_policy() {
    local bundle=$1
    local bundle_file=$2
    local bundle_args=$3

    library_inputs=""
    for library_file in "${LIBRARY_FILES[@]}"; do
        library_input="\"$CFENGINE_MASTERFILES_DIR/$library_file\""
        if [[ $library_inputs == "" ]]; then
            library_inputs="$library_input,"
        else
        library_inputs=$(printf "%s %s," \
            "$library_inputs" "$library_input"
        )
        fi
    done

    wrapper="body common control {
        inputs => {
            $library_inputs
            \"$bundle_file\",
        };
        bundlesequence => { \"test\" };
    }

    bundle agent test
    {
        methods:
            any::
                \"test\" usebundle => $bundle($bundle_args);
    }
    "

    echo "$wrapper"
}

function run_policy() {
    local verbose=$1
    local policy=$2
    local wrapper_pol_dir=$3

    cat > "$wrapper_pol_dir/test.cf" <<< "$policy"

    if $verbose; then
        cf-agent -Kvf "$wrapper_pol_dir/test.cf"
    else
        cf-agent -Kf "$wrapper_pol_dir/test.cf"
    fi
}

bundle_file=
bundle_args=''
verbose=false
while (( $# > 0 )); do
    case $1 in
        -h|--help)
            usage
            exit 1
            ;;
        -f|--file)
            bundle_file=$2
            # CFEngine takes non-absolute paths as relative to
            # /var/lib/cfengine3/inputs
            if ! grep -q '^/' <<< "$bundle_file"; then
                bundle_file="$(pwd)/$bundle_file"
            fi
            shift 2
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        *)
            if [[ $bundle == "" ]]; then
                bundle=$1
            elif [[ $bundle_args == "" ]]; then
                bundle_args="\"$1\""
            else
                bundle_args="$bundle_args, \"$1\""
            fi
            shift
            ;;
    esac
done

if [[ $bundle == "" ]]; then
    echo "Error: no bundle specified" >&2
    usage
    exit 1
fi
shift

if [[ $USER != root ]]; then
    echo "Error: must be run as root" >&2
    exit 1
fi

if [[ $bundle_file == "" ]]; then
    bundle_file=$(find_bundle_file "$bundle")
    if [[ $bundle_file == "" ]]; then
            echo "Error: unable to find file containing bundle '$bundle'" >&2
            exit 1
    fi
    echo "Bundle found in '$bundle_file'"
fi

wrapper_policy=$(prepare_wrapper_policy "$bundle" "$bundle_file" "$bundle_args")

echo "Running cf-agent..."
# CFEngine requires policy directory not be world-writeable
wrapper_pol_dir=$(mktemp --directory)
chmod 600 "$wrapper_pol_dir"
run_policy "$verbose" "$wrapper_policy" "$wrapper_pol_dir"
echo "Exit status was $?"
