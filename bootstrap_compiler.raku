#!/usr/bin/rakudo
# Copyright (c) 2021 mildbeard

sub Unquote($Quoted)
{
    my $fc = $Quoted.substr(0,1);
    return $Quoted unless $fc eq '"' or $fc eq "'" or $fc eq '`';
    my $Text = $Quoted.substr(1, *-1);
    $Text = $Text.subst("\\\\", "\\", :g);
    $Text = $Text.subst("\\\"", "\"", :g);
    $Text = $Text.subst("\\\.", "\.", :g);
    $Text = $Text.subst("\\\$", "\$", :g);
    $Text = $Text.subst("\\\{", "\{", :g);
    #$Text = $Text.subst("\\\_", "\_", :g);
    $Text = $Text.subst("\\\}", "\}", :g);
    $Text = $Text.subst("\\\(", "\(", :g);
    $Text = $Text.subst("\\\)", "\)", :g);
    $Text = $Text.subst("\\\[", "\[", :g);
    $Text = $Text.subst("\\\]", "\]", :g);
    $Text = $Text.subst("\\n", "\n", :g);
    return $Text;
}

sub Enquote($Unquoted)
{
    if !($Unquoted.contains('"'))
    {
        return '"' ~ $Unquoted ~ '"';
    }
    elsif !($Unquoted.contains("'"))
    {
        return "'" ~ $Unquoted ~ "'";
    }
    elsif !($Unquoted.contains('`'))
    {
        return '`' ~ $Unquoted ~ '`';
    }
    else
    {
        return '"' ~ $Unquoted.subst('"', '\"', :g) ~ '"';
    }
}

sub ClassName($Text)
{
    my $Return;
    if $Text eq ':class' || $Text eq ':group'
    {
        $Return = $Text;
    }
    elsif substr($Text,0,1) eq ':'
    {
        $Return = substr($Text,1);
    }
    else
    {
        $Return = $Text;
    }
    $Return = $Return.subst(':', '_', :g);
    #say "ClassName $Text returns $Return";
    return $Return;
}

class Document {...}
class Token {...}
class Parser {...}

class Element 
{
    has $.Document;
    has Int $.StartPos;
    has Int $.EndPos;
    has Str $.Text is rw = '';

    has Int $.Position is rw;
    has Str %.Errors;
    has @.Elements is rw;
    has @.Parse_Context;
    has @.Containment;

    has $.Usage is rw = 'initial';
    has $.DataType is rw = '';
    has Str $.Name is rw;
    has $.Key is rw;
    has @.Tokens is rw;
    has Element @.Components is rw;
    has Element @.Arguments is rw;
    has Element $.Parent is rw;
    has %.ElementTypes is rw;
    has Int $.Deferral = 0;

    has Str $.Gal is rw;
    has Str $.Gal_Definition is rw;
    has Str $.Raku is rw;
    has Int $.Raku_Precedence = 999;
    has Str $.Python is rw;
    has Str $.Javascript is rw;
    has Str $.Mumps is rw;
    has Str $.C is rw;
    has $.Group is rw;
    method IsExpression() { return False; }
    method IsStatement() { return False; }
    method IsBlock() { return False; }
    method Lookup($Name)
    {
        return False unless $.Parent;
        return $.Parent.Lookup($Name);
    }
    method GetText() 
    {
        #say "Get Text $.^name";
        return '' unless $.Text;
        return $.Text;
    }
    method AddName($Name) { }
    method AddType($Name, $Type)
    {
        die "Parent Required for AddType" unless $.Parent;
        return $.Parent.AddType($Name, $Type);
    }
    method AddArgument(Element $Argument)
    {
        push @!Arguments: $Argument;
    }
    method After(Element $Predecessor)
    {
        my $Deferral = $Predecessor.Deferral + 1;
        my $Changed = ($Deferral > $.Deferral);
        $.Deferral = $Deferral if $Changed;
    }
    method Gal_Generate()
    {
        say "$.^name does not support Gal_Generate.";
        # TODO: this element delegates to the compiled document.
    }
    method Gal_Parse() { }
    method Attributes() { }
    method Prepare() { }
    method Structure() { }
    method Express()
    {
        my $Start = self.StartPos // '?start';
        my $End = self.EndPos // '?end';
        my $ClassName = self.^name // '?name';
        my $Name = $.Name // '';
        if defined($.Text) && $.Text gt ''
        {
            my $Text = $.Text;
            $Text = Enquote($.Text) if $Text.trim() ne $Text;
            $Name = "$Name $Text";
        }
        my $Components = "";
        my $Component;
        for @.Components -> $Component
        {
            my $CStart = $Component.StartPos;
            my $CEnd = $Component.EndPos;
            my $CClass = $Component.^name;
            my $CText = $Component.Text;
            $CText = Enquote($CText) if $CText.trim() ne $CText;
            $Components ~= " ($CStart-$CEnd $CClass) $CText ";
        }
        my $Arguments = "";
        for @.Arguments -> $Component
        {
            my $CStart = $Component.StartPos;
            my $CEnd = $Component.EndPos;
            my $CClass = $Component.^name;
            my $CText = $Component.Text;
            $CText = Enquote($CText) if $CText.trim() ne $CText;
            $Arguments ~= ", $CStart-$CEnd $CClass $CText ";
        }
        return "$Start-$End: $ClassName $Name $Components $Arguments";
    }
    method BuildComponents()
    {
        @.Components = @.Components.sort: { $^a.StartPos cmp $^b.StartPos };
        for @.Components -> $Component
        {
            $Component.Parent = self;
        }
    }

    method Raku_Datatype($GalType)
    {
        if $GalType eq 'string' { return 'Str'; }
        if $GalType eq 'number' { return 'Real'; }
        if $GalType eq 'integer' { return 'Int'; }
        if $GalType eq 'flag' { return 'Bool'; }
        if $GalType.substr(0,1) eq ':' 
        {
            return ClassName($GalType);
        }
        return '';
    }
    method Python_Datatype($GalType)
    {
        if $GalType eq 'string' { return 'str'; }
        if $GalType eq 'number' { return 'real'; }
        if $GalType eq 'integer' { return 'int'; }
        if $GalType eq 'flag' { return 'bool'; }
        if $GalType.substr(0,1) eq ':' 
        {
            return ClassName($GalType);
        }
        return '';
    }
    method Raku_Generate()
    {
        #say 'Default Element Raku_Generate of ', self.^name;
        self.Gal_Generate();
        my Str $Input = $.Text;
        my Str $Gal = $.Gal // '';
        if $Gal eq '' or $Gal eq $Input
        {
            die "Raku_Generate not implemented by '" ~ self.^name ~ "'\.";
        }
        $.Text = $.Gal;
        #say 'Tokenizing: ', $.Text;
        self.Tokenize();
        #self.Dump(True);
        self.Parse();
        self.Structure();
        self.Prepare();
        self.Attributes();
        #self.Dump();
        return;
        my Str $Raku_Code = "";
        my $Element;
        for @.Elements -> $Element
        {
            $Raku_Code ~= $Element.Raku ~ "\n";
        }
        $.Raku = $Raku_Code;
    }
    
    method Tokenize
    {
        #say "Tokenize...";
        Parser.Tokenize(self);
        #say "Done Tokenizing";
    }
    method Parse
    {
        #say "Parse...";
        Parser.Parse(self);
        #say "Done parsing.";
    }
    method FixTokens()
    {
        #say "Fixing Tokens";
        my $Token;
        my @Tokens;
        for @.Tokens -> $Token
        {
            next if ($Token.Mode eq 'Space');
            @Tokens.push: $Token;
        }
        @.Tokens = @Tokens;
    }
    method PushContext($Element)
    {
        #say "Push Context $Element";
        @.Parse_Context.push: $Element;
    }
    method PopContext()
    {
        my $Element = @.Parse_Context.pop;
        #say "Pop Context $Element";
        return $Element;
    }
    method GetContext()
    {
        my $Count = @.Parse_Context.elems;
        my $Element;
        if $Count < 1
        {
            $Element = @.Elements[0];
        }
        else
        {
            $Element = @.Parse_Context[*-1];
        }
        #say "Get Context $Element";
        return $Element;
    }
    method Advance()
    {
        die "Advance beyond End" if @!Elements.elems <= $.Position;
        %!Errors<$.Position>:delete;
        $.Position = $.Position + 1;
    }
    method Reset(Str $Position)
    {
        $.Position = $Position;
    }
    method Position()
    {
        return $.Position;
    }
    method Error(Str $Message, Int $Position=$.Position)
    {
        %!Errors<$Position> ~= $Message;
        my $Substring = '';
        my $Window = 10;
        my $Tnum = $Position - $Window;
        $Tnum = 0 if $Tnum < 0;
        say "Message: $Message";
        for $Position-$Window..$Position-1 -> $Tnum
        {
            $Substring ~= $.Tokens[$Tnum].Text ~ ' ';
        }
        $Substring ~= '<*' ~ $.Tokens[$Position].Text ~ '*>';
        for $Position+1..$Position+$Window -> $Tnum
        {
            $Substring ~= ' ' ~ $.Tokens[$Tnum].Text;
        }
        say "Document Error: $Message at $Position\n$Substring";
    }
    method Length()
    {
        return @.Tokens.elems;
    }
    method AddToken(Str $Text, Str $Mode, Int $Line, Int $Offset)
    {
        #say "Adding new token $Mode $Text line $Line offset $Offset";
        my $Length = @.Tokens.elems;
        my $Token = Token.new(Mode=>$Mode, Text=>$Text, Position=>$Length, Document=>self, Line=>$Line, Offset=>$Offset);
        @!Tokens.push: $Token;
        #say "Added new token $Mode $Text line $Line offset $Offset";
    }
    
    method AddElement($Element)
    {
        #say "ADDING ELEMENT ", $Element.Express();
        @.Elements.push: $Element;

        my $Start = $Element.StartPos;
        my $End = $Element.EndPos;
        my $Index = @.Containment.elems;
        #say "Supersede $Start-$End";
        while ($Index--)
        {
            my $Component = @.Containment[$Index];
            my $CStart = $Component.StartPos;
            my $CEnd = $Component.EndPos;
            if ($CStart <= $End && $CEnd >= $Start)
            {
                #say "$Start - $End supersedes $CStart - $CEnd";
                #list.splice [. self Containment] Index 1;
                @.Containment.splice($Index, 1);
                $Element.Components.push($Component);
            }
        }
        @.Containment.push: $Element;
        $Element.BuildComponents();
    }

    method AppendToken(Str $Char)
    {
        my $Token = @!Tokens[*-1];
        $Token.Append($Char);
    }

    method Dump($Tokens=False)
    {
        say "Dumping $Tokens";
        my $Token;
        if $Tokens
        {
            say "Tokens";
            for @.Tokens -> $Token
            {
                my $Position = $Token.Position;
                my $Text = $Token.Text;
                my $Mode = $Token.Mode;
                say "$Position [$Text] $Mode";
            }
        }
        say '';
        say 'Elements';
        my $Element;
        my $Count = -1;
        for @.Elements -> $Element
        {
            $Count++;
            unless ($Element ~~ Element)
            {
                say "Unknown element $Element";
                next;
            }
            say $Count, " ", $Element.Express();
        }
        my $ContextOutput = "";
        my $Context;
        $Count = 0;
        for @.Parse_Context -> $Context
        {
            my $Express = $Context.Express();
            $ContextOutput ~= "$Count $Express\n";
            $Count++;
        }
        if $ContextOutput gt ''
        {
            say "\nContext\n$ContextOutput";
        }
    }

    method Indent($Body, $Tab="    ")
    {
        my $Return = "";
        my $Line;
        for $Body.lines() -> $Line
        {
            $Return ~= "$Tab$Line\n";
        }
        return $Return;
    }
}

class Document is Element
{
    # Document.new(FileName=>"test.gal");
    has $.FileName;

    has @.ToGenerate;
    has %.ClassNames;
    has %.Groups;

    has @.Elements is rw;
    has Str %.Errors;

    method Read()
    {
        my $FileName = $.FileName;
        #say "Reading $FileName";
        my $FileHandle = open($FileName, :r);
        $.Text = $FileHandle.slurp();
        $FileHandle.close();
    }
    method Say()
    {
        my $FileHandle = open $.FileName, :w;
        $FileHandle.print($.Text);
        $FileHandle.close();
    }
    method Sort()
    {
        @.Elements.sort: 
        {
            say "(", $^a.StartPos, ":", $^a.EndPos, ") ? (", $^b.StartPos, ":", $^b.EndPos, ")";
            my $Cmp = $^a.EndPos cmp $^b.EndPos;
            return $Cmp unless $Cmp == Order::Same;
            say "hm";
            return $^b.StartPos cmp $^a.StartPos;
        };
        
    }
    method Error_Report()
    {
        # TODO: formatted code output with errors.
        my $First = 1;
        my $Token;
        for @.Tokens -> $Token
        {
            my $Position = $Token.Position;
            next unless %.Errors{$Position}:exists;
            if $First {
                say "\nErrors";
                $First = 0;
            }
            my $Error =  %.Errors{$Position};
            my $Text = $Token.Text;
            say "$Position [$Text] $Error";
        }
    }
    method Attributes()
    {
        my $Statement;
        for @.Elements -> $Statement
        {
            # add the components to the canonical group.
            $.AddStatement($Statement);
        }
    }
    method AddStatement($Statement)
    {
        $Statement.Group = self;
        my $Name = $Statement.ClassName.Text;
        CATCH {
            default {
                return;
            }
        }
        unless ($Name ~~ /^:/)
        {
            $Name = ':' ~ $Name;
        }
        if (defined %.ClassNames{$Name})
        {
            #say "        $.Name ", $.ClassName.Text, " merges $Name";
            my $CanonicalClass = %.ClassNames{$Name};
            $CanonicalClass.MergeClass($Statement);
        }
        else
        {
            #say "        $.Name ", $.ClassName.Text, " adds $Name";
            %.ClassNames{$Name} = $Statement;
            @.ToGenerate.push($Statement);
        }
    }
    method Gal_Generate()
    {
        my $GalCode = "";
        my $Statement;
        for @.Containment -> $Statement
        {
            $Statement.Gal_Generate();
            $GalCode = $GalCode ~ $Statement.Gal ~ "\n";
        }
        $.Gal = $GalCode;
    }
    method Raku_Generate()
    {
        #say "Document.Raku_Generate called";
        my $ClassNameRaku = $.ClassName.Raku;
        CATCH {
            default {
                $ClassNameRaku = '<ERROR UNDEFINED NAME>';
            }
        }
        my $RakuCode = "$.RakuStatement $ClassNameRaku;\n\n";
        # Raku group block code is not indented
        my $Statement;
        for @.ToGenerate -> $Statement
        {
            my $StatementCode = $Statement.Raku;
            # TODO: raiseunless
            die "Unknown Statement Raku in Group: $Statement" unless defined $StatementCode;
            $RakuCode ~= "$StatementCode\n\n";
        }
        $.Raku = $RakuCode;
        #say "Document.Raku_Generate finished";
    }
}


class Extended is Element
{ 
    # special <...> syntax for future use
    method IsExpression() { return True; }
    method Attributes()
    {
        # TODO: get the name of the extended element.
    }
}

class Named_Element is Element
{
    our %.Classes;
    our $.Nonkeyword;

    method AddName($name)
    {
        #say "Add Name $name to ", self.^name;
        my $OldName = self.Name // '';
        unless $OldName gt ''
        {
            $.Name = $name;
            #say self.^name, " assigned name to ", $name, ": ", self.Express();
        }
    }

    method Classify($name, $document, $start, $end) 
    {
        unless defined($name)
        {
            die "$.^name Classify \$name undefined - did you do () or [] or something??";
        }
        my $First = substr($name, 0, 1);
        #say "$.^name Classifying '$name' first char $First $start-$end";
        my ($Class, $Element);
        my $Extrinsic = False;
        if 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_1234567890:'.contains($First)
        {
            $Class = $.Nonkeyword;
            $Extrinsic = True;
        }
        else
        {
            unless %.Classes{$name}:exists
            {
                my $Token_Num;
                my $Token_Text = '';
                for ($start..$end) -> $Token_Num {
                    try
                    {
                        $Token_Text ~= $document.Tokens[$Token_Num].Text;
                    }
                }
                die "ERROR Named_Element Classify. Unknown $.^name '$name' at $start-$end '$Token_Text'";
            }
            $Class = %.Classes{$name};
        }
        #say "Creating New name $name, $document, start $start - end $end";
        $Element = $Class.new(Name => $name, Document => $document, StartPos => $start, EndPos => $end);
        # TODO: if $Extrinsic { ? }
        #say "Classifying '$name' as $Class, returns $Element";
        return $Element;
    }

    method BuildComponents()
    {
        @.Components = @.Components.sort: { $^a.StartPos cmp $^b.StartPos };
        my $First = True;
        my $Component;
        for @.Components -> $Component
        {
            $Component.Parent = self;
            if $Component.IsExpression()
            {
                if $First
                {
                    $First = False;
                    $Component.Usage = 'keyword';
                }
                else
                {
                    @.Arguments.push: $Component;
                    $Component.Usage = 'value' if $Component.Usage eq 'initial';
                }
            }
        }
    }
}

class Stmt_Context is Named_Element { }

class Punct_Element is Element 
{
    has $.Usage is rw = 'initial';
    method Gal_Generate() { }
    method Raku_Generate() { }
    method Python_Generate() { }
    method Mumps_Generate() { }
    method Javascript_Generate() { }
    method C_Generate() { }
}

class Statement_Invocation {...}
class Statement_Add {...}
class Statement_Alias {...}
class Statement_Append {...}
class Statement_Argument {...}
class Statement_Assign {...}
class Statement_Break {...}
class Statement_Breakif {...}
class Statement_Call {...}
class Statement_Catch {...}
class Statement_Class {...}
class Statement_Classprop {...}
class Statement_Classpropset {...}
class Statement_Comment {...}
class Statement_Constant {...}
class Statement_Constructor {...}
class Statement_Contif {...}
class Statement_Continue {...}
class Statement_Debug {...}
class Statement_Debug_Stack {...}
class Statement_Debug_Variable {...}
class Statement_Decrement {...}
class Statement_Definition {...}
class Statement_Hash_Assign {...}
class Statement_Hash_Delete {...}
class Statement_Hash_Foreach {...}
class Statement_Hash {...}
class Statement_Else {...}
class Statement_ElseIf {...}
class Statement_Entities {...}
class Statement_Entity {...}
class Statement_Entity_New {...}
class Statement_Fallback {...}
class Statement_Flag {...}
class Statement_File_Dump {...}
class Statement_File_Slurp {...}
class Statement_For_Range {...}
class Statement_Foreach {...}
class Statement_Foreachline {...}
class Statement_Forgive {...}
class Statement_Forward {...}
class Statement_Gal {...}
class Statement_Goal {...}
class Statement_Group {...}
class Statement_Handle {...}
class Statement_Http_Get {...}
class Statement_I {...}
class Statement_I_Equals {...}
class Statement_If {...}
class Statement_Increment {...}
class Statement_Indirect {...}
class Statement_Index {...}
class Statement_Interface {...}
class Statement_Integer {...}
class Statement_Integers {...}
class Statement_Iterate {...}
class Statement_Javascript {...}
class Statement_Know {...}
class Statement_Language {...}
class Statement_License {...}
class Statement_List {...}
class Statement_List_Append {...}
class Statement_List_Copy {...}
class Statement_List_Splice {...}
class Statement_Log_Message {...}
class Statement_Main {...}
class Statement_Method {...}
class Statement_Module {...}
class Statement_Mumps {...}
class Statement_New {...}
class Statement_Number {...}
class Statement_Operation {...}
class Statement_Optional {...}
class Statement_Property {...}
class Statement_Proplist {...}
class Statement_Propset {...}
class Statement_Python {...}
class Statement_Raise {...}
class Statement_Replace {...}
class Statement_Return {...}
class Statement_Returnif {...}
class Statement_Say {...}
class Statement_Sort {...}
class Statement_Spell {...}
class Statement_Statement {...}
class Statement_String {...}
class Statement_Symbol {...}
class Statement_Syntax {...}
class Statement_Todo {...}
class Statement_Try {...}
class Statement_Unless {...}
class Statement_Variant {...}
class Statement_Verb {...}
class Statement_While {...}

class Function_Invocation {...}

class Function_Add {...}
class Function_And {...}
class Function_Append {...}
class Function_Classpropget {...}
class Function_Contains {...}
class Function_Defined {...}
class Function_Dict_Get {...}
class Function_Divide {...}
class Function_Dot {...}
class Function_Enquote {...}
class Function_Entity {...}
class Function_Equal {...}
class Function_Exp {...}
class Function_Firstchar {...}
class Function_Flag {...}
class Function_Get {...}
class Function_Greater {...}
class Function_GreaterEqual {...}
class Function_I {...}
class Function_Indirect {...}
class Function_Integer {...}
class Function_Isa {...}
class Function_Isnull {...}
class Function_Keyexists {...}
class Function_Lastchar {...}
class Function_Less {...}
class Function_LessEqual {...}
class Function_List_First {...}
class Function_List_Get {...}
class Function_List_Last {...}
class Function_List_Length {...}
class Function_List_Pop {...}
class Function_List_Shift {...}
class Function_Log {...}
class Function_Lowercase {...}
class Function_Middle {...}
class Function_Modulo {...}
class Function_Multiply {...}
class Function_New {...}
class Function_Not {...}
class Function_NotEqual {...}
class Function_NotNull {...}
class Function_Number {...}
class Function_Or {...}
class Function_Power {...}
class Function_Propget {...}
class Function_Split {...}
class Function_String {...}
class Function_StringEqual {...}
class Function_StringGreater {...}
class Function_StringGreaterEqual {...}
class Function_Stringlength {...}
class Function_StringLess {...}
class Function_StringLessEqual {...}
class Function_StringNotEqual {...}
class Function_Substring {...}
class Function_Subtract {...}
class Function_Uppercase {...}
class Function_Variant {...}
class Function_Whitespace {...}
#class Function_~ {...}

class Syntax_Backslash {...}
class Syntax_Classname {...}
class Syntax_Classprop {...}
class Syntax_Class_Self {...}
class Syntax_Dot {...}
class Syntax_Embed {...}
class Syntax_Entity {...}
class Syntax_False {...}
class Syntax_Flag {...}
class Syntax_Hash {...}
class Syntax_I {...}
class Syntax_Indent {...}
class Syntax_Integer {...}
class Syntax_Is {...}
class Syntax_Key {...}
class Syntax_Line {...}
class Syntax_List {...}
class Syntax_Node {...}
class Syntax_Null {...}
class Syntax_Number {...}
class Syntax_Self {...}
class Syntax_String {...}
class Syntax_True {...}
class Syntax_Variant {...}
#class Syntax_~ {...}

class Quote_Single {...}
class Quote_Double {...}
class Quote_Backquote {...}
class Quote_European {...}

class Quote is Punct_Element
{
    has Str $.Quote is rw;
    has $.DataType is rw = 'string';
    method IsExpression() { return True; }
    method Gal_Parse()
    {
        my $Quote = Quote.Classify($.Text, $.Document, $.StartPos, $.EndPos);
        #say "Quote $.Text Classified: ", $Quote.Express();
        $.Document.AddElement($Quote);
        my $Context = $.Document.GetContext();
        my $Text = $.Text;
        $Context.AddName($Text);
    }
    method Classify($Text, $Document, $Start, $End)
    {
        #say "Classifying '$Text' $Start - $End";
        my $Char = substr($Text, 0, 1);
        if $Char eq '"'
        {
            return Quote_Double.new(Text => $Text, Document => $Document, StartPos => $Start, EndPos => $End);
        }
        if $Char eq "'"
        {
            return Quote_Single.new(Text => $Text, Document => $Document, StartPos => $Start, EndPos => $End);
        }
        if $Char eq 'Statement'
        {
            return Quote_Backquote(Text => $Text, Document => $Document, StartPos => $Start, EndPos => $End);
        }
        # TODO: European quotes.
    }
    method Gal_Generate()
    {
        return unless defined $.Quote;
        my $Text = $.Quote;
        if $Text.contains('"')
        {
            if $Text.contains("'")
            {
                $Text = $Text.subst('"', '""', :g);
                $.Gal = "\"$Text\"";
            }
            else
            {
                $.Gal = "'$Text'";
            }
        }
        else
        {
            $.Gal = "\"$Text\"";
        }
    }
    method Raku_Generate()
    {
        return unless defined $.Quote;
        my $Text = $.Quote;
        $Text = $Text.subst("\\", "\\\\", :g);
        $Text = $Text.subst("\"", "\\\"", :g);
        $Text = $Text.subst("\.", "\\\.", :g);
        $Text = $Text.subst("\$", "\\\$", :g);
        $Text = $Text.subst("\{", "\\\{", :g);
        $Text = $Text.subst("\}", "\\\}", :g);
        #$Text = $Text.subst("\_", "\\\_", :g);
        $Text = $Text.subst("\(", "\\\(", :g);
        $Text = $Text.subst("\)", "\\\)", :g);
        $Text = $Text.subst("\[", "\\\[", :g);
        $Text = $Text.subst("\]", "\\\]", :g);
        $Text = $Text.subst("\n", "\\n", :g);
        $.Raku = "\"$Text\"";
    }
    method Python_Generate()
    {
        return unless defined $.Quote;
        my $Text = $.Quote;
        if $Text.contains('"')
        {
            $Text = $Text.subst('"', '\"', :g);
        }
        $.Python = "\"$Text\"";
    }
    method Mumps_Generate()
    {
        return unless defined $.Quote;
        my $Text = $.Quote;
        if $Text.contains('"')
        {
            $Text = $Text.subst('"', '""', :g);
        }
        $.Mumps = "\"$Text\"";
    }
    method Javascript_Generate()
    {
        if !(defined($.Quote))
        {
            return;
        }
        my Str $Text = $.Quote;
        # TODO: See Raku Version for Ideas Now
        if $Text.contains("\"")
        {
            $Text = $Text.subst("\"", "\\\"", :g);
        }
        $.Javascript = "\"$Text\"";
    }
    method C_Generate()
    {
        return unless defined $.Quote;
        my $Text = $.Quote;
        if $Text.contains('"')
        {
            $Text = $Text.subst('"', '\"', :g);
        }
        $.C = "\"$Text\"";
    }
}

