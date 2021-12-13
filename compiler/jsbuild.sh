#!/usr/bin/bash

function Compile5
{
    rm -f $2
    echo Gal Compiling $1 to $2
    rakudo Compiler.tojs fallback "$1" "$2"
    cat "$2"
    echo
    echo "-------------------------------------------------------------------------------"
    echo
    echo Gal Compiling $2 to $3
    rakudo Compiler.tojs javascript "$2" "$3"
    cat "$3"
}

function Build5
{
    f1=$1.gal
    f2=$1.simple
    f3=$1.js

    rm -f $f2
    rm -f $f3

    if [ -f Compiler.raku ]
    then
        cp Compiler.raku Compiler.tojs
    fi
    Compile5 $f1 $f2 $f3
}

echo Javascript Builds
##Build5 Language

Build5 Main
#Build5 Token
#Build5 Additions
#Build5 Fallback
#Build5 Factory
#Build5 Atomic
#Build5 Element
#Build5 Debug

#printf "\a"
echo Complete.