#** @file Moon.pm
package Doxygen::Filter::Moon;

use warnings;
use strict;
use parent qw(Doxygen::Filter);
use Log::Log4perl;
use IO::Handle;
use File::Slurp;

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';
$VERSION = eval $VERSION;


my $validStates = {
    'NORMAL'         => 0,
    'COMMENT'        => 1,
    'DOXYGEN'        => 2,
    'METHOD'         => 3,
    'CLASS'          => 4,
    'DOXYFILE'       => 21,
    'DOXYCLASS'      => 22,
    'DOXYFUNCTION'   => 23,
    'DOXYMETHOD'     => 24,
    'DOXYCOMMENT'    => 25,
};

my $flags = {
    'isMoonClassDefinedInFile' => 0
};


=head2 SUBROUTINES/METHODS

=head1 new

This function will create a Doxygen::Moon object.

=cut

sub new
{
    #** @method private new ()
    # This is the constructor and it calls _init() to initiate
    # the various variables
    #*
    my $pkg = shift;
    my $module = ref($pkg) || $pkg;

    my $self = {};
    bless ($self, $module);

    $self->{'_iDebug'}           = 0;

    my $logger = $self->GetLogger($self);

    $logger->debug("=== Entering New ===");
    $logger->info("Class : $module\n");

    # Lets send any passed in arguments to the _init method
    $self->_init(@_);
    return $self;
}

sub DESTROY
{
    #** @method private DESTROY ()
    # This is the destructor
    #*
    my $self = shift;
    $self = {};
}

sub RESETSUB
{
    my $self = shift;
    $self->{'_sCurrentMethodName'}  = undef;
    $self->{'_currentIndentLevel'}  = 0;
    $self->{'_sCurrentMethodType'}  = undef;
    $self->{'_sCurrentMethodState'} = undef;
}

sub RESETFILE  { my $self = shift; $self->{'_aRawFileData'}   = []; $self->{'_aUncommentFileData'}   = [];   }

sub RESETMODULE
{
    my $self = shift;
    #$self->{'_sCurrentClass'}  = 'main';
    #push (@{$self->{'_hData'}->{'class'}->{'classorder'}}, 'main');
    $self->_SwitchModule('main');
}

sub RESETDOXY  { shift->{'_aDoxygenBlock'}  = [];    }

sub _init
{
    my $self = shift;
    my $module = shift;
    $self->{'_sState'}          = undef;
    $self->{'_sPreviousState'}  = [];
    $self->_ChangeState('NORMAL');
    $self->{'_hData'}           = {};
    $self->RESETFILE();
    $self->RESETMODULE();
    $self->RESETSUB();
    $self->RESETDOXY();
}

sub _RestoreState { shift->_ChangeState(); }
sub _ChangeState
{
    #** @method private _ChangeState ($state)
    # This method will change and keep track of the various states that the state machine
    # transitions to and from. Having this information allows you to return to a previous
    # state. If you pass nothing in to this method it will restore the previous state.
    # @param state - optional string (state to change to)
    #*

    my $self = shift;
    my $state = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("=== Entering _ChangeState ===");

    if (defined $state && exists $validStates->{$state})
    {
        $logger->debug("State pased in: $state");
        unless (defined $self->{'-sState'} && $self->{'_sState'} eq $state)
        {
            # Need to push the current state to the array BEFORE we change it and only
            # if we are not currently at that state
            push (@{$self->{'_sPreviousState'}}, $self->{'_sState'});
            $self->{'_sState'} = $state;
        }
    }
    else
    {
        # If nothing is passed in, lets set the current state to the previous state.
        $logger->debug("No state passed in, lets revert to previous state");
        my $previous = pop @{$self->{'_sPreviousState'}};
        if (defined $previous)
        {
            $logger->debug("Previous state was $previous");
        }
        else
        {
            $logger->error("There is no previous state! Setting to NORMAL");
            $previous = 'NORMAL';
        }
        $self->{'_sState'} = $previous;
    }
}

sub _RemoveMoonComments
{
    my $Data = shift;

    # Remove single-line comments (starting with --)
    $Data =~ s/--.*//g;

    # Remove multi-line comments (starting with --[[ and ending with --]])
    $Data =~ s/--\[\[.*?--\]\]//gs;

    return $Data;
}

