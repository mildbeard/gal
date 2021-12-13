#!/usr/bin/bash

function Compile2
{
    rm -f $2
    rm -f $3
    rm -f $4
    echo "  gal_compiler.js fallback $1 --> $2"
    node ../gal_compiler.js fallback "$1" "$2"
    echo "    gal_compiler.js python $2 --> $3"
    node ../gal_compiler.js python "$2" "$3"
    echo "    gal_compiler.js javascript $2 --> $4"
    node ../gal_compiler.js javascript "$2" "$4"
}

function Build2
{
    f1=src/$1.gal
    f2=jsgal/atomic/$1.atomic
    f3=jsgal/python/$1.py
    f4=jsgal/javascript/$1.js

    if [ -s "$f2" ] && [ -s "$f3" ] && [ -s "$f4" ]
    then
        d1=`stat -c %Y "$f1"`
        d2=`stat -c %Y "$f2"`
        d3=`stat -c %Y "$f3"`
        d4=`stat -c %Y "$f4"`
        if [ $d1 -gt $d2 ] || [ $d1 -gt $d3 ] || [ $d1 -gt $d4 ]
        then
            Compile2 $f1 $f2 $f3 $f4
        #else
        #    echo "   up to date '$f2'"
        fi
    else
        Compile2 $f1 $f2 $f3 $f4
    fi
}

Build2 $1
