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
    'DOXYFILE'       => 21,
    'DOXYCLASS'      => 22,
    'DOXYFUNCTION'   => 23,
    'DOXYMETHOD'     => 24,
    'DOXYCOMMENT'    => 25,
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
    my $class = ref($pkg) || $pkg;

    my $self = {};
    bless ($self, $class);

    $self->{'_iDebug'}           = 1;

    my $logger = $self->GetLogger($self);

    $logger->debug("=== Entering New ===");
    $logger->info("Class : $class\n");

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
    $self->{'_iOpenBrace'}          = 0;
    $self->{'_iCloseBrace'}         = 0;
    $self->{'_sCurrentMethodName'}  = undef;
    $self->{'_sCurrentMethodType'}  = undef;
    $self->{'_sCurrentMethodState'} = undef;
}

sub RESETFILE  { my $self = shift; $self->{'_aRawFileData'}   = []; $self->{'_aUncommentFileData'}   = [];   }

sub RESETCLASS
{
    my $self = shift;
    #$self->{'_sCurrentClass'}  = 'main';
    #push (@{$self->{'_hData'}->{'class'}->{'classorder'}}, 'main');
    $self->_SwitchClass('main');
}

sub RESETDOXY  { shift->{'_aDoxygenBlock'}  = [];    }

sub _init
{
    my $self = shift;
    $self->{'_sState'}          = undef;
    $self->{'_sPreviousState'}  = [];
    $self->_ChangeState('NORMAL');
    $self->{'_hData'}           = {};
    $self->RESETFILE();
    $self->RESETCLASS();
    $self->RESETSUB();
    $self->RESETDOXY();
}

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


sub ProcessFile
{
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("=== Entering ReadFile ===");

    $self->{'_hData'}->{'lineNo'} = 0;
    foreach my $line (@{$self->{'_aRawFileData'}})
    {
        my $uncommentLine = $self->{'_aUncommentFileData'}[$self->{'_hData'}->{'lineNo'}];
        $self->{'_hData'}->{'lineNo'}++;

        # Convert syntax block header to supported doxygen form, if this line is a header
        $line = $self->_ConvertToOfficialDoxygenSyntax($line);

        if ($self->{'_sState'} eq 'NORMAL')
        {
            $logger->debug("We are in state: NORMAL");
            if ($line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*->/ or $line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*=>/) { $self->_ChangeState('METHOD');  }
            elsif ($line =~ /^\s*#\*\*\s*\@/) { $self->_ChangeState('DOXYGEN'); }
        }
        elsif ($self->{'_sState'} eq 'METHOD')
        {
            $logger->debug("We are in state: METHOD");
            if ($line =~ /^\s*#\*\*\s*\@/ ) { $self->_ChangeState('DOXYGEN'); }
        }

        if ($self->{'_sState'} eq 'NORMAL')
        {
            if ($line =~ /^\s*(\w+)\s*=\s*(?:assert\s+)?require\s+(?:['"][^'"]*['"]|\w+)(?:\s*\.\.\s*(?:['"][^'"]*['"]|\w+))*/)
            {
                my $sIncludeModule = $1;
                if (!defined($sIncludeModule))
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
        }


    }


}

# ----------------------------------------
# Private Methods
# ----------------------------------------

sub _SwitchClass
{
    my $self = shift;
    my $class = shift;

    $self->{'_sCurrentClass'} = $class;
    if (!exists $self->{'_hData'}->{'class'}->{$class})
    {
        push(@{$self->{'_hData'}->{'class'}->{'classorder'}}, $class);
        $self->{'_hData'}->{'class'}->{$class} = {
            classname                   => $class,
            inherits                    => [],
            attributeorder              => [],
            subroutineorder             => [],
        };
    }

    return $self->{'_hData'}->{'class'}->{$class};
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

sub _ProcessMoonMethod
{
    my $self = shift;
    my $line = shift;
    my $rawLine = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("=== Entering _ProcessPerlMethod ===");

    my $sClassName = $self->{'_sCurrentClass'};

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

        push (@{$self->{'_hData'}->{'class'}->{$sClassName}->{'subroutineorder'}}, $sName);
        $self->{'_sCurrentMethodName'} = $sName;
        $self->{'_sProtoType'} = $sProtoType;
    }
}



1; # End of Doxygen::Filter::Moon
