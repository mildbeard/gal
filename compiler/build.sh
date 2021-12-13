#!/usr/bin/bash

function Add1
{
    f1=src/$1.gal
    f2=fallback/$1.fallback
    f3=raku/$1.raku
    cat $f1 >> ../gal_compiler.gal
    cat $f2 >> ../gal_compiler.fallback
    cat $f3 >> ../gal_compiler.raku
}

function Add2
{
    f1=atomic/$1.atomic
    f2=python/$1.py
    f3=javascript/$1.js
    cat $f1 >> ../gal_compiler.atomic
    cat $f2 >> ../gal_compiler.py
    cat $f3 >> ../gal_compiler.js
}

function Add3
{
    f1=pygal/atomic/$1.atomic
    f2=pygal/python/$1.py
    f3=pygal/javascript/$1.js
    cat $f1 >> ../pygal_compiler.atomic
    cat $f2 >> ../pygal_compiler.py
    cat $f3 >> ../pygal_compiler.js
}

function Add4
{
    f1=jsgal/atomic/$1.atomic
    f2=jsgal/python/$1.py
    f3=jsgal/javascript/$1.js
    cat $f1 >> ../jsgal_compiler.atomic
    cat $f2 >> ../jsgal_compiler.py
    cat $f3 >> ../jsgal_compiler.js
}

function Initialize
{
    mkdir -p atomic
    mkdir -p python
    mkdir -p javascript
    mkdir -p fallback
    mkdir -p raku
    mkdir -p pygal/atomic
    mkdir -p pygal/python
    mkdir -p pygal/javascript
    mkdir -p jsgal/atomic
    mkdir -p jsgal/python
    mkdir -p jsgal/javascript
    echo 'Atomic_Statement_AM' > build_files.txt
    echo 'Atomic_Statement_LZ' >> build_files.txt
    echo 'Statement' >> build_files.txt
    echo 'Factory' >> build_files.txt
    echo 'Element' >> build_files.txt
    echo 'Atomic_Operation' >> build_files.txt
    echo 'Fallback' >> build_files.txt
    echo 'Expression' >> build_files.txt
    echo 'Additions' >> build_files.txt
    echo 'Atomic_Syntax' >> build_files.txt
    echo 'Token' >> build_files.txt
    echo 'Main' >> build_files.txt
    echo 'Language' >> build_files.txt
    #echo 'Debug' >> build_files.txt
    #echo 'Test' >> build_files.txt
    echo 'Goal' >> build_files.txt
    #echo 'Game' >> build_files.txt
}

function Raku_Builder
{
    echo "bootstrap_compiler.raku builds gal_compiler.raku"

    echo 'use fatal;'> ../gal_compiler.raku
    #echo 'use Data::Dump;'>> ../gal_compiler.raku
    echo >> ../gal_compiler.raku
    cat build_files.txt | parallel -u bootstrap_file.sh

    echo "Creating gal_compiler.raku"
    #Add1 Debug
    Add1 Token
    Add1 Element
    Add1 Statement
    Add1 Expression
    Add1 Language
    Add1 Atomic_Operation
    Add1 Atomic_Syntax
    Add1 Atomic_Statement_AM
    Add1 Atomic_Statement_LZ
    Add1 Fallback
    Add1 Additions
    Add1 Goal
    Add1 Factory
    Add1 Main
    #Add1 Game
}

function Python_Js_Builder
{
    echo "gal_compiler.raku creating gal_compiler.py and gal_compiler.js"

    cat build_files.txt | parallel -u compile_file.sh

    echo '#!/usr/bin/python'>../gal_compiler.py
    echo 'import sys'>>../gal_compiler.py
    echo 'import re'>>../gal_compiler.py
    echo 'import zdebug'>>../gal_compiler.py
    echo 'from gal import gal'>>../gal_compiler.py

    echo 'let gal = require("./gal.js");'>../gal_compiler.js
    echo 'let gal_file_reader = require("fs");'>>../gal_compiler.js
    echo 'class gal_class { constructor() { } }'>>../gal_compiler.js

    #Add2 Debug
    Add2 Token
    Add2 Element
    Add2 Statement
    Add2 Expression
    Add2 Language
    Add2 Atomic_Operation
    Add2 Atomic_Syntax
    Add2 Atomic_Statement_AM
    Add2 Atomic_Statement_LZ
    Add2 Fallback
    Add2 Additions
    Add2 Goal
    Add2 Factory
    Add2 Main
    #Add2 Game
}

