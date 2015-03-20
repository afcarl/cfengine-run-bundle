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
readonly LIBRARY_FILES=(def.cf lib/3.6/common.cf sanger/global_functions.cf)

function usage() {
    echo "Usage: $0 [-v] <bundle to run> <bundle arguments>" >&2
    echo "(-v runs cf-agent with --verbose)" >&2
}

# CFEngine requires policy directory not be world-writeable
wrapper_pol_dir=$(mktemp --directory)
chmod 600 "$wrapper_pol_dir"

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
    bundle_file=$(grep -E -R -l \
        "bundle agent $BUNDLE\$|bundle agent $BUNDLE\(" \
        "$CFENGINE_MASTERFILES_DIR"
    )
    if [[ $bundle_file == "" ]]; then
        echo "Error: unable to find file containing bundle '$BUNDLE'" >&2
        exit 1
    fi
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
    cat > "$wrapper_pol_dir/test.cf" <<< "$policy"

    if $verbose; then
        cf-agent -Kvf "$wrapper_pol_dir/test.cf"
    else
        cf-agent -Kf "$wrapper_pol_dir/test.cf"
    fi
}

if [[ $USER != root ]]; then
    echo "Error: must be run as root" >&2
    exit 1
fi

verbose=false
if [[ $1 == "-v" ]]; then
    verbose=true
    shift
fi

readonly BUNDLE=$1
if [[ $BUNDLE == "" ]]; then
    echo "Error: no bundle specified" >&2
    usage
    exit 1
fi
shift

bundle_args=''
while [[ $1 != "" ]]; do
    if [[ $bundle_args == "" ]]; then
        bundle_args="\"$1\""
    else
        bundle_args="$bundle_args, \"$1\""
    fi
    shift
done

bundle_file=$(find_bundle_file "$BUNDLE")
echo "Bundle found in '$bundle_file'"
wrapper_policy=$(prepare_wrapper_policy "$BUNDLE" "$bundle_file" "$bundle_args")
echo "Running cf-agent..."
run_policy "$verbose" "$wrapper_policy"