sub ReadFile
{
    my $self = shift;
    my $sFilename = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("=== Entering ReadFile ===");
    $logger->debug("=== Entering ReadFile ===");

    # Lets record the file name in the data structure
    $self->{'_hData'}->{'filename'}->{'fullpath'} = $sFilename;

    # Replace forward slash with a black slash
    $sFilename =~ s/\\/\//g;
    # Remove windows style drive letters
    $sFilename =~ s/^.*://;

    # Lets grab just the file name not the full path for the short name
    $sFilename =~ /^(.*\/)*(.*)$/;
    $self->{'_hData'}->{'filename'}->{'shortname'} = $2;

    my $aFileData = read_file($sFilename);
    $aFileData =~ s/\r$//g;
    my @aRawFileData= split /(?<=\n)/, $aFileData;
    $self->{'_aRawFileData'} = \@aRawFileData;
    $self->{'_decommentOK'} = 1;

    my @aUncommentFileData;
    my $aUncommentFileData_tmp;

    $aUncommentFileData_tmp = _RemoveMoonComments($aFileData);
    @aUncommentFileData = split /(?<=\n)/, $aUncommentFileData_tmp;
    $self->{'_aUncommentFileData'} = \@aUncommentFileData;
}

sub _DetectMoonClass
{
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("=== Entering _DetectMoonClass ===");

    foreach my $line (@{$self->{'_aRawFileData'}})
    {
        if ($line =~  /^\s*class\s+(\w+)\s+extends\s+(\w+)?\s*$/ || ($line =~  /^\s*class\s+(\w+)/))
        {
            if (defined($2))
            {
                $self->_SwitchModule($2 . "::" . $1);
            }
            else
            {
                $self->_SwitchModule($1);
            }
            $flags->{'isMoonClassDefinedInFile'} = 1;
            last;
        }
    }
}

