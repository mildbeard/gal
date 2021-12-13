#!/usr/bin/bash

function Compile1
{
    # NOTE: Any change to the compiler in gal triggers a full rebuild.
    rm -f atomic/*.atomic
    rm -f python/*.py
    rm -f javascript/*.js
    rm -f $2
    rm -f $3
    echo "  bootstrap_compiler.raku Simplifying $1 to $2"
    rakudo ../bootstrap_compiler.raku -g "$1" "$2"
    echo "    bootstrap_compiler.raku Translating $2 to $3"
    rakudo ../bootstrap_compiler.raku -r "$2" "$3"
    echo Created $3
}

function Build1
{
    f1=src/$1.gal
    f2=fallback/$1.fallback
    f3=raku/$1.raku
    if [ -f "$f2" ]
    then
        d1=`stat -c %Y "$f1"`
        d2=`stat -c %Y "$f2"`
        if [ $d1 -gt $d2 ]
        then
            Compile1 $f1 $f2 $f3
        #else
            #echo "   skipping '$f2'"
        fi
    else
        Compile1 $f1 $f2 $f3
    fi
}

Build1 $1
