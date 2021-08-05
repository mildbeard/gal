#!/usr/bin/bash

function Compile
{
    echo "Simplifying $1 to $2"
    rakudo ../bootstrap_compiler.raku -g "$1" "$2"
    echo "Translating $2 to $3"
    rakudo ../bootstrap_compiler.raku -r "$2" "$3"
}

function Build
{
    f1="$1.gal"
    f2="$1.fallback"
    f3="$1.raku"
    if [ -f "$f2" ]
    then
        d1=`stat -c %Y "$f1"`
        d2=`stat -c %Y "$f2"`
        if [ $d1 -gt $d2 ]
        then
            Compile $f1 $f2 $f3
        else
            echo " skipping '$1'"
        fi
    else
        Compile $f1 $f2 $f3
    fi
    cat $f3 >> Compiler.raku
}

function Gal_Test
{
    rakudo Compiler.raku gal $1.gal $1.simple
    #echo 'Input:'
    #cat $1.gal
    #echo 'Output:'
    #cat $1.simple
    echo 'Output Diff:'
    diff $1.gal $1.simple
}

function Fallback_Test
{
    rm $1.simple
    rakudo Compiler.raku fallback $1.gal $1.simple
    echo "Fallback Version:"
    cat $1.simple
    #echo 'Output Diff:'
    #diff $1.gal $1.simple
}

function Debug_Test
{
    rm $1.simple
    rm $1.debug
    rakudo Compiler.raku fallback $1.gal $1.simple
    echo "Fallback Version:"
    cat $1.simple
    rakudo Compiler.raku debug $1.simple $1.debug
    echo "Debug Version:"
    cat $1.debug
}

function Fallback_Twice
{
    rm $1.simple
    rm $1.fallback
    rakudo Compiler.raku fallback $1.gal $1.fallback
    echo "Fallback Version:"
    cat $1.fallback
    rakudo Compiler.raku fallback $1.gal $1.simple
    echo "Simple Version:"
    cat $1.simple
    #echo 'Output Diff:'
    #diff $1.fallback $1.simple
}

function Python_Test
{
    rm $1.py
    rakudo Compiler.raku python $1.simple $1.py
    cat $1.py
}

function Javascript_Test
{
    rm $1.js
    rakudo Compiler.raku javascript $1.simple $1.js
    cat $1.js
}

function Mumps_Test
{
    rm $1.m
    rakudo Compiler.raku mumps $1.simple $1.m
    cat $1.m
}

echo 'use fatal;' > Compiler.raku
echo >> Compiler.raku

Build Debug
Build Token
Build Element
Build Language
Build Atomic
Build Fallback
Build Additions
Build Factory
Build Main

echo "Running Compiler.raku"

#Gal_Test ../samples/Hello
#Python_Test ../samples/Hello
#Javascript_Test ../samples/Hello
#Mumps_Test ../samples/Hello

#Gal_Test ../samples/Todo
#Python_Test ../samples/Todo
#Javascript_Test ../samples/Todo
#Mumps_Test ../samples/Todo
#Fallback_Test ../samples/Todo
#Debug_Test ../samples/Todo

# TODO: build out the mumps tests.

#Gal_Test Test
#Fallback_Test Test
#Python_Test Test

#Gal_Test Test_Unless
#Fallback_Test Test_Unless
#Fallback_Twice Test_Unless
#Python_Test Test_Unless
#Javascript_Test Test_Unless

#Gal_Test Token
#Fallback_Test Token
#Python_Test Token
#Gal_Test Language
#Fallback_Test Language
#Gal_Test Element
#Fallback_Test Element
#Gal_Test Atomic
#Fallback_Test Atomic
#Gal_Test Fallback
#Fallback_Test Fallback
#Gal_Test Additions
#Fallback_Test Additions
#Gal_Test Factory
#Fallback_Test Factory
#Gal_Test Main
#Fallback_Test Main