class Quote_Single is Quote
{
    method Attributes()
    {
        my $Text = $.Text.substr(1, *-1);
        $Text = $Text.subst("''", "'", :g);
        $.Quote = $Text;
        #say "Single Quote Attribute `$.Quote`";
    }
}
class Quote_Double is Quote
{
    method Attributes()
    {
        my $Text = $.Text.substr(1, *-1);
        $Text = $Text.subst('""', '"', :g);
        $.Quote = $Text;
        #say "Double Quote Attribute `$.Quote`";
    }
}
class Quote_Backquote is Quote 
{ 
    method Attributes()
    {
        my $Text = $.Text.substr(1, *-1);
        $Text = $Text.subst('``', '`', :g);
        $.Quote = $Text;
        say "Back-Quote Attribute `$.Quote`";
    }
}
class Quote_European is Quote { }

class Name is Element
{
    method IsExpression() { return True; }
    has $.Usage is rw = 'initial';
    method Gal_Parse() 
    { 
        my $Context = $.Document.GetContext();
        my $Text = $.Text;
        #say "Parse Name $Text $Context";
        $Context.AddName($Text);
    }
    method Gal_Generate()
    {
        my $Text = $.Text;
        $.Gal = $Text;
    }
    method Raku_Generate()
    {
        my $OrigText = $.Text;
        my $Text = $OrigText.subst('.', '_', :g);
        if ($OrigText.substr(0,1) eq '.') {
            $Text = $OrigText;
        }
        my $Usage = $.Usage;
        my $Element = $.Parent.Lookup($OrigText);
        if $Element and $Usage ne 'propref' and $Usage ne 'class'
        {
            $Usage = $Element.Usage;
            #say "$Usage $OrigText overrides $.Usage";
            #say $.Parent.^name, " Classified $Text given $Element from $.Usage to $Usage";
        }
        if $Text eq 'null'
        {
            $.Raku = '""';
        }
        elsif $Text eq 'true'
        {
            $.Raku = 'True';
        }
        elsif $Text eq 'false'
        {
            $.Raku = 'False';
        }
        elsif $Text eq ':class'
        {
            $.Raku = 'self.type';
        }
        elsif $Usage eq 'class' || substr($Text,0,1) eq ':'
        {
            $.Raku = ClassName($Text);
        }
        elsif $Usage eq 'initial'
        {
            $.Raku = $.Text;
        }
        elsif $Usage eq 'property list' or $Usage eq 'classprop list'
        {
            #$Text = $Text.lc();
            $.Raku = "\@.$Text";
        }
        elsif $Usage eq 'property hash' or $Usage eq 'classprop hash' or $Usage eq 'property index' or $Usage eq 'classprop index'
        {
            #$Text = $Text.lc();
            $.Raku = "\%.$Text";
        }
        elsif $Usage eq 'constant'
        {
            #$Text = $Text.lc();
            $.Raku = $Text;
        }
        elsif $Usage eq 'constant list'
        {
            #$Text = $Text.lc();
            $.Raku = "\@$Text";
        }
        elsif $Usage eq 'constant hash' or $Usage eq 'constant index'
        {
            #$Text = $Text.lc();
            $.Raku = "\%$Text";
        }
        elsif $Usage eq 'property' or $Usage eq 'classprop'
        {
            #$Text = $Text.lc();
            $.Raku = "\$.$Text";
        }
        elsif $Usage eq 'variable' || $Usage eq 'value'
        {
            if $Text eq 'self' || substr($Text,0,1) eq '-'
            {
                $.Raku = $Text;
            }
            else
            {
                #$Text = $Text.lc();
                $.Raku = "\$$Text";
            }
            #say "Usage $Usage text $Text";
        }
        elsif $Usage eq 'string'
        {
            #$Text = $Text.lc();
            $.Raku = "\"\$$Text\"";
        }
        elsif $Usage eq 'entity'
        {
            if $Text eq 'self'
            {
                $.Raku = 'self';
            }
            else
            {
                #$Text = $Text.lc();
                $.Raku = "\$$Text";
            }
            #say "Usage $Usage text $Text";
        }
        elsif $Usage eq 'method' || $Usage eq 'keyword' || $Usage eq 'key'
        {
            #$Text = $Text.lc();
            $.Raku = $Text;
            #say "Usage $Usage text $Text";
        }
        elsif $Usage eq 'list'
        {
            #$Text = $Text.lc();
            $.Raku = "\@$Text";
        }
        elsif $Usage eq 'hash' or $Usage eq 'index'
        {
            #$Text = $Text.lc();
            $.Raku = "\%$Text";
        }
        elsif $Usage eq 'http'
        {
            #$Text = $Text.lc();
            $.Raku = ":$Text";
        }
        elsif $Usage eq 'data_type'
        {
            $.Raku = self.Raku_Datatype($Text);
        }
        elsif $Usage eq 'propref'
        {
            #$Text = $Text.lc();
            $.Raku = $Text;
        }
        else
        {
            die "Name '$Text' has unknown usage '$Usage'";
        }
        #say "Name.Raku $Usage $Text -> $.Raku";
    }
    method Python_Generate()
    {
        my $OrigText = $.Text;
        my $Text = $OrigText.subst('.', '_', :g);
        my $Usage = $.Usage;
        my $Element = $.Parent.Lookup($OrigText);
        if $Element and $Usage ne 'propref'
        {
            $Usage = $Element.Usage;
            #say "$Usage $OrigText overrides $.Usage";
            #say $.Parent.^name, " Classified $Text given $Element from $.Usage to $Usage";
        }
        if $Usage eq 'class' || substr($Text,0,1) eq ':'
        {
            $.Python = ClassName($Text);
        }
        elsif $Usage eq 'initial'
        {
            $.Python = $.Text;
        }
        elsif $Usage eq 'property list' or $Usage eq 'classprop list'
        {
            $Text = $Text.lc();
            $.Python = "\@.$Text";
        }
        elsif $Usage eq 'property hash' or $Usage eq 'classprop hash' or $Usage eq 'property index' or $Usage eq 'classprop index'
        {
            $Text = $Text.lc();
            $.Python = "\%.$Text";
        }
        elsif $Usage eq 'constant'
        {
            $Text = $Text.lc();
            $.Python = $Text;
        }
        elsif $Usage eq 'constant list'
        {
            $Text = $Text.lc();
            $.Python = "\@$Text";
        }
        elsif $Usage eq 'constant hash' or $Usage eq 'constant index'
        {
            $Text = $Text.lc();
            $.Python = "\%$Text";
        }
        elsif $Usage eq 'property' or $Usage eq 'classprop'
        {
            $Text = $Text.lc();
            $.Python = "\$.$Text";
        }
        elsif $Usage eq 'variable' || $Usage eq 'value'
        {
            if $Text eq 'self'
            {
                $.Python = $Text;
            }
            else
            {
                $Text = $Text.lc();
                $.Python = "\$$Text";
            }
        }
        elsif $Usage eq 'entity'
        {
            if $Text eq 'self'
            {
                $.Python = 'self';
            }
            else
            {
                $Text = $Text.lc();
                $.Python = "\$$Text";
            }
        }
        elsif $Usage eq 'method' || $Usage eq 'keyword' || $Usage eq 'key'
        {
            $Text = $Text.lc();
            $.Python = $Text;
        }
        elsif $Usage eq 'list'
        {
            $Text = $Text.lc();
            $.Python = "\@$Text";
        }
        elsif $Usage eq 'hash' or $Usage eq 'index'
        {
            $Text = $Text.lc();
            $.Python = "\%$Text";
        }
        elsif $Usage eq 'http'
        {
            $Text = $Text.lc();
            $.Python = ":$Text";
        }
        elsif $Usage eq 'data_type'
        {
            $.Python = self.Python_Datatype($Text);
        }
        elsif $Usage eq 'propref'
        {
            $Text = $Text.lc();
            $.Python = $Text;
        }
        else
        {
            die "Name '$Text' has unknown usage '$Usage'";
        }
        #say "Name.Python $Usage $Text -> $.Python";
    }
    method Mumps_Generate()
    {
        my $OrigText = $.Text;
        my $Text = $OrigText.subst('.', '_', :g);
        my $Usage = $.Usage;
        my $Element = $.Parent.Lookup($OrigText);
        if $Element and $Usage ne 'propref'
        {
            $Usage = $Element.Usage;
            #say "$Usage $OrigText overrides $.Usage";
            #say $.Parent.^name, " Classified $Text given $Element from $.Usage to $Usage";
        }
        if $Usage eq 'class' || substr($Text,0,1) eq ':'
        {
            $.Mumps = ClassName($Text);
        }
        elsif $Usage eq 'initial'
        {
            $.Mumps = $.Text;
        }
        elsif $Usage eq 'property list' or $Usage eq 'classprop list'
        {
            $Text = $Text.lc();
            $.Mumps = "\@.$Text";
        }
        elsif $Usage eq 'property hash' or $Usage eq 'classprop hash' or $Usage eq 'property index' or $Usage eq 'classprop index'
        {
            $Text = $Text.lc();
            $.Mumps = "\%.$Text";
        }
        elsif $Usage eq 'constant'
        {
            $Text = $Text.lc();
            $.Mumps = $Text;
        }
        elsif $Usage eq 'constant list'
        {
            $Text = $Text.lc();
            $.Mumps = "\@$Text";
        }
        elsif $Usage eq 'constant hash' or $Usage eq 'constant index'
        {
            $Text = $Text.lc();
            $.Mumps = "\%$Text";
        }
        elsif $Usage eq 'property' or $Usage eq 'classprop'
        {
            $Text = $Text.lc();
            $.Mumps = "\$.$Text";
        }
        elsif $Usage eq 'variable' || $Usage eq 'value'
        {
            if $Text eq 'self'
            {
                $.Mumps = $Text;
            }
            else
            {
                $Text = $Text.lc();
                $.Mumps = "\$$Text";
            }
        }
        elsif $Usage eq 'entity'
        {
            if $Text eq 'self'
            {
                $.Mumps = 'self';
            }
            else
            {
                $Text = $Text.lc();
                $.Mumps = "\$$Text";
            }
        }
        elsif $Usage eq 'method' || $Usage eq 'keyword' || $Usage eq 'key'
        {
            $Text = $Text.lc();
            $.Mumps = $Text;
        }
        elsif $Usage eq 'list'
        {
            $Text = $Text.lc();
            $.Mumps = "\@$Text";
        }
        elsif $Usage eq 'hash' or $Usage eq 'index'
        {
            $Text = $Text.lc();
            $.Mumps = "\%$Text";
        }
        elsif $Usage eq 'http'
        {
            $Text = $Text.lc();
            $.Mumps = ":$Text";
        }
        elsif $Usage eq 'data_type'
        {
            $.Mumps = self.Mumps_Datatype($Text);
        }
        elsif $Usage eq 'propref'
        {
            $Text = $Text.lc();
            $.Mumps = $Text;
        }
        else
        {
            die "Name '$Text' has unknown usage '$Usage'";
        }
        #say "Name.Mumps $Usage $Text -> $.Mumps";
    }
    method Javascript_Generate()
    {
        my Str $Name = $.Text;
        my Str $Usage = $.Usage;
        # TODO: There's clearly more to it here.
        say "JS Name $Name usage $Usage";
        $.Javascript = $Name;
    }
}

class Number is Element
{
    has $.Usage is rw = 'value';
    has $.DataType is rw = 'number';
    method IsExpression() { return True; }
    method Gal_Parse() 
    { 
        my $Context = $.Document.GetContext();
        my $Text = $.Text;
        $Context.AddName($Text);
    }
    method Gal_Generate()
    {
        my $Text = $.Text;
        $.Gal = $Text;
    }
    method Raku_Generate()
    {
        my $Text = $.Text;
        $.Raku = $Text;
    }
    method Python_Generate()
    {
        my $Text = $.Text;
        $.Raku = $Text;
    }
    method Javascript_Generate()
    {
        my Str $Text = $.Text;
        $.Javascript = $Text;
    }
}

class Key is Element
{
    has $.Key is rw;
    has $.Value is rw;
    has $.Usage is rw = 'initial';
    method IsExpression() { return True; }
    method BuildComponents()
    {
        @.Components = @.Components.sort: { $^a.StartPos cmp $^b.StartPos };
        my $Component;
        for @.Components -> $Component
        {
            $Component.Parent = self;
            next unless $Component.IsExpression();
            $Component.Usage = 'value' if $Component.Usage eq 'initial';
            @.Arguments.push($Component);
        }
    }

    method Attributes()
    {
        $.Key = @.Arguments[0];
        $.Value = @.Arguments[1];
    }
    method Gal_Generate
    {
        my $Key = $.Key.Gal;
        my $Value = $.Value.Gal;
        $.Gal = "\[$Key $Value\]";
    }
    method Raku_Generate()
    {
        my $KeyRaku = $.Key.Raku;
        my $ValueRaku = $.Value.Raku;
        $.Raku = "$KeyRaku => $ValueRaku";
    }
    method Javascript_Generate()
    {
        my Str $KeyJS = $.Key.Javascript;
        my Str $ValueJS = $.Value.Javascript;
        $.Javascript = "$KeyJS: $ValueJS, ";
    }
}



class Statement is Named_Element 
{
    # TODO: add Statement classes.
    our $.Gal_Keyword;
    our $.Nonkeyword = Statement_Invocation;
    has Str $.JSFunction is rw;
    our %.Classes = 
        'add' => Statement_Add, '+' => Statement_Add,
        'alias' => Statement_Alias,
        'append' => Statement_Append, 
        'argument' => Statement_Argument,
        'assign' => Statement_Assign, '=' => Statement_Assign, 
        'break' => Statement_Break,
        'breakif' => Statement_Breakif, 'break.if' => Statement_Breakif,
        'call' => Statement_Call, '.' => Statement_Call,
        'catch' => Statement_Catch,
        'class.prop.set' => Statement_Classpropset,
        'class.property' => Statement_Classprop,
        'classpropset' => Statement_Classpropset,
        'classprop' => Statement_Classprop,
        'class' => Statement_Class,
        'class.method' => Statement_Method, 'classmethod' => Statement_Method,
        'comment' => Statement_Comment,
        'constant' => Statement_Constant,
        'constructor' => Statement_Constructor,
        'contif' => Statement_Contif, 'continue.if' => Statement_Contif,
        'continue' => Statement_Continue,
        'decrement' => Statement_Decrement,
        'debug' => Statement_Debug, 'd' => Statement_Debug,
        'debug.stack' => Statement_Debug_Stack, 'ds' => Statement_Debug_Stack,
        'debug.variable' => Statement_Debug_Variable, 'dv' => Statement_Debug_Variable,
        'definition' => Statement_Definition,
        'directive' => Statement_Syntax,
        'else.if' => Statement_ElseIf,
        'else' => Statement_Else,
        'entities' => Statement_Entities,
        'entity' => Statement_Entity,
        'entity.new' => Statement_Entity_New,
        'error' => Statement_Raise,
        'fallback' => Statement_Fallback,
        'file.dump' => Statement_File_Dump,
        'file.readall' => Statement_File_Slurp,
        'file.slurp' => Statement_File_Slurp,
        'flag' => Statement_Flag,
        'foreachline' => Statement_Foreachline, 'foreach.line' => Statement_Foreachline, 
        'foreach' => Statement_Foreach, 'foreach.list' => Statement_Foreach,
        'forgive' => Statement_Forgive,
        'for.range' => Statement_For_Range,
        'forward' => Statement_Forward,
        'gal' => Statement_Gal,
        'goal' => Statement_Goal,
        'group' => Statement_Group,
        'handle' => Statement_Handle,
        'hash' => Statement_Hash,
        'hash.assign' => Statement_Hash_Assign, 'dict.assign' => Statement_Hash_Assign,
        'hash.delete' => Statement_Hash_Delete, 'dict.delete' => Statement_Hash_Delete,
        'hash.foreach' => Statement_Hash_Foreach, 'dict.foreach' => Statement_Hash_Foreach,
        'http.get' => Statement_Http_Get,
        'i' => Statement_I, 
        'i=' => Statement_I_Equals, 
        'if' => Statement_If, 
        'increment' => Statement_Increment,
        'index' => Statement_Index,
        'indirect' => Statement_Indirect,
        'integer' => Statement_Integer,
        'integers' => Statement_Integers,
        'interface' => Statement_Interface,
        'iterate' => Statement_Iterate,
        'know' => Statement_Know,
        'javascript' => Statement_Javascript,
        'language' => Statement_Language,
        'license' => Statement_License,
        'list' => Statement_List, 'list.copy' => Statement_List_Copy,
        'list.append' => Statement_List_Append,
        'list.foreach' => Statement_Foreach,
        'list.splice' => Statement_List_Splice,
        'list.sort' => Statement_Sort,
        'list.push' => Statement_List_Append,
        'log' => Statement_Log_Message,
        'log.message' => Statement_Log_Message,
        'message' => Statement_Log_Message,
        'main' => Statement_Main,
        'method' => Statement_Method,
        'module' => Statement_Module,
        'mumps' => Statement_Mumps,
        'my' => Statement_Property,
        'my=' => Statement_I_Equals, 
        'new' => Statement_New,
        'number' => Statement_Number,
        'operation' => Statement_Operation,
        'optional' => Statement_Optional,
        'property.list' => Statement_Proplist,
        'property.set' => Statement_Propset, '.=' => Statement_Propset,
        'property' => Statement_Property,
        'propset' => Statement_Propset, 
        'push' => Statement_List_Append,
        'python' => Statement_Python,
        'raise' => Statement_Raise,
        'replace' => Statement_Replace,
        'returnif' => Statement_Returnif,
        'return' => Statement_Return,
        'say' => Statement_Say,
        'sort' => Statement_Sort,
        'spell' => Statement_Spell,
        'statement' => Statement_Statement,
        'string' => Statement_String,
        'string.append' => Statement_Append,
        'string.foreachline' => Statement_Foreachline,
        'string.replace' => Statement_Replace,
        'symbol' => Statement_Symbol,
        'syntax' => Statement_Syntax,
        'todo' => Statement_Todo,
        'try' => Statement_Try,
        'unless' => Statement_Unless,
        'variant' => Statement_Variant,
        'verb' => Statement_Verb,
        'while' => Statement_While,
        'writeline' => Statement_Say,
        ;
    method IsStatement() { return True; }
}


class Block is Element 
{
    has @.Statements;
    has $.Statement_Raku is rw;
    has $.Statement_Gal is rw;
    method IsBlock() { return True; }
    method Attributes()
    {
        my $Statement;
        for @.Components -> $Statement
        {
            next unless $Statement.IsStatement();
            @.Statements.push: $Statement;
        }
    }
    method Gal_Generate()
    {
        my $Statement;
        my $GalCode = "";
        for @.Statements -> $Statement
        {
            my $StatementCode = $Statement.Gal;
            $GalCode ~= "$StatementCode\n";
        }
        $GalCode = $.Indent($GalCode);
        $.Statement_Gal = $GalCode;
        $GalCode = "\n\{\n$GalCode\}";
        $.Gal = $GalCode;
    }
    method Raku_Generate()
    {
        my $ParentClass = $.Parent.^name;
        my $Statement;
        my $RakuCode = "";
        for @.Statements -> $Statement
        {
            my $StatementCode = $Statement.Raku;
            #if defined($.Usage) and $.Usage eq 'constructor' and $StatementCode.contains('self')
            #{
            #    # TODO: this is a total kludge.
            #    $StatementCode = $StatementCode.subst('self','Self',:g);
            #}
            die "Unknown Statement Raku in $ParentClass: $Statement" unless defined $StatementCode;
            $RakuCode ~= "$StatementCode\n";
        }
        if defined($.Usage) and $.Usage eq 'constructor'
        {
            $RakuCode = "self.bless();\n$RakuCode";
        }
        $.Statement_Raku = $.Indent($RakuCode);
        $RakuCode = "\n\{\n$.Statement_Raku\}";
        $.Raku = $RakuCode;
    }
    method Python_Generate()
    {
        my $ParentClass = $.Parent.^name;
        my $Statement;
        my $PythonCode = "";
        for @.Statements -> $Statement
        {
            my $StatementCode = $Statement.Python;
            die "Unknown Statement Python in $ParentClass: $Statement" unless defined $StatementCode;
            $PythonCode ~= "$StatementCode\n";
        }
        $PythonCode = $.Indent($PythonCode);
        $.Python = $PythonCode;
    }
    method Mumps_Generate()
    {
        my $ParentClass = $.Parent.^name;
        my $Statement;
        my $MumpsCode = "";
        for @.Statements -> $Statement
        {
            my $StatementCode = $Statement.Mumps;
            die "Unknown Statement Mumps in $ParentClass: $Statement" unless defined $StatementCode;
            $MumpsCode ~= "    $StatementCode\n";
        }
        $.Mumps = $MumpsCode;
    }
    method Javascript_Generate()
    {
        my Str $ParentClass = $.Parent.^name;
        my $Statement;
        my Str $JSCode = "";
        for @.Statements -> $Statement
        {
            my Str $StatementCode = $Statement.Javascript;
            if !(defined($StatementCode))
            {
                die "Unknown Statement Javascript in block of $ParentClass: $Statement";
            }
            $JSCode ~= $StatementCode ~ "\n";
        }
        $JSCode = $.Indent($JSCode);
        $JSCode = " \{\n$JSCode\}";
        $.Javascript = $JSCode;
    }
}

class Function is Named_Element
{
    method IsExpression() { return True; }
    has $.Usage is rw = 'value';
    # TODO: add Function classes.
    our $.Gal_Keyword;
    our $.Nonkeyword = Function_Invocation;
    our %.Classes = 
        '.' => Function_Dot,
        'add' => Function_Add, '+' => Function_Add,
        'and' => Function_And, '&' => Function_And,
        'append' => Function_Append, 'string.append' => Function_Append,
        'classpropget' => Function_Classpropget,
        'contains' => Function_Contains, 'string.contains' => Function_Contains,
        'defined' => Function_Defined,
        'dict.get' => Function_Dict_Get,
        'divide' => Function_Divide, '/' => Function_Divide,
        'enquote' => Function_Enquote, 'quote' => Function_Enquote,
        'entity' => Function_Entity,
        'equal' => Function_Equal, '=' => Function_Equal,
        'string.eq' => Function_StringEqual,
        'string.ne' => Function_StringNotEqual,
        'exp' => Function_Exp,
        'firstchar' => Function_Firstchar,
        'flag' => Function_Flag,
        'ge' => Function_GreaterEqual,
        'get' => Function_Get,
        'greater' => Function_Greater, 'gt' => Function_Greater,
        'indirect' => Function_Indirect,
        'integer' => Function_Integer,
        'i' => Function_I, 'we' => Function_I,
        'isa' => Function_Isa,
        'isnull' => Function_Isnull, 'string.isnull' => Function_Isnull,
        'key.exists' => Function_Keyexists, 'keyexists' => Function_Keyexists,
        'key.get' => Function_Dict_Get, 'keyget' => Function_Dict_Get,
        'lastchar' => Function_Lastchar,
        'le' => Function_LessEqual,
        'string.le' => Function_StringLessEqual,
        'string.ge' => Function_StringGreaterEqual,
        'string.lt' => Function_StringLess,
        'string.gt' => Function_StringGreater,
        'length' => Function_Stringlength,
        'less' =>Function_Less, lt => Function_Less,
        'list.first' => Function_List_First,
        'list.get' => Function_List_Get,
        'list.last' => Function_List_Last,
        'list.length' => Function_List_Length,
        'list.pop' => Function_List_Pop,
        'list.shift' => Function_List_Shift,
        'log' => Function_Log,
        'lower' => Function_Lowercase, 'lowercase' => Function_Lowercase,
        'middle' => Function_Middle,
        'mod' => Function_Modulo, '%' => Function_Modulo,
        'multiply' => Function_Multiply, '*' => Function_Multiply,
        'ne' => Function_NotEqual, '!=' => Function_NotEqual,
        'new' => Function_New,
        'not' => Function_Not, '!' => Function_Not,
        'notnull' => Function_NotNull, 'not.null' => Function_NotNull, 'string.notnull' => Function_NotNull,
        'number' => Function_Number,
        'or' => Function_Or, '|' => Function_Or,
        'pop' => Function_List_Pop,
        'power' => Function_Power, '^' => Function_Power,
        'propget' => Function_Propget,
        'shift' => Function_List_Shift,
        'split' => Function_Split,
        'string' => Function_String,
        'string.length' => Function_Stringlength,
        'string.split' => Function_Split,
        'string.substring' => Function_Substring,
        'substring' => Function_Substring,
        'subtract' => Function_Subtract, '-' => Function_Subtract,
        'upper' => Function_Uppercase, 'uppercase' => Function_Uppercase,
        'variant' => Function_Variant,
        'whitespace' => Function_Whitespace,
        ;
    method Gal_Generate()
    {
        my $GalCode = "($.Gal_Keyword";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            #say "Function Argument $ArgCode";
            $GalCode ~= " $ArgCode";
        }
        $GalCode ~= ")";
        $.Gal = $GalCode;
    }
    method Raku_Binop($Operator, $Force_Parens = 0)
    {
        my $Arg0 = @.Arguments[0];
        my $Arg1 = @.Arguments[1];
        my $Arg0Raku = $Arg0.Raku;
        if $Arg0.Raku_Precedence <= $.Raku_Precedence
        {
            $Arg0Raku = "($Arg0Raku)";
        }
        my $Arg1Raku = $Arg1.Raku;
        if $Arg1.Raku_Precedence <= $.Raku_Precedence
        {
            $Arg1Raku = "($Arg1Raku)";
        }
        my $RakuCode = "$Arg0Raku $Operator $Arg1Raku";
        if $Force_Parens 
        {
            $RakuCode = '(' ~ $RakuCode ~ ')';
        }
        $.Raku = $RakuCode;
    }
    method Raku_Unaryop($Operator)
    {
        my $Arg0 = @.Arguments[0];
        my $Arg0Raku = $Arg0.Raku;
        if $Arg0.Raku_Precedence <= $.Raku_Precedence
        {
            $Arg0Raku = "($Arg0Raku)";
        }
        my $RakuCode = "$Operator$Arg0Raku";
        $.Raku = $RakuCode;
    }
}
class Syntax is Named_Element
{
    # TODO: add more Syntax classes.
    our $.Gal_Keyword;
    has $.Usage is rw = 'value';
    our %.Classes = 
        '.' => Syntax_Dot,
        'backslash' => Syntax_Backslash,
        'classname' => Syntax_Classname, 'class.name' => Syntax_Classname,
        'classprop' => Syntax_Classprop, 'class.property' => Syntax_Classprop, 'cp' => Syntax_Classprop,
        'class.self' => Syntax_Class_Self,
        'entity' => Syntax_Entity,
        'embed' => Syntax_Embed,
        'false' => Syntax_False,
        'flag' => Syntax_Flag,
        'hash' => Syntax_Hash,
        'dict' => Syntax_Hash,
        'dictionary' => Syntax_Hash,
        'i' => Syntax_I,
        'integer' => Syntax_Integer, 
        'indent' => Syntax_Indent,
        'is' => Syntax_Is, 
        'key' => Syntax_Key,
        'line' => Syntax_Line,
        'list' => Syntax_List,
        'my' => Syntax_I,
        'node' => Syntax_Node,
        'null' => Syntax_Null,
        'number' => Syntax_Number,
        'property' => Syntax_Dot,
        'true' => Syntax_True,
        'self' => Syntax_Self,
        'string' => Syntax_String,
        'variant' => Syntax_Variant,
        ;
    method Classify($name, $document, $start, $end) 
    {
        unless defined($name)
        {
            my $Message = "$.^name Classify \$name undefined - did you do () or [] or something??";
            $document.Error($Message, $start);
            die $Message;
        }
        my $First = substr($name, 0, 1);
        #say "Syntax Classifying '$name' first char $First $start-$end";
        my $Element;
        if 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-"\'`'.contains($First)
        {
            $Element = Key.new(Name => 'key', Document => $document, StartPos => $start, EndPos => $end);
        }
        else
        {
            unless %.Classes{$name}:exists
            {
                my $Message = "ERROR Syntax Classify. Unknown $.^name '$name'";
                $document.Error($Message, $start);
                die $Message;
            }
            my $Class = %.Classes{$name};
            $Element = $Class.new(Name => $name, Document => $document, StartPos => $start, EndPos => $end);
        }
        #say "Classifying '$name' as ", $Class, " returns ", $Element;
        return $Element;
    }
    method IsExpression() { return True; }
    method Gal_Generate()
    {
        my $GalCode = "[$.Gal_Keyword";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Syntax $Argument!>";
            }
            #say "Function Argument $ArgCode";
            $GalCode ~= " $ArgCode";
        }
        $GalCode ~= "]";
        $.Gal = $GalCode;
    }
    method Raku_Generate()
    {
        # a syntax has no output in Raku unless overridden.
        $.Raku = "";
    }
    method Javascript_Generate()
    {
        $.Javascript = "";
    }
}

