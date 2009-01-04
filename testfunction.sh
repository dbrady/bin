#!/bin/bash
# testfunction
function quit {
	exit
}  
function e {
	echo $1
	echo "GARG: $GARG" 
}
function args_are_implicit {
	echo "1: $1"
	echo "3: $3"
	echo '$*: ' $*
}
GARG=foo
e Hello
e World
args_are_implicit 'one' 'two' 'three' 'foo' 'bar' 'boo' 'squoo'
quit
echo foo 
