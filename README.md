# gal

gal is short for general abstract language. It consists of a language compiler capable of translating gal programs into a variety of different target output languages. 

This is gal version 0.8.9, intended to be the last version that still requires the bootstrap compiler in order to function. 

The first release version will be gal 0.9.0 when the compiler can fully compile itself into multiple working languages. 

Version 1.0 will be when the gal compiler can cross compile itself through three successive target languages without introducing any differences. 

# goal

This will be openly released under the MIT license in hopes that people will create new language generators in gal, to translate gal programs into many new target languages. 

# installation

First obtain the gal source code and this readme file.

The setup script is intended to be run from inside the gal directory.

    $ cd your_local_path/gal

Take a look at the setup script so you know what you're executing. 

Note that the prototype gal compiler is written in Raku (formerly Perl 6), so that has to be installed. This is a temporary dependency slated for removal in version 1.0 - from then on, the gal compiler will be language agnostic. 

    $ sudo apt install -y rakudo
    $ alias gal='rakudo "your_local_path/gal/bootstrap_compiler.raku"'

Add that alias to a login script if you plan to continue running gal.

To test that it worked, try running the gal compiler with no arguments from any directory.

    $ gal
    Usage:
      gal [-x|--xecute] [-r|--raku] [-p|--python] [-j|--javascript] [-m|--mumps] [-c|--cee] [-g|--gal] [-v|--verbose] <file> <target>

# hello world

NOTE: The following examples still use the bootstrap compiler. The gal compiler will be used here soon.

One way to try out gal is to compile the Hello World application. It is included in the git repository, but it's not hard to type the code.

    $ cd samples
    $ cat Hello.gal
    main
    {
        writeline "Hello World";
    }

Since we know you definitely have Raku installed, let's compile and execute the program into Raku. 

    $ gal -r Hello.gal Hello.raku

    $ cat Hello.raku
    sub MAIN() {
        say "Hello World";
    }

    $ rakudo Hello.raku
    Hello World

The gal compiler can also produce Python 3. You need to have Python installed. To find out, try the following command.

    $ python --version

Let's try hello world in Python.

    $ gal -p Hello.gal Hello.py

    $ cat Hello.py
    if __name__ == '__main__':
        print("Hello World")

    $ python Hello.py
    Hello World

You can also produce Javascript. To run it on the server side, you could use Node.js. 

    $ node --version

Compiling and testing in Javascript is then straightforward.

    $ gal -j Hello.gal Hello.js

    $ cat Hello.js
    console.log("Hello World");

    $ node Hello.js
    Hello World

This project originally started in Mumps, and you can run programs in Yottadb if you have it installed.

    $ gal -m Hello.gal ~/.yottadb/r/Hello.m

    $ cat ~/.yottadb/r/Hello.m
    main ; main entry point
        write "Hello World",!
        quit

    $ yottadb -run Hello
    Hello World

# samples

You can find other gal programs in the samples directory. The compiler is still under development, having been rewritten many times. Nothing is guaranteed to work. When in doubt, try it in Raku first. 

	$ cat Todo.gal
	main
	{
	    list Todo "Breakfast" "Lunch" "Dinner" "Bedtime";
	    string Item;
	    foreach Todo Item
	    {
	        writeline "- " Item;
	    }
	}

	$ gal -r -x Todo.gal Todo.raku
	- Breakfast
	- Lunch
	- Dinner
	- Bedtime

	$ cat Todo.raku
	sub MAIN() {
	    my @Todo = "Breakfast", "Lunch", "Dinner", "Bedtime";
	    my Str $Item;
	    for @Todo -> $Item {
	        say "- $Item";
	    }
	}
	

# project status

This is gal version 0.8.0

It contains a bootstrap gal compiler written in Raku, that can translate a gal program to Raku or to simplified gal.

It contains a gal compiler written in gal, in the compiler directory. This compiler mostly works but a lot of language elements still need to be implemented. 

A variety of gal dialects exist. There is simple gal containing the basic atomic language elements that must be implemented by a language generator. There is fallback gal, in which higher-level language elements are themselves implemented in simple gal. There is debug gal, which transforms a simple gal program into a debug compiled version. 