sub ProcessFile
{
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("=== Entering ProcessFile ===");

    $self->_DetectMoonClass();

    $self->{'_hData'}->{'lineNo'} = 0;
    foreach my $line (@{$self->{'_aRawFileData'}})
    {
        my $uncommentLine = $self->{'_aUncommentFileData'}[$self->{'_hData'}->{'lineNo'}];
        $self->{'_hData'}->{'lineNo'}++;

        # Convert syntax block header to supported doxygen form, if this line is a header
        $line = $self->_ConvertToOfficialDoxygenSyntax($line);

        if ($self->{'_sState'} eq 'NORMAL')
        {
            if ($line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*->/ or $line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*=>/)
            {
                $self->_ChangeState('METHOD');
            }
            elsif ($line =~ /^\s*class\s+\w+(\s+extends\s+\w+)?\s*$/)
            {
                $self->_ChangeState('CLASS');
            }
            elsif ($line =~ /^\s*--\*\*\s*\@/)
            {
                $self->_ChangeState('DOXYGEN');
            }
        }
        elsif ($self->{'_sState'} eq 'METHOD')
        {
            $logger->debug("We are in state: METHOD");
            if ($line =~ /^\s*--\*\*\s*\@/ ) {
              $self->_ChangeState('DOXYGEN');
            }
        }
        elsif ($self->{'_sState'} eq 'CLASS')
        {
            $logger->debug("We are in state: CLASS");
            if ($line =~ /^\s*--\*\*\s*\@/ ) {
              $self->_ChangeState('DOXYGEN');
            }
        }
        elsif ($self->{'_sState'} eq 'DOXYGEN')
        {
            $logger->debug("We are in state: DOXYGEN");
            # If there are no more comments, then reset the state to the previous state
            unless ($line =~ /^\s*--/)
            {
                # The general idea is we gather the whole doxygen comment in to an array and process
                # that array all at once in the _ProcessDoxygenCommentBlock.  This way we do not have
                # to artificially keep track of what type of comment block it is between each line
                # that we read from the file.
                $logger->debug("End of Doxygen Comment Block");
                $self->_ProcessDoxygenCommentBlock();
                $self->_RestoreState();
                $logger->debug("We are in state $self->{'_sState'}");
                if ($self->{'_sState'} eq 'NORMAL')
                {
                    # If this comment block is right next to a subroutine, lets make sure we
                    # handle that condition
                    if ($line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*->/ or $line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*=>/) { $self->_ChangeState('METHOD'); }
                }
                elsif ($self->{'_sState'} eq 'CLASS')
                {
                    #print "LINE SWITCHING STATE :::: $line\n";
                }
            }
        }

        if ($self->{'_sState'} eq 'NORMAL')
        {
            if ($line =~ /^\s*(\w+)\s*=\s*(?:assert\s+)?require\s+(?:['"][^'"]*['"]|\w+)(?:\s*\.\.\s*(?:['"][^'"]*['"]|\w+))*/)
            {
                my $sIncludeModule = $1;
                if (defined($sIncludeModule))
                {
                    push (@{$self->{'_hData'}->{'includes'}}, $sIncludeModule);
                }
            }
            elsif ($line =~ /^\s*VERSION\s*=\s*['"]([^'"]+)['"]\s*$/)
            {
                # VERSION = '0.25';
                my $version = $1;

                # remove () if we have them
                $version =~ s/[\'\"\(\)\;]//g;
                $self->{'_hData'}->{'filename'}->{'version'} = $version;
            }
            elsif ($line =~ /^\s*_MODULE_\s*=\s*['"]([^'"]+)['"]\s*$/ && $flags->{'isMoonClassDefinedInFile'} == 0)
            {
                $logger->debug("=== SWITCH MODULE ===");
                $self->_SwitchModule($1);
            }
            elsif ($flags->{'isMoonClassDefinedInFile'} == 0)
            {
                my $module = $self->{'_hData'}->{'filename'}->{'shortname'};
                $module =~ s{\.[^.]+$}{};
                $self->_SwitchModule($module);
            }
            elsif ($line =~ /^(\w+)\s*=\s*(?:"(.*?)"|(\d+)|{.*}|(\w+)|(\w+)\\)$/)
            {
                # Variables
                my $varName = $1;
                my $scope = substr($varName, 0, 1);

                if (defined $varName)
                {
                    my $sModuleName = $self->{'_sCurrentModule'};
                    if (!exists $self->{'_hData'}->{'module'}->{$sModuleName}->{attributes}->{$varName})
                        {
                            # only define the attribute if it was not yet defined by doxygen comment
                            my $attrDef = $self->{'_hData'}->{'module'}->{$sModuleName}->{attributes}->{$varName} = {
                                modifiers   => "static ",
                                state       => $scope eq "_" ? "private" : "public",
                            };
                            push(@{$self->{'_hData'}->{'module'}->{$sModuleName}->{attributeorder}}, $varName);
                        }

                }
                if ($line =~ /(--\*\*\s+\@.*$)/)
                {
                    # Lets look for an single in-line doxygen comment on a variable, array, or hash declaration
                    my $sBlock = $1;
                    push (@{$self->{'_aDoxygenBlock'}}, $sBlock);
                    $self->_ProcessDoxygenCommentBlock();
                }
            }
        }
        elsif ($self->{'_sState'} eq 'METHOD')
        {
            $self->_ProcessMoonMethod($uncommentLine, $line);
        }
        elsif ($self->{'_sState'} eq 'CLASS')
        {
            $self->_ProcessMoonClass($uncommentLine, $line);
        }
        elsif ($self->{'_sState'} eq 'DOXYGEN')
        {
            push (@{$self->{'_aDoxygenBlock'}}, $line);
        }
    }
}

# ----------------------------------------
# Private Methods
# ----------------------------------------

sub _SwitchModule
{
    my $self = shift;
    my $module = shift;

    $self->{'_sCurrentModule'} = $module;
    if (!exists $self->{'_hData'}->{'module'}->{$module})
    {
        push(@{$self->{'_hData'}->{'module'}->{'moduleorder'}}, $module);
        $self->{'_hData'}->{'module'}->{$module} = {
            modulename                   => $module,
            inherits                    => [],
            attributeorder              => [],
            subroutineorder             => [],
        };
    }

    return $self->{'_hData'}->{'module'}->{$module};
}


sub _ConvertToOfficialDoxygenSyntax
{
    #** @method private _ConvertToOfficialDoxygenSyntax ($line)
    # This method will check the current line for various unsupported doxygen comment blocks and convert them
    # to the type we support, #** @command.  The reason for this is so that we do not need to add them in
    # every if statement throughout the code.
    # @param line - required string (line of code)
    # @retval line - string (line of code)
    #*
    my $self = shift;
    my $line = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("=== Entering _ConvertToOfficialDoxygenSyntax ===");

    # This will match ## @command and convert it to #** @command
    if ($line =~ /^\s*--\s+\@/) { $line =~ s/^(\s*)--(\s+\@)/$1#\*\*$2/; }
    else {
        $logger->debug('Nothing to do, did not find any ## @');
    }
    return $line;
}

sub _GetIndentationLevel
{
    my $self = shift;
    my $line = shift;

    # Count leading spaces or tabs to determine the indentation level
    my $indentation_level = 0;

    if ($line =~ /^(\s*)/)
    {
        $indentation_level = length($1);
    }

    return $indentation_level;
}

sub _ProcessMoonMethod
{
    my $self = shift;
    my $line = shift;
    my $rawLine = shift;
    my $logger = $self->GetLogger($self);
    my $signature = 0;

    my $sModuleName = $self->{'_sCurrentModule'};

    if ($line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*->/ or $line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*=>/)
    {
        # We should keep track of the order in which the methods were written in the code so we can print
        # them out in the same order
        my $sName = $1;
        # Remove any leading or trailing whitespace from the name, just to be safe
        $sName =~ s/\s//g;
        # check if we have a prototype
        my ($method, $proto)  = split /[()]/, $sName;
        $sName = $method || "";
        $sName =~ s/\s//g;
        if (defined($proto)) {$proto =~ s/\s//g;}
        my $sProtoType = $proto || "";
        $logger->debug("Method Name: $sName");
        $logger->debug("Method Proto: $sProtoType");

        push (@{$self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutineorder'}}, $sName);
        $self->{'_sCurrentMethodName'} = $sName;
        $self->{'_sProtoType'} = $sProtoType;
        $signature = 1;
    }

    if (!defined($self->{'_sCurrentMethodName'})) {$self->{'_sCurrentMethodName'}='';}
    if (!defined($self->{'_sProtoType'})) {$self->{'_sProtoType'}='';}

    my $sMethodName = $self->{'_sCurrentMethodName'};
    my $sProtoType = $self->{'_sProtoType'};

    # Lets find out if this is a public or private method/function based on a naming standard
    if ($sMethodName =~ /^_/) { $self->{'_sCurrentMethodState'} = 'private'; }
    else { $self->{'_sCurrentMethodState'} = 'public'; }

    my $sMethodState = $self->{'_sCurrentMethodState'};
    $logger->debug("Method State: $sMethodState");

    # Track the indentation level to determine when we are inside the function body
    my $indentation_level = $self->_GetIndentationLevel($line);

     # We use the indentation level to determine if we are still inside the function block
    if ($indentation_level > $self->{'_currentIndentLevel'})
    {
        # We're still inside the function body, increasing indentation
        $self->{'_currentIndentLevel'} = $indentation_level;
    }
    elsif ($indentation_level < $self->{'_currentIndentLevel'} && !$signature)
    {
        # TODO : we might need to ignore the first empty line after the function
        # We are exiting the function body, as indentation has decreased
        $logger->debug("Exiting the function body");
        $self->_ChangeState('NORMAL');
        $self->RESETSUB();
        $self->{'_currentIndentLevel'} = $indentation_level;
    }

    # Record the current line for code output
    $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'code'} .= $rawLine;
    $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'length'}++;


     unless (defined $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'state'})
    {
        $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'state'} = $sMethodState;
    }
    # This is for function/method
    unless (defined $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'type'})
    {
        $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'type'} = "method";
    }
    $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'prototype'} = $sProtoType;
}