function PyPy_Builder
{
    echo "gal_compiler.py creating pygal_compiler.py"

    cat build_files.txt | parallel -u py_compile_file.sh
    
    echo '#!/usr/bin/python'>../pygal_compiler.py
    echo 'import sys'>>../pygal_compiler.py
    echo 'import re'>>../pygal_compiler.py
    echo 'import zdebug'>>../pygal_compiler.py
    echo 'from gal import gal'>>../pygal_compiler.py

    echo 'let gal = require("./gal.js");'>../pygal_compiler.js
    echo 'let gal_file_reader = require("fs");'>>../pygal_compiler.js
    echo 'class gal_class { constructor() { } }'>>../pygal_compiler.js

    #Add3 Debug
    Add3 Token
    Add3 Element
    Add3 Statement
    Add3 Expression
    Add3 Language
    Add3 Atomic_Operation
    Add3 Atomic_Syntax
    Add3 Atomic_Statement_AM
    Add3 Atomic_Statement_LZ
    Add3 Fallback
    Add3 Additions
    Add3 Goal
    Add3 Factory
    Add3 Main
    #Add3 Game
}

function JsJs_Builder
{
    echo "gal_compiler.js creating jsgal_compiler.js"

    cat build_files.txt | parallel -u js_compile_file.sh
    
    echo '#!/usr/bin/python'>../jsgal_compiler.py
    echo 'import sys'>>../jsgal_compiler.py
    echo 'import re'>>../jsgal_compiler.py
    echo 'import zdebug'>>../jsgal_compiler.py
    echo 'from gal import gal'>>../jsgal_compiler.py

    echo 'let gal = require("./gal.js");'>../jsgal_compiler.js
    echo 'let gal_file_reader = require("fs");'>>../jsgal_compiler.js
    echo 'class gal_class { constructor() { } }'>>../jsgal_compiler.js

    #Add4 Debug
    Add4 Token
    Add4 Element
    Add4 Statement
    Add4 Expression
    Add4 Language
    Add4 Atomic_Operation
    Add4 Atomic_Syntax
    Add4 Atomic_Statement_AM
    Add4 Atomic_Statement_LZ
    Add4 Fallback
    Add4 Additions
    Add4 Goal
    Add4 Factory
    Add4 Main
    #Add4 Game
}

echo "Building gal compiler in two stages"
Initialize
rm -f ../gal_compiler.*
rm -f ../jsgal_compiler.*
rm -f ../pygal_compiler.*
Raku_Builder

#cat src/Test.gal
#echo "Running Raku gal compiler on Test.gal to Test.atomic"
#rakudo ../gal_compiler.raku fallback src/Test.gal atomic/Test.atomic
#cat atomic/Test.atomic
echo "-------------------------------------------------------------------------------"
Python_Js_Builder
echo "-------------------------------------------------------------------------------"
PyPy_Builder
echo "-------------------------------------------------------------------------------"
JsJs_Builder
echo "-------------------------------------------------------------------------------"
echo "diff ../gal_compiler.atomic ../pygal_compiler.atomic"
diff ../gal_compiler.atomic ../pygal_compiler.atomic
echo "diff ../gal_compiler.atomic ../jsgal_compiler.atomic"
diff ../gal_compiler.atomic ../jsgal_compiler.atomic
echo "diff ../gal_compiler.py ../pygal_compiler.py"
diff ../gal_compiler.py ../pygal_compiler.py
echo "diff ../gal_compiler.py ../jsgal_compiler.py"
diff ../gal_compiler.py ../jsgal_compiler.py
echo "diff ../gal_compiler.js ../pygal_compiler.js"
diff ../gal_compiler.js ../pygal_compiler.js
echo "diff ../gal_compiler.js ../jsgal_compiler.js"
diff ../gal_compiler.js ../jsgal_compiler.js
echo "$0 Complete"
printf "\a"