Version 0.8 introduces a gal debugger written in gal. This is written but not debugged yet. It contains the debug gal dialect and the Context class that serves as both a process stack frame and a debug console. 

In version 0.9 the gal compiler will be able to compile itself correctly. This consists of building out atomic language elements in Javascript and Python. The bootstrap compiler already generates Raku output. 

In version 1.0 the gal compiler will be able to compile itself into all dialects of gal, running consisently in Raku, Python and Javascript. 

# language

The most important thing about the gal language syntax is that it is designed to be translated into any programming language. For that reason, the syntax itself has been greatly simplified without losing expressiveness. The simple syntax makes translation easy. 

Though simple, the gal language syntax is highly expressive and easily extended. To create a new output language generator, just add a generator method to each atomic language element. 

## special characters

Everything is separated by whitespace. Only a few punctuation characters have meaning. For that reason, language element verbs can contain punctuation characters. The first word is a verb, which defines the meaning of all the remaining arguments. 

    method string Indent [string Input]
    {
        list Lines (split Input [line]);
        string Indented '';
        entity Line;
        foreach Lines Line
        {
            append Indented [indent] Line [line];
        }
        return Indented;
    }

The above method translates as follows into Raku:

method Indent(Str $Input)
{
    my @Lines = split("\n", $Input);
    my Str $Indented = "";
    my $Line;
    for @Lines -> $Line
    {
        $Indented ~= "    $Line\n";
    }
    return $Indented;
}

And in Python:

    def Indent(self, Input):
        Lines = Input.split("\n")
        Indented = ''
        Line = None
        for Line in Lines:
            Indented +=  + Line + "\n"
        return Indented

The colon and semicolon are used because they are easy to type. 

Other meaningful characters include three kinds of quote: 'apostrophes', "quotes" and \`backquotes\`. 

Four special pairs of surrounding punctuations include:

- parentheses around operations (+ X Y)
- brackets around blocks { += Y 10; } 
- square brackets around syntax constructs \[is :Parent_Class\]
- and angle brackets around keyvalue pairs &lt;Key "Value"&gt; 
 
The comma is sometimes used to indicate successive syntax elements, especially in formal argument list declarations. So this statement:
 
    writeline "First" [line] [tab] "second";

is identical to the following version:

    writeline "First" [line, tab] "second";

That's essentially the entire syntax of the language. 

## verb first syntax

All language elements are expressed in a simple verb-first syntax. After the verb, the remaining arguments are separated by whitespace. Arguments are usually positional, so their order has meaning. 

Often the first word isn't actually an English verb. But it is still considered a verb by the gal syntax. 

There are three types of named language element: statement, \(invocation\) and \[syntax\]. This verb-first syntax applies to all three. It does not apply to keyvalues, which are a key=value pair.

Statements end with a semicolon ';' or a block surrounded by curly braces.

    integer X 5;
    string Full_Name First_Name " " Middle_Initial ". " Last_Name;
    if (greater Y 10)
    {
        comment "Note in the following statement, the verb is an '=' sign.";
        = Y 10;
    }

Invocations are surrounded by parentheses. The verb comes after the opening '('. An invocation always returns a value. 

    (power X 2)

    if (or (string.eq Char '"')
           (string.eq Char "'")
           (string.eq Char '`'))
    {
        = Token (new :Quote_Token Document Position Char);
    }

Syntax constructs are surrounded by square brackets. The '[' is followed by the verb.

    method Append [entity Element]
    {
    	comment "In the following syntax element, the '.' is the verb.";
        list.append [. self Elements] Element;
    }

Successive pairs of syntax constructs can be separated by commas rather than being repeated. Consider the following example:

	method Add_Numbers [number X] [number Y]
	{
		return (+ X Y);
	}

The method argument list is not an invocation using parentheses. In gal it is expressed as a sequence of syntax constructs. This is cumbersome, so the comma can be used instead between them. The following is exactly equivalent.

	method Add_Numbers [number X, number Y]
	{
		return (+ X Y);
	}
    