class Punct_LeftFunc is Named_Element
{
    method Gal_Parse()
    {
        $.Document.PushContext(self);
    }
    method Gal_Generate() { }
    method Raku_Generate() { }
}

class Punct_LeftDirect is Named_Element
{
    method Gal_Parse()
    {
        #say "LeftDirect Parse ", $.StartPos, "=", $.Text;
        $.Document.PushContext(self);
    }
    method Gal_Generate() { }
    method Raku_Generate() { }
}

class Punct_LeftBlock is Named_Element
{
    method Gal_Parse()
    {
        my $End = self.EndPos;
        $.Document.PushContext(self);
        $.Document.PushContext(Stmt_Context.new(:StartPos($End+1)));
    }
    method Gal_Generate() { }
    method Raku_Generate() { }
}

class Punct_LeftExtended is Named_Element
{
    method Gal_Parse()
    {
        $.Document.PushContext(self);
    }
    method Raku_Generate() { }
}

class Punct_Close is Named_Element 
{ 
    method Gal_Generate() { }
    method Raku_Generate() { }
}
class Punct_RightFunc is Punct_Close
{
    method Gal_Parse()
    {
        my $StartElement = $.Document.PopContext();
        # TODO: validate that it is a function!
        my $Start = $StartElement.StartPos;
        my $Name = $StartElement.Name;
        my $End = self.EndPos;
        my $Function = Function.Classify($Name, $.Document, $Start, $End);
        #say "Function $Name Classified: $Function";
        $.Document.AddElement($Function);
        $.Document.GetContext().AddArgument($Function);
    }
    method Raku_Generate() { }
}

class Punct_RightDirect is Punct_Close
{
    method Gal_Parse()
    {
        #say "RightDirect Parse ", $.StartPos, "=", $.Text;
        my $StartElement = $.Document.PopContext();
        # TODO: validate that it is a syntax!
        my $Start = $StartElement.StartPos;
        my $Name = $StartElement.Name;
        my $End = $.Text eq Parser.Separator ?? $.EndPos-1 !! $.EndPos;
        #say "Classifying ", $StartElement.Express();
        my $Syntax = Syntax.Classify($Name, $.Document, $Start, $End);
        #say "Syntax $Name Classified: $Syntax";
        $.Document.AddElement($Syntax);
        $.Document.GetContext().AddArgument($Syntax);
        # NOTE: comma acts as left syntax.
        if $.Text eq Parser.Separator
        {
            #say "Comma pushes context";
            $.Document.PushContext(self);
        }
    }
}

class Punct_RightBlock is Punct_Element
{
    method Gal_Parse()
    {
        # TODO: validate that it is a statement!
        #say "Right Block Begin";
        #$.Document.Dump();
        my $BlockStatementElement = $.Document.PopContext();
        #say "Block Statement ", $BlockStatementElement.Express();
        my $BlockElement = $.Document.PopContext();
        #say "Block Element ", $BlockElement.Express();
        my $BlockStart = $BlockElement.StartPos;
        my $BlockEnd = self.EndPos;
        my $Block = Block.new(:Document($.Document), :StartPos($BlockStart), :EndPos($BlockEnd));
        #say "Block: $Block.Express()";
        $.Document.AddElement($Block);
        my $StartElement = $.Document.PopContext();
        #say "Start Element ", $StartElement.Express();
        unless $StartElement
        {
            say "!!!!ERROR!!!!";
            $.Document.Error("Block start element (pop context) is missing.");
        }
        my $Start = $StartElement.StartPos // '';
        my $Name = $StartElement.Name // '';
        my $End = $.EndPos // '';
        #say "Right Block $Start - $End $Name";
        my $Statement = Statement.Classify($Name, $.Document, $Start, $End);
        #say "Statement $Name Classified: $Statement";
        $.Document.AddElement($Statement);
        # TODO: this statement must be added to the parent block now.
        $.Document.PushContext(Stmt_Context.new(:StartPos($End+1)));
        #say "Right Block End";
    }
}

class Punct_RightExtended is Punct_Element
{
    method Gal_Parse()
    {
        # TODO: this is the End of an extended element.
        die "Implement Right Extended";
    }
}

class Punct_Semi is Punct_Element
{
    method Gal_Parse()
    {
        my $StartElement = $.Document.PopContext();
        # TODO: validate that it is a statement!
        my $Name = $StartElement.Name;
        my $Start = $StartElement.StartPos;
        my $End = $.EndPos;
        my $Statement = Statement.Classify($Name, $.Document, $Start, $End);
        unless $Statement
        {
            say "ERROR UNKNOWN Statement $Name";
        }
        #say "Statement $Name Classified: ", $Statement.Express();
        $.Document.AddElement($Statement);
        # TODO: this statement must be added to the parent block now.
        $.Document.PushContext(Stmt_Context.new(:StartPos($End+1)));
    }
}

class Token 
{
    has Int $.Position;
    has Str $.Text is rw;
    has Int $.Line is rw;
    has Int $.Offset is rw;
    has Str $.Mode is rw;
    has Str $.Match is rw = '';
    has $.Document;
    method Append(Str $Char)
    {
        $.Text ~= $Char;
        #say "Token Append ", $.Text;
    }
    method Gal_Element($Document)
    {
        my $Mode = $.Mode;
        my $Element;
        return if $Mode eq 'Space';
        if $Mode eq 'Word'
        {
            $Element = Name.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq 'Number'
        {
            $Element = Number.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq 'Quote'
        {
            $Element = Quote.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq 'Semi'
        {
            $Element = Punct_Semi.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq 'LFunc'
        {
            $Element = Punct_LeftFunc.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq 'LDirect'
        {
            $Element = Punct_LeftDirect.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq 'LBlock'
        {
            $Element = Punct_LeftBlock.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq 'LExtended'
        {
            $Element = Punct_LeftExtended.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq Parser.FunctionEnd
        {
            $Element = Punct_RightFunc.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq Parser.SyntaxEnd
        {
            $Element = Punct_RightDirect.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq Parser.BlockEnd
        {
            $Element = Punct_RightBlock.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        elsif $Mode eq Parser.ExtendedEnd
        {
            $Element = Punct_RightExtended.new(:StartPos($.Position), :EndPos($.Position), :Text($.Text), :Document($Document));
        }
        #say "Token Mode $Mode Add Element $Element";
        $Document.AddElement($Element);
    }
}

class Parser 
{
    our $.SpellPrefix = ':';
    our $.EndStatement = ';';
    our $.BlockBegin = '{';
    our $.BlockEnd = '}';
    our $.FunctionBegin = '(';
    our $.FunctionEnd = ')';
    our $.SyntaxBegin = '[';
    our $.Separator = ',';
    our $.SyntaxEnd = ']';
    our $.ExtendedBegin = '<';
    our $.ExtendedEnd = '>';
    has $.RootElement;
    method Tokenize($Document)
    {
        my $Char;
        my $Mode = 'Initial';
        my $Quote = '';
        my $Match = '';
        my $Line = 0;
        my $Offset = 0;
        for $Document.Text.comb -> $Char
        {
            if $Char eq "\n"
            {
                $Line++;
                $Offset = 0;
            }
            else
            {
                $Offset++;
            }
            my $LastMatch = $Match eq '' ?? '' !! $Match.comb[*-1];
            my $Say = "Character '$Char' Mode '$Mode'";
            $Say ~= " Quote $Quote" if $Quote gt '';
            $Say ~= " Match '$Match'" if $Match gt '';
            $Say ~= " LastMatch '$LastMatch'" if $Match gt '';
            #say $Say;
            if $Mode eq 'Initial'
            {
                # drop through to Initial Mode handler.
            }
            elsif $Mode eq 'Quote'
            {
                if $Char eq $Quote
                {
                    $Mode = 'Quote2';
                }
                $Document.AppendToken($Char);
            }
            elsif $Mode eq 'Quote2'
            {
                if $Char eq $Quote
                {
                    $Mode = 'Quote';
                    $Document.AppendToken($Char);
                }
                else
                {
                    #say "Started $Quote Ended '$Char'";
                    $Mode = 'Initial';
                    $Quote = '';
                }
            }
            elsif $Mode eq 'Word'
            {
                if ($Char ~~ m/\W/) && !('~!@#$%^&*_-+=|\:/?.'.contains($Char))
                {
                    $Mode = 'Initial';
                }
                else
                {
                    #say "Appending Word character $Char";
                    $Document.AppendToken($Char);
                }
            }
            elsif $Mode eq 'Number'
            {
                if $Char ~~ m/\D/ and $Char ne '.'
                {
                    $Mode = 'Initial';
                }
                else
                {
                    #say "Appending Number character $Char";
                    $Document.AppendToken($Char);
                }
            }
            elsif $Mode eq 'Space'
            {
                if $Char ~~ m/\S/
                {
                    $Mode = 'Initial';
                }
                else
                {
                    $Document.AppendToken($Char);
                }
            }
            elsif $Mode eq 'Semi'
            {
                $Mode = 'Initial';
            }
            # TODO: insert more parser Modes here.
            else
            {
                say "Unknown Mode $Mode";
            }
            if $Mode eq 'Initial'
            {
                #say "$Mode determines token creation Mode";
                # Determine the token creation Mode.
                # TODO: European quotes.
                if $Char eq '"' or $Char eq "'" or $Char eq 'Statement'
                {
                    $Mode = 'Quote';
                    $Quote = $Char;
                }
                # TODO: European quotes.
                elsif $Char ~~ m/\d/ # TODO.
                {
                    $Mode = 'Number';
                }
                elsif $Char eq '.'
                {
                    $Mode = 'Word';
                }
                elsif $Char ~~ m/\s/
                {
                    $Mode = 'Space';
                }
                elsif $Char ~~ m/\w/
                {
                    $Mode = 'Word';
                }
                elsif $Char eq $.FunctionBegin
                {
                    $Mode = 'LFunc';
                    $Match ~= $.FunctionEnd;
                }
                elsif $Char eq $.SyntaxBegin
                {
                    $Mode = 'LDirect';
                    $Match ~= $.SyntaxEnd;
                }
                elsif $Char eq $.BlockBegin
                {
                    $Mode = 'LBlock';
                    $Match ~= $.BlockEnd;
                }
                elsif $Char eq $.ExtendedBegin
                {
                    $Mode = 'LExtended';
                    $Match ~= $.ExtendedEnd;
                }
                elsif $Char eq $LastMatch
                {
                    #say "Matched $Char equals $LastMatch";
                    $Mode = $Char;
                    $Match = $Match.substr(0, *-1);
                }
                elsif $Char eq $.Separator
                {
                    #say "Matched $Char as $LastMatch";
                    $Mode = $LastMatch;
                }
                elsif $Char ~~ m/\w/ or $Char eq $.SpellPrefix
                {
                    $Mode = 'Word';
                }
                elsif $Char ~~ m/|w/
                {
                    $Mode = 'Initial';
                }
                elsif $Char eq $.EndStatement
                {
                    $Mode = 'Semi';
                }
                # TODO: insert more token creation Modes here.
                else
                {
                    #say "Error unhandled character '$Char' while tokenizing.";
                    $Mode = 'Word';
                }
                #say "Token Creation Mode $Mode";
                # Create a new token.
                $Document.AddToken($Char, $Mode, $Line, $Offset);
                #say "Token Added";
                if $Char eq $.Separator && " LFunc LDirect LBlock LExtended ".contains(" $Mode ") 
                {
                    # NOTE: this is a comma so we seek to end the prior language element before here, and begin the next one here.
                    # We are still in the same mode as before. The comma does not change that.
                    # TODO: any adjustments needed here?
                }
                elsif " LFunc LDirect LBlock LExtended $.FunctionEnd $.SyntaxEnd $.BlockEnd $.ExtendedEnd Semi ".contains(" $Mode ") 
                {
                    # Some Modes reset following token Mode to Initial. 
                    $Mode = 'Initial';
                }
            }
        }
        $Document.FixTokens();
    }
    method Parse($Document)
    {
        my $Token;
        for $Document.Tokens -> $Token
        {
            #print '.';
            $Token.Gal_Element($Document);
        }
        #say '';
        my $InitialContext = Stmt_Context.new(:StartPos(0));
        $Document.PushContext($InitialContext);
        my @Elements = $Document.Elements;
        my $Element;
        for @Elements -> $Element
        {
            #say "Parser parsing ", $Element.Express();
            $Element.Gal_Parse();
        }
        $Document.PopContext();
    }
    method Attributes($Document)
    {
        my @Elements = $Document.Elements;
        my $Element;
        for @Elements -> $Element
        {
            #say 'parser attributes ', $Element.Express();
            $Element.Attributes();
        }
        $Document.Attributes();
        #say 'completed parser attributes\n';
    }
    method Prepare($Document)
    {
        my @Elements = $Document.Elements;
        my $Element;
        for @Elements -> $Element
        {
            $Element.Prepare();
        }
    }
}

class Scoped_Statement is Statement
{
    has $.Block is rw;
    has %.NameList is rw;
    method Lookup($Name)
    {
        if %.NameList{$Name}:exists
        {
            #say "$.^name Lookup($Name) FOUND";
            return %.NameList{$Name};
        }
        unless $.Parent
        {
            #say "$.^name Lookup($Name) failed, no parent";
            return False;
        }
        #say "$.^name Lookup($Name) delegating to $.Parent.^name";
        return $.Parent.Lookup($Name);
    }
    method AddType($Name, $Type)
    {
        #say "$.^name Adding '$Name' as $Type";
        %.NameList{$Name} = $Type;
    }
    method BuildComponents()
    {
        @.Components = @.Components.sort: { $^a.StartPos cmp $^b.StartPos };
        my $Component;
        my $First = True;
        for @.Components -> $Component
        {
            $Component.Parent = self;
            if $First
            {
                $First = False;
                $Component.Usage = 'keyword';
            }
            elsif $Component.IsExpression()
            {
                #say "Statement Component $Component";
                @.Arguments.push: $Component;
                $Component.Usage = 'value' if $Component.Usage eq 'initial';
            }
            elsif $Component.IsBlock()
            {
                $!Block = $Component;
            }
        }
    }
    method Gal_Generate()
    {
        my $GalCode = "$.Gal_Keyword";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            if $ArgCode.starts-with('[') and $GalCode.ends-with(']')
            {
                $GalCode = $GalCode.substr(0, *-1) ~ ", " ~ $ArgCode.substr(1);
            }
            else
            {
                $GalCode ~= " $ArgCode";
            }
        }
        if $.Block && $.Block.Gal
        {
            $GalCode ~= ' ';
            $GalCode ~= $.Block.Gal;
        }
        else
        {
            $GalCode ~= '; ';
        }
        $.Gal = $GalCode;
    }
}

class Line_Statement is Statement
{
    method Gal_Generate()
    {
        my $GalCode = $.Gal_Keyword;
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            if $ArgCode.starts-with('[') and $GalCode.ends-with(']')
            {
                $GalCode = $GalCode.substr(0, *-1) ~ ", " ~ $ArgCode.substr(1);
            }
            else
            {
                $GalCode ~= " $ArgCode";
            }
        }
        $GalCode ~= ";";
        $.Gal = $GalCode;
    }
}

class Append_Args_Statement is Line_Statement 
{
    has Str $.RakuStatement;
    has Str $.PythonFunction;
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'string';
        }
    }
    method Raku_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $RakuArgs = "";
        for @.Arguments -> $Argument
        {
            next unless $Argument.IsExpression();
            my $ArgRakuCode = $Argument.Raku;
            unless $ArgRakuCode
            {
                say "ERROR: Argument $Argument has no .Raku";
                say $Argument.Express();
            }
            if $RakuArgs eq ""
            {
                $RakuArgs = $ArgRakuCode;
            }
            elsif $ArgRakuCode.starts-with("\"_") || $RakuArgs.ends-with("_\"")
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs ~ $ArgRakuCode";
            }
            elsif $ArgRakuCode.starts-with("\"") 
                && $RakuArgs.ends-with("\"") 
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                my $ArgTail = $ArgRakuCode.substr(1);
                $RakuArgs = "$RakuHead$ArgTail";
            }
            elsif $ArgRakuCode.starts-with('$') && !$ArgRakuCode.contains('.') && $RakuArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                $RakuArgs = "$RakuHead$ArgRakuCode\"";
            }
            else
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs ~ $ArgRakuCode";
            }
        }
        my Str $RakuCode = "$.RakuStatement $RakuArgs;";
        $.Raku = $RakuCode;
    }
    method Python_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $PythonArgs = "";
        for @.Arguments -> $Argument
        {
            next unless $Argument.IsExpression();
            my $ArgPythonCode = $Argument.Python;
            unless $ArgPythonCode
            {
                say "ERROR: Argument $Argument has no .Python";
                say $Argument.Express();
            }
            if $PythonArgs eq ""
            {
                $PythonArgs = $ArgPythonCode;
            }
            elsif $ArgPythonCode.starts-with('"') && $PythonArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $PythonHead = chop($PythonArgs);
                my $ArgTail = $ArgPythonCode.substr(1);
                $PythonArgs = "$PythonHead$ArgTail";
            }
            elsif $ArgPythonCode.starts-with('$') && $PythonArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $PythonHead = chop($PythonArgs);
                $PythonArgs = "$PythonHead$ArgPythonCode\"";
            }
            else
            {
                # Append String Arguments into a comma-separated argument list.
                $PythonArgs = "$PythonArgs, $ArgPythonCode";
            }
        }
        my Str $PythonCode = $.PythonFunction ~ '(' ~ $PythonArgs ~ ')';
        $.Python = $PythonCode;
    }
    method Mumps_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $MumpsArgs = "";
        for @.Arguments -> $Argument
        {
            next unless $Argument.IsExpression();
            my $ArgMumpsCode = $Argument.Mumps;
            unless $ArgMumpsCode
            {
                say "ERROR: Argument $Argument has no .Mumps";
                say $Argument.Express();
            }
            if $MumpsArgs eq ""
            {
                $MumpsArgs = $ArgMumpsCode;
            }
            else
            {
                # Append String Arguments into a comma-separated argument list.
                $MumpsArgs ~= "_$ArgMumpsCode";
            }
        }
        my Str $MumpsCode = $.MumpsStatement ~ ' ' ~ $MumpsArgs;
        $.Mumps = $MumpsCode;
    }
    method Javascript_Generate()
    {
        my @Arguments;
        my $Argument;
        my Str $JSArgs = "";
        for @.Arguments -> $Argument
        {
            next if !$Argument.IsExpression();
            my Str $ArgJSCode = $Argument.Javascript;
            unless $ArgJSCode ne ""
            {
                say "ERROR: Argument $Argument has no \.Javascript";
                say $Argument.Express();
            }
            if $JSArgs eq ""
            {
                # first argument
                if ($ArgJSCode.substr(0, 1)) eq "\""
                {
                    # string literal
                    $JSArgs = $ArgJSCode;
                }
                else 
                {
                    # embedded expression in string
                    $JSArgs = "\"\$\{$ArgJSCode\}\"";
                }
            }
            elsif ($ArgJSCode.substr(0, 1)) eq "\""
            {
                # string literal consolidation
                my Str $JSHead = $JSArgs.substr(0, *-1);
                my Str $ArgTail = $ArgJSCode.substr(1);
                $JSArgs = "$JSHead$ArgTail";
            }
            else 
            {
                # embedded expression in string
                my Str $JSHead = $JSArgs.substr(0, *-1);
                $JSArgs = "$JSHead\$\{$ArgJSCode\}\"";
            }
            if $JSArgs.contains("\$\{")
            {
                $JSArgs = "`" ~ $JSArgs.substr(1, *-1) ~ "`";
            }
            my Str $JSCode = $.JSFunction ~ "\($JSArgs\);";
            $.Javascript = $JSCode;
        }
    }
}

class Statement_Append is Line_Statement 
{
    our $.Gal_Keyword = 'append';
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'string';
        }
        @.Arguments[0].Usage = 'variable';
    }
    method Raku_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $RakuArgs = "";
        my $Between = "";
        for @.Arguments -> $Argument
        {
            next unless $Argument.IsExpression();
            my $ArgRakuCode = $Argument.Raku;
            unless $ArgRakuCode
            {
                say "ERROR: Argument $Argument has no .Raku";
                say $Argument.Express();
            }
            if $RakuArgs eq ""
            {
                $RakuArgs = $ArgRakuCode;
                $Between = " ~= ";
            }
            elsif $ArgRakuCode.starts-with('"_') && $RakuArgs.ends-with('_"')
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs$Between$ArgRakuCode";
                $Between = " ~ ";
            }
            elsif $ArgRakuCode.starts-with('"') && $RakuArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                my $ArgTail = $ArgRakuCode.substr(1);
                $RakuArgs = "$RakuHead$ArgTail";
            }
            elsif $ArgRakuCode.starts-with('$') && !$ArgRakuCode.contains('.') && $RakuArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                $RakuArgs = "$RakuHead$ArgRakuCode\"";
            }
            else
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs$Between$ArgRakuCode";
                $Between = " ~ ";
            }
        }
        my Str $RakuCode = "$RakuArgs;";
        $.Raku = $RakuCode;
    }
    method Javascript_Generate()
    {
        my @Arguments;
        my $Argument;
        my Str $JSArgs = "";
        for @.Arguments -> $Argument
        {
            next if !$Argument.IsExpression();
            my Str $ArgJSCode = $Argument.Javascript;
            unless $ArgJSCode ne ""
            {
                say "ERROR: Argument $Argument has no \.Javascript";
                say $Argument.Express();
            }
            if $JSArgs eq ""
            {
                # first argument
            }
            elsif ($ArgJSCode.substr(0, 1)) == "\""
            {
                # string literal consolidation
                my Str $JSHead = $JSArgs.substr(0, *-1);
                my Str $ArgTail = $ArgJSCode.substr(1);
                $JSArgs = "$JSHead$ArgTail";
            }
            else 
            {
                # embedded expression in string
                my Str $JSHead = $JSArgs.substr(0, *-1);
                my Str $ArgTail = $ArgJSCode.substr(1);
                $JSArgs = "$JSHead\$\{$ArgTail\}`";
            }
            my Str $JSCode = $JSArgs;
            $.Javascript = $JSCode;
        }
    }
}

class Argument_Statement is Statement { }