sub _ProcessMoonClass
{
    my $self = shift;
    my $line = shift;
    my $rawLine = shift;
    my $logger = $self->GetLogger($self);
    my $signature = 0;

    my $sModuleName = $self->{'_sCurrentModule'};

    if ($line =~ /^\s*class\s+(\w+)(\s+extends\s+\w+)?\s*$/)
    {
        my $className = $1;
        $signature = 1;
    }

    # Track the indentation level to determine when we are inside the function body
    my $indentation_level = $self->_GetIndentationLevel($line);

     # We use the indentation level to determine if we are still inside the function block
    if ($indentation_level > $self->{'_currentIndentLevel'})
    {
        # We're still inside the function body, increasing indentation
        $self->{'_currentIndentLevel'} = $indentation_level;
    }
    elsif ($indentation_level < $self->{'_currentIndentLevel'} && !$signature)
    {
        # TODO : we might need to ignore the first empty line after the function
        # We are exiting the function body, as indentation has decreased
        $logger->debug("Exiting the function body");
        $self->_ChangeState('NORMAL');
        $self->RESETSUB();
        $self->{'_currentIndentLevel'} = $indentation_level;
    }


}


sub _ProcessDoxygenCommentBlock
{
    #** @method private _ProcessDoxygenCommentBlock ()
    # This method will process an entire comment block in one pass, after it has all been gathered by the state machine
    #*
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _ProcessDoxygenCommentBlock ###");

    my @aBlock = @{$self->{'_aDoxygenBlock'}};

    # Lets clean up the array in the object now that we have a local copy as we will no longer need that.  We want to make
    # sure it is all clean and ready for the next comment block
    $self->RESETDOXY();

    my $sModuleName = $self->{'_sCurrentModule'};
    my $sSubState = '';

    # Lets grab the command line and put it in a variable for easier use
    my $sCommandLine = $aBlock[0];

    $sCommandLine =~ /^\s*--\*\*\s+\@([\w:]+)\s+(.*)/;
    my $sCommand = lc($1);
    my $sOptions = $2;

    if (!defined($sOptions))
    {
        # Lets check special case with a '.' or ',' e.g @winchhooks.
        $sCommandLine =~ /^\s*--\*\*\s+\@([\w:]+)([\.,].*)/;
        $sCommand = lc($1);
        $sOptions = "";
        if (defined($2))
        {
            $sOptions = "$2";
        }
    }

    # If the user entered @fn instead of @function, lets change it
    if ($sCommand eq "fn") { $sCommand = "function"; }

    # Lets find out what doxygen sub state we should be in
    if    ($sCommand eq 'file')     { $sSubState = 'DOXYFILE';     }
    elsif ($sCommand eq 'class')    { $sSubState = 'DOXYCLASS';    }
    elsif ($sCommand eq 'package')  { $sSubState = 'DOXYCLASS';    }
    elsif ($sCommand eq 'function') { $sSubState = 'DOXYFUNCTION'; }
    elsif ($sCommand eq 'method')   { $sSubState = 'DOXYMETHOD';   }
    elsif ($sCommand eq 'attr')     { $sSubState = 'DOXYATTR';     }
    elsif ($sCommand eq 'var')      { $sSubState = 'DOXYATTR';     }
    else { $sSubState = 'DOXYCOMMENT'; }
    $logger->debug("Substate is now $sSubState");

    if ($sSubState eq 'DOXYFILE' )
    {
        $logger->debug("Processing a Doxygen file object");
        # We need to remove the command line from this block
        shift @aBlock;
        $self->{'_hData'}->{'filename'}->{'details'} = $self->_RemoveMoonCommentFlags(\@aBlock);
    }
    elsif ($sSubState eq 'DOXYCOMMENT')
    {
        $logger->debug("Processing a Doxygen class object");
        # For extra comment blocks we need to add the command and option line back to the front of the array
        my $sMethodName = $self->{'_sCurrentMethodName'};
        if (defined $sMethodName)
        {
            $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'comments'} .= "\n";
            $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'comments'} .= $self->_RemoveMoonCommentFlags(\@aBlock);
            $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'comments'} .= "\n";
        }
        else
        {
            $self->{'_hData'}->{'module'}->{$sModuleName}->{'comments'} .= "\n";
            $self->{'_hData'}->{'module'}->{$sModuleName}->{'comments'} .= $self->_RemoveMoonCommentFlags(\@aBlock);
            $self->{'_hData'}->{'module'}->{$sModuleName}->{'comments'} .= "\n";
        }
    }
    elsif ($sSubState eq 'DOXYATTR')
    {
        # Process the doxygen header first then loop through the rest of the comments
        #my ($sState, $sAttrName, $sComments) = ($sOptions =~ /(?:(public|private)\s+)?([\$@%\*][\w:]+)\s+(.*)/);
        my ($sState, $modifiers, $modifiersLoop, $modifiersChoice, $fullSpec, $typeSpec, $typeName, $typeLoop, $pointerLoop, $typeCode, $sAttrName, $sComments) = ($sOptions =~ /(?:(public|protected|private)\s+)?(((static|const)\s+)*)((((\w+::)*\w+(\s+|\s*\*+\s+|\s+\*+\s*))|)([\$@%\*])([\w:]+))\s+(.*)/);
        if (defined $sAttrName)
        {
            my $attrDef = $self->{'_hData'}->{'module'}->{$sModuleName}->{'attributes'}->{$sAttrName} ||= {};
            if ($typeName)
            {
                $attrDef->{'type'} = $typeName;
            }
            else
            {
                $attrDef->{'type'} = $self->_ConvertTypeCode($typeCode);
            }
            if (defined $sState)
            {
                $attrDef->{'state'} = $sState;
            }
            if (defined $sComments)
            {
                $attrDef->{'comments'} = $sComments;
            }
            if (defined $modifiers)
            {
                $attrDef->{'modifiers'} = $modifiers;
            }
            ## We need to remove the command line from this block
            shift @aBlock;
            $attrDef->{'details'} = $self->_RemoveMoonCommentFlags(\@aBlock);
            push(@{$self->GetCurrentClass()->{attributeorder}}, $sAttrName);
        }
        else
        {
            print("invalid syntax for attribute: $sOptions\n"); # TODO
        }
    } # End DOXYATTR
    elsif ($sSubState eq 'DOXYFUNCTION' || $sSubState eq 'DOXYMETHOD')
    {
        # Process the doxygen header first then loop through the rest of the comments
        $sOptions =~ /^(.*?)\s*\(\s*(.*?)\s*\)/;
        $sOptions = $1;

        my $sParameters = $2;

        my @aOptions;
        my $state;
        my $sMethodName;

        if (defined $sOptions)
        {
            @aOptions = split(/\s+/, $sOptions);
            # State = Public/Private
            if ($aOptions[0] eq "public" || $aOptions[0] eq "private" || $aOptions[0] eq "protected")
            {
                $state = shift @aOptions;
            }
            $sMethodName = pop(@aOptions);
        }

        if ($sSubState eq "DOXYFUNCTION" && !grep(/^static$/, @aOptions))
        {
            unshift(@aOptions, "static");
        }


        unless (defined $sMethodName)
        {
            # If we are already in a subroutine and a user uses sloppy documentation and only does
            # #**@method in side the subroutine, then lets pull the current method name from the object.
            # If there is no method defined there, we should die.
            if (defined $self->{'_sCurrentMethodName'}) { $sMethodName = $self->{'_sCurrentMethodName'}; }
            else { die "Missing method name in $sCommand syntax"; }
        }

        # If we are not yet in a subroutine, lets keep track that we are now processing a subroutine and its name
        unless (defined $self->{'_sCurrentMethodName'}) { $self->{'_sCurrentMethodName'} = $sMethodName; }

        $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'returntype'} = join(" ", @aOptions);
        $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'type'} = $sCommand;
        if (defined $state)
        {
            $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'state'} = $state;
        }
        $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'parameters'} = $sParameters;
        # We need to remove the command line from this block
        shift @aBlock;
        $self->{'_hData'}->{'module'}->{$sModuleName}->{'subroutines'}->{$sMethodName}->{'details'} = $self->_RemoveMoonCommentFlags(\@aBlock);

    } # End DOXYFUNCTION || DOXYMETHOD

}