There are only a few universal data types, though more can freely be added. 

 - classes come in two varieties, entity classes and symbol classes. A class name is preceded by a colon ':'. 
 - entity is a typical object having a class, methods and properties.
 - hash or dictionary is an unordered key=value collection.
 - list is an extendable zero-based array that grows dynamically as elements are appended to it.
 - string is a dead-simple string (it doesn't understand \r, \t or \n) but strings can be surrounded by "double quotes", 'single quotes' or \`backquotes\`. Multi-line strings are allowed in all three types. Syntax elements and appending are used instead of any string embedding syntax. 
 - number is a decimal number
 - integer is a whole number
 - flag is a true/false value

## name case rule

The gal compiler will be case agnostic. The rigid syntax of gal eliminates the need for reserved words or case conventions. 

However the bootstrap compiler is case sensitive, and allows a more ambiguous syntax. 

For that reason, the following case convention is used within the gal compiler code itself.

"Intrinsic" words are all lowercase. Any word defined by the syntax of the gal language is considered to be 'intrinsic' in this sense. This applies to all named language elements (statements, operations and syntaxes) as well as to keywords (void, false, null) found in the arguments.

"Extrinsic" words are title case or Pascal case with underscores between multiple words. This applies to Variable_Names, Method_Names, Class_Names and so on. 

The gal compiler is case agnostic. If you use the variable names X or x, it will consider them to be the same. You can expect the output code generator for your target language to apply a case convention that makes sense for that target language. 

## automated testing

The gal language doesn't specify every detail about how the language works. Certain details may vary among target language and code generators. It is a very good idea to write automated testing logic for that reason. 

# language elements

This list of language elements is very incomplete. Although gal has a very simple syntax, the number of language elements will continue to grow in the future as new language elements are added to output code generators. 

## statements

### uppercase statement names are void method calls
	Method Target First_Argument Second_Argument;

### assignment statements
	assign X 5;
	    = X 5;
	add X Y;
	    + X Y;
	increment X;
	    ++ X;
	decrement X;
	    -- X;
	append Names ", " First_Name " " Last_Name;

### class statements
    forward :Class_Defined_Later;
	class.property Size 0;
	class :Employee {
    	constructor Arg1 Arg2 { todo 'object initializations go here'; }
	}
	class :World {
		method void Hello {
			writeline "Hello World";
		}
	}
	property.list Members 'Alice' 'Bob' 'Cathy' 'Dave';
	property number Amount 2.2;
	method void Add_Record [entity Record] { todo; }
	class.method Lookup [string Name] { todo; }
	new First_Document :Document File_Name;
	new.entity Second_Document :Document File_Name;

### entity (object) statements
	propset Entity Balance 0;
	    property.assign Entity Property Value;
	    .= Entity Property Value;
	propset self Balance 0;
    	.= self Balance 0;
    	my= Balance 0;
	entity.new First_Document :Document File_Name;

### function statements
	main { writeline 'Hello'; }
	method Name Arg1 Arg2 { todo; }
	function flag Name Arg1 Arg2 { return false; }
	subroutine Name Arg1 Arg2 { return; }
	return;
	return true;
	return.if (less X 0) 0;
	function.async Callback { todo; }
	call Name_Of_Subroutine Arg1 Arg2;

### declaration statements
	list Members 'Alice' 'Bob' 'Cathy' 'Dave';
	list.copy Arguments [. self Arguments];
	string Title 'Unititled';
	string Member;
	entity Parent [. self Parent];
	string Name "Sharon";
	string.append Name " " Middle_Initial ". " Last_Name;
	integer Total 0;
	number X -0.1234;
	flag Exit false;
	variant Item;

### flow control statements
	list.foreach Members Member { writeline Member; }
	    foreach Members Member { writeline Member; }
	if (= X Y) { todo; }
	else.if (gt X Y) { todo; }	
	else { todo; }
	unless (!= X Y) { todo; }
	for.range Character 0 (length Text) { todo; }
	forever { todo; break; }
	break;
	breakif (gt X 10);
	continue;
	contif (lt x 5);

### input/output statements
	writeline 'Member: ' First ' ' Middle '. ' Last;
	file.readall Input_Text 'input.txt';
	file.dump Output_Text 'output.txt';

### http statements
	http.server Server_Name { todo; }
	http.get '/marco' { return (http.response 'polo'); }
	http.post '/upload' { todo; }
	http.delete '/user' { todo; }

### sql statements
    sql.execute `delete from table where column='value'`;

### comment statements
	todo "Fix the bug in the following code";
	comment "This is how you create a comment.";

### error statements
    log.message 'user not authenticated, returning login page';
    log.message 10 'user ' Username ' has been authenticated, returning index page';
    log.error "database error '" Error_Message "' received.";
    try { 
        file.dump 'hello.txt' 'hello'; 
    }
    catch Error_Message {
         error "Writing to file 'hello.txt', received '" Error_Message "'.";
    }
    raise "No Such Employee";
	raiseif (less X 0) "Negative Number";

### compiler statements
    language gal
    {
        statement.line your.statement.here
        {
            todo;
        }
        statement.block unless
        {
            argument Condition;
            gal 'if (not ' [i Condition] ')' [i Block];
            raku 'unless ' [i Condition, i Block];
        }
    }
    parser Mumps
    {
        element Commands
        {
            required Command;
            optional.repeating Tail
            {
                required Cs;
                required Command;
                mumps ' ' [i Command];
                gal ' ' [i Command];
            }
            mumps [i Command] [optional.repeating Tail];
            gal [i Command] [optional.repeating Tail];
        }
    }
    element.optional
    element.required.repeating
    element.optional.repeating
    element.required
    character
    optional
    optional.repeating
    required
    required.repeating
    okthen;
    forbidden
    either
    choice

## intrinsic functions
Intrinsic functions are part of the gal language, and have their own lowercase keyword. Extrinsic functions are written in gal, and their names begin with uppercase. 

### uppercase function names are value-returning method calls.
    (Method_Name Target Arg1 Arg2)

### operations
	(and X Y Z)
		(& X Y Z)
	(or X Y Z)
		(| X Y Z)
	(greater X Y)
		(gt X Y)
	(ge X Y)
	(less X Y)
		(lt X Y)
	(le X Y)
	(equal X Y)
		(= X Y)
	(not X)
		(! X)
	(add X Y Z)
		(+ X Y Z)
	(subtract X Y)
		(- X Y)
	(multiply X Y)
		(* X Y)
	(divide X Y)
		(/ X Y)

### string functions
    (string V1)
    (string.append ...)
        (append ...)
    (string.eq S1 S2)
    (string.ne S1 S2)
    (string.contains S1 S2)
        (contains S1 S2)
    (firstchar S1)
    (lastchar S1)
    (string.le S1 S2)
    (string.ge S1 S2)
    (string.lt S1 S2)
    (string.gt S1 S2)
    (lowercase S1)
        (lower S1)
    (uppercase S1)
        (upper S1)
    (middle S1 N2 N3)
    (string.isnull S1)
        (isnull S1)
    (string.notnull S1)
        (notnull S1)
    (string.split S1 S2)
        (split S1 S2)
    (string.length S1)
        (length S1)
    (string.substring S1 N2 N3)
        (substring S1 N2 N3)
	(middle String 1 1)
	(is.whitespace String)
    	(whitespace String)

### list functions
	(list.length Members)
	(list.pop Members)
	(list.get Members 0)
	(list.shift Members)
	(list.last Members)

### others
	(http.fetch '/marco')
	(Method :Target Arg1 Arg2)
	(new :Class Arg1 Arg2)
	(defined X)
	(whitespace Input_Text)
	(isa :Entity)
	(call Name_Of_Function Arg1 Arg2)

### sql functions
    (sql.query 'select * from table')
    (sql.escape User_Input)

## syntax

Syntax constructs in gal are surrounded by square brackets.

	[await (http.fetch '/marco')]
	[await (sql.query 'select * from table')]
	[property self Property]
		[. self Property]
	[entity Element]
	[integer Iterations]
	[string Name]
	[number Account_Balance]
	[flag Special_Mode]
	[variant Input]
	[is :Statement]
	[classname self]	

a method argument list is technically a series of syntax constructs.

	method void Add_Item [string Name] [integer Number] { todo; }

It's most common to use commas to consolidate multiple syntax constructs.

	method void Add_Item [string Name, integer Number] { todo; }