class Statement_Argument is Argument_Statement
{
    our $.Gal_Keyword = "argument";
    has $.Arg_Name is rw;
    has $.Usage_Value is rw;
    method Attributes()
    {
        $.Arg_Name = @.Arguments.shift();
        $.Arg_Name.Usage = "variable";
        if (@.Arguments.elems) > 0
        {
            $.Usage_Value = @.Arguments.shift();
            $.Usage_Value.Usage = "value";
        }
    }
    method Gal_Generate()
    {
        my Str $Definition = "property entity " ~ $.Arg_Name.Gal ~ ";";
        my Str $Code = ".= self " ~ $.Arg_Name.Gal ~ " \(list\.shift [. self Listargs]\);\n";
        if $.Usage_Value
        {
            $Code ~= "\.= [. self " ~ $.Arg_Name.Gal ~ "] Usage " ~ $.Usage_Value.Gal ~ ";\n";
        }
        $.Gal_Definition = $Code;
        $.Gal = $Definition;
    }
} 

class Statement_Optional is Argument_Statement
{
    our $.Gal_Keyword = "optional";
    has $.VarName is rw;
    has $.Usage_Value is rw;
    method Attributes()
    {
        $.VarName = @.Arguments.shift();
        $.VarName.Usage = "variable";
        if (@.Arguments.elems) > 0
        {
            $.Usage_Value = @.Arguments.shift();
            $.Usage_Value.Usage = "value";
        }
    }
    method Gal_Generate()
    {
        my Str $GalName = $.VarName.Gal;
        #say "Gal Name ", $GalName;
        my Str $Definition = "property entity " ~ $GalName ~ ";";
        my Str $Code = "if \(gt \(list\.length [\. self Listargs]\) 0\)\n\{\n    .= self " ~ $GalName ~ " \(list\.shift [\. self Listargs]\);\n";
        #say "Code ", $Code;
        if $.Usage_Value
        {
            $Code ~= "    \.= [. self " ~ $GalName ~ "] Usage " ~ $.Usage_Value.Gal ~ ";\n";
        }
        $Code ~= "\}\n";
        $.Gal_Definition = $Code;
        $.Gal = $Definition;
    }
} 

class Statement_Forward is Line_Statement 
{
    our $.Gal_Keyword = 'forward';
    our $.Raku_Keyword = 'class';
    has $.ClassName is rw;
    method Attributes() 
    {
        $.ClassName = @.Arguments[0];
        $.ClassName.Usage = 'class';
    }
    method Raku_Generate() 
    { 
        my $ClassRaku = $.ClassName.Raku;
        my $Scope = '{...}';
        my $RakuCode = "$.Raku_Keyword $ClassRaku $Scope";
        $.Raku = $RakuCode;
    }
    method Javascript_Generate()
    {
        # TODO: Figure out if we need to really do anything here.
        my Str $ClassNameJS = $.ClassName.Javascript;
        my Str $JSCode = " /* TODO? forward declaration of $ClassNameJS class\. */ ";
        $.Javascript = $JSCode;
    }
}
class Statement_Indirect is Line_Statement
{
    our $.Gal_Keyword = 'indirect';
    has $.Target is rw;
    has @.IndirectArgs is rw;
    method Attributes()
    {
        @.IndirectArgs = @.Arguments;
        $.Target = @.IndirectArgs.shift;
    }
}
class Statement_Classprop is Line_Statement 
{
    our $.Gal_Keyword = 'class.property';
    has $.DataType is rw;
    has $.Property is rw;
    has $.InitialValue is rw;
    method Attributes() 
    {
        my ($Arg1, $Arg2, $Arg3) = @.Arguments;
        my $Contain = $Arg1.Text;
        if ",void,string,number,integer,flag,variant,entity,hash,list,index,".contains(",$Contain,")
        {
            $.DataType = $Arg1.Text;
            $.Property = $Arg2;
            $.InitialValue = $Arg3 if defined $Arg3;
        }
        else
        {
            $.DataType = '';
            $.Property = $Arg1;
            $.InitialValue = $Arg2 if defined $Arg2;
        }
        if $.DataType eq 'list'
        {
            $.Property.Usage = "classprop list";
        }
        elsif $.DataType eq 'hash'
        {
            $.Property.Usage = "classprop hash";
        }
        elsif $.DataType eq 'index'
        {
            $.Property.Usage = "classprop index";
        }
        else
        {
            $.Property.Usage = "classprop";
        }
    }
    method Raku_Generate() 
    { 
        my $Type = self.Raku_Datatype($.DataType);
        $Type = " $Type" if $Type gt '';
        my $Name = $.Property.Raku;
        my $Assignment = "";
        if defined $.InitialValue
        {
            $Assignment = " = " ~ $.InitialValue.Raku
        }
        my $RakuCode = "our $Name$Assignment;";
        $.Raku = $RakuCode;
    }
    method Javascript_Generate()
    {
        my Str $ArgumentJS = $.Variable.Javascript;
        if defined($.InitialValue)
        {
            $ArgumentJS ~= " = " ~ $.InitialValue.Javascript;
        }
        my Str $JSCode = "static $ArgumentJS;";
        $.Javascript = $JSCode;
    }
}

class Declare_Statement is Line_Statement 
{
    our $.Gal_Keyword;
    our $.Raku_Type;
    has Str $.RakuStatement = "my";
    has Element $.Variable is rw;
    has $.InitialValue is rw;
    method Attributes()
    {
        my ($N, $V) = @.Arguments;
        $.Variable = $N;
        $.Variable.Usage = 'variable';
        $.InitialValue = $V if defined $V;
        $.Parent.AddType($.Variable.Text, $.Variable);
    }
    method Raku_Generate() 
    { 
        my $Name = $.Variable.Raku;
        my $Assignment = "";
        if defined $.InitialValue
        {
            $Assignment = " = " ~ $.InitialValue.Raku
        }
        my $Type = ($.Raku_Type gt '') ?? " $.Raku_Type" !! "";
        my $RakuCode = "$.RakuStatement$Type $Name$Assignment;";
        $.Raku = $RakuCode;
    }
    method Javascript_Generate()
    {
        my Str $ArgCode = $.Variable.Javascript;
        if defined($.InitialValue)
        {
            $ArgCode ~= " = " ~ $.InitialValue.Javascript;
        }
        my Str $JSCode = "let $ArgCode;";
        $.Javascript = $JSCode;
    }
}

class Multi_Declare_Statement is Declare_Statement 
{
    our $.Gal_Keyword;
    our $.Raku_Type;
    has Str $.RakuStatement = "my";
    has Element $.Variable is rw;
    has @.InitialValues is rw;
    method Attributes()
    { 
        @.InitialValues = @.Arguments;
        $.Variable = @.InitialValues.shift;
        $.Variable.Usage = 'variable';
        my $Value;
        for @.InitialValues -> $Value
        {
            $Value.Usage = 'value' if $Value.Usage eq 'initial';
        }
        unless defined($.Parent)
        {
            die "$.Name statement must have a parent variable context.";
        }
        $.Parent.AddType($.Variable.Text, $.Variable);
    }
}

class Definition_Statement is Scoped_Statement
{
    our $.Base_Class;
    our $.Gal_Keyword;
    has $.Parent_Class is rw;
    has Str $.Assignments is rw = "";
    has Str $.Declarations is rw = "";
    has @.Argument_Statements is rw;
    has Bool $.Generate_Attributes is rw;
    has $.Parent is rw;
    has $.Keyword is rw;
    has $.My_Name is rw;
    method Attributes()
    {
        $.My_Name = @.Arguments[0];
        $.Keyword = @.Arguments[1];
        if (@.Arguments.elems) > 2
        {
            $.Parent_Class = @.Arguments[2];
        }
    }
    method Gal_Generate()
    {
        my Str $Gal_Code = "class " ~ $.Base_Class ~ "_" ~ $.My_Name.Gal;
        if defined($.Parent_Class)
        {
            $Gal_Code ~= " [is " ~ $.Parent_Class.Gal ~ "_" ~ $.Base_Class ~ "]";
        }
        else 
        {
            $Gal_Code ~= " [is " ~ $.Base_Class ~ "]";
        }
        $Gal_Code ~= "\n\{\n    class\.property Gal_Keyword '" ~ $.Keyword.Gal ~ "';\n";
        if $.Block
        {
            $Gal_Code ~= $.Block.Statement_Gal;
        }
        if $.Generate_Attributes
        {
            my Str $Attribute_Statements = "";
            my $Statement;
            if $.Block
            {
                for $.Block.Statements -> $Statement
                {
                    if defined($Statement.Gal_Definition)
                    {
                        $Attribute_Statements ~= $Statement.Gal_Definition;
                    }
                }
                my Str $Attribute_Method = "method void Attributes\n\{\n" ~ $.Indent($Attribute_Statements) ~ "\}\n";
                $Gal_Code ~= $.Indent($Attribute_Method);
                #say 'Gal Code ', $Gal_Code;
            }
        }
        $Gal_Code ~= "\}";
        $.Gal = $Gal_Code;
    }
    method Prepare()
    {
        my $Statement;
        $.Generate_Attributes = True;
        if (defined($.Block)) && (defined($.Block.Statements))
        {
            for $.Block.Statements -> $Statement
            {
                if ($Statement ~~ Statement_Method) && ($Statement.MethodName.Text eq "Attributes")
                {
                    $.Generate_Attributes = False;
                }
                if ($Statement ~~ Argument_Statement)
                {
                    @.Argument_Statements.push($Statement);
                }
            }
        }
        #say "Definition_Statement.Prepare(): Generate_Attributes: ", $.Generate_Attributes;
    }
} 

class Statement_Statement is Definition_Statement
{
    our $.Gal_Keyword = "statement";
    our $.Base_Class = "Statement";
    has $.Parent_Class is rw;
} 
class Statement_Operation is Definition_Statement
{
    our $.Gal_Keyword = "operation";
    our $.Base_Class = "Operation";
    has $.Parent_Class is rw;
} 
class Statement_Syntax is Definition_Statement
{
    our $.Gal_Keyword = 'syntax';
    our $.Base_Class = 'Syntax';
    has $.Parent_Class is rw;
} 

class Statement_String is Multi_Declare_Statement
{
    our $.Gal_Keyword = 'string';
    our $.Raku_Type = 'Str';
    method Attributes()
    { 
        @.InitialValues = @.Arguments;
        $.Variable = @.InitialValues.shift;
        $.Variable.Usage = 'variable';
        $.Variable.DataType = 'string';
        my $Value;
        for @.InitialValues -> $Value
        {
            $Value.Usage = 'value' if $Value.Usage eq 'initial';
            $Value.DataType = 'string';
        }
        unless defined($.Parent)
        {
            die "$.Name statement must have a parent variable context.";
        }
        $.Parent.AddType($.Variable.Text, $.Variable);
    }
    method Raku_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $RakuArgs = "";
        my $Between = "";
        for @.Arguments -> $Argument
        {
            next unless $Argument.IsExpression();
            my $ArgRakuCode = $Argument.Raku;
            unless $ArgRakuCode
            {
                say "ERROR: Argument $Argument has no .Raku";
                say $Argument.Express();
            }
            if $RakuArgs eq ""
            {
                $RakuArgs = $ArgRakuCode;
                $Between = " = ";
            }
            elsif $ArgRakuCode.starts-with('"_') && $RakuArgs.ends-with('_"')
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs$Between$ArgRakuCode";
                $Between = " ~ ";
            }
            elsif $ArgRakuCode.starts-with('"') && $RakuArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                my $ArgTail = $ArgRakuCode.substr(1);
                $RakuArgs = "$RakuHead$ArgTail";
            }
            elsif $ArgRakuCode.starts-with('$') && !$ArgRakuCode.contains('.') && $RakuArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                $RakuArgs = "$RakuHead$ArgRakuCode\"";
            }
            else
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs$Between$ArgRakuCode";
                $Between = " ~ ";
            }
        }
        my Str $RakuCode = "$.RakuStatement $.Raku_Type $RakuArgs;";
        $.Raku = $RakuCode;
    }
    method Javascript_Generate()
    {
        my Str $VariableJS = $.Variable.Javascript;
        my Str $AssignmentJS = "";
        my $Argument;
        for @.InitialValues -> $Argument
        {
            my Str $ValueJS = $Argument.Javascript;
            if ($ValueJS.substr(0, 1)) eq "\""
            {
                $ValueJS = $ValueJS.substr(1, *-1);
            }
            else 
            {
                $ValueJS = "\$\{$ValueJS\}";
            }
            if $AssignmentJS eq ""
            {
                $AssignmentJS ~= " = `";
            }
            $AssignmentJS ~= $ValueJS;
        }
        if $AssignmentJS ne ""
        {
            $AssignmentJS ~= "`";
        }
        my Str $JSCode = "let $VariableJS$AssignmentJS;";
        $.Javascript = $JSCode;
    }
}

class Statement_List is Multi_Declare_Statement
{
    our $.Gal_Keyword = 'list';
    method Attributes()
    { 
        @.InitialValues = @.Arguments;
        $.Variable = @.InitialValues.shift;
        $.Variable.Usage = 'list';
        my $Value;
        for @.InitialValues -> $Value
        {
            $Value.Usage = 'value' if $Value.Usage eq 'initial';
        }
        $.Parent.AddType($.Variable.Text, $.Variable);
    }
    method Raku_Generate() 
    {
        my $RakuElems = "";
        my $Value;
        my $Between = "";
        for @.InitialValues -> $Value
        {
            my $ValueRaku = $Value.Raku;
            $RakuElems ~= "$Between$ValueRaku";
            $Between = ", ";
        }
        if $RakuElems gt ""
        {
            $RakuElems = " = $RakuElems";
        }
        my $VariableRaku = $.Variable.Raku;
        my $RakuCode = "$.RakuStatement $VariableRaku$RakuElems;";
        $.Raku = $RakuCode;
    }
    method Javascript_Generate()
    {
        my Str $VariableJS = $.Variable.Javascript;
        my Str $AssignmentJS = "";
        my $Argument;
        my Str $Between = " = [";
        for @.InitialValues -> $Argument
        {
            my Str $ValueJS = $Argument.Javascript;
            $AssignmentJS ~= $Between ~ $ValueJS;
            $Between = ", ";
        }
        if $AssignmentJS ne ""
        {
            $AssignmentJS ~= "]";
        }
        my Str $JSCode = "let $VariableJS$AssignmentJS;";
        $.Javascript = $JSCode;
    }
}

class Statement_List_Copy is Declare_Statement
{
    our $.Gal_Keyword = 'list.copy';
    method Attributes()
    { 
        my ($N, $V) = @.Arguments;
        $.Variable = $N;
        $.Variable.Usage = 'list';
        $.InitialValue = $V;
        $.InitialValue.Usage = 'list';
        $.Parent.AddType($.Variable.Text, $.Variable);
        $.Parent.AddType($.InitialValue.Text, $.InitialValue);
    }
    method Raku_Generate() 
    {
        my $VariableRaku = $.Variable.Raku;
        my $InitialValueRaku = $.InitialValue.Raku;
        my $RakuCode = "$.RakuStatement $VariableRaku = $InitialValueRaku;";
        $.Raku = $RakuCode;
    }
}

class Statement_Hash is Multi_Declare_Statement
{
    our $.Gal_Keyword = 'hash';
    method Attributes()
    { 
        @.InitialValues = @.Arguments;
        $.Variable = @.InitialValues.shift;
        $.Variable.Usage = 'hash';
        $.Parent.AddType($.Variable.Text, $.Variable);
    }
    method Raku_Generate() 
    {
        my $RakuElems = "";
        my $Value;
        my $Between = "";
        for @.InitialValues -> $Value
        {
            my $ValueRaku = $Value.Raku;
            $RakuElems ~= "$Between$ValueRaku";
            $Between = ", ";
        }
        if $RakuElems gt ""
        {
            $RakuElems = " = $RakuElems";
        }
        my $VariableRaku = $.Variable.Raku;
        my $RakuCode = "$.RakuStatement $VariableRaku$RakuElems;";
        $.Raku = $RakuCode;
    }
    method Javascript_Generate()
    {
        my Str $VariableJS = $.Variable.Javascript;
        my Str $AssignmentJS = "";
        my $Argument;
        my Str $Between = " = \{";
        for @.InitialValues -> $Argument
        {
            my Str $ValueJS = $Argument.Javascript;
            $AssignmentJS ~= $Between ~ $ValueJS;
            $Between = ", ";
        }
        if $AssignmentJS ne ""
        {
            $AssignmentJS ~= "\}";
        }
        my Str $JSCode = "let $VariableJS$AssignmentJS;";
        $.Javascript = $JSCode;
    }
}

class Statement_Index is Multi_Declare_Statement
{
    our $.Gal_Keyword = 'index';
    method Attributes()
    { 
        @.InitialValues = @.Arguments;
        $.Variable = @.InitialValues.shift;
        $.Variable.Usage = 'index';
        $.Parent.AddType($.Variable.Text, $.Variable);
    }
    method Raku_Generate() 
    {
        my $RakuElems = "";
        my $Value;
        my $Between = "";
        for @.InitialValues -> $Value
        {
            my $ValueRaku = $Value.Raku;
            $RakuElems ~= "$Between$ValueRaku";
            $Between = ", ";
        }
        if $RakuElems gt ""
        {
            $RakuElems = " = $RakuElems";
        }
        my $VariableRaku = $.Variable.Raku;
        my $RakuCode = "$.RakuStatement $VariableRaku$RakuElems;";
        $.Raku = $RakuCode;
    }
    method Javascript_Generate()
    {
        my Str $VariableJS = $.Variable.Javascript;
        my Str $AssignmentJS = "";
        my $Argument;
        my Str $Between = " = \{";
        for @.InitialValues -> $Argument
        {
            my Str $ValueJS = $Argument.Javascript;
            $AssignmentJS ~= $Between ~ $ValueJS;
            $Between = ", ";
        }
        if $AssignmentJS ne ""
        {
            $AssignmentJS ~= "\}";
        }
        my Str $JSCode = "let $VariableJS$AssignmentJS;";
        $.Javascript = $JSCode;
    }
}

class Statement_Integer is Declare_Statement 
{
    our $.Gal_Keyword = 'integer';
    our $.Raku_Type = 'Int';
}
class Statement_Number is Declare_Statement
{
    our $.Gal_Keyword = 'number';
    our $.Raku_Type = 'Real';
}
class Statement_Flag is Declare_Statement
{
    our $.Gal_Keyword = 'flag';
    our $.Raku_Type = 'Bool';
}
class Statement_Entity is Declare_Statement
{
    our $.Gal_Keyword = 'entity';
    our $.Raku_Type = '';
}
class Statement_Entities is Line_Statement
{
    our $.Gal_Keyword = "entities";
    method Gal_Generate()
    {
        my Str $Gal_Code = "";
        my Str $Between = "";
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Gal_Code ~= $Between ~ "entity " ~ $Argument.Gal ~ ";";
            $Between = "\n";
        }
        $.Gal = $Gal_Code;
    }
}
class Statement_Integers is Line_Statement
{
    our $.Gal_Keyword = "integers";
    method Gal_Generate()
    {
        my Str $Gal_Code = "";
        my Str $Between = "";
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Gal_Code ~= $Between ~ "integer " ~ $Argument.Gal ~ ";";
            $Between = "\n";
        }
        $.Gal = $Gal_Code;
    }
}
class Statement_Variant is Declare_Statement
{
    our $.Gal_Keyword = 'variant';
    our $.Raku_Type = '';
}
class Statement_Else is Scoped_Statement
{
    our $.Gal_Keyword = 'else';
    has $.RakuStatement = "else";
    has $.JSFunction = 'else';
    method Raku_Generate()
    {
        unless $.^lookup('RakuStatement')
        {
            #say "DELEGATING TO SCOPED_STATEMENT PARENT";
            nextsame;
            #say "DELEGATION COMPLETE";
            return;
        }
        my $RakuCode = "$.RakuStatement ";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode";
            #$Between = ", ";
            $Between = " ";
        }
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}
class Statement_Forgive is Scoped_Statement
{
    our $.Gal_Keyword = 'forgive';
    has $.RakuStatement = "try";
    method Raku_Generate()
    {
        unless $.^lookup('RakuStatement')
        {
            #say "DELEGATING TO SCOPED_STATEMENT PARENT";
            nextsame;
            #say "DELEGATION COMPLETE";
            return;
        }
        my $BlockRaku = $.Block.Raku;
        my $RakuCode = "$.RakuStatement$BlockRaku";
        $.Raku = $RakuCode;
    }
}

class Statement_Try is Scoped_Statement
{
    our $.Gal_Keyword = 'try';
    has $.RakuStatement = "try";
    has $.JSFunction = 'try';
    method Raku_Generate()
    {
        unless $.^lookup('RakuStatement')
        {
            #say "DELEGATING TO SCOPED_STATEMENT PARENT";
            nextsame;
            #say "DELEGATION COMPLETE";
            return;
        }
        my $RakuCode = "$.RakuStatement \{\n";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode";
            #$Between = ", ";
            $Between = " ";
        }
        $RakuCode ~= $.Block.Statement_Raku;
        $.Raku = $RakuCode;
    }
}

class Statement_Catch is Scoped_Statement
{
    our $.Gal_Keyword = 'catch';
    has $.RakuStatement = "CATCH";
    has $.JSFunction = 'catch';
    has $.Variable is rw;

    method Attributes()
    {
        if @.Arguments.elems > 0
        {
            $.Variable = @.Arguments[0];
            $.Variable.Usage = 'variable';
            $.Parent.AddType($.Variable.Text, $.Variable);
        }
    }

    method Raku_Generate()
    {
        unless $.^lookup('RakuStatement')
        {
            #say "DELEGATING TO SCOPED_STATEMENT PARENT";
            nextsame;
            #say "DELEGATION COMPLETE";
            return;
        }
        my $RakuCode = "$.RakuStatement \{ default \{\n";
        if (defined $.Variable)
        {
            my $VariableCode = $.Variable.Raku;
            $RakuCode ~= "    my $VariableCode = .Str;\n";
        }
        $RakuCode ~= $.Block.Statement_Raku;
        $RakuCode ~= "\} \} \}";
        $.Raku = $RakuCode;
    }
}

class Statement_ElseIf is Scoped_Statement
{
    our $.Gal_Keyword = 'else.if';
    has $.RakuStatement = "elsif";
    has $.JSFunction = 'else if';
    method Raku_Generate()
    {
        unless $.^lookup('RakuStatement')
        {
            #say "DELEGATING TO SCOPED_STATEMENT PARENT";
            nextsame;
            #say "DELEGATION COMPLETE";
            return;
        }
        my $RakuCode = "$.RakuStatement ";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode";
            #$Between = ", ";
            $Between = " ";
        }
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}