sub _RemoveMoonCommentFlags
{
    #** @method private _RemoveMoonCommentFlags ($aBlock)
    # This method will remove all of the comment marks "--" for our output to Doxygen.  If the line is
    # flagged for verbatim then lets not do anything.
    # @param aBlock - required array_ref (doxygen comment as an array of code lines)
    # @retval sBlockDetails - string (doxygen comments in one long string)
    #*
    my $self = shift;
    my $aBlock = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _RemoveMoonCommentFlags ###");

    my $sBlockDetails = "";
    my $iInVerbatimBlock = 0;
    foreach my $line (@$aBlock)
    {
        # Lets check for a verbatim command option like '# @verbatim'
        if ($line =~ /^\s*--\s*\@verbatim/)
        {
            $logger->debug("Found verbatim command");
            # We need to remove the comment marker from the '# @verbaim' line now since it will not be caught later
            $line =~ s/^\s*#\s*/ /;
            $iInVerbatimBlock = 1;
        }
        elsif ($line =~ /^\s*--\s*\@endverbatim/)
        {
            $logger->debug("Found endverbatim command");
            $iInVerbatimBlock = 0;
        }
        # Lets remove any doxygen command initiator
        $line =~ s/^\s*--\*\*\s*//;
        # Lets remove any doxygen command terminators
        $line =~ s/^\s*--\*\s*//;
        # Lets remove all of the Perl comment markers so long as we are not in a verbatim block
        # if ($iInVerbatimBlock == 0) { $line =~ s/^\s*#+//; }
        # Patch from Sebastian Rose to address spacing and indentation in code examples
        if ($iInVerbatimBlock == 0) { $line =~ s/^\s*--\s?//; }
        $logger->debug("code: $line");
        # Patch from Mihai MOJE to address method comments all on the same line.
        $sBlockDetails .= $line . "<br>";
        #$sBlockDetails .= $line;
    }
    $sBlockDetails =~ s/^([ \t]*\n)+//s;
    chomp($sBlockDetails);
    if ($sBlockDetails)
    {
        $sBlockDetails =~ s/^/ \*/gm;
        $sBlockDetails .= "\n";
    }
    return $sBlockDetails;
}

sub _PrintFilenameBlock
{
    #** @method private _PrintFilenameBlock ()
    # This method will print the filename section in appropriate doxygen syntax
    #*
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _PrintFilenameBlock ###");

     if (defined $self->{'_hData'}->{'filename'}->{'fullpath'})
     {
        print "/** \@file \"$self->{'_hData'}->{'filename'}->{'fullpath'}\"\n";
        if (defined $self->{'_hData'}->{'filename'}->{'details'}) { print "$self->{'_hData'}->{'filename'}->{'details'}\n"; }
        if (defined $self->{'_hData'}->{'filename'}->{'version'}) { print "\@version $self->{'_hData'}->{'filename'}->{'version'}\n"; }
        if (defined($PPR::ERROR))
        {
            print "\n";
            my $opt_offset = 0;
            my $line = $PPR::ERROR->line($opt_offset);
            my $source = $PPR::ERROR->source();
            print("Found error in the perl code around line: $line\n");
            print("\\verbatim\n$source\n\\endverbatim\n");
        }
        else
        {
          if ($self->{'_decommentOK'} == 0)
          {
              print("Found problem in decommenting the perl code\n");
          }
        }
        print "*/\n";
     }
}

sub _PrintIncludesBlock
{
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _PrintIncludeBlock ###");

    foreach my $include (@{$self->{'_hData'}->{'includes'}})
    {
        # print without extention for now
        print "\#include \"$include\"\n";
    }
    print "\n";
}

sub _PrintModuleBlock
{
    my $self = shift;
    my $sFullModule = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _PrintClassBlock ###");

    $sFullModule =~ /./;
    $sFullModule =~ /(.*)\:\:(\w+)$/;
    my $parent = $1;
    $sFullModule =~ /(.*)\:\:(\w+)$/;
    my $module = $2 || $sFullModule;

    my $usedModule = $sFullModule;

    if ($sFullModule eq "main")
    {
      $usedModule = $self->{'_hData'}->{'filename'}->{'shortname'};
      $usedModule =~ s/\.p[lm]$//;
      $usedModule =~ s/-/_/g;
      $usedModule =~ s/^/main_/;
    }

    print "/** \@class $usedModule\n";

    my $moduleDef = $self->{'_hData'}->{'module'}->{$sFullModule};

    my $details = $self->{'_hData'}->{'module'}->{$sFullModule}->{'details'};
    if (defined $details) { print "$details\n"; }

    my $comments = $self->{'_hData'}->{'module'}->{$sFullModule}->{'comments'};
    if (defined $comments) { print "$comments\n"; }

    print "\@nosubgrouping */\n";
    print "namespace $parent {\n" if ($parent);
    if ($sFullModule eq "main")
    {
        print "class $usedModule";
    }
    else
    {
        print "class $module";
    }

    print "\n{\n";
    print "public:\n";
}

sub _PrintMethodBlock
{
     #*
    my $self = shift;
    my $module = shift;
    my $method = shift;

    my $methodDef = $self->{'_hData'}->{'module'}->{$module}->{'subroutines'}->{$method};

    my $state = $methodDef->{state};
    my $type = $methodDef->{type};

    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _PrintMethodBlock ###");

    my $returntype = $methodDef->{'returntype'} || $type;
    my $parameters = $methodDef->{'parameters'} || "";
    my $prototype = $methodDef->{'prototype'} || "";

    if ($parameters =~ /^ *$/)
    {
        if ($prototype =~ /^ *$/)
        {
            print "/** \@fn $state $returntype $method\(\)\n";
        }
        else
        {
            print "/** \@fn $state $returntype $method\($prototype\)\n";
        }
    }
    else
    {
        print "/** \@fn $state $returntype $method\($parameters\)\n";
    }

    my $details = $methodDef->{'details'};
    if (defined $details) { print "$details\n"; }
    else { print "Undocumented Method\n"; }

    my $comments = $methodDef->{'comments'};
    if (defined $comments) { print "$comments\n"; }

    # Print collapsible source code block
    print "\@htmlonly[block]\n";
    print "<div id='codesection-$method' class='dynheader closed' style='cursor:pointer;' onclick='return toggleVisibility(this)'>\n";
    print "\t<img id='codesection-$method-trigger' src='closed.png' alt='open/close icon' style='display:inline'/> <b>Code:</b>\n";
    print "</div>\n";
    print "<div id='codesection-$method-summary' class='dyncontent' style='display:block;font-size:small;'>click to view</div>\n";
    print "<div id='codesection-$method-content' class='dyncontent' style='display: none;'>\n";
    print "\@endhtmlonly\n";

    print "\@code\n";
    print "\# Number of lines of code in $method: $methodDef->{'length'}\n";
    print "$methodDef->{'code'}\n";
    print "\@endcode \@htmlonly[block]\n";
    print "</div>\n";
    print "\@endhtmlonly */\n";

    if ($parameters =~ /^ *$/)
    {
        if ($prototype =~ /^ *$/)
        {
            print "$state $returntype $method\(\)\;\n";
        }
        else
        {
            print "$state $returntype $method\($prototype\)\;\n";
        }
    }
    else
    {
        print "$state $returntype $method\($parameters\)\;\n";
    }
}

sub PrintAll
{
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering PrintAll ###");

    binmode STDOUT, ":utf8";

    $self->_PrintFilenameBlock();
    $self->_PrintIncludesBlock();

    foreach my $module (@{$self->{'_hData'}->{'module'}->{'moduleorder'}})
    {
        my $moduleDef = $self->{'_hData'}->{'module'}->{$module};

        # skip the default main class unless we really have something to print
        if ($module eq "main" &&
            @{$moduleDef->{attributeorder}} == 0 &&
            @{$moduleDef->{subroutineorder}} == 0 &&
            (!defined $moduleDef->{details}) &&
            (!defined $moduleDef->{comments})
        )
        {
            next;
        }

        $self->_PrintModuleBlock($module);

        foreach my $sAttrName (@{$self->{'_hData'}->{'module'}->{$module}->{'attributeorder'}})
        {
            my $attrDef = $self->{'_hData'}->{'module'}->{$module}->{'attributes'}->{$sAttrName};

            my $sState = $attrDef->{'state'} || 'public';
            my $sComments = $attrDef->{'comments'};
            my $sDetails = $attrDef->{'details'};
            if (defined $sComments || defined $sDetails)
            {
                print "/**\n";
                if (defined $sComments)
                {
                    print " \* \@brief $sComments\n";
                }

                if ($sDetails)
                {
                    print " * \n".$sDetails;
                }

                print " */\n";
            }

            print("$sState:\n$attrDef->{modifiers}$sAttrName;\n\n");
        }

        foreach my $methodName (@{$self->{'_hData'}->{'module'}->{$module}->{'subroutineorder'}})
        {
            $self->_PrintMethodBlock($module, $methodName);
        }
        # Print end of class mark
        print "}\;\n";
        # print end of namespace if class is nested
        print "};\n" if ($module =~ /::/);
    }
}





1; # End of Doxygen::Filter::Moon
