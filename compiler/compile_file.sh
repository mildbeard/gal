#!/usr/bin/bash

function Compile2
{
    rm -f pygal/atomic/*.atomic
    rm -f pygal/python/*.py
    rm -f pygal/javascript/*.js
    rm -f jsgal/atomic/*.atomic
    rm -f jsgal/python/*.py
    rm -f jsgal/javascript/*.js
    rm -f $2
    rm -f $3
    rm -f $4
    echo "  gal_compiler.raku fallback $1 --> $2"
    rakudo ../gal_compiler.raku fallback "$1" "$2"
    echo "    gal_compiler.raku python $2 --> $3"
    rakudo ../gal_compiler.raku python "$2" "$3"
    echo "    gal_compiler.raku javascript $2 --> $4"
    rakudo ../gal_compiler.raku javascript "$2" "$4"
}

function Build2
{
    f1=src/$1.gal
    f2=atomic/$1.atomic
    f3=python/$1.py
    f4=javascript/$1.js

    if [ -s "$f2" ] && [ -s "$f4" ] && [ -s "$f3" ]
    then
        d1=`stat -c %Y "$f1"`
        d2=`stat -c %Y "$f2"`
        d3=`stat -c %Y "$f3"`
        d4=`stat -c %Y "$f4"`
        if [ $d1 -gt $d2 ] || [ $d1 -gt $d4 ] || [ $d1 -gt $d3 ]
        then
            Compile2 $f1 $f2 $f3 $f4
        #else
            #echo "   up to date '$f2' and '$f4'"
        fi
    else
        Compile2 $f1 $f2 $f3 $f4
    fi
}

Build2 $1