class Statement_Foreach is Scoped_Statement
{
    our $.Gal_Keyword = 'foreach';
    has $.RakuStatement = "for";
    has $.JSFunction = 'foreach_list';
    has Element $.Target is rw;
    has Element $.IterVar is rw;
    method Attributes()
    {
        $.Target = @.Arguments[0];
        $.Target.Usage = 'list';
        $.IterVar = @.Arguments[1];
        $.IterVar.Usage = 'variable';
    }
    method Raku_Generate()
    {
        my $TargetRaku = $.Target.Raku;
        my $IterVarRaku = $.IterVar.Raku;
        my $RakuCode = "$.RakuStatement $TargetRaku -> $IterVarRaku";
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
    method Javascript_Generate()
    {
        my Str $TargetJS = $.Target.Javascript;
        my Str $IterVarJS = $.IterVar.Javascript;
        my Str $BlockJS = "\{ \}";
        if (defined($.Block)) && (defined($.Block.Javascript))
        {
            $BlockJS = $.Block.Javascript;
        }
        my Str $JSCode = $TargetJS ~ "\.forEach\($IterVarJS => $BlockJS\);";
        self.Javascript = $JSCode;
    }
}

class Statement_For_Range is Scoped_Statement
{
    our $.Gal_Keyword = 'for.range';
    has $.RakuStatement = "for";
    has $.JSFunction = 'for_range';
    has Element $.IterVar is rw;
    has Element $.StartValue is rw;
    has Element $.EndValue is rw;
    method Attributes()
    {
        $.IterVar = @.Arguments[0];
        $.IterVar.Usage = 'variable';
        $.StartValue = @.Arguments[1];
        $.StartValue.Usage = 'value' if $.StartValue.Usage eq 'initial';
        $.EndValue = @.Arguments[2];
        $.EndValue.Usage = 'value' if $.EndValue.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $IterVarRaku = $.IterVar.Raku;
        my $StartRaku = $.StartValue.Raku;
        my $EndRaku = $.EndValue.Raku;
        my $RakuCode = "$.RakuStatement $StartRaku\.\.$EndRaku -> $IterVarRaku";
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}
class Statement_Hash_Foreach is Scoped_Statement
{
    our $.Gal_Keyword = 'hash.foreach';
    has $.RakuStatement = "for";
    has $.JSFunction = 'foreach_hash';
    has Element $.Target is rw;
    has Element $.IterVar is rw;
    method Attributes()
    {
        $.Target = @.Arguments[0];
        $.Target.Usage = 'hash';
        $.IterVar = @.Arguments[1];
        $.IterVar.Usage = 'variable';
    }
    method Raku_Generate()
    {
        my $TargetRaku = $.Target.Raku;
        my $IterVarRaku = $.IterVar.Raku;
        my $RakuCode = "$.RakuStatement $TargetRaku\.keys -> $IterVarRaku";
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}
class Statement_Foreachline is Scoped_Statement
{
    our $.Gal_Keyword = 'foreachline';
    has $.RakuStatement = "for";
    has $.JSFunction = 'foreach_line';
    has Element $.Target is rw;
    has Element $.IterVar is rw;
    method Attributes()
    {
        $.Target = @.Arguments[0];
        $.Target.Usage = 'value';
        $.IterVar = @.Arguments[1];
        $.IterVar.Usage = 'variable';
    }
    method Raku_Generate()
    {
        my $TargetRaku = $.Target.Raku;
        my $IterVarRaku = $.IterVar.Raku;
        my $RakuCode = "$.RakuStatement $TargetRaku\.lines -> $IterVarRaku";
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}
class Statement_Iterate is Scoped_Statement
{
    our $.Gal_Keyword = 'iterate';
    has $.RakuStatement = "for";
    has $.JSFunction = 'iterate';
    has Element $.Target is rw;
    has Element $.IterVar is rw;
    has Element $.ValueVar is rw;
    method Attributes()
    {
        $.Target = @.Arguments[0];
        $.Target.Usage = 'hash';
        $.IterVar = @.Arguments[1];
        $.IterVar.Usage = 'variable';
        $.ValueVar = @.Arguments[2];
        $.ValueVar.Usage = 'variable';
    }
    method Raku_Generate()
    {
        my $TargetRaku = $.Target.Raku;
        my $IterVarRaku = $.IterVar.Raku;
        my $ValueVarRaku = $.ValueVar.Raku;
        my $RakuCode = "$.RakuStatement $TargetRaku\.sort()\.map(*\.kv) -> ($IterVarRaku, $ValueVarRaku)";
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}
class Statement_New is Line_Statement 
{
    our $.Gal_Keyword = 'new';
    method Attributes()
    {
        my @Args = @.Arguments;
        my $Variable = @Args.shift();
        my $Class = @Args.shift();
        $Variable.Usage = 'variable';
        $Class.Usage = 'class';
        my $Arg;
        for @Args -> $Arg
        {
            if $Arg.Key
            {
                $Arg.Key.Usage = 'key';
            }
        }
    }
    method Raku_Generate()
    {
        my @Args = @.Arguments;
        my $Variable = @Args.shift();
        my $Class = @Args.shift();
        my $RakuArgs = "";
        my $Argument;
        my $Before = "";
        for @Args -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            if $RakuArgs eq ''
            {
                $RakuArgs = $ArgRaku;
                $Before = ", ";
            }
            else
            {
                $RakuArgs ~= "$Before$ArgRaku";
                $Before = ", ";
            }
        }
        my $VariableRaku = $Variable.Raku;
        my $ClassRaku = $Class.Raku;
        my $RakuCode = "$VariableRaku = $ClassRaku\.new\($RakuArgs\);";
        $.Raku = $RakuCode;
    }
}

class Statement_Entity_New is Line_Statement 
{
    our $.Gal_Keyword = 'entity.new';
    method Attributes()
    {
        my @Args = @.Arguments;
        my $Variable = @Args.shift();
        my $Class = @Args.shift();
        $Variable.Usage = 'variable';
        $Class.Usage = 'class';
        my $Arg;
        for @Args -> $Arg
        {
            if $Arg.Usage eq 'initial'
            {
                $Arg.Usage = 'variable';
            }
            if $Arg.Key
            {
                $Arg.Key.Usage = 'key';
            }
        }
    }
    method Raku_Generate()
    {
        #say "Entity New Begin";
        my @Args = @.Arguments;
        my $Variable = @Args.shift();
        my $Class = @Args.shift();
        my $RakuArgs = "";
        my $Argument;
        my $Before = "";
        for @Args -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            if $RakuArgs eq ''
            {
                $RakuArgs = $ArgRaku;
                $Before = ", ";
            }
            else
            {
                $RakuArgs ~= "$Before$ArgRaku";
                $Before = ", ";
            }
        }
        my $VariableRaku = $Variable.Raku;
        my $ClassRaku = $Class.Raku;
        my $RakuCode = "my $VariableRaku = $ClassRaku\.new\($RakuArgs\);";
        $.Raku = $RakuCode;
        #say $RakuCode;
        #say "Entity New End\n";
    }
}

class Statement_Propset is Line_Statement 
{
    our $.Gal_Keyword = '.=';
    has $.DataType is rw = '';
    method Attributes()
    {
        my $Type = @.Arguments[0].Text;
        if $Type eq 'list' || $Type eq 'hash' || $Type eq 'index'
        {
            $.DataType = $Type;
            @.Arguments.shift();
        }
        @.Arguments[0].Usage = "entity";
        @.Arguments[1].Usage = 'propref';
    }
    method Raku_Generate()
    {
        my $DestCode = "";
        my $Argument;
        my $Before = "";
        my $After = "";
        my @Args = @.Arguments;
        my $Object = @Args.shift();
        my $Value = @Args.pop();
        for @Args -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            if $DestCode eq ''
            {
                $DestCode = $ArgRaku;
            }
            else
            {
                $DestCode ~= "$Before$ArgRaku$After";
            }
            if $Before eq ''
            {
                $Before = '.';
                $After = '';
            }
            if $.DataType eq 'list'
            {
                $Before = '[';
                $After = ']';
            }
            elsif $.DataType eq 'hash' || $.DataType eq 'index'
            {
                $Before = '{';
                $After = '}';
            }
            else
            {
                $Before = '.';
                $After = '';
            }
        }
        my $ObjectRaku = $Object.Raku;
        $ObjectRaku = '$' if $ObjectRaku eq 'self';
        my $ValueRaku = $Value.Raku;
        my $Dot = '.';
        #$Dot = '!' if $ObjectRaku eq '$';
        my $RakuCode = "$ObjectRaku$Dot$DestCode = $ValueRaku;";
        #say "Raku Propset $ObjectRaku $DestCode $ValueRaku";
        $.Raku = $RakuCode;
    }
}

class Statement_I_Equals is Line_Statement 
{
    our $.Gal_Keyword = '.= self';
    has $.DataType is rw = '';
    has $.Property is rw;
    has $.Value is rw;
    method Attributes()
    {
        my @Args = @.Arguments;
        my $Property = @Args.shift();
        my $Name = $Property.Text;
        my $Type;
        if $Name eq 'list' || $Name eq 'hash' || $Name eq 'index'
        {
            $Type = $Property;
            $Property = @Args.shift();
        }
        else
        {
            $Type = $.Parent.Lookup($Name);
        }
        $Property.DataType = $Type;
        $Property.Usage = 'propref';
        $.Property = $Property;
        $.Value = @Args.shift();
        $Name = $.Value.Text;
        $Type = $.Parent.Lookup($Name);
        if $Type
        {
            $.Value.DataType = $Type;
        }
        # TODO: error on too many arguments?
    }
    method Raku_Generate()
    {
        my $PropertyRaku = $.Property.Raku;
        my $ValueRaku = $.Value.Raku;
        my $ObjectRaku = '$';
        my $PropertyType = $.Property.DataType;
        if $PropertyType eq 'list'
        {
            $ObjectRaku = '@';
        }
        elsif $PropertyType eq 'hash' || $PropertyType eq 'index'
        {
            $ObjectRaku = '%';
        }
        my $Code = $ObjectRaku ~ '.' ~ $PropertyRaku ~ ' = ' ~ $ValueRaku ~ ';';
        $.Raku = $Code;
    }
}

class Statement_Proplist is Line_Statement 
{
    our $.Gal_Keyword = 'property.list';
    has $.Class is rw;
    has $.Property is rw;
    method Attributes()
    {
        my ($Property, $Class) = @.Arguments;
        $.Property = $Property;
        $.Property.Usage = 'property list';
        if defined $Class
        {
            $.Class = $Class;
            $.Class.Usage = 'class';
        }
    }
    method Raku_Generate()
    {
        my $PropertyRaku = $.Property.Raku;
        my $ArgRaku = $PropertyRaku;
        if defined $.Class
        {
            my $ClassRaku = $.Class.Raku;
            $ArgRaku = "$ClassRaku $ArgRaku";
        }
        my $RakuCode = "has $ArgRaku is rw;";
        $.Raku = $RakuCode;
    }
}
class Statement_Classpropset is Line_Statement 
{
    our $.Gal_Keyword = 'classpropset';
    has $.DataType is rw = '';
    has Element $.Property is rw;
    has Element $.Value is rw;
    has Element $.Entity is rw;
    has @.Subscripts;
    method Attributes()
    {
        my @Args = @.Arguments;
        my $Type = @Args[0].Text;
        if $Type eq 'list' || $Type eq 'hash' || $Type eq 'index'
        {
            $.DataType = $Type;
            @Args.shift();
            $Type = "classprop $Type";
        }
        else
        {
            $Type = "classprop";
        }
        
        $.Entity = @Args.shift();
        $.Entity.Usage = $Type;
        $.Property = @Args.shift();
        $.Property.Usage = 'propref';
        $.Value = @Args.pop();
        $.Value.Usage = 'value' if $.Value.Usage eq 'initial';
        my $Argument;
        for @Args -> $Argument
        {
            $Argument.Usage = 'value' if $Argument.Usage eq 'initial';
        }
        @.Subscripts = @Args;
    }
    method Raku_Generate()
    {
        my $Before = "";
        my $After = "";
        if $.DataType eq 'list'
        {
            $Before = '[';
            $After = ']';
        }
        elsif $.DataType eq 'hash' || $.DataType eq 'index'
        {
            $Before = '{';
            $After = '}';
        }
        
        my $EntityRaku = $.Entity.Raku;
        if $EntityRaku.contains('.self')
        {
            $EntityRaku = $EntityRaku.subst('.self', '', :g);
        }
        my $PropertyRaku = $.Property.Raku;
        my $ValueRaku = $.Value.Raku;
        my $SubscriptRaku = "";
        for @.Subscripts -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            $SubscriptRaku ~= "$Before$ArgRaku$After";
        }
        my $RakuCode = "$EntityRaku\.$PropertyRaku$SubscriptRaku = $ValueRaku;";
        $.Raku = $RakuCode;
    }
}
class Statement_Return is Line_Statement 
{
    our $.Gal_Keyword = 'return';
    our $.RakuStatement = "return";
    has Element $.ReturnValue is rw;
    method Attributes()
    { 
        unless @.Arguments.elems <= 1
        {
            say "ERROR $.Gal_Keyword argument count: ", @.Arguments.elems;
        }
        if @.Arguments.elems > 0
        {
            $.ReturnValue = @.Arguments[0];
            $.ReturnValue.Usage = 'value' if $.ReturnValue.Usage eq 'initial';
        }
    }
    method Raku_Generate() 
    {
        if @.Arguments.elems == 0
        {
            $.Raku = "$.RakuStatement;";
        }
        else
        {
            my $ReturnCode = $.ReturnValue.Raku;
            my $RakuCode = "$.RakuStatement $ReturnCode;";
            $.Raku = $RakuCode;
        }
    }
}
class Statement_Contif is Line_Statement 
{
    our $.Gal_Keyword = 'contif';
    our $.RakuStatement = "next";
    has Element $.Condition is rw;
    method Attributes()
    { 
        $.Condition = @.Arguments[0];
        $.Condition.Usage = 'value';
    }
    method Raku_Generate() 
    { 
        my $ConditionCode = $.Condition.Raku;
        my $RakuCode = "$.RakuStatement if $ConditionCode;";
        $.Raku = $RakuCode;
    }
}

class Statement_Alias is Line_Statement
{
    our $.Gal_Keyword = "alias";
    method Gal_Generate()
    {
        my Str $Code = "class\.property string Aliases \"";
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Code ~= " " ~ $Argument.Gal;
        }
        $Code ~= " \";";
        $.Gal = $Code;
    }
}

class Statement_Continue is Line_Statement 
{
    our $.Gal_Keyword = 'continue';
    our $.RakuStatement = "next";
    method Raku_Generate() 
    { 
        my $RakuCode = "$.RakuStatement;";
        $.Raku = $RakuCode;
    }
}
class Statement_Breakif is Line_Statement 
{
    our $.Gal_Keyword = 'breakif';
    our $.RakuStatement = "last";
    has Element $.Condition is rw;
    method Attributes()
    { 
        $.Condition = @.Arguments[0];
        $.Condition.Usage = 'value';
    }
    method Raku_Generate() 
    { 
        my $ConditionCode = $.Condition.Raku;
        my $RakuCode = "$.RakuStatement if $ConditionCode;";
        $.Raku = $RakuCode;
    }
}
class Statement_Break is Line_Statement 
{
    our $.Gal_Keyword = 'break';
    our $.RakuStatement = "last";
    method Raku_Generate() 
    { 
        my $RakuCode = "$.RakuStatement;";
        $.Raku = $RakuCode;
    }
}
class Statement_Increment is Line_Statement 
{
    our $.Gal_Keyword = 'increment';
    has Element $.ReturnValue is rw;
    method Attributes()
    { 
        $.ReturnValue = @.Arguments[0];
        $.ReturnValue.Usage = 'value' if $.ReturnValue.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        my $ReturnCode = $.ReturnValue.Raku;
        my $RakuCode = "$ReturnCode++;";
        $.Raku = $RakuCode;
    }
}
class Statement_Know is Line_Statement 
{
    our $.Gal_Keyword = 'know';
    has Element $.Module is rw;
    method Attributes()
    { 
        $.Module = @.Arguments[0];
        $.Module.Usage = 'name' if $.Module.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        my $ModuleCode = $.Module.Raku;
        # need use require
        my $RakuVerb = 'use';
        my $RakuCode = "$RakuVerb $ModuleCode;";
        $.Raku = $RakuCode;
    }
}
class Statement_Module is Line_Statement 
{
    our $.Gal_Keyword = 'module';
    has Element $.Module is rw;
    method Attributes()
    { 
        $.Module = @.Arguments[0];
        $.Module.Usage = 'name' if $.Module.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        my $ModuleCode = $.Module.Raku;
        # need use require
        my $RakuVerb = 'unit module';
        my $RakuCode = "\n$RakuVerb $ModuleCode;\n";
        $.Raku = $RakuCode;
    }
}
class Statement_Decrement is Line_Statement 
{
    our $.Gal_Keyword = 'decrement';
    has Element $.ReturnValue is rw;
    method Attributes()
    { 
        $.ReturnValue = @.Arguments[0];
        $.ReturnValue.Usage = 'value' if $.ReturnValue.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        my $ReturnCode = $.ReturnValue.Raku;
        my $RakuCode = "$ReturnCode--;";
        $.Raku = $RakuCode;
    }
}
class Statement_Assign is Line_Statement 
{
    our $.Gal_Keyword = 'assign';
    has Element $.Variable is rw;
    has Element $.Value is rw;
    method Attributes() 
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
        $.Value = @.Arguments[1];
        $.Value.Usage = 'value' if $.Value.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        my $VariableCode = $.Variable.Raku;
        my $ValueCode = $.Value.Raku;
        my $RakuCode = "$VariableCode = $ValueCode;";
        $.Raku = $RakuCode;
    }
}
class Statement_Replace is Line_Statement 
{
    our $.Gal_Keyword = 'replace';
    has Element $.Variable is rw;
    has Element $.Search is rw;
    has Element $.Replace is rw;
    method Attributes() 
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
        $.Search = @.Arguments[1];
        $.Search.Usage = 'value' if $.Search.Usage eq 'initial';
        $.Replace = @.Arguments[2];
        $.Replace.Usage = 'value' if $.Replace.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        my $VariableCode = $.Variable.Raku;
        my $SearchCode = $.Search.Raku;
        my $ReplaceCode = $.Replace.Raku;
        my $RakuCode = "$VariableCode = $VariableCode\.subst($SearchCode, $ReplaceCode, :g);";
        $.Raku = $RakuCode;
    }
}
class Statement_Add is Line_Statement 
{
    our $.Gal_Keyword = 'add';
    has Element $.Variable is rw;
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'value' if $Argument.Usage eq 'initial';
        }
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
    }
    method Raku_Generate() 
    { 
        my $RakuCode = "";
        my $Between = "";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            $RakuCode ~= $Between ~ $ArgRaku;
            $Between = ($Between eq '') ?? " += " !! " + ";
        }
        $RakuCode ~= ";";
        $.Raku = $RakuCode;
    }
}
class Statement_Returnif is Line_Statement 
{
    our $.Gal_Keyword = 'returnif';
    has Element $.Condition is rw;
    has Element $.Value is rw;
    method Attributes() 
    {
        $.Condition = @.Arguments[0];
        $.Condition.Usage = 'value' if $.Condition.Usage eq 'initial';
        if @.Arguments.elems == 2
        {
            $.Value = @.Arguments[1];
            $.Value.Usage = 'value' if $.Value.Usage eq 'initial';
        }
    }
    method Raku_Generate() 
    { 
        my $ConditionCode = $.Condition.Raku;
        my $RakuCode;
        my $ValueCode = '';
        if defined($.Value)
        {
            $ValueCode = $.Value.Raku;
            $RakuCode = "return $ValueCode if $ConditionCode;";
        }
        else
        {
            $RakuCode = "return if $ConditionCode;";
        }
        $.Raku = $RakuCode;
    }
}
class Statement_Hash_Assign is Line_Statement 
{
    our $.Gal_Keyword = 'hash.assign';
    has Element $.Variable is rw;
    has Element $.Key is rw;
    has Element $.Value is rw;
    method Attributes() 
    {
        unless @.Arguments.elems == 3
        {
            say "ERROR $.Gal_Keyword argument count: ", @.Arguments.elems;
        }
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
        $.Key = @.Arguments[1];
        $.Key.Usage = 'value' if $.Key.Usage eq 'initial';
        $.Value = @.Arguments[2];
        $.Value.Usage = 'value' if $.Value.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        my $VariableCode = $.Variable.Raku;
        my $KeyCode = $.Key.Raku;
        my $ValueCode = $.Value.Raku;
        my $RakuCode = "$VariableCode\{$KeyCode\} = $ValueCode;";
        $.Raku = $RakuCode;
    }
}

class Statement_Hash_Delete is Line_Statement 
{
    our $.Gal_Keyword = 'hash.delete';
    has Element $.Variable is rw;
    has Element $.Key is rw;
    method Attributes() 
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
        $.Key = @.Arguments[1];
        $.Key.Usage = 'value' if $.Key.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        my $VariableCode = $.Variable.Raku;
        my $KeyCode = $.Key.Raku;
        my $RakuCode = "$VariableCode\{$KeyCode\}\:delete;";
        $.Raku = $RakuCode;
    }
}

class Statement_File_Slurp is Line_Statement 
{
    our $.Gal_Keyword = 'file.readall';
    has Element $.Variable is rw;
    has Element $.FileName is rw;
    method Attributes() 
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
        $.FileName = @.Arguments[1];
        $.FileName.Usage = 'value' if $.FileName.Usage eq 'initial';
    }
    method Raku_Generate() 
    {
        my $VariableCode = $.Variable.Raku;
        my $FileNameCode = $.FileName.Raku;
        my $FileSlurpCode = $FileNameCode ~ '.IO.slurp()';
        my $RakuCode = "$VariableCode = $FileSlurpCode;";
        $.Raku = $RakuCode;
    }
}

class Statement_File_Dump is Line_Statement 
{
    our $.Gal_Keyword = 'file.dump';
    has Element $.Variable is rw;
    has Element $.FileName is rw;
    method Attributes() 
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
        $.FileName = @.Arguments[1];
        $.FileName.Usage = 'value' if $.FileName.Usage eq 'initial';
    }
    method Raku_Generate() 
    {
        my $VariableCode = $.Variable.Raku;
        my $FileNameCode = $.FileName.Raku;
        my $RakuCode = "spurt $FileNameCode, $VariableCode;";
        $.Raku = $RakuCode;
    }
}

class Statement_List_Append is Line_Statement 
{
    our $.Gal_Keyword = 'list.append';
    has Element $.List is rw;
    has Element $.Value is rw;
    method Attributes() 
    {
        $.List = @.Arguments[0];
        $.List.Usage = 'list';
        $.Value = @.Arguments[1];
        $.Value.Usage = 'variable' if $.Value.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        my $ListCode = $.List.Raku;
        my $ValueCode = $.Value.Raku;
        my $RakuCode = "$ListCode\.push($ValueCode);";
        $.Raku = $RakuCode;
    }
}

class Statement_List_Splice is Line_Statement 
{
    our $.Gal_Keyword = 'list.splice';
    has Element $.List is rw;
    has Element $.Index is rw;
    has Element $.Count is rw;
    method Attributes() 
    {
        $.List = @.Arguments[0];
        $.List.Usage = 'list';
        $.Index = @.Arguments[1];
        $.Index.Usage = 'value' if $.Index.Usage eq 'initial';
        $.Count = @.Arguments[2];
        $.Count.Usage = 'value' if $.Count.Usage eq 'initial';
    }
    method Raku_Generate() 
    { 
        #todo "@.Containment.splice($Index, 1);";
        #list.splice [. self Containment] Index 1;
        my $ListCode = $.List.Raku;
        my $IndexCode = $.Index.Raku;
        my $CountCode = $.Count.Raku;
        my $RakuCode = "$ListCode\.splice\($IndexCode, $CountCode\);";
        $.Raku = $RakuCode;
    }
}
class Statement_Sort is Line_Statement 
{
    our $.Gal_Keyword = 'list.sort';
    has Element $.List is rw;
    has Element $.Method is rw;
    method Attributes() 
    {
        $.List = @.Arguments[0];
        $.List.Usage = 'list';
        if (@.Arguments.elems > 1)
        {
            $.Method = @.Arguments[1];
            $.Method.Usage = 'method';
        }
    }
    method Raku_Generate() 
    { 
        #todo "@.Containment.splice($Index, 1);";
        #list.splice [. self Containment] Index 1;
        my $ListCode = $.List.Raku;
        my $SortCode = '$^a cmp $^b';
        if defined($.Method)
        {
            my $MethodCode = $.Method.Raku;
            $SortCode = '$^a.' ~ $MethodCode ~ '($^b)';
        }
        my $RakuCode = "$ListCode = $ListCode\.sort: \{ $SortCode \};";
        $.Raku = $RakuCode;
    }
}

class Class_Statement is Scoped_Statement
{
    has $.RakuStatement = "class";
    has $.PythonStatement = 'class';
    has $.JSFunction = 'class';
    has Element $.ClassName is rw;
    has @.Ancestors;
    has %.ClassProperties;
    has %.Properties;
    has %.Methods;
    method MergeClass($Duplicate)
    {
        my $DupBlock = $Duplicate.Block;
        my $Statement;
        #say "            $.Gal_Keyword ", $.ClassName.Text, " merges ", $Duplicate.ClassName.Text;
        for $DupBlock.Statements -> $Statement
        {
            if ($Statement ~~ Statement_Classprop)
            {
                my $Name = $Statement.Property.Text;
                #say "                classprop $Name";
                %.ClassProperties{$Name} = $Statement;
            } 
            elsif ($Statement ~~ Statement_Property)
            {
                my $Name = $Statement.Property.Text;
                #say "                property $Name";
                %.Properties{$Name} = $Statement;
            }
            elsif ($Statement ~~ Statement_Method)
            {
                my $Name = $Statement.MethodName.Text;
                #say "                method $Name";
                %.Methods{$Name} = $Statement;
            }
            elsif ($Statement ~~ Statement_Constructor)
            {
                my $Name = 'constructor';
                %.Methods{$Name} = $Statement;
            }
        }
    }
    method Attributes()
    {
        $.ClassName = @.Arguments[0];
        $.ClassName.Usage = 'class';
        # TODO: [is ...] syntax appended to @.Ancestors.
        my $Statement;
        #say $.^name, ": ", $.ClassName.Text;
        if defined($.Block)
        {
            for $.Block.Statements -> $Statement
            {
                if ($Statement ~~ Statement_Classprop)
                {
                    my $Name = $Statement.Property.Text;
                    #say "    Classprop $Name";
                    %.ClassProperties{$Name} = $Statement;
                } 
                elsif ($Statement ~~ Statement_Property)
                {
                    my $Name = $Statement.Property.Text;
                    #say "    Property $Name";
                    %.Properties{$Name} = $Statement;
                }
                elsif ($Statement ~~ Statement_Method)
                {
                    my $Name = $Statement.MethodName.Text;
                    #say "    Method $Name";
                    %.Methods{$Name} = $Statement;
                }
                elsif ($Statement ~~ Statement_Constructor)
                {
                    my $Name = 'constructor';
                    %.Methods{$Name} = $Statement;
                }
            }
        }
    }
    method Gal_Generate()
    {
        my $GalCode = "$.Gal_Keyword";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            if $ArgCode.starts-with('[') and $GalCode.ends-with(']')
            {
                $GalCode = $GalCode.substr(0, *-1) ~ ", " ~ $ArgCode.substr(1);
            }
            else
            {
                $GalCode ~= " $ArgCode";
            }
        }
        if $.Block && $.Block.Gal
        {
            $GalCode ~= $.Block.Gal;
        }
        else
        {
            $GalCode ~= '; ';
        }
        $.Gal = $GalCode;
    }
    method Raku_Generate()
    {
        # TODO: support Ancestors.
        my $RakuCode = "$.RakuStatement ";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode";
            #$Between = ", ";
            $Between = " ";
        }
        if $.Block && $.Block.Raku
        {
            my $BlockCode = "";
            my $Statement;
            my $Name;
            for %.ClassProperties.keys.sort -> $Name
            {
                #say 'classprop ', $Name;
                $Statement = %.ClassProperties{$Name};
                if defined($Statement) && defined($Statement.Raku)
                {
                    $BlockCode = $BlockCode ~ $Statement.Raku ~ "\n";
                }
                else
                {
                    $BlockCode = $BlockCode ~ "# ERROR unknown statement raku.\n";
                }
            }
            # %.Properties{$Name}
            for %.Properties.keys.sort -> $Name
            {
                #say 'prop ', $Name;
                $Statement = %.Properties{$Name};
                if defined($Statement) && defined($Statement.Raku)
                {
                    $BlockCode = $BlockCode ~ $Statement.Raku ~ "\n";
                }
                else
                {
                    $BlockCode = $BlockCode ~ "# ERROR unknown statement raku.\n";
                }
            }
            for %.Methods.keys.sort -> $Name
            {
                #say 'method ', $Name;
                $Statement = %.Methods{$Name};
                if defined($Statement) && defined($Statement.Raku)
                {
                    $BlockCode = $BlockCode ~ $Statement.Raku ~ "\n";
                }
                else
                {
                    $BlockCode = $BlockCode ~ "# ERROR unknown statement raku.\n";
                }
            }
            $BlockCode = $.Block.Indent($BlockCode);
            $RakuCode ~= "\n\{\n$BlockCode\} ";
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}

class Statement_Class is Class_Statement
{
    our $.Gal_Keyword = 'class';
    has $.RakuStatement = "class";
    has $.ClassName is rw;
}
class Statement_Spell is Class_Statement
{
    our $.Gal_Keyword = 'spell';
    has $.RakuStatement = "class";
    has Element $.ClassName is rw;
    has @.Ancestors;
}
class Statement_Symbol is Statement_Spell
{
    our $.Gal_Keyword = 'symbol';
    has $.RakuStatement = "class";
    has Element $.ClassName is rw;
    has @.Ancestors;
}

class Statement_Interface is Statement_Spell
{
    our $.Gal_Keyword = 'interface';
}

class Statement_Group is Class_Statement
{
    our $.Gal_Keyword = 'group';
    has $.RakuStatement = "unit module";
    has Element $.ClassName is rw;
    has @.Ancestors;
    has @.ToGenerate;
    has %.ClassNames;
    method Attributes()
    {
        $.ClassName = @.Arguments[0];
        $.ClassName.Usage = 'class';
        my $Name = $.ClassName.Text;
        unless ($Name ~~ /^:/)
        {
            $Name = ':' ~ $Name;
        }
        # identify (or become) the canonical group.
        #say $.^name, ": $Name";
        my $CanonicalGroup;
        if (defined $.Document.Groups{$Name})
        {
            $CanonicalGroup = $.Document.Groups{$Name};
            #say "    Canonical: ", $CanonicalGroup.ClassName;
        }
        else
        {
            $CanonicalGroup = self;
            $.Document.Groups{$Name} = $CanonicalGroup;
            #say "    Registered Canonical.";
        }
        my $Statement;
        for $.Block.Statements -> $Statement
        {
            # add the components to the canonical group.
            $CanonicalGroup.AddStatement($Statement);
        }
    }
    method AddStatement($Statement)
    {
        $Statement.Group = self;
        if $Statement ~~ Class_Statement
        {
            my $Name = $Statement.ClassName.Text;
            unless ($Name ~~ /^:/)
            {
                $Name = ':' ~ $Name;
            }
            if (defined %.ClassNames{$Name})
            {
                #say "        $.Name ", $.ClassName.Text, " merges $Name";
                my $CanonicalClass = %.ClassNames{$Name};
                $CanonicalClass.MergeClass($Statement);
            }
            else
            {
                #say "        $.Name ", $.ClassName.Text, " adds $Name";
                %.ClassNames{$Name} = $Statement;
                @.ToGenerate.push($Statement);
            }
        }
    }
    method Gal_Generate()
    {
        my $GalCode = "$.Gal_Keyword";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            if $ArgCode.starts-with('[') and $GalCode.ends-with(']')
            {
                $GalCode = $GalCode.substr(0, *-1) ~ ", " ~ $ArgCode.substr(1);
            }
            else
            {
                $GalCode ~= " $ArgCode";
            }
        }
        if $.Block && $.Block.Gal
        {
            my $BlockCode = "";
            my $Statement;
            my $Name;
            for %.ClassProperties.keys.sort -> $Name
            {
                $Statement = %.ClassProperties{$Name};
                $Statement.Gal_Generate();
                $BlockCode = $BlockCode ~ $Statement.Gal ~ "\n";
            }
            # %.Properties{$Name}
            for %.Properties.keys.sort -> $Name
            {
                $Statement = %.Properties{$Name};
                $Statement.Gal_Generate();
                $BlockCode = $BlockCode ~ $Statement.Gal ~ "\n";
            }
            for %.Methods.keys.sort -> $Name
            {
                $Statement = %.Methods{$Name};
                $Statement.Gal_Generate();
                #say $Statement.Gal;
                $BlockCode = $BlockCode ~ $Statement.Gal ~ "\n";
            }
            for %.ClassNames.keys.sort -> $Name
            {
                $Statement = %.ClassNames{$Name};
                $Statement.Gal_Generate();
                #say $Statement.Gal;
                $BlockCode = $BlockCode ~ $Statement.Gal ~ "\n";
            }
            $BlockCode = $.Block.Indent($BlockCode);
            $GalCode ~= "\n\{\n$BlockCode\} ";
        }
        else
        {
            $GalCode ~= '; ';
        }
        $.Gal = $GalCode;
    }
    method Raku_Generate()
    {
        my $ClassNameRaku = $.ClassName.Raku;
        my $RakuCode = "$.RakuStatement $ClassNameRaku;\n\n";
        # Raku group block code is not indented
        my $Statement;
        for @.ToGenerate -> $Statement
        {
            my $StatementCode = $Statement.Raku;
            # TODO: raiseunless
            die "Unknown Statement Raku in Group: $Statement" unless defined $StatementCode;
            $RakuCode ~= "$StatementCode\n\n";
        }
        $.Raku = $RakuCode;
    }
}

class Statement_Goal is Statement_Group
{
    our $.Gal_Keyword = 'class';
    method Gal_Generate()
    {
        my $Argument;
        my @Args = @.Arguments;
        my $Class = @Args.shift;
        my $Class_Name = $Class.Gal;
        $Class_Name = "Group_$Class_Name";
        my $GalCode = "class $Class_Name";
        for @Args -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            if $ArgCode.starts-with('[') and $GalCode.ends-with(']')
            {
                $GalCode = $GalCode.substr(0, *-1) ~ ", " ~ $ArgCode.substr(1);
            }
            else
            {
                $GalCode ~= " $ArgCode";
            }
        }
        $GalCode ~= " [is Goal]";
        if $.Block && $.Block.Gal
        {
            my $BlockCode = "";
            my $Statement;
            my $Name;
            for %.ClassProperties.keys.sort -> $Name
            {
                $Statement = %.ClassProperties{$Name};
                $Statement.Gal_Generate();
                $BlockCode = $BlockCode ~ $Statement.Gal ~ "\n";
            }
            # %.Properties{$Name}
            for %.Properties.keys.sort -> $Name
            {
                $Statement = %.Properties{$Name};
                $Statement.Gal_Generate();
                $BlockCode = $BlockCode ~ $Statement.Gal ~ "\n";
            }
            for %.Methods.keys.sort -> $Name
            {
                $Statement = %.Methods{$Name};
                $Statement.Gal_Generate();
                #say $Statement.Gal;
                $BlockCode = $BlockCode ~ $Statement.Gal ~ "\n";
            }
            for %.ClassNames.keys.sort -> $Name
            {
                $Statement = %.ClassNames{$Name};
                $Statement.Gal_Generate();
                #say $Statement.Gal;
                $BlockCode = $BlockCode ~ $Statement.Gal ~ "\n";
            }
            $BlockCode = $.Block.Indent($BlockCode);
            $GalCode ~= "\n\{\n$BlockCode\} ";
        }
        else
        {
            $GalCode ~= '; ';
        }
        $.Gal = $GalCode;
    }
}

class Statement_Language is Definition_Statement
{
    our $.Gal_Keyword = "language";
    has $.Name is rw;
    method Attributes()
    {
        $.Name = @.Arguments[0];
    }
    method Gal_Generate()
    {
        my Str $Gal_Body = "property string Gal_Keyword '" ~ $.Name.Gal.lc() ~ "';\n" ~ $.Declarations;
        $Gal_Body = $.Indent($Gal_Body);
        if $.Block
        {
            $Gal_Body ~= $.Block.Statement_Gal;
        }
        my Str $Gal_Code = "class :" ~ $.Name.Gal ~ " [is :Language]\n\{\n$Gal_Body\}";
        $.Gal = $Gal_Code;
    }
    method Model() { } 
    method Prepare() { } 
} 

class Statement_Gal is Line_Statement
{
    method Gal_Generate()
    {
        my Str $Gal_Code = "method void Gal_Generate\n\{\n    string Gal_Code";
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Gal_Code ~= " " ~ $Argument.Gal;
        }
        $Gal_Code ~= ";\n    .= self Gal Gal_Code;\n\}";
        $.Gal = $Gal_Code;
    }
} 

class Statement_Fallback is Line_Statement
{
    method Gal_Generate()
    {
        my Str $Gal_Code = "method void Fallback_Generate\n\{\n    string Gal_Code";
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Gal_Code ~= " " ~ $Argument.Gal;
        }
        $Gal_Code ~= ";\n    .= self Fallback Gal_Code;\n\}";
        $.Gal = $Gal_Code;
    }
} 

class Statement_Javascript is Line_Statement
{
    method Gal_Generate()
    {
        my Str $Gal_Code = "method void Javascript_Generate\n\{\n    string Javascript_Code";
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Gal_Code ~= " " ~ $Argument.Gal;
        }
        $Gal_Code ~= ";\n    .= self Javascript Javascript_Code;\n\}";
        $.Gal = $Gal_Code;
    }
} 

class Statement_Mumps is Line_Statement
{
    method Gal_Generate()
    {
        my Str $Gal_Code = "method void Mumps_Generate\n\{\n    string Mumps_Code";
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Gal_Code ~= " " ~ $Argument.Gal;
        }
        $Gal_Code ~= ";\n    .= self Mumps Mumps_Code;\n\}";
        $.Gal = $Gal_Code;
    }
} 

class Statement_Python is Line_Statement
{
    method Gal_Generate()
    {
        my Str $Gal_Code = "method void Python_Generate\n\{\n    string Python_Code";
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Gal_Code ~= " " ~ $Argument.Gal;
        }
        $Gal_Code ~= ";\n    .= self Python Python_Code;\n\}";
        $.Gal = $Gal_Code;
    }
} 

class If_Statement is Scoped_Statement
{
    has Element $.Condition is rw;
    method Attributes()
    { 
        $.Condition = @.Arguments[0];
        $.Condition.Usage = 'value' if $.Condition.Usage eq 'initial';
    }
}

class Statement_If is If_Statement 
{
    our $.Gal_Keyword = 'if';
    has $.RakuStatement = "if";
    has $.JSFunction = 'if';
    method Raku_Generate()
    {
        unless $.^lookup('RakuStatement')
        {
            #say "DELEGATING TO SCOPED_STATEMENT PARENT";
            nextsame;
            #say "DELEGATION COMPLETE";
            return;
        }
        my $RakuCode = "$.RakuStatement ";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode";
            #$Between = ", ";
            $Between = " ";
        }
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}
class Statement_Unless is Scoped_Statement 
{
    our $.Gal_Keyword = 'unless';
    has $.RakuStatement = "unless";
    has $.JSFunction = 'unless';
    has Element $.Condition is rw;
    method Attributes()
    { 
        $.Condition = @.Arguments[0];
        $.Condition.Usage = 'value' if $.Condition.Usage eq 'initial';
    }
    method Gal_Generate()
    {
        my Str $Gal_Code = "if \(not " ~ $.Condition.Gal ~ "\) " ~ $.Block.Gal;
        $.Gal = $Gal_Code;
    }
    method Raku_Generate()
    {
        unless $.^lookup('RakuStatement')
        {
            #say "DELEGATING TO SCOPED_STATEMENT PARENT";
            nextsame;
            #say "DELEGATION COMPLETE";
            return;
        }
        my $RakuCode = "$.RakuStatement ";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode";
            #$Between = ", ";
            $Between = " ";
        }
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}
class Statement_While is Scoped_Statement 
{
    our $.Gal_Keyword = 'while';
    has $.RakuStatement = "while";
    has $.JSFunction = 'while';
    has Element $.Condition is rw;
    method Attributes()
    { 
        $.Condition = @.Arguments[0];
        $.Condition.Usage = 'value' if $.Condition.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        unless $.^lookup('RakuStatement')
        {
            #say "DELEGATING TO SCOPED_STATEMENT PARENT";
            nextsame;
            #say "DELEGATION COMPLETE";
            return;
        }
        my $RakuCode = "$.RakuStatement ";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Scoped Statement Argument $ArgCode";
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode";
            #$Between = ", ";
            $Between = " ";
        }
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}

class Statement_Method is Scoped_Statement 
{
    our $.Gal_Keyword = 'method';
    has $.RakuStatement = "method";
    has $.JSFunction = '';
    has Element $.MethodName is rw;
    has Element $.ReturnType is rw;
    has @.MethodArgs;
    method Attributes()
    {
        my @Args = @.Arguments;
        my $Arg = @Args.shift;
        my $NameText = $Arg.Text;
        if ",void,string,number,integer,flag,variant,entity,hash,list,index,".contains(",$NameText,")
        {
            $.ReturnType = $Arg;
            $.ReturnType.Usage = 'data_type';
            $Arg = @Args.shift;
        }
        $.MethodName = $Arg;
        $.MethodName.Usage = 'method';
        if (@Args.elems > 0)
        {
            @.MethodArgs = @Args.shift;
        }
    }
    method Raku_Generate()
    {
        # TODO: our $.SpellMethod = &(SomeClass.Implementor);
        my $RakuCode = "$.RakuStatement ";
        my $Argument;
        my $Between = "";
        my $After = "(";
        my @Args = @.Arguments;
        if @Args[0].Usage eq 'data_type'
        {
            my $DataType = @Args.shift();
            my $DtRaku = $DataType.Raku;
            # TODO: $RakuCode ~= "$DtRaku ";
        }
        for @Args -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Method Statement Argument $ArgCode";
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode$After";
            $Between = ", " unless $After gt "";
            $After = "";
        }
        $RakuCode ~= ')';
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}

class Statement_Constructor is Scoped_Statement 
{
    our $.Gal_Keyword = 'constructor';
    has $.RakuStatement = "submethod";
    has $.JSFunction = '';
    has Element $.MethodName is rw;
    has Element $.ReturnType is rw;
    has @.MethodArgs;
    method Attributes()
    {
        @.MethodArgs = @.Arguments;
        $.Block.Usage = 'constructor';
    }
    method Raku_Generate()
    {
        # TODO: our $.SpellMethod = &(SomeClass.Implementor);
        #my $RakuCode = "$.RakuStatement BUILD (";
        my $RakuCode = "method new (";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode";
            $Between = ", ";
        }
        $RakuCode ~= ')';
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}

class Statement_Verb is Statement_Method
{
    our $.Gal_Keyword = 'verb';
    has $.RakuStatement = 'verb'
}

class Statement_Handle is Scoped_Statement
{
    # TODO: make the gal name hierarchy accessible from here.
    our $.Gal_Keyword = 'handle';
    has $.RakuStatement = "method";
    has $.JSFunction = 'method';
    has Element $.Verb is rw;
    has Element $.HandleMethod is rw;
    has Element $.ReturnType is rw;
    has Element $.ClassName is rw;
    method Attributes()
    {
        $.Verb = $.Parent.Parent;
        $.HandleMethod = $.Verb.MethodName;
        $.ReturnType = $.Verb.ReturnType;
        if @.Arguments.elems != 1
        {
            say "ERROR handle argcount '@.Arguments.elems'";
        }
        $.ClassName = @.Arguments[0];
        # TODO: insert this element as a method in the class being handled.
    }
    method Raku_Generate()
    {
        my $ClassNameRaku = $.ClassName.Raku;
        my $RakuCode = "# class $ClassNameRaku\n$.RakuStatement ";
        my $Argument;
        my $Between = "";
        my $After = "(";
        my @Args = $.Verb.Arguments;
        if @Args[0].Usage eq 'data_type'
        {
            my $DataType = @Args.shift();
            my $DtRaku = $DataType.Raku;
            # TODO: $RakuCode ~ "$DtRaku ";
        }
        for @Args -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            #say "Method Statement Argument $ArgCode";
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode$After";
            $Between = ", " unless $After gt "";
            $After = "";
        }
        $RakuCode ~= ')';
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}

class Http_Statement is Scoped_Statement
{
    has $.JSFunction = 'fetch';
    method Attributes()
    {
        my Element $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'http';
        }
    }
    method Raku_Generate()
    {
        my @Arguments;
        my Element $Argument;
        my $RakuArgs = "";
        for @.Arguments -> $Argument
        {
            next unless $Argument.IsExpression();
            my $ArgRakuCode = $Argument.Raku;
            unless $ArgRakuCode
            {
                say "ERROR: Argument $Argument has no .Raku";
                say $Argument.Express();
            }
            if $RakuArgs eq ""
            {
                $RakuArgs = $ArgRakuCode;
            }
            elsif $ArgRakuCode.starts-with('"_') && $RakuArgs.ends-with('_"')
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs, $ArgRakuCode";
            }
            elsif $ArgRakuCode.starts-with('"') && $RakuArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                my $ArgTail = $ArgRakuCode.substr(1);
                $RakuArgs = "$RakuHead$ArgTail";
            }
            elsif $ArgRakuCode.starts-with('$') && !$ArgRakuCode.contains('.') && $RakuArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                $RakuArgs = "$RakuHead$ArgRakuCode\"";
            }
            else
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs, $ArgRakuCode";
            }
        }
        my Str $RakuCode = "$.RakuStatement $RakuArgs ";
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
}

class Statement_Http_Get is Http_Statement
{
    our $.Gal_Keyword = 'http.get';
    has $.RakuStatement = "get";
}

class Statement_Main is Scoped_Statement 
{
    our $.Gal_Keyword = 'main';
    has $.RakuStatement = "sub MAIN";
    has $.JSFunction = '';
    has @.MethodArgs is rw;
    method Attributes()
    {
        @.MethodArgs = @.Arguments;
        my $Arg;
        for @.MethodArgs -> $Arg
        {
            unless defined $Arg.Usage
            {
                $Arg.Usage = 'value';
            }
        }
    }
    method Raku_Generate()
    {
        my $RakuCode = $.RakuStatement ~ "(";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            next if $ArgCode eq '';
            $RakuCode ~= "$Between$ArgCode";
            $Between = ", ";
        }
        $RakuCode ~= ')';
        if $.Block && $.Block.Raku
        {
            $RakuCode ~= $.Block.Raku;
        }
        else
        {
            $RakuCode ~= ' { } ';
        }
        $.Raku = $RakuCode;
    }
    method Python_Generate()
    {
        my $PythonCode = "if __name__ == '__main__':\n";
        my $Argument;
        my $Between = "";
        my $PythonArguments = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Python;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            next if $ArgCode eq '';
            $PythonArguments ~= "$Between$ArgCode";
            $Between = ", ";
        }
        # TODO: PYTHON ARGUMENT CODE??
        if $.Block && $.Block.Python
        {
            $PythonCode ~= $.Block.Python;
        }
        else
        {
            $PythonCode ~= "    pass\n";
        }
        $.Python = $PythonCode;
    }
    method Mumps_Generate()
    {
        my $MumpsCode = "main";
        my $Argument;
        my $Between = "";
        my $MumpsArguments = "";
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Mumps;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Scoped Statement $Argument!>";
            }
            next if $ArgCode eq '';
            $MumpsArguments ~= "$Between$ArgCode";
            $Between = ", ";
        }
        if $MumpsArguments gt ''
        {
            $MumpsCode ~= '(' ~ $MumpsArguments ~ ')';
        }
        $MumpsCode ~= " ; main entry point\n";
        if $.Block && $.Block.Mumps
        {
            $MumpsCode ~= $.Block.Mumps;
        }
        $MumpsCode ~= "    quit\n";
        $.Mumps = $MumpsCode;
    }
    method Javascript_Generate()
    {
        my Str $JSCode = "";
        my $Argument;
        my Str $Between = "";
        my Str $JSArguments = "";
        for @.Arguments -> $Argument
        {
            my Str $ArgCode = $Argument.Javascript;
            unless defined($ArgCode)
            {
                $ArgCode = "<! ERROR UNDEFINED main Statement argument $Argument \.Javascript !>";
            }
            next if $ArgCode eq "";
            $JSArguments ~= $Between ~ $ArgCode;
            $Between = ", ";
        }
        if $JSArguments ne ""
        {
            $JSCode ~= "TODO_MAIN_ENTRY_POINT\($JSArguments\)\n";
        }
        if $.Block && $.Block.Javascript
        {
            if $JSCode ne ""
            {
                $JSCode ~= $.Block.Javascript;
            }
            else 
            {
                my $Statement;
                for $.Block.Statements -> $Statement
                {
                    my Str $StatementCode = $Statement.Javascript;
                    unless defined($StatementCode)
                    {
                        die "Unknown Statement Javascript in main: $Statement";
                    }
                    $JSCode ~= $StatementCode ~ "\n";
                }
            }
        }
        $.Javascript = $JSCode;
    }
}

class Statement_Property is Line_Statement 
{
    our $.Gal_Keyword = 'property';
    has $.DataType is rw;
    has $.ChildType is rw;
    has $.Property is rw;
    has $.InitialValue is rw;
    method Attributes() 
    {
        my ($Arg1, $Arg2, $Arg3) = @.Arguments;
        my $Contain = $Arg1.Text;
        if ",void,string,number,integer,flag,variant,entity,".contains(",$Contain,")
        {
            $.DataType = $Arg1;
            $.Property = $Arg2;
            $.InitialValue = $Arg3 if defined $Arg3;
        }
        elsif ",hash,list,index,".contains(",$Contain,")
        {
            # TODO: hash subscript and value types
            $.DataType = $Arg1;
            $.Property = $Arg2;
            if defined $Arg3
            {
                $.ChildType = $Arg3;
            }
        }
        elsif $Arg1.Text.contains(":")
        {
            $.DataType = $Arg1;
            $.Property = $Arg2;
            $.InitialValue = $Arg3 if defined $Arg3;
        }
        else
        {
            $.Property = $Arg1;
            $.InitialValue = $Arg2 if defined $Arg2;
        }
        if !defined $.DataType
        {
            $.Property.Usage = "property";
        }
        elsif $.DataType.Text eq 'list'
        {
            $.Property.Usage = "property list";
        }
        elsif $.DataType.Text eq 'hash'
        {
            $.Property.Usage = "property hash";
        }
        elsif $.DataType.Text eq 'index'
        {
            $.Property.Usage = "property index";
        }
        else
        {
            $.Property.Usage = "property";
        }
        if defined $.InitialValue
        {
            $.InitialValue.Usage = 'value';
            if defined $.DataType
            {
                $.InitialValue.DataType = $.DataType
            }
        }
        #say "Property Attributes $Contain ", $.Property.Text;
    }
    method Raku_Prepare() { }
    method Raku_Generate() 
    { 
        # TODO: list element type
        # TODO: hash subscript and value types
        my $DataType;
        if defined $.DataType
        {
            $DataType = $.DataType.Text;
        }
        else
        {
            $DataType = 'variant';
        }
        my $Type = self.Raku_Datatype($DataType);
        $Type = " $Type" if $Type gt '';
        my $Name = $.Property.Raku;
        my $Assignment = "";
        if defined $.InitialValue
        {
            $Assignment = " = " ~ $.InitialValue.Raku
        }
        my $RakuCode = "has$Type $Name is rw$Assignment;";
        $.Raku = $RakuCode;
    }
}

class Statement_Constant is Line_Statement 
{
    our $.Gal_Keyword = 'constant';
    has $.DataType is rw;
    has $.ChildType is rw;
    has $.Constant is rw;
    has $.InitialValue is rw;
    method Attributes() 
    {
        my ($Arg1, $Arg2, $Arg3) = @.Arguments;
        my $Contain = $Arg1.Text;
        if ",void,string,number,integer,flag,variant,entity,".contains(",$Contain,")
        {
            $.DataType = $Arg1;
            $.Constant = $Arg2;
            $.InitialValue = $Arg3 if defined $Arg3;
        }
        if ",hash,list,index,".contains(",$Contain,")
        {
            # TODO: hash subscript and value types
            $.DataType = $Arg1;
            $.Constant = $Arg2;
            if defined $Arg3
            {
                $.ChildType = $Arg3;
            }
        }
        elsif $Arg1.Text.contains(":")
        {
            $.DataType = $Arg1;
            $.Constant = $Arg2;
            $.InitialValue = $Arg3 if defined $Arg3;
        }
        else
        {
            $.Constant = $Arg1;
            $.InitialValue = $Arg2 if defined $Arg2;
        }
        if !defined $.DataType
        {
            $.Constant.Usage = "constant";
        }
        elsif $.DataType.Text eq 'list'
        {
            $.Constant.Usage = "constant list";
        }
        elsif $.DataType.Text eq 'hash'
        {
            $.Constant.Usage = "constant hash";
        }
        elsif $.DataType.Text eq 'index'
        {
            $.Constant.Usage = "constant index";
        }
        else
        {
            $.Constant.Usage = "constant";
        }
        $.Parent.AddType($.Constant.Text, $.Constant);
    }
    method Raku_Prepare() { }
    method Raku_Generate() 
    { 
        # TODO: list element type
        # TODO: hash subscript and value types
        my $DataType;
        if defined $.DataType
        {
            $DataType = $.DataType.Text;
        }
        else
        {
            $DataType = 'variant';
        }
        my $Type = self.Raku_Datatype($DataType);
        $Type = " $Type" if $Type gt '';
        my $Name = $.Constant.Raku;
        my $Assignment = "";
        if defined $.InitialValue
        {
            $Assignment = " = " ~ $.InitialValue.Raku
        }
        my $RakuCode = "constant $Name$Assignment;";
        $.Raku = $RakuCode;
    }
}

class Statement_Say is Append_Args_Statement
{
    our $.Gal_Keyword = 'writeline';
    has $.RakuStatement = "say";
    has $.PythonFunction = 'print';
    has $.MumpsStatement = 'write';
    has $.JSFunction = 'console.log';
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            #say $Argument.Express(), " begin";
            $Argument.Usage = 'value';
            #say $Argument.Express(), " middle";
            $Argument.DataType = 'string';
            #say $Argument.Express(), " end";
        }
    }

    method Mumps_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $MumpsArgs = "";
        for @.Arguments -> $Argument
        {
            next unless $Argument.IsExpression();
            my $ArgMumpsCode = $Argument.Mumps;
            unless $ArgMumpsCode
            {
                say "ERROR: Argument $Argument has no .Mumps";
                say $Argument.Express();
            }
            if $MumpsArgs eq ""
            {
                $MumpsArgs = $ArgMumpsCode;
            }
            else
            {
                # Append String Arguments into a comma-separated argument list.
                $MumpsArgs ~= ",$ArgMumpsCode";
            }
        }
        my Str $MumpsCode = $.MumpsStatement ~ ' ' ~ $MumpsArgs ~ ',!';
        $.Mumps = $MumpsCode;
    }
}

class Statement_Debug is Append_Args_Statement
{
    our $.Gal_Keyword = 'debug';
    has $.RakuStatement = "";
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'value';
            $Argument.DataType = 'string';
        }
    }
}

class Statement_Debug_Stack is Append_Args_Statement
{
    our $.Gal_Keyword = 'debug.stack';
    method Raku_Generate()
    { 
        my $RakuCode = 'say "Stack"; say ~Backtrace.new;';
        $.Raku = $RakuCode;
    }
}

class Statement_Debug_Variable is Append_Args_Statement
{
    our $.Gal_Keyword = 'debug.variable';
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'string';
            $Argument.DataType = 'string';
        }
    }
    method Raku_Generate
    {
        my $Argument;
        my $Code = 'try { say \'DV: \'';
        for @.Arguments -> $Argument
        {
            my $Text = $Argument.Raku;
            my $Unquoted = Unquote($Text);
            my $First = substr($Unquoted, 0, 1);
            my $Method = '';
            if ($First eq '$')
            {
                $Method = '.Str';
                #$Method = '.gist';
            }
            elsif ($First eq '@')
            {
                $Method = '.gist';
            }
            elsif ($First eq '%')
            {
                $Method = '.gist';
            }
            $Code ~= ", '$Unquoted: ', $Unquoted$Method";
        }
        $Code ~= '; } ';
        $.Raku = $Code;
    }
    method Raku_Generate_1
    {
        my $Argument;
        my $Code = 'try { ';
        for @.Arguments -> $Argument
        {
            my $Text = $Argument.Raku;
            my $Unquoted = Unquote($Text);
            $Code ~= "say $Text,':'; Dump($Unquoted, :skip-methods(True), :max-recursion(0));\n";
        }
        $Code ~= ' } ';
        $.Raku = $Code;
    }
}

class Statement_Log_Message is Append_Args_Statement
{
    our $.Gal_Keyword = 'log.message';
    has $.RakuStatement = "say";
    has $.PythonFunction = 'print';
    has $.MumpsStatement = 'write';
    has $.JSFunction = 'console.log';
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'value';
            $Argument.DataType = 'string';
        }
    }

    method Mumps_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $MumpsArgs = "";
        for @.Arguments -> $Argument
        {
            next unless $Argument.IsExpression();
            my $ArgMumpsCode = $Argument.Mumps;
            unless $ArgMumpsCode
            {
                say "ERROR: Argument $Argument has no .Mumps";
                say $Argument.Express();
            }
            if $MumpsArgs eq ""
            {
                $MumpsArgs = $ArgMumpsCode;
            }
            else
            {
                # Append String Arguments into a comma-separated argument list.
                $MumpsArgs ~= ",$ArgMumpsCode";
            }
        }
        my Str $MumpsCode = $.MumpsStatement ~ ' ' ~ $MumpsArgs ~ ',!';
        $.Mumps = $MumpsCode;
    }
}

class Statement_Raise is Append_Args_Statement
{
    our $.Gal_Keyword = 'raise';
    has $.RakuStatement = "die";
}
class Statement_License is Line_Statement
{
    our $.Gal_Keyword = 'license';
    has $.RakuStatement = "#LICENSE:";
    method Raku_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $RakuArgs = "";
        for @.Arguments -> $Argument
        {
            my $ArgRakuCode = $Argument.Raku;
            unless $ArgRakuCode
            {
                say "ERROR: Argument $Argument has no .Raku";
                say $Argument.Express();
            }
            $ArgRakuCode = Unquote($ArgRakuCode);
            if $RakuArgs eq ""
            {
                $RakuArgs = $ArgRakuCode;
            }
            else
            {
                $RakuArgs = "$RakuArgs $ArgRakuCode";
            }
        }
        my Str $RakuCode = "$.RakuStatement $RakuArgs";
        $.Raku = $RakuCode;
    }
}
class Statement_Comment is Line_Statement
{
    our $.Gal_Keyword = 'comment';
    has $.RakuStatement = "#";
    method Raku_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $RakuArgs = "";
        for @.Arguments -> $Argument
        {
            my $ArgRakuCode = $Argument.Raku;
            unless $ArgRakuCode
            {
                say "ERROR: Argument $Argument has no .Raku";
                say $Argument.Express();
            }
            #$ArgRakuCode = Unquote($ArgRakuCode);
            $ArgRakuCode = $ArgRakuCode.subst('\n', ' ', :g);
            $RakuArgs ~= " $ArgRakuCode";
        }
        my Str $RakuCode = "$.RakuStatement$RakuArgs";
        $.Raku = $RakuCode;
    }
}
class Statement_Todo is Line_Statement
{
    our $.Gal_Keyword = 'todo';
    has $.RakuStatement = "# TODO:";
    method Raku_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $RakuArgs = "";
        for @.Arguments -> $Argument
        {
            my $ArgRakuCode = $Argument.Raku;
            unless $ArgRakuCode
            {
                say "ERROR: Argument $Argument has no .Raku";
                say $Argument.Express();
            }
            $ArgRakuCode = Unquote($ArgRakuCode);
            if $RakuArgs eq ""
            {
                $RakuArgs = $ArgRakuCode;
            }
            else
            {
                $RakuArgs = "$RakuArgs $ArgRakuCode";
            }
        }
        my Str $RakuCode = "$.RakuStatement $RakuArgs";
        $.Raku = $RakuCode;
    }
}

class Statement_Definition is Line_Statement
{
    our $.Gal_Keyword = 'definition';
    has $.RakuStatement = "# DEFINITION:";
    method Raku_Generate() 
    {
        my @Arguments;
        my Element $Argument;
        my $RakuArgs = "";
        for @.Arguments -> $Argument
        {
            my $ArgRakuCode = $Argument.Raku;
            unless $ArgRakuCode
            {
                say "ERROR: Argument $Argument has no .Raku";
                say $Argument.Express();
            }
            $ArgRakuCode = Unquote($ArgRakuCode);
            if $RakuArgs eq ""
            {
                $RakuArgs = $ArgRakuCode;
            }
            else
            {
                $RakuArgs = "$RakuArgs $ArgRakuCode";
            }
        }
        my Str $RakuCode = "$.RakuStatement $RakuArgs";
        $.Raku = $RakuCode;
    }
}

class Statement_Invocation is Statement
{
    method Attributes()
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'value';
        }
    }
    method Gal_Generate()
    {
        my $GalCode = "$.Name";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            #say "Function Argument $ArgCode";
            $GalCode ~= " $ArgCode";
        }
        $GalCode ~= ";";
        $.Gal = $GalCode;
        #say "Gal $.^name Generated $.Gal";
    }
    method Raku_Generate()
    {
        #say "Raku Generate $.^name $.Name ...";
        my $MethodName = $.Name;
        #my $MethodName = $.Name.lc();
        my @Args = @.Arguments;
        my $Object = @Args.shift();
        my $ObjectRaku = $Object.Raku;
        my $RakuCode = $ObjectRaku ~ '.' ~ $MethodName ~ '(';
        my $Argument;
        my $Between = "";
        for @Args -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            $RakuCode ~= "$Between$ArgCode";
            $Between = ", ";
        }
        $RakuCode ~= ");";
        $.Raku = $RakuCode;
        #say "Raku $.^name Generated $.Raku";
    }
}

class Statement_Call is Line_Statement
{
    our $.Gal_Keyword = '.';
    has $.Object is rw;
    has $.Method is rw; 
    has @.Meth_Args is rw;
    method Attributes()
    {
        @.Meth_Args = @.Arguments;
        $.Object = @.Meth_Args.shift();
        $.Object.Usage = 'value';
        $.Method = @.Meth_Args.shift();
        $.Method.Usage = 'method';
        my $Argument;
        for @.Meth_Args -> $Argument
        {
            $Argument.Usage = 'value';
        }
        #say "Object ", $.Object.Text, ', Method ', $.Method.Text;
    }
    method Raku_Generate()
    {
        #say "Raku Generate $.^name $.Name ...";
        my $MethodName = $.Method.Raku;
        #my $MethodName = $MethodName.lc();
        my $ObjectRaku = $.Object.Raku;
        my $RakuCode = $ObjectRaku ~ '.' ~ $MethodName ~ '(';
        my $Argument;
        my $Between = "";
        for @.Meth_Args -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            $RakuCode ~= "$Between$ArgCode";
            $Between = ", ";
        }
        $RakuCode ~= ");";
        $.Raku = $RakuCode;
        #say "Raku $.^name Generated $.Raku";
    }
}

class Statement_I is Line_Statement
{
    our $.Gal_Keyword = '. self';
    has $.Method is rw;
    has @.Meth_Args is rw;
    method Attributes()
    {
        @.Meth_Args = @.Arguments;
        $.Method = @.Meth_Args.pop();
        $.Method.Usage = 'method';
        my $Argument;
        for @.Meth_Args -> $Argument
        {
            $Argument.Usage = 'value';
        }
    }
    method Raku_Generate()
    {
        #say "Raku Generate $.^name $.Name ...";
        my $MethodName = $.Method.Raku;
        #my $MethodName = $MethodName.lc();
        my $ObjectRaku = 'self';
        my $RakuCode = $ObjectRaku ~ '.' ~ $MethodName ~ '(';
        my $Argument;
        my $Between = "";
        for @.Meth_Args -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            $RakuCode ~= "$Between$ArgCode";
            $Between = ", ";
        }
        $RakuCode ~= ");";
        $.Raku = $RakuCode;
        #say "Raku $.^name Generated $.Raku";
    }
}

class Function_Invocation is Function
{
    # TODO: method invocation here.
    method Gal_Generate()
    {
        #say "Gal Generate $.^name \($.Name ...)";
        my $GalCode = "($.Name";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            #say "Function Argument $ArgCode";
            $GalCode ~= " $ArgCode";
        }
        $GalCode ~= ")";
        $.Gal = $GalCode;
    }
    method Raku_Generate()
    {
        my $MethodName = $.Name;
        my @Args = @.Arguments;
        my $Object = @Args.shift();
        my $ObjectRaku = $Object.Raku;
        if $ObjectRaku eq 'self'
        {
            $ObjectRaku = '$';
        }
        my $RakuCode = $ObjectRaku ~ '.' ~ $MethodName ~ '(';
        my $Argument;
        my $Between = "";
        for @Args -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            $RakuCode ~= "$Between$ArgCode";
            $Between = ", ";
        }
        $RakuCode ~= ")";
        $.Raku = $RakuCode;
    }
}

class Function_I is Function
{
    our $.Gal_Keyword = '. self';
    has $.Method is rw;
    has @.Meth_Args is rw;
    method Attributes()
    {
        @.Meth_Args = @.Arguments;
        $.Method = @.Meth_Args.pop();
        $.Method.Usage = 'method';
        my $Argument;
        for @.Meth_Args -> $Argument
        {
            $Argument.Usage = 'value';
        }
    }
    method Raku_Generate()
    {
        my $MethodName = $.Method.Raku;
        my $RakuCode = '$.' ~ $MethodName ~ '(';
        my $Argument;
        my $Between = "";
        for @.MethArgs -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            $RakuCode ~= "$Between$ArgCode";
            $Between = ", ";
        }
        $RakuCode ~= ")";
        $.Raku = $RakuCode;
    }
}

class Function_Dot is Function
{
    our $.Gal_Keyword = '.';
    method Attributes()
    {
        #say $.Express(), " begin";
        my @Args = @.Arguments;
        #say "Arglength? ";
        my $Object = @Args.shift();
        #say $Object.Express(), " object";
        $Object.Usage = 'value' if $Object.Usage eq 'initial';
        my $Method = @Args.shift();
        #say $Method.Express(), " method";
        $Method.Usage = 'method';
        my $Argument;
        for @Args -> $Argument
        {
            #say $Argument.Express(), " argument";
            $Argument.Usage = 'variable' if $Argument.Usage eq 'initial';
            #say $Argument.Express(), " arg success";
        }
        #say $.Express(), " end";
    }
    method Raku_Generate()
    {
        my @Args = @.Arguments;
        my $Object = @Args.shift();
        my $ObjectRaku = $Object.Raku;
        my $Method = @Args.shift();
        my $MethodName = $Method.Raku;
        my $RakuCode = $ObjectRaku ~ '.' ~ $MethodName ~ '(';
        my $Argument;
        my $Between = "";
        for @Args -> $Argument
        {
            my $ArgCode = $Argument.Raku;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            $RakuCode ~= "$Between$ArgCode";
            $Between = ", ";
        }
        $RakuCode ~= ")";
        $.Raku = $RakuCode;
    }
}

class Function_Split is Function
{
    our $.Gal_Keyword = 'split';
    has Element $.String is rw;
    has Element $.Delimiter is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
        $.String.DataType = 'string';
        $.Delimiter = @.Arguments[1];
        $.Delimiter.Usage = 'value' if $.Delimiter.Usage eq 'initial';
        $.Delimiter.DataType = 'string';
    }
    method Gal_Generate()
    {
        #say "Gal Generate $.^name \($.Name ...)";
        my $GalCode = "($.Gal_Keyword";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            #say "Function Argument $ArgCode";
            $GalCode ~= " $ArgCode";
        }
        $GalCode ~= ")";
        $.Gal = $GalCode;
    }
    method Raku_Generate()
    {
        my $StringRaku = $.String.Raku;
        my $DelimiterRaku = $.Delimiter.Raku;
        my $RakuCode = "split($DelimiterRaku, $StringRaku)";
        $.Raku = $RakuCode;
    }
}

class Function_Get is Function
{
    our $.Gal_Keyword = 'get';
    has Element $.Variable is rw;
    has Element $.Default is rw;
    method Attributes()
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
        $.Default = @.Arguments[1];
        $.Default.Usage = 'value' if $.Default.Usage eq 'initial';
    }
    method Gal_Generate()
    {
        #say "Gal Generate $.^name \($.Name ...)";
        my $GalCode = "($.Gal_Keyword";
        my $Argument;
        for @.Arguments -> $Argument
        {
            my $ArgCode = $Argument.Gal;
            unless defined $ArgCode
            {
                $ArgCode = "<! ERROR UNDEFINED Function $Argument!>";
            }
            #say "Function Argument $ArgCode";
            $GalCode ~= " $ArgCode";
        }
        $GalCode ~= ")";
        $.Gal = $GalCode;
    }
    method Raku_Generate()
    {
        my $VariableRaku = $.Variable.Raku;
        my $DefaultRaku = $.Default.Raku;
        # TODO: precedence
        my $RakuCode = "$VariableRaku\:exists ?? $VariableRaku !! $DefaultRaku";
        $.Raku = $RakuCode;
    }
}

class Function_Append is Function
{
    our $.Gal_Keyword = 'append';
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'value';
            $Argument.DataType = 'string';
        }
    }
    method Raku_Generate() 
    {
        return if $.Raku;
        my @Arguments;
        my Element $Argument;
        my $RakuArgs = "";
        my $Between = "";
        for @.Arguments -> $Argument
        {
            next unless $Argument.IsExpression();
            my $ArgRakuCode = $Argument.Raku;
            if $RakuArgs eq ""
            {
                if $ArgRakuCode.starts-with("\$")
                {
                    $RakuArgs = "\"$ArgRakuCode\"";
                }
                else
                {
                    $RakuArgs = $ArgRakuCode;
                }
                $Between = " ~ ";
            }
            elsif $ArgRakuCode.starts-with('"_') && $RakuArgs.ends-with('_"')
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs$Between$ArgRakuCode";
                $Between = " ~ ";
            }
            elsif $ArgRakuCode.starts-with('"') && $RakuArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                my $ArgTail = $ArgRakuCode.substr(1);
                $RakuArgs = "$RakuHead$ArgTail";
            }
            elsif $ArgRakuCode.starts-with('$') && !$ArgRakuCode.contains('.') && $RakuArgs.ends-with('"')
            {
                # Successive String Literal Consolidation.
                my $RakuHead = chop($RakuArgs);
                $RakuArgs = "$RakuHead$ArgRakuCode\"";
            }
            else
            {
                # Append String Arguments into a comma-separated argument list.
                $RakuArgs = "$RakuArgs$Between$ArgRakuCode";
                $Between = " ~ ";
            }
        }
        $.Raku = $RakuArgs;
    }
}

class Function_Keyexists is Function
{
    our $.Gal_Keyword = 'key.exists';
    method Attributes()
    {
        @.Arguments[0].Usage = 'hash';
    }
    method Raku_Generate()
    {
        my $RakuCode = "";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            if $RakuCode eq ''
            {
                $RakuCode = "$ArgRaku\{";
                $Between = "";
            }
            else
            {
                $RakuCode ~= "$Between$ArgRaku";
                $Between = "\}\{";
            }
        }
        $RakuCode ~= "\}:exists";
        $.Raku = $RakuCode;
    }
}

class Function_Dict_Get is Function
{
    our $.Gal_Keyword = 'dict.get';
    method Attributes()
    {
        @.Arguments[0].Usage = 'hash';
    }
    method Raku_Generate()
    {
        my $RakuCode = "";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            if $RakuCode eq ''
            {
                $RakuCode = "$ArgRaku\{";
                $Between = "";
            }
            else
            {
                $RakuCode ~= "$Between$ArgRaku";
                $Between = "\}\{";
            }
        }
        $RakuCode ~= "\}";
        $.Raku = $RakuCode;
    }
}

class Function_Classpropget is Function
{
    our $.Gal_Keyword = 'classpropget';
    has $.DataType is rw = '';
    has @.Listargs;
    method Attributes()
    {
        @.Listargs = @.Arguments;
        my $Type = @.Listargs[0].Text;
        if $Type eq 'list' || $Type eq 'hash' || $Type eq 'index'
        {
            $.DataType = $Type;
            @.ListArgs.shift();
            $Type = "classprop $Type";
        }
        else
        {
            $Type = "classprop";
        }
        @.Listargs[0].Usage = $Type;
    }
    method Raku_Generate()
    {
        my $RakuCode = "";
        my $Argument;
        my $Before = "";
        my $After = "";
        if $.DataType eq 'list'
        {
            $Before = '[';
            $After = ']';
        }
        elsif $.DataType eq 'hash' || $.DataType eq 'index'
        {
            $Before = '{';
            $After = '}';
        }
        for @.Listargs -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            if $RakuCode eq ''
            {
                $RakuCode = $ArgRaku;
            }
            else
            {
                $RakuCode ~= "$Before$ArgRaku$After";
            }
        }
        $.Raku = $RakuCode;
    }
}

class Syntax_False is Syntax
{
    our $.Gal_Keyword = 'false';
    has $.DataType is rw = 'flag';
    method Gal_Generate()
    {
        $.Gal = 'false';
    }
    method Raku_Generate()
    {
        $.Raku = 'False';
    }
}

class Syntax_Null is Syntax
{
    our $.Gal_Keyword = 'null';
    has $.DataType is rw = 'string';
    method Gal_Generate()
    {
        $.Gal = "null";
    }
    method Raku_Generate()
    {
        $.Raku = 'Nil';
    }
}

class Syntax_True is Syntax
{
    our $.Gal_Keyword = 'true';
    has $.DataType is rw = 'flag';
    method Gal_Generate()
    {
        $.Gal = 'true';
    }
    method Raku_Generate()
    {
        $.Raku = 'True';
    }
}

class Syntax_Self is Syntax
{
    our $.Gal_Keyword = 'self';
    has $.DataType is rw = 'entity';
    method Raku_Generate()
    {
        $.Raku = 'self';
    }
}

class Syntax_Class_Self is Syntax
{
    our $.Gal_Keyword = 'class.self';
    has $.DataType is rw = 'entity';
    method Raku_Generate()
    {
        $.Raku = 'self';
    }
}

class Syntax_Classprop is Syntax
{
    our $.Gal_Keyword = 'class.property';
    has $.DataType is rw = '';
    method Attributes()
    {
        my $Type = @.Arguments[0].Text;
        if $Type eq 'list' || $Type eq 'hash' || $Type eq 'index'
        {
            $.DataType = $Type;
            @.Arguments.shift();
            $Type = "classprop $Type";
        }
        else
        {
            $Type = "classprop";
        }
        @.Arguments[0].Usage = $Type;
    }
    method Raku_Generate()
    {
        my $RakuCode = "";
        my $Argument;
        my $Before = "";
        my $After = "";
        if $.DataType eq 'list'
        {
            $Before = '[';
            $After = ']';
        }
        elsif $.DataType eq 'hash' || $.DataType eq 'index'
        {
            $Before = '{';
            $After = '}';
        }
        for @.Arguments -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            if $RakuCode eq ''
            {
                $RakuCode = $ArgRaku;
            }
            else
            {
                $RakuCode ~= "$Before$ArgRaku$After";
            }
        }
        $.Raku = $RakuCode;
    }
}
class Function_New is Function
{
    our $.Gal_Keyword = 'new';
    has $.Type is rw;
    method Attributes()
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'value' if $Argument.Usage eq 'initial';
        }
        $.Type = @.Arguments[0];
        $.Type.Usage = "class";
    }
    method Raku_Generate()
    {
        my $RakuCode = "";
        my $Argument;
        my $Before = "";
        my $After = "";
        my @Args = @.Arguments;
        @Args.shift();
        for @Args -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            #say $ArgRaku;
            if $RakuCode eq ''
            {
                $RakuCode = $ArgRaku;
            }
            else
            {
                $RakuCode ~= ", $ArgRaku";
            }
        }
        my $TypeRaku = $.Type.Raku;
        #say "new $TypeRaku usage ", $.Type.Usage;
        $RakuCode = "$TypeRaku\.new\($RakuCode\)";
        $.Raku = $RakuCode;
    }
}
class Function_Propget is Function
{
    our $.Gal_Keyword = 'propget';
    has $.DataType is rw = '';
    has $.Entity is rw;
    has $.Property is rw;
    has @.Subscripts is rw;
    method Attributes()
    {
        my @Args = @.Arguments;
        my $Type = @Args[0].Text;
        if $Type eq 'list' || $Type eq 'hash' || $Type eq 'index'
        {
            $.DataType = $Type;
            @Args.shift();
            $Type = "property $Type";
        }
        else
        {
            $Type = "property";
        }
        $.Entity = @Args.shift();
        $.Entity.Usage = $Type;
        $.Property = @Args.shift();
        $.Property.Usage = 'propref';
        @.Subscripts = @Args;
        my $Arg;
        for @Args -> $Arg
        {
            $Arg.Usage = 'value' unless defined $Arg.Usage;
        }
    }
    method Raku_Generate()
    {
        my $Before = '';
        my $After = '';
        if $.DataType eq 'list'
        {
            $Before = '[';
            $After = ']';
        }
        elsif $.DataType eq 'hash' || $.DataType eq 'index'
        {
            $Before = '{';
            $After = '}';
        }
        my $EntRaku = $.Entity.Raku;
        if $EntRaku.contains('.self')
        {
            $EntRaku = $EntRaku.subst('.self', '', :g);
        }
        my $PropRaku = $.Property.Raku;
        my $RakuCode = $EntRaku ~ '.' ~ $PropRaku;
        my $Subscript;
        for @.Subscripts -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            $RakuCode ~= "$Before$ArgRaku$After";
        }
        $.Raku = $RakuCode;
    }
}

class Function_String is Function 
{
    our $.Gal_Keyword = 'string';
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'value';
            $Argument.DataType = 'string';
        }
    }
}
class Function_Number is Function 
{
    our $.Gal_Keyword = 'number';
}
class Function_Integer is Function 
{
    our $.Gal_Keyword = 'integer';
}
class Function_Variant is Function 
{
    our $.Gal_Keyword = 'variant';
}
class Function_Flag is Function 
{
    our $.Gal_Keyword = 'flag';
}
class Function_Entity is Function 
{
    our $.Gal_Keyword = 'entity';
}

class Function_Isa is Function 
{
    our $.Gal_Keyword = 'isa';
    has $.Raku_Precedence = 6;
    method Attributes() 
    {
        @.Arguments[0].Usage = 'variable';
        @.Arguments[1].Usage = 'class';
    }
    method Raku_Generate()
    {
        self.Raku_Binop('~~', 1);
    }
}
class Function_Indirect is Function
{
    our $.Gal_Keyword = 'indirect';
    has $.Target is rw;
    has @.IndirectArgs is rw;
    method Attributes()
    {
        @.IndirectArgs = @.Arguments;
        $.Target = @.IndirectArgs.shift;
    }
}
class Function_Add is Function 
{
    our $.Gal_Keyword = '+';
    has $.Raku_Precedence = 6;
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'value';
            $Argument.DataType = 'number';
        }
    }
    method Raku_Generate()
    {
        self.Raku_Binop('+');
    }
}
class Function_Multiply is Function 
{
    our $.Gal_Keyword = '*';
    has $.Raku_Precedence = 6;
    method Attributes() 
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'value';
            $Argument.DataType = 'number';
        }
    }
    method Raku_Generate()
    {
        self.Raku_Binop('*');
    }
}
class Function_Equal is Function
{
    our $.Gal_Keyword = '=';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        my $Operator = '==';
        self.Raku_Binop($Operator);
    }
}
class Function_StringEqual is Function
{
    our $.Gal_Keyword = 'string.eq';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        my $Operator = 'eq';
        self.Raku_Binop($Operator);
    }
}
class Function_NotEqual is Function
{
    our $.Gal_Keyword = '!=';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        my $Operator = '!=';
        if @.Arguments[0].DataType eq 'string'
        {
            $Operator = 'ne';
        }
        self.Raku_Binop($Operator);
    }
}
class Function_StringNotEqual is Function
{
    our $.Gal_Keyword = 'string.ne';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        my $Operator = 'ne';
        self.Raku_Binop($Operator);
    }
}
class Function_Less is Function
{
    our $.Gal_Keyword = 'lt';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('<');
    }
}
class Function_StringLess is Function
{
    our $.Gal_Keyword = 'string.lt';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('lt');
    }
}
class Function_StringGreater is Function
{
    our $.Gal_Keyword = 'string.gt';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('gt');
    }
}
class Function_StringLessEqual is Function
{
    our $.Gal_Keyword = 'string.le';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('le');
    }
}
class Function_StringGreaterEqual is Function
{
    our $.Gal_Keyword = 'string.ge';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('ge');
    }
}
class Function_Subtract is Function
{
    our $.Gal_Keyword = '-';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        if @.Arguments.elems == 1
        {
            self.Raku_Unaryop('-');
        }
        else
        {
            self.Raku_Binop('-');
        }
    }
}
class Function_Divide is Function
{
    our $.Gal_Keyword = '/';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('/');
    }
}
class Function_Modulo is Function
{
    our $.Gal_Keyword = '%';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('%');
    }
}
class Function_Greater is Function
{
    our $.Gal_Keyword = 'gt';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        #say self.Express();
        self.Raku_Binop('>');
    }
}
class Function_LessEqual is Function
{
    our $.Gal_Keyword = 'le';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('<=');
    }
}
class Function_GreaterEqual is Function
{
    our $.Gal_Keyword = 'ge';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('>=');
    }
}
class Function_Power is Function
{
    our $.Gal_Keyword = '^';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('**');
    }
}
class Function_And is Function
{
    our $.Gal_Keyword = '&';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('&&');
    }
}
class Function_Or is Function
{
    our $.Gal_Keyword = '|';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Binop('||');
    }
}
class Function_Not is Function
{
    our $.Gal_Keyword = '!';
    has $.Raku_Precedence = 6;
    method Raku_Generate()
    {
        self.Raku_Unaryop('!');
    }
}
class Function_Log is Function
{
    our $.Gal_Keyword = 'log';
    method Raku_Generate()
    {
        my $Argument = @.Arguments[0];
        my $ArgRaku = $Argument.Raku;
        my $RakuCode = "log($ArgRaku)";
        $.Raku = $RakuCode;
    }
}
class Function_Exp is Function
{
    our $.Gal_Keyword = 'exp';
    method Raku_Generate()
    {
        my $Argument = @.Arguments[0];
        my $ArgRaku = $Argument.Raku;
        my $RakuCode = "exp($ArgRaku)";
        $.Raku = $RakuCode;
    }
}

class Function_NotNull is Function
{
    our $.Gal_Keyword = 'notnull';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $Name = $.String.Raku;
        my $Tail = ' ne ""';
        self.Raku = "$Name$Tail";
    }
}

class Function_Isnull is Function
{
    our $.Gal_Keyword = 'string.isnull';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $Name = $.String.Raku;
        my $Tail = ' eq ""';
        self.Raku = "$Name$Tail";
    }
}

class Function_Defined is Function
{
    our $.Gal_Keyword = 'defined';
    has $.Raku_Precedence = 6;
    has $.Variable is rw;
    method Attributes()
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
    }
    method Raku_Generate()
    {
        my $VariableRaku = $.Variable.Raku;
        self.Raku = "defined($VariableRaku)";
    }
}

class Function_Firstchar is Function
{
    our $.Gal_Keyword = 'firstchar';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $Name = $.String.Raku;
        my $Tail = '.substr(0, 1)';
        self.Raku = "$Name$Tail";
    }
}
class Function_Contains is Function
{
    our $.Gal_Keyword = 'contains';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    has $.Substring is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
        $.Substring = @.Arguments[1];
        $.Substring.Usage = 'value' if $.Substring.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $StringRaku = $.String.Raku;
        my $SubstringRaku = $.Substring.Raku;
        self.Raku = "$StringRaku\.contains($SubstringRaku)";
    }
}
class Function_Lastchar is Function
{
    our $.Gal_Keyword = 'lastchar';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $Name = $.String.Raku;
        my $Tail = '.substr(*-1)';
        self.Raku = "$Name$Tail";
    }
}
class Function_Whitespace is Function
{
    our $.Gal_Keyword = 'whitespace';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $Name = $.String.Raku;
        my $RakuCode = "($Name " ~ '~~ m/\\s/)';
        self.Raku = $RakuCode;
    }
}
class Function_Lowercase is Function
{
    our $.Gal_Keyword = 'lower';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $Name = $.String.Raku;
        my $Tail = '.lc()';
        self.Raku = "$Name$Tail";
    }
}
class Function_Enquote is Function
{
    our $.Gal_Keyword = 'enquote';
    method Attributes()
    {
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Argument.Usage = 'string';
        }
    }
    method Raku_Generate()
    {
        my $Raku_Code = '';
        my $Between = '';
        my $Argument;
        for @.Arguments -> $Argument
        {
            $Raku_Code ~= $Between ~ $Argument.Raku;
            $Between = ' ~ ';
        }
        $Raku_Code = "Enquote($Raku_Code)";
        $.Raku = $Raku_Code;
    }
}
class Function_Uppercase is Function
{
    our $.Gal_Keyword = 'upper';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $Name = $.String.Raku;
        my $Tail = '.uc()';
        self.Raku = "$Name$Tail";
    }
}
class Function_List_Length is Function
{
    our $.Gal_Keyword = 'list.length';
    has $.Raku_Precedence = 6;
    has $.List is rw;
    method Attributes()
    {
        $.List = @.Arguments[0];
        $.List.Usage = 'list';
    }
    method Raku_Generate()
    {
        my $ListRaku = $.List.Raku;
        my $Tail = '.elems';
        self.Raku = "$ListRaku$Tail";
    }
}

class Function_List_Pop is Function
{
    our $.Gal_Keyword = 'pop';
    has $.Raku_Precedence = 6;
    has $.List is rw;
    method Attributes()
    {
        $.List = @.Arguments[0];
        $.List.Usage = 'list';
    }
    method Raku_Generate()
    {
        my $ListRaku = $.List.Raku;
        my $Tail = '.pop()';
        self.Raku = "$ListRaku$Tail";
    }
}

class Function_List_Shift is Function
{
    our $.Gal_Keyword = 'shift';
    has $.Raku_Precedence = 6;
    has $.List is rw;
    method Attributes()
    {
        $.List = @.Arguments[0];
        $.List.Usage = 'list';
    }
    method Raku_Generate()
    {
        my $ListRaku = $.List.Raku;
        my $Tail = '.shift()';
        self.Raku = "$ListRaku$Tail";
    }
}

class Function_List_Last is Function
{
    our $.Gal_Keyword = 'list.last';
    has $.Raku_Precedence = 6;
    has $.List is rw;
    method Attributes()
    {
        $.List = @.Arguments[0];
        $.List.Usage = 'list';
    }
    method Raku_Generate()
    {
        # @!Tokens[*-1]
        my $ListRaku = $.List.Raku;
        my $Tail = '[*-1]';
        self.Raku = "$ListRaku$Tail";
    }
}

class Function_List_First is Function
{
    our $.Gal_Keyword = 'list.first';
    has $.Raku_Precedence = 6;
    has $.List is rw;
    method Attributes()
    {
        $.List = @.Arguments[0];
        $.List.Usage = 'list';
    }
    method Raku_Generate()
    {
        # @!Tokens[*-1]
        my $ListRaku = $.List.Raku;
        my $Tail = '[0]';
        self.Raku = "$ListRaku$Tail";
    }
}

class Function_Middle is Function
{
    our $.Gal_Keyword = 'middle';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    has $.FrontCount is rw;
    has $.BackCount is rw;
    method Attributes()
    {
        if @.Arguments.elems != 3
        {
            say "ERROR (middle argcount ", @.Arguments.elems, ")";
        }
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
        $.FrontCount = @.Arguments[1];
        $.FrontCount.Usage = 'value' if $.FrontCount.Usage eq 'initial';
        $.BackCount = @.Arguments[2];
        $.BackCount.Usage = 'value' if $.BackCount.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $StringRaku = $.String.Raku;
        my $FrontRaku = $.FrontCount.Raku;
        my $BackRaku = $.BackCount.Raku;
        self.Raku = "$StringRaku\.substr($FrontRaku, *-$BackRaku)";
    }
}

class Function_Substring is Function
{
    our $.Gal_Keyword = 'substring';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    has $.StringStart is rw;
    has $.Length is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
        $.StringStart = @.Arguments[1];
        $.StringStart.Usage = 'value' if $.StringStart.Usage eq 'initial';
        $.Length = @.Arguments[2];
        if defined($.Length)
        {
            $.Length.Usage = 'value' if $.Length.Usage eq 'initial';
        }
    }
    method Raku_Generate()
    {
        my $StringRaku = $.String.Raku;
        my $StartRaku = $.StringStart.Raku;
        if defined($.Length)
        {
            my $LengthRaku = $.Length.Raku;
            self.Raku = "$StringRaku\.substr($StartRaku, $LengthRaku)";
        }
        else
        {
            self.Raku = "$StringRaku\.substr($StartRaku)";
        }
    }
}

class Function_Stringlength is Function
{
    our $.Gal_Keyword = 'string.length';
    has $.Raku_Precedence = 6;
    has $.String is rw;
    method Attributes()
    {
        $.String = @.Arguments[0];
        $.String.Usage = 'value' if $.String.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $StringRaku = $.String.Raku;
        self.Raku = "$StringRaku\.chars()";
    }
}

class Function_List_Get is Function
{
    our $.Gal_Keyword = 'list.get';
    has $.Raku_Precedence = 6;
    has $.List is rw;
    has $.Index is rw;
    method Attributes()
    {
        $.List = @.Arguments[0];
        $.List.Usage = 'list';
        $.Index = @.Arguments[1];
        $.Index.Usage = 'value' if $.Index.Usage eq 'initial';
    }
    method Raku_Generate()
    {
        my $ListRaku = $.List.Raku;
        my $IndexRaku = $.Index.Raku;
        self.Raku = "$ListRaku\[$IndexRaku\]";
    }
}


class Variable_Syntax is Syntax 
{
    our $.Gal_Keyword;
    has Str $.VariableName is rw;
    has $.Variable is rw;
    method Attributes()
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'variable';
        $.VariableName = $.Variable.Text;
        $.Parent.AddType($.VariableName, $.Variable);
    }
    method Raku_Generate() 
    { 
        my $Type = self.Raku_Datatype($.Gal_Keyword);
        my $Name = @.Arguments[0].Raku;
        if $.Parent ~~ Statement_Constructor
        {
            #say "Ignore Parent $.Parent type $Type...?";
            $Type = '';
            $Name = ":$Name";
        }
        my $Assignment = "";
        if @.Arguments.elems > 1
        {
            $Assignment = " = " ~ @.Arguments[1].Raku;
        }
        if $Type gt ''
        {
            $Type ~= ' ';
        }
        my $RakuCode = "$Type$Name$Assignment";
        $.Raku = $RakuCode;
    }
}

class Syntax_String is Variable_Syntax
{
    our $.Gal_Keyword = 'string';
}
class Syntax_Integer is Variable_Syntax
{
    our $.Gal_Keyword = 'integer';
}
class Syntax_Number is Variable_Syntax
{
    our $.Gal_Keyword = 'number';
}
class Syntax_Flag is Variable_Syntax
{
    our $.Gal_Keyword = 'flag';
}
class Syntax_List is Variable_Syntax
{
    our $.Gal_Keyword = 'list';
    method Attributes()
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'list';
        $.VariableName = $.Variable.Text;
        $.Parent.AddType($.VariableName, $.Variable);
    }
}
class Syntax_Hash is Variable_Syntax
{
    our $.Gal_Keyword = 'hash';
    method Attributes()
    {
        $.Variable = @.Arguments[0];
        $.Variable.Usage = 'hash';
        $.VariableName = $.Variable.Text;
        $.Parent.AddType($.VariableName, $.Variable);
    }
}
class Syntax_Dot is Syntax
{
    # this is an entity.property reference
    our $.Gal_Keyword = '.';
    has $.Entity is rw;
    has $.Property is rw;
    has @.Propchain is rw;
    method Attributes()
    {
        @.Propchain = @.Arguments;
        $.Entity = @.Propchain.shift;
        $.Entity.Usage = 'entity';
        $.Property = @.Propchain.shift;
        $.Property.Usage = 'propref';
        my $Element;
        for @.Propchain -> $Element
        {
            $Element.Usage = 'propref';
        }
    }
    method Raku_Generate() 
    {
        my $EntityRaku = $.Entity.Raku;
        if $EntityRaku eq 'self'
        {
            if @.Propchain.elems > 0
            {
                $EntityRaku = '$';
            }
            elsif $.Usage eq 'list'
            {
                $EntityRaku = '@';
            }
            elsif $.Usage eq 'hash' or $.Usage eq 'index'
            {
                $EntityRaku = '%';
            }
            else
            {
                $EntityRaku = '$';
            }
        }
        my $PropertyRaku = $.Property.Raku;
        my $RakuCode = "$EntityRaku\.$PropertyRaku";
        my $Element;
        for @.Propchain -> $Element
        {
            $PropertyRaku = $Element.Raku;
            $RakuCode ~= "\.$PropertyRaku";
        }
        #say "Syntax Dot $.Usage $EntityRaku $PropertyRaku";
        $.Raku = $RakuCode;
    }
}

class Syntax_I is Syntax
{
    # this is an entity.property reference
    our $.Gal_Keyword = '. self';
    has $.Property is rw;
    has @.Propchain is rw;
    method Attributes()
    {
        if @.Arguments.elems < 1
        {
            die 'Missing Argument List';
        }
        @.Propchain = @.Arguments;
        $.Property = @.Propchain.shift;
        $.Property.Usage = 'propref';
        my $Element;
        for @.Propchain -> $Element
        {
            $Element.Usage = 'propref';
        }
    }
    method Raku_Generate() 
    {
        my $EntityRaku = 'self';
        #if @.Propchain.elems > 0
        #{
        #    $EntityRaku = '$';
        #}
        #els
        if $.Usage eq 'list'
        {
            $EntityRaku = '@';
        }
        elsif $.Usage eq 'hash' or $.Usage eq 'index'
        {
            $EntityRaku = '%';
        }
        else
        {
            $EntityRaku = '$';
        }
        my $PropertyRaku = $.Property.Raku;
        my $RakuCode = "$EntityRaku\.$PropertyRaku";
        my $Element;
        for @.Propchain -> $Element
        {
            $PropertyRaku = $Element.Raku;
            $RakuCode ~= "\.$PropertyRaku";
        }
        #say "Syntax i $.Usage $EntityRaku $PropertyRaku";
        $.Raku = $RakuCode;
    }
}

class Syntax_Entity is Variable_Syntax
{
    our $.Gal_Keyword = 'entity';
}
class Syntax_Variant is Variable_Syntax
{
    our $.Gal_Keyword = 'variant';
}

class Syntax_Is is Syntax 
{
    our $.Gal_Keyword = 'is';
    our $.Raku_Keyword = 'is';
    has $.Class is rw;
    method Attributes()
    {
        my $ArgCount = @.Arguments.elems;
        return unless $ArgCount > 0;
        my $NameEntity = @.Arguments[0];
        if $NameEntity
        {
            #say "Class Entity $NameEntity";
            $NameEntity.Usage = 'class';
            $.Class = $NameEntity;
            die "IS Syntax doesn't have a parent!" unless $.Parent;
            $.Parent.Ancestors.push($.Class);
        }
    }
    method Raku_Generate()
    {
        my $ClassName = $.Class.Raku;
        $.Raku = "$.Raku_Keyword $ClassName";
        #say "Is Syntax Raku: '$.Raku', Classname '$ClassName'"
    }
}

class Syntax_Line is Syntax 
{
    our $.Gal_Keyword = 'line';
    has Int $.Count is rw = 1;
    method Attributes()
    {
        my $ArgCount = @.Arguments.elems;
        return unless $ArgCount > 0;
        my Element $CountEntity = @.Arguments[0];
        if $CountEntity
        {
            $.Count = Int($CountEntity.GetText());
        }
    }
    method Raku_Generate() 
    {
        my $Count = $.Count;
        my $Returns = "\\n" x $Count;
        $.Raku = "\"$Returns\"";
    }
}

class Syntax_Backslash is Syntax 
{
    our $.Gal_Keyword = 'backslash';
    has Int $.Count is rw = 1;
    method Attributes()
    {
        my $ArgCount = @.Arguments.elems;
        return unless $ArgCount > 0;
        my Element $CountEntity = @.Arguments[0];
        if $CountEntity
        {
            $.Count = Int($CountEntity.GetText());
        }
    }
    method Raku_Generate() 
    {
        my $Count = $.Count;
        my $Returns = "\\\\" x $Count;
        $.Raku = "\"$Returns\"";
    }
}

class Syntax_Indent is Syntax 
{
    our $.Gal_Keyword = 'indent';
    has Int $.Count is rw = 1;
    method Attributes()
    {
        my $ArgCount = @.Arguments.elems;
        return unless $ArgCount > 0;
        my Element $CountEntity = @.Arguments[0];
        if $CountEntity
        {
            my $Entity_Text = $CountEntity.GetText();
            #say "ENTITY TEXT: '$Entity_Text'";
            $.Count = Int($Entity_Text);
        }
    }
    method Raku_Generate() 
    {
        my $Count = $.Count;
        my $Indent = "    " x $Count;
        $.Raku = "\"$Indent\"";
    }
}
class Syntax_Classname is Syntax 
{
    our $.Gal_Keyword = 'class.name';
    has Element $.Entity is rw;
    method Attributes()
    {
        my Element $Entity = @.Arguments[0];
        $.Entity = $Entity;
    }
    method Gal_Generate()
    {
        my $EntityGal;
        if $.Entity
        {
            my $Entity = $.Entity;
            $EntityGal = ' ' ~ $Entity.Gal;
        }
        else
        {
            $EntityGal = '';
        }
        my $GalCode = "[$.Gal_Keyword$EntityGal]";
        $.Gal = $GalCode;
    }
    method Raku_Generate() 
    {
        my $EntityRaku;
        if $.Entity
        {
            my $Entity = $.Entity;
            $EntityRaku = $Entity.Raku;
        }
        else
        {
            $EntityRaku = '$';
        }
        $.Raku = "$EntityRaku\.^name";
    }
}

class Syntax_Key is Syntax
{
    our $.Gal_Keyword = 'key';
    method Attributes()
    {
        @.Arguments[0].Usage = 'hash';
    }
    method Raku_Generate()
    {
        my $RakuCode = "";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            if $RakuCode eq ''
            {
                $RakuCode = "$ArgRaku\{";
                $Between = "";
            }
            else
            {
                $RakuCode ~= "$Between$ArgRaku";
                $Between = "\}\{";
            }
        }
        $RakuCode ~= "\}";
        $.Raku = $RakuCode;
    }
}

class Syntax_Node is Syntax 
{
    our $.Gal_Keyword = 'node';
    method Attributes()
    {
        @.Arguments[0].Usage = 'list';
    }
    method Raku_Generate()
    {
        my $RakuCode = "";
        my $Argument;
        my $Between = "";
        for @.Arguments -> $Argument
        {
            my $ArgRaku = $Argument.Raku;
            if $RakuCode eq ''
            {
                $RakuCode = "$ArgRaku\[";
                $Between = "";
            }
            else
            {
                $RakuCode ~= "$Between$ArgRaku";
                $Between = "\]\[";
            }
        }
        $RakuCode ~= "\]";
        $.Raku = $RakuCode;
    }
}

class Syntax_Embed is Syntax 
{
    # NOTE: the embed syntax interpolates the target language code of the named property of the owner.
    # For example, in Raku [embed Argument] interpolates the .Raku of Owner.Argument at the correct precedence level.
    our $.Gal_Keyword = 'embed';
    has $.Argument is rw;
    method Attributes()
    {
        $.Argument = @.Arguments[0];
        $.Argument.Usage = 'property';
    }
    method Raku_Generate()
    {
        my $Argument = $.Argument;
        my $ArgProp = $.Owner.$Argument;
        my $RakuCode = $ArgProp.Raku;
        $.Raku = $RakuCode;
        $.RakuPrecedence = $ArgProp.RakuPrecedence;
    }
}

class Generator 
{
    method Gal_Generate($Document)
    {
        my $Element;
        for $Document.Elements -> $Element
        {
            #say "Gal Generating: ", $Element.Express();
            $Element.Gal_Generate();
        }
        my $GalCode = "";
        for $Document.Containment -> $Element
        {
            $GalCode ~= $Element.Gal ~ "\n";
        }
        $Document.Gal = $GalCode;
    }
    method Raku_Generate($Document)
    {
        my $Element;
        for $Document.Elements -> $Element
        {
            #say 'Raku Generating: ', $Element.Express();
            $Element.Raku_Generate();
        }
        my $RakuCode = "";
        for $Document.Containment -> $Element
        {
            #$Element.Raku_Generate();
            if !defined($Element.Raku) 
            {
                say $Element.^name, ' gal ', $Element.Gal, ' raku ', $Element.Raku;
            }
            $RakuCode ~= $Element.Raku ~ "\n";
        }
        $Document.Raku = $RakuCode;
    }
    method Python_Generate($Document)
    {
        my $Element;
        for $Document.Elements -> $Element
        {
            #say $Element.Express();
            $Element.Python_Generate();
        }
        my $PythonCode = "";
        for $Document.Containment -> $Element
        {
            $PythonCode ~= $Element.Python ~ "\n";
        }
        $Document.Python = $PythonCode;
    }
    method Mumps_Generate($Document)
    {
        my $Element;
        for $Document.Elements -> $Element
        {
            #say "Mumps Generating: ", $Element.Express();
            $Element.Mumps_Generate();
        }
        my $MumpsCode = "";
        for $Document.Containment -> $Element
        {
            $MumpsCode ~= $Element.Mumps ~ "\n";
        }
        $Document.Mumps = $MumpsCode;
    }
    method Javascript_Generate($Document)
    {
        my $Element;
        for $Document.Elements -> $Element
        {
            #say "JS Generating: ", $Element.Express();
            $Element.Javascript_Generate();
        }
        my Str $JSCode = "";
        for $Document.Containment -> $Element
        {
            $JSCode ~= $Element.Javascript ~ "\n";
        }
        $Document.Javascript = $JSCode;
    }
}

sub MAIN ( Str $file, Str $target 
         , Bool :x(:$xecute) = False
         , Bool :r(:$raku) = False
         , Bool :p(:$python) = False
         , Bool :j(:$javascript) = False
         , Bool :m(:$mumps) = False
         , Bool :c(:$cee) = False
         , Bool :g(:$gal) = False
         , Bool :v(:$verbose) = False
         )
{
    #say "TODO: support compiler/source directory for input files";
    #say "TODO: support compiler/bin directory for output files";
    say 'startup' if $verbose;
    my $Document = Document.new(FileName => $file);
    $Document.Read();
    if $verbose 
    { 
        say "Document Text:\n", $Document.Text; 
    }
    Parser.Tokenize($Document);
    #$Document.Dump(True);
    say "Parsing\n" if $verbose;
    Parser.Parse($Document);
    #$Document.Dump();
    say "Attributes" if $verbose;
    Parser.Attributes($Document);
    say "Document Prepare" if $verbose;
    Parser.Prepare($Document);
    #say "Document Dump";
    #$Document.Dump();
    $Document.Error_Report();
    if $gal
    {
        say "Generator Generating gal" if $verbose;
        Generator.Gal_Generate($Document);
        say "Document Generating gal" if $verbose;
        $Document.Gal_Generate();
        if $verbose
        {
            say "\ngal:\n", $Document.Gal; 
        }
        spurt($target, $Document.Gal);
    }
    if $raku
    {
        if $verbose {
            say "Generating raku";
            #$Document.Dump();
        }
        #$Document.Dump();
        Generator.Gal_Generate($Document);
        Generator.Raku_Generate($Document);
        $Document.Raku_Generate();
        if $verbose
        { 
            say "\nraku:\n", $Document.Raku; 
        }
        my $rakufile = Str($file.IO.extension('raku'));
        spurt($target, $Document.Raku);
        if $xecute
        {
            if $verbose {
                say "Executing raku";
            }
            my $exitcode = shell("rakudo $target");
            if $verbose {
                say "Exit code: $exitcode";
            }
        }
    }
    if $python
    {
        say "Generating Python" if $verbose;
        #$Document.Dump();
        Generator.Python_Generate($Document);
        if $verbose
        { 
            say "\nPython:\n", $Document.Python; 
        }
        my $pythonfile = Str($file.IO.extension('py'));
        spurt($target, $Document.Python);
        if $xecute
        {
            if $verbose {
                say "Executing python";
            }
            my $exitcode = shell("python $target");
            if $verbose {
                say "Exit code: $exitcode";
            }
        }
    }
    if $javascript
    {
        if $verbose {
            say "Generating Javascript";
        }
        #$Document.Dump();
        Generator.Javascript_Generate($Document);
        if $verbose
        { 
            say "\nJavascript:\n", $Document.Javascript; 
        }
        my $javascriptfile = Str($file.IO.extension('py'));
        spurt($target, $Document.Javascript);
        if $xecute
        {
            if $verbose {
                say "Executing node.js";
            }
            my $exitcode = shell("node $target");
            if $verbose {
                say "Exit code: $exitcode";
            }
        }
    }
    if $mumps
    {
        if $verbose {
            say "Generating Mumps";
            #$Document.Dump();
        }
        Generator.Mumps_Generate($Document);
        if $verbose
        { 
            say "\nMumps:\n", $Document.Mumps; 
        }
        my $mumpsfile = Str($file.IO.extension('m'));
        spurt($target, $Document.Mumps);
        if $xecute
        {
            my $exitcode = shell("mumps $target");
            if $verbose {
                say "Exit code: $exitcode";
            }
        }
    }
    if $cee
    {
        if $verbose {
            say "Generating C";
        }
        $Document.Dump();
        Generator.C_Generate($Document);
        if $verbose
        { 
            say "\nC:\n", $Document.C; 
        }
        my $ceefile = Str($file.IO.extension('c'));
        spurt($target, $Document.C);
        if $xecute
        {
            my $exitcode = shell("TODO gcc $target");
            if $verbose {
                say "Exit code: $exitcode";
            }
        }
    }
}

